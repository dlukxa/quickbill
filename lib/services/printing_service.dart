import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import '../utils/region_utils.dart';
import '../utils/formatters.dart';
import '../providers/preference_provider.dart';
import 'pdf_service.dart';
import 'sinhala_search_service.dart';
import 'receipt_image_generator.dart';
import 'receipt_raster_converter.dart';
import 'package:intl/intl.dart';

class PrinterTestResult {
  final bool success;
  final String message;

  PrinterTestResult({required this.success, required this.message});
}

class PrintingService {
  PrintingService._();
  static final PrintingService instance = PrintingService._();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  // ==========================================
  // BLUETOOTH THERMAL PRINTER (Android SPP)
  // ==========================================

  Future<List<BluetoothDevice>> getDevices() async {
    if (!Platform.isAndroid) return [];
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint('Bluetooth not supported on this platform: $e');
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (!Platform.isAndroid) return false;
    try {
      bool? isConnected = await _bluetooth.isConnected;
      if (isConnected == true) {
        await _bluetooth.disconnect();
      }
      
      await _bluetooth.connect(device);
      return true;
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (!Platform.isAndroid) return;
    try {
      await _bluetooth.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  Future<bool> isConnected() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _bluetooth.isConnected ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if any receipt content contains Sinhala characters or non-English typography requiring raster rendering.
  bool containsSinhala(Sale sale, List<SaleItem> items, AppSettings settings) {
    // If receipt language is Sinhala, Tamil, or Bilingual, raster rendering is required for thermal printers
    if (settings.receiptLanguage != 'en') return true;
    if (settings.receiptTemplate == 'sri_lankan_retail') return true;
    if (SinhalaSearchService.isSinhala(settings.shopName)) return true;
    if (SinhalaSearchService.isSinhala(settings.shopAddress)) return true;
    if (SinhalaSearchService.isSinhala(settings.receiptFooter)) return true;
    if (sale.cashierName != null && SinhalaSearchService.isSinhala(sale.cashierName!)) return true;
    if (sale.customerName != null && SinhalaSearchService.isSinhala(sale.customerName!)) return true;
    for (final item in items) {
      if (SinhalaSearchService.isSinhala(item.productName)) return true;
    }
    return false;
  }

  // ==========================================
  // UNIFIED MULTI-PRINTER DISPATCHER
  // ==========================================

  /// Unified receipt printing method that routes according to configured printer type
  Future<void> printReceiptUnified(
    Sale sale,
    List<SaleItem> items,
    AppSettings settings, {
    double? cashReceived,
    double? change,
  }) async {
    // 1. Desktop handling (macOS / Windows / Linux)
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      if (settings.printerConnectionType.toLowerCase() == 'network') {
        await printNetworkReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
      } else {
        await printDesktopReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
      }
      return;
    }

    // 2. Mobile handling (Android / iOS)
    final connectionType = settings.printerConnectionType.toLowerCase();

    switch (connectionType) {
      case 'network':
        await printNetworkReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
        break;

      case 'system':
        await printDesktopReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
        break;

      case 'bluetooth':
      default:
        final bool btConnected = await isConnected();
        if (btConnected) {
          await printReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
        } else {
          // Fallback to system print dialog if Bluetooth is not connected
          await PdfService.instance.generateReceipt(
            sale,
            items,
            settings: settings,
            cashReceived: cashReceived,
            change: change,
          );
        }
        break;
    }
  }

  // ==========================================
  // DESKTOP / DIRECT WINDOWS PRINTING
  // ==========================================

  Future<void> printDesktopReceipt(
    Sale sale,
    List<SaleItem> items,
    AppSettings settings, {
    double? cashReceived,
    double? change,
  }) async {
    try {
      Uint8List pdfBytes;
      if (containsSinhala(sale, items, settings)) {
        // Render via Flutter high-resolution offscreen widget for 100% Sinhala Unicode shaping
        final pngBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
          sale: sale,
          items: items,
          settings: settings,
          cashReceived: cashReceived,
          change: change,
        );
        final doc = await PdfService.instance.buildImageReceiptDocument(
          pngBytes,
          is58mm: settings.is58mm,
        );
        pdfBytes = await doc.save();
      } else {
        final doc = await PdfService.instance.buildReceiptDocument(
          sale,
          items,
          settings: settings,
          cashReceived: cashReceived,
          change: change,
        );
        pdfBytes = await doc.save();
      }

      if (settings.selectedPrinterName != null && settings.selectedPrinterName!.isNotEmpty) {
        final printers = await Printing.listPrinters();
        final match = printers.where((p) => p.name == settings.selectedPrinterName || p.url == settings.selectedPrinterName);
        if (match.isNotEmpty) {
          await Printing.directPrintPdf(
            printer: match.first,
            onLayout: (format) async => pdfBytes,
            name: 'Receipt_${sale.billNumber}',
            dynamicLayout: false,
          );
          return;
        }
      }

      // Fallback to system layout dialog if specific printer not found
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Receipt_${sale.billNumber}',
        dynamicLayout: false,
      );
    } catch (e) {
      debugPrint('Desktop direct print error: $e');
    }
  }

  // ==========================================
  // WI-FI / NETWORK (LAN) RAW TCP SOCKET PRINTER
  // ==========================================

  Future<void> printNetworkReceipt(
    Sale sale,
    List<SaleItem> items,
    AppSettings settings, {
    double? cashReceived,
    double? change,
  }) async {
    Socket? socket;
    try {
      final ip = settings.printerIpAddress.trim();
      final port = settings.printerPort;

      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));

      final int targetWidth = settings.is58mm ? 384 : 576;
      final pngBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sale,
        items: items,
        settings: settings,
        cashReceived: cashReceived,
        change: change,
      );

      final escPosBytes = ReceiptRasterConverter.instance.convertPngToEscPosRaster(
        pngBytes,
        targetWidth: targetWidth,
      );
      socket.add(escPosBytes);

      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 300));
      await socket.close();
    } catch (e) {
      debugPrint('Network printer error ($e). Falling back to system print dialog.');
      try {
        await socket?.close();
      } catch (_) {}
      await printDesktopReceipt(
        sale,
        items,
        settings,
        cashReceived: cashReceived,
        change: change,
      );
    }
  }

  /// Test network printer connectivity and print a sample test slip
  Future<PrinterTestResult> testNetworkPrinter({
    required String ip,
    required int port,
    String paperSize = '80mm',
  }) async {
    Socket? socket;
    try {
      final cleanIp = ip.trim();
      socket = await Socket.connect(cleanIp, port, timeout: const Duration(seconds: 3));

      // Build a test sale receipt
      final testSale = Sale(
        billNumber: 'TEST-001',
        total: 150.0,
        itemsCount: 1,
        paymentMethod: 'cash',
        cashierName: 'Admin',
        createdAt: DateTime.now(),
      );
      final List<SaleItem> testItems = [
        SaleItem(
          saleId: 0,
          productId: 0,
          productName: 'කිරි තේ / Milk Tea',
          quantity: 1,
          unitPrice: 150.0,
          costPrice: 80.0,
          total: 150.0,
        ),
      ];
      final testSettings = AppSettings(
        shopName: 'QuickBill Network Test',
        shopAddress: 'LAN / Wi-Fi Thermal Printer Test',
        shopPhone: '',
        lowStockThreshold: 10,
        receiptFooter: 'මුද්‍රණ පරීක්ෂාව සාර්ථකයි! / Test OK!',
        languageCode: 'en',
        regionCode: 'LK',
        businessType: 'Retail',
        isSetupComplete: true,
        autoSync: false,
        entityCode: '1',
        printerPaperSize: paperSize,
      );

      final int targetWidth = paperSize == '58mm' ? 384 : 576;
      final pngBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: testSale,
        items: testItems,
        settings: testSettings,
      );

      final escPosBytes = ReceiptRasterConverter.instance.convertPngToEscPosRaster(
        pngBytes,
        targetWidth: targetWidth,
      );
      socket.add(escPosBytes);

      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 300));
      await socket.close();

      return PrinterTestResult(
        success: true,
        message: 'Successfully connected to $cleanIp:$port and printed test receipt!',
      );
    } catch (e) {
      try {
        await socket?.close();
      } catch (_) {}
      return PrinterTestResult(
        success: false,
        message: 'Failed to connect to printer at $ip:$port ($e). Please verify IP & Wi-Fi connection.',
      );
    }
  }

  // ==========================================
  // DIRECT BLUETOOTH RECEIPT METHODS
  // ==========================================

  Future<void> printReceipt(
    Sale sale,
    List<SaleItem> items,
    AppSettings settings, {
    double? cashReceived,
    double? change,
  }) async {
    bool? isConnected = await _bluetooth.isConnected;
    if (isConnected != true) return;

    // If Sinhala Unicode is present, render via high-contrast raster bitmap
    if (containsSinhala(sale, items, settings)) {
      await _printRasterReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
      return;
    }

    // Direct ESC/POS text mode for pure ASCII receipts
    await _printTextReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
  }

  Future<void> _printRasterReceipt(
    Sale sale,
    List<SaleItem> items,
    AppSettings settings, {
    double? cashReceived,
    double? change,
  }) async {
    try {
      final int targetWidth = settings.is58mm ? 384 : 576;
      final pngBytes = await ReceiptImageGenerator.instance.generateReceiptImage(
        sale: sale,
        items: items,
        settings: settings,
        cashReceived: cashReceived,
        change: change,
      );

      final monoPng = ReceiptRasterConverter.instance.convertToMonochromePng(
        pngBytes,
        targetWidth: targetWidth,
      );

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/rcpt_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(monoPng);

      try {
        await _bluetooth.printImage(tempFile.path);
      } catch (btErr) {
        debugPrint('Bluetooth printImage failed ($btErr). Attempting writeBytes ESC/POS raster fallback.');
        final escPosRaster = ReceiptRasterConverter.instance.convertPngToEscPosRaster(
          pngBytes,
          targetWidth: targetWidth,
        );
        await _bluetooth.writeBytes(Uint8List.fromList(escPosRaster));
      }

      await Future.delayed(const Duration(milliseconds: 300));
      try {
        await tempFile.delete();
      } catch (_) {}

      await _bluetooth.write('\n\n\n');
      await _bluetooth.paperCut();
    } catch (e) {
      debugPrint('Error printing raster Sinhala receipt: $e. Falling back to ESC/POS text mode.');
      await _printTextReceipt(sale, items, settings, cashReceived: cashReceived, change: change);
    }
  }

  Future<void> _printTextReceipt(
    Sale sale,
    List<SaleItem> items,
    AppSettings settings, {
    double? cashReceived,
    double? change,
  }) async {
    final bool is58mm = settings.is58mm;
    final String divider = is58mm ? '--------------------------------\n' : '------------------------------------------------\n';
    final String doubleDivider = is58mm ? '================================\n' : '================================================\n';

    // Parse effective cash received & change if not passed
    double? effectiveCashReceived = cashReceived;
    double? effectiveChange = change;
    if (effectiveCashReceived == null && sale.paymentMethod.toLowerCase() == 'cash' && sale.notes != null) {
      final cashMatch = RegExp(r'(?:Cash|Received):\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (cashMatch != null) effectiveCashReceived = double.tryParse(cashMatch.group(1)!);
      final changeMatch = RegExp(r'Change:\s*([0-9.]+)', caseSensitive: false).firstMatch(sale.notes!);
      if (changeMatch != null) effectiveChange = double.tryParse(changeMatch.group(1)!);
    }
    if (effectiveCashReceived != null && effectiveChange == null) {
      effectiveChange = (effectiveCashReceived - sale.total).clamp(0.0, double.infinity);
    }

    // 1. STORE HEADER
    await _bluetooth.write(divider);
    await _bluetooth.printCustom(settings.shopName.toUpperCase(), 2, 1);
    if (settings.shopAddress.isNotEmpty) {
      await _bluetooth.printCustom(settings.shopAddress, 1, 1);
    }
    if (settings.shopPhone.isNotEmpty) {
      await _bluetooth.printCustom('Tel: ${settings.shopPhone}', 1, 1);
    }
    await _bluetooth.write(divider);

    // 2. METADATA
    final dateStr = DateFormat('dd/MM/yyyy  HH:mm').format(sale.createdAt);
    await _bluetooth.printLeftRight('Bill No:', sale.billNumber, 1);
    await _bluetooth.printLeftRight('Date:', dateStr, 1);
    if (sale.cashierName != null && sale.cashierName!.isNotEmpty) {
      await _bluetooth.printLeftRight('Cashier:', sale.cashierName!, 1);
    }
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      await _bluetooth.printLeftRight('Customer:', sale.customerName!, 1);
    }
    await _bluetooth.write(divider);

    // 3. TABLE HEADER
    if (is58mm) {
      await _bluetooth.printCustom('ITEM            QTY PRICE  TOTAL', 1, 0);
    } else {
      await _bluetooth.printCustom('ITEM                      QTY   PRICE     TOTAL', 1, 0);
    }
    await _bluetooth.write(divider);

    // 4. ITEMS
    for (var item in items) {
      final qty = item.soldQuantity ?? item.quantity;
      final qtyStr = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1);
      final priceStr = item.unitPrice.toStringAsFixed(2);
      final totalStr = item.total.toStringAsFixed(2);

      await _bluetooth.printCustom(item.productName, 1, 0);
      await _bluetooth.printLeftRight(
        '  $qtyStr x $priceStr',
        totalStr,
        1,
      );
      if (item.discount > 0) {
        await _bluetooth.printCustom('   (Disc: -${item.discount.toStringAsFixed(2)})', 0, 0);
      }
    }

    await _bluetooth.write(divider);

    // 5. TOTALS & SUMMARY
    double totalPcs = items.fold(0.0, (sum, i) => sum + (i.soldQuantity ?? i.quantity));
    final pcsStr = totalPcs == totalPcs.roundToDouble() ? totalPcs.toInt().toString() : totalPcs.toStringAsFixed(1);
    await _bluetooth.printLeftRight('Items: ${items.length}', 'Pcs: $pcsStr', 1);

    final subtotalGross = items.fold(0.0, (sum, item) => sum + item.total + item.discount);
    await _bluetooth.printLeftRight('Subtotal:', subtotalGross.toStringAsFixed(2), 1);

    final totalDiscount = items.fold(0.0, (sum, item) => sum + item.discount) + sale.discount;
    if (totalDiscount > 0) {
      await _bluetooth.printLeftRight('Total Savings (සම්පූර්ණ ලාභය):', '-${totalDiscount.toStringAsFixed(2)}', 1);
    }
    if (sale.tax > 0) {
      await _bluetooth.printLeftRight('Tax (VAT):', sale.tax.toStringAsFixed(2), 1);
    }
    if (sale.serviceCharge > 0) {
      await _bluetooth.printLeftRight('Service Charge:', sale.serviceCharge.toStringAsFixed(2), 1);
    }

    // 6. GRAND TOTAL
    await _bluetooth.write(doubleDivider);
    await _bluetooth.printLeftRight('TOTAL:', Formatters.currency(sale.total), 2);
    await _bluetooth.write(doubleDivider);

    // 7. PAYMENT DETAILS
    await _bluetooth.printLeftRight('Payment:', sale.paymentMethod.toUpperCase(), 1);
    if (sale.paymentMethod.toLowerCase() == 'cash' && effectiveCashReceived != null) {
      await _bluetooth.printLeftRight('Cash Received:', effectiveCashReceived.toStringAsFixed(2), 1);
      await _bluetooth.printLeftRight('Change / Balance:', (effectiveChange ?? 0.0).toStringAsFixed(2), 1);
    }
    await _bluetooth.write(divider);

    // 8. FOOTER
    if (settings.receiptFooter.isNotEmpty) {
      await _bluetooth.printCustom(settings.receiptFooter, 1, 1);
    }
    await _bluetooth.printCustom('Powered by QuickBill POS', 0, 1);
    await _bluetooth.printCustom('* ${sale.billNumber} *', 1, 1);
    await _bluetooth.write('\n\n\n'); // Feed paper
    await _bluetooth.paperCut();
  }

  Future<void> printPurchaseOrder(Purchase purchase, AppSettings settings, Supplier? supplier) async {
    final isConnected = await _bluetooth.isConnected;
    if (isConnected != true) {
      throw Exception('Printer not connected');
    }

    await _bluetooth.printCustom(settings.shopName, 3, 1);
    if (settings.shopAddress.isNotEmpty) {
      await _bluetooth.printCustom(settings.shopAddress, 1, 1);
    }
    if (settings.shopPhone.isNotEmpty) {
      await _bluetooth.printCustom(settings.shopPhone, 1, 1);
    }
    await _bluetooth.printCustom('--------------------------------', 1, 1);
    await _bluetooth.printCustom('PURCHASE ORDER', 2, 1);
    await _bluetooth.printCustom('--------------------------------', 1, 1);
    await _bluetooth.printLeftRight('PO No:', '${purchase.id ?? "Draft"}', 1);
    await _bluetooth.printLeftRight('Date:', purchase.date.toString().substring(0, 16), 1);
    await _bluetooth.printLeftRight('Status:', purchase.status, 1);
    
    if (supplier != null) {
      await _bluetooth.printCustom('--------------------------------', 1, 1);
      await _bluetooth.printCustom('SUPPLIER DETAILS', 1, 1);
      await _bluetooth.printLeftRight('Name:', supplier.name, 1);
      if (supplier.phone != null) {
        await _bluetooth.printLeftRight('Phone:', supplier.phone!, 1);
      }
    }

    await _bluetooth.printCustom('--------------------------------', 1, 1);
    for (final item in purchase.items) {
      await _bluetooth.printCustom(item.productName, 1, 0);
      await _bluetooth.printLeftRight(
        '${item.quantity} x ${item.costPrice.toStringAsFixed(2)}',
        (item.quantity * item.costPrice).toStringAsFixed(2),
        1,
      );
    }
    
    await _bluetooth.printCustom('--------------------------------', 1, 1);
    await _bluetooth.printLeftRight('TOTAL:', '${globalAppRegion.currencySymbol} ${purchase.totalAmount.toStringAsFixed(2)}', 2);
    await _bluetooth.printCustom('--------------------------------', 1, 1);
    
    if (purchase.notes != null && purchase.notes!.isNotEmpty) {
      await _bluetooth.printCustom('Notes: ${purchase.notes}', 1, 0);
      await _bluetooth.printCustom('--------------------------------', 1, 1);
    }
    
    await _bluetooth.printCustom('Powered by QuickBill POS', 0, 1);
    await _bluetooth.write('\n\n\n');
    await _bluetooth.paperCut();
  }
}
