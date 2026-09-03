import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import '../utils/formatters.dart';

class ExportService {
  static final ExportService instance = ExportService._internal();
  ExportService._internal();

  /// Export all sales for a branch to CSV
  Future<void> exportSales(int branchId) async {
    final sales = await DatabaseService.instance.getAllSales(branchId);
    if (sales.isEmpty) return;
    await exportSalesToCsv(sales, sales.first.createdAt, sales.last.createdAt);
  }

  /// Export all products for a branch to CSV
  Future<void> exportProducts(int branchId) async {
    final products = await DatabaseService.instance.getAllProducts(branchId);
    if (products.isEmpty) return;

    final List<List<dynamic>> rows = [];
    rows.add(['Name', 'Barcode', 'Category', 'Unit', 'Price', 'Cost Price', 'Current Stock']);

    for (var p in products) {
      rows.add([
        p.name,
        p.baseBarcode ?? '',
        p.category ?? 'Uncategorized',
        p.unit,
        p.price,
        p.costPrice ?? 0.0,
        p.calculatedStock,
      ]);
    }

    await _saveOrShareCsv(rows, 'inventory_export_$branchId');
  }

  /// Export all customers for a branch to CSV
  Future<void> exportCustomers(int branchId) async {
    final customers = await DatabaseService.instance.getAllCustomers(branchId);
    if (customers.isEmpty) return;

    final List<List<dynamic>> rows = [];
    rows.add(['Name', 'Phone', 'Address', 'Total Debt', 'Registered Date']);

    for (var c in customers) {
      rows.add([
        c.name,
        c.phone ?? '',
        c.address ?? '',
        c.totalDebt,
        DateFormat('dd MMM yyyy').format(c.createdAt),
      ]);
    }

    await _saveOrShareCsv(rows, 'customers_export_$branchId');
  }

  /// Original method used by SalesReportScreen
  Future<void> exportSalesToCsv(List<Sale> sales, DateTime start, DateTime end) async {
    final List<List<dynamic>> rows = [];
    rows.add(['Date', 'Bill Number', 'Customer', 'Total Amount', 'Discount', 'Payment Method', 'Items']);

    for (var sale in sales) {
      final itemsText = sale.items
          .map((i) => '${i.productName} (${Formatters.quantity(i.quantity)})')
          .join('; ');
      
      rows.add([
        DateFormat('dd MMM yyyy HH:mm').format(sale.createdAt),
        sale.billNumber,
        sale.customerName ?? 'Guest',
        sale.total,
        sale.discount,
        sale.paymentMethod.toUpperCase(),
        itemsText,
      ]);
    }

    await _saveOrShareCsv(rows, 'sales_report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}');
  }

  /// Export refunds for a date range to CSV
  Future<void> exportRefundsToCsv(List<Map<String, dynamic>> refunds, DateTime start, DateTime end) async {
    final List<List<dynamic>> rows = [];
    rows.add(['Return Date', 'Bill Number', 'Customer', 'Refund Amount', 'Payment Method', 'Reason', 'Returned Items']);

    for (var refund in refunds) {
      final items = refund['items'] as List? ?? [];
      final itemsText = items
          .map((i) => '${i['product_name']} (${Formatters.quantity(i['quantity'])} - ${i['condition'] == 'restockable' ? 'Stock' : 'Damaged'})')
          .join('; ');

      final returnDate = refund['return_date'] != null 
          ? DateTime.tryParse(refund['return_date'].toString()) 
          : null;
      final dateText = returnDate != null 
          ? DateFormat('dd MMM yyyy HH:mm').format(returnDate) 
          : (refund['return_date'] ?? '');

      rows.add([
        dateText,
        refund['bill_number'] ?? '',
        refund['customer_name'] ?? 'Guest',
        refund['refund_amount'] ?? 0.0,
        (refund['payment_method'] ?? '').toString().toUpperCase(),
        refund['reason'] ?? '',
        itemsText,
      ]);
    }

    await _saveOrShareCsv(rows, 'refunds_report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}');
  }

  /// Exports damage and waste report to CSV
  Future<void> exportDamageReportToCsv(List<Map<String, dynamic>> items, DateTime start, DateTime end) async {
    final List<List<dynamic>> rows = [
      // Header
      ['Type', 'Date', 'Product', 'Quantity', 'Cost Value', 'Reason/Notes'],
    ];

    for (final item in items) {
      final dateText = item['date'] != null 
          ? DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(item['date'])) 
          : '';
          
      final isWriteOff = item['source'] == 'write_off';

      rows.add([
        isWriteOff ? 'Manual Write-off' : 'Customer Return (Damaged)',
        dateText,
        item['product_name'] ?? '',
        item['quantity'] ?? 0,
        item['cost_value'] ?? 0.0,
        item['reason'] ?? '',
      ]);
    }

    await _saveOrShareCsv(rows, 'damage_waste_report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}');
  }

  /// Exports supplier returns report to CSV
  Future<void> exportSupplierReturnsReportToCsv(List<Map<String, dynamic>> items, DateTime start, DateTime end) async {
    final List<List<dynamic>> rows = [
      // Header
      ['Type', 'Date', 'Product', 'Quantity', 'Cost Value', 'Reason/Notes'],
    ];

    for (final item in items) {
      final dateText = item['date'] != null 
          ? DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(item['date'])) 
          : '';

      rows.add([
        'Supplier Return',
        dateText,
        item['product_name'] ?? '',
        item['quantity'] ?? 0,
        item['cost_value'] ?? 0.0,
        item['reason'] ?? '',
      ]);
    }

    await _saveOrShareCsv(rows, 'supplier_returns_report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}');
  }

  /// Internal helper to save and share CSV
  Future<void> _saveOrShareCsv(List<List<dynamic>> rows, String filenamePrefix) async {
    final csvData = const ListToCsvConverter().convert(rows);

    try {
      // 1. Try to open the native "Save File" dialog to let the user select where to store the CSV
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: '$filenamePrefix.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(csvData),
      );

      if (selectedPath != null) {
        final file = File(selectedPath);
        await file.writeAsString(csvData);
        return; // Successfully saved
      }

      // If user cancelled the dialog, return early without fallback
      return;
    } catch (e) {
      // On some platforms, saveFile is not implemented or throws an error. Fallback to share sheet.
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filenamePrefix.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Data Export - QuickBill',
      );
    }
  }
}
