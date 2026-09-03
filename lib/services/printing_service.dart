import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import '../utils/region_utils.dart';
import '../providers/preference_provider.dart';
import 'pdf_service.dart';
import 'sinhala_search_service.dart';

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

  /// Checks if any receipt content contains Sinhala characters requiring raster rendering.
  bool containsSinhala(Sale sale, List<SaleItem> items, AppSettings settings) {
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
  Future<void> printReceiptUnified(Sale sale, List<SaleItem> items, AppSettings settings) async {
    // 1. Desktop handling (macOS / Windows / Linux)
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      if (settings.printerConnectionType.toLowerCase() == 'network') {
        await printNetworkReceipt(sale, items, settings);
      } else {
        await printDesktopReceipt(sale, items, settings);
      }
      return;
    }

    // 2. Mobile handling (Android / iOS)
    final connectionType = settings.printerConnectionType.toLowerCase();

    switch (connectionType) {
      case 'network':
        await printNetworkReceipt(sale, items, settings);
        break;

      case 'system':
        await printDesktopReceipt(sale, items, settings);
        break;

      case 'bluetooth':
      default:
        final bool btConnected = await isConnected();
        if (btConnected) {
          await printReceipt(sale, items, settings);
        } else {
          // Fallback to system print dialog if Bluetooth is not connected
          await PdfService.instance.generateReceipt(sale, items, settings: settings);
        }
        break;
    }
  }

  // ==========================================
  // DESKTOP / DIRECT WINDOWS PRINTING
  // ==========================================

  Future<void> printDesktopReceipt(Sale sale, List<SaleItem> items, AppSettings settings) async {
    try {
      final doc = await PdfService.instance.buildReceiptDocument(sale, items, settings: settings);
      final pdfBytes = await doc.save();

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

  Future<void> printNetworkReceipt(Sale sale, List<SaleItem> items, AppSettings settings) async {
    Socket? socket;
    try {
      final ip = settings.printerIpAddress.trim();
      final port = settings.printerPort;

      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));

      final doc = await PdfService.instance.buildReceiptDocument(sale, items, settings: settings);
      final pdfBytes = await doc.save();

      // Convert PDF to 203 DPI PNG bitmap
      await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 203)) {
        final pngBytes = await page.toPng();
        final escPosBytes = _convertPngToEscPosRaster(pngBytes);
        socket.add(escPosBytes);
      }

      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 300));
      await socket.close();
    } catch (e) {
      debugPrint('Network printer error ($e). Falling back to system print dialog.');
      try {
        await socket?.close();
      } catch (_) {}
      await PdfService.instance.generateReceipt(sale, items, settings: settings);
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

      final doc = await PdfService.instance.buildReceiptDocument(testSale, testItems, settings: testSettings);
      final pdfBytes = await doc.save();

      await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 203)) {
        final pngBytes = await page.toPng();
        final escPosBytes = _convertPngToEscPosRaster(pngBytes);
        socket.add(escPosBytes);
      }

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

  /// Converts PNG bytes to 1-bit monochrome ESC/POS raster bitmap command (`GS v 0`)
  List<int> _convertPngToEscPosRaster(Uint8List pngBytes) {
    final image = img.decodeImage(pngBytes);
    if (image == null) return [];

    final int width = image.width;
    final int height = image.height;
    final int widthBytes = (width + 7) ~/ 8;

    final List<int> bytes = [];

    // Initialize printer: ESC @ (0x1B, 0x40)
    bytes.addAll([0x1B, 0x40]);

    // Set line spacing to 0: ESC 3 0 (0x1B, 0x33, 0x00)
    bytes.addAll([0x1B, 0x33, 0x00]);

    // ESC/POS raster bitmap command: GS v 0 0 xL xH yL yH d1...dk
    final int xL = widthBytes % 256;
    final int xH = widthBytes ~/ 256;
    final int yL = height % 256;
    final int yH = height ~/ 256;

    bytes.addAll([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);

    for (int y = 0; y < height; y++) {
      for (int xByte = 0; xByte < widthBytes; xByte++) {
        int byteVal = 0;
        for (int bit = 0; bit < 8; bit++) {
          final int x = xByte * 8 + bit;
          if (x < width) {
            final pixel = image.getPixel(x, y);
            final lum = img.getLuminance(pixel);
            // In ESC/POS raster: 1 = Black dot, 0 = White dot
            if (lum < 160) {
              byteVal |= (1 << (7 - bit));
            }
          }
        }
        bytes.add(byteVal);
      }
    }

    // Reset line spacing: ESC 2 (0x1B, 0x32)
    bytes.addAll([0x1B, 0x32]);

    // Feed paper: ESC d 4 (0x1B, 0x64, 0x04)
    bytes.addAll([0x1B, 0x64, 0x04]);

    // Partial paper cut: GS V 66 0 (0x1D, 0x56, 0x42, 0x00)
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  // ==========================================
  // DIRECT BLUETOOTH RECEIPT METHODS
  // ==========================================

  Future<void> printReceipt(Sale sale, List<SaleItem> items, AppSettings settings) async {
    bool? isConnected = await _bluetooth.isConnected;
    if (isConnected != true) return;

    // If Sinhala Unicode is present, render via high-contrast raster bitmap
    if (containsSinhala(sale, items, settings)) {
      await _printRasterReceipt(sale, items, settings);
      return;
    }

    // Direct ESC/POS text mode for pure ASCII receipts
    await _printTextReceipt(sale, items, settings);
  }

  Future<void> _printRasterReceipt(Sale sale, List<SaleItem> items, AppSettings settings) async {
    try {
      final doc = await PdfService.instance.buildReceiptDocument(sale, items, settings: settings);
      final pdfBytes = await doc.save();
      final tempDir = await getTemporaryDirectory();

      await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 203)) {
        final pngBytes = await page.toPng();
        final tempFile = File('${tempDir.path}/rcpt_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(pngBytes);
        await _bluetooth.printImage(tempFile.path);
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      await _bluetooth.write('\n\n\n');
      await _bluetooth.paperCut();
    } catch (e) {
      debugPrint('Error printing raster Sinhala receipt: $e. Falling back to ESC/POS text mode.');
      await _printTextReceipt(sale, items, settings);
    }
  }

  Future<void> _printTextReceipt(Sale sale, List<SaleItem> items, AppSettings settings) async {
    // ESC/POS receipt generation
    await _bluetooth.write('--------------------------------\n');
    await _bluetooth.printCustom(settings.shopName, 3, 1); // Size 3, Align Center
    if (settings.shopAddress.isNotEmpty) {
      await _bluetooth.printCustom(settings.shopAddress, 1, 1);
    }
    if (settings.shopPhone.isNotEmpty) {
      await _bluetooth.printCustom(settings.shopPhone, 1, 1);
    }
    await _bluetooth.printCustom('--------------------------------', 1, 1);
    
    await _bluetooth.printLeftRight('Bill No:', sale.billNumber, 1);
    await _bluetooth.printLeftRight('Date:', sale.createdAt.toString().substring(0, 16), 1);
    if (sale.cashierName != null && sale.cashierName!.isNotEmpty) {
      await _bluetooth.printLeftRight('Cashier:', sale.cashierName!, 1);
    }
    await _bluetooth.write('--------------------------------\n');

    for (var item in items) {
      await _bluetooth.printCustom(item.productName, 1, 0);
      await _bluetooth.printLeftRight(
        '${item.quantity} x ${globalAppRegion.currencySymbol} ${item.unitPrice.toStringAsFixed(2)}',
        '${globalAppRegion.currencySymbol} ${item.total.toStringAsFixed(2)}',
        1,
      );
    }

    await _bluetooth.printCustom('--------------------------------', 1, 1);
    await _bluetooth.printLeftRight('SUBTOTAL:', '${globalAppRegion.currencySymbol} ${sale.subtotal.toStringAsFixed(2)}', 1);
    if (sale.discount > 0) {
      await _bluetooth.printLeftRight('DISCOUNT:', '-${globalAppRegion.currencySymbol} ${sale.discount.toStringAsFixed(2)}', 1);
    }
    await _bluetooth.printLeftRight('TOTAL:', '${globalAppRegion.currencySymbol} ${sale.total.toStringAsFixed(2)}', 2);
    await _bluetooth.printCustom('--------------------------------', 1, 1);
    
    if (settings.receiptFooter.isNotEmpty) {
      await _bluetooth.printCustom(settings.receiptFooter, 1, 1);
    }
    await _bluetooth.printCustom('Powered by QuickBill POS', 0, 1);
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
