import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/csv_import_model.dart';
import 'package:quickbill/services/csv_inventory_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('quickbill_csv_test_');
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CSV Inventory Import Service Tests', () {
    test('Fault-tolerant CSV parser handles headers, Sinhala items, currency symbols, and delimiters', () async {
      // Create a test CSV with semicolon delimiter, currency prefixes, formatted numbers, and Sinhala text
      final csvContent = '''
Barcode;Product Name;Sinhala Name;Category;Selling Price;Cost Price;Stock Qty;Unit
4792015000101;Anchor Milk Powder 400g;ඇන්කර් කිරිපිටි 400g;Dairy;Rs. 1,150.00;LKR 1,020.00;45;pcs
4791001000215;Munchee Cream Cracker 490g;මන්චි ක්‍රීම් ක්‍රැකර්;Biscuits;\$380.00;340.00;60;pcs
;White Sugar 1kg;සුදු සීනි;Staples;260.00;240.00;150;kg
4792011000543;;මයිසූර් පරිප්පු;Staples;340.00;310.00;80;kg
4792019000650;Keells Sausages 500g;සොසේජස්;Meat;invalid_price;660.00;30;pcs
''';

      final testFile = File('${tempDir.path}/test_inventory.csv');
      await testFile.writeAsString(csvContent);

      // Parse using CsvInventoryImportService
      final preview = await CsvInventoryImportService.instance.parseAndValidateCsv(
        filePath: testFile.path,
        branchId: 1,
      );

      // 1. Verify delimiter detection
      expect(preview.detectedDelimiter, equals(';'));

      // 2. Verify total rows
      expect(preview.totalRows, equals(5));

      // 3. Verify column auto-mapping detected accurately
      expect(preview.columnMapping.values, contains(CsvColumnType.barcode));
      expect(preview.columnMapping.values, contains(CsvColumnType.name));
      expect(preview.columnMapping.values, contains(CsvColumnType.nameSinhala));
      expect(preview.columnMapping.values, contains(CsvColumnType.sellingPrice));
      expect(preview.columnMapping.values, contains(CsvColumnType.costPrice));
      expect(preview.columnMapping.values, contains(CsvColumnType.stock));
      expect(preview.columnMapping.values, contains(CsvColumnType.unit));

      // 4. Verify Row 1: Anchor Milk Powder
      final row1 = preview.parsedRows[0];
      expect(row1.status, equals(CsvRowValidationStatus.valid));
      expect(row1.product.name, equals('Anchor Milk Powder 400g'));
      expect(row1.product.nameSinhala, equals('ඇන්කර් කිරිපිටි 400g'));
      expect(row1.product.price, equals(1150.00));
      expect(row1.product.costPrice, equals(1020.00));
      expect(row1.product.stock, equals(45.0));
      expect(row1.product.baseBarcode, equals('4792015000101'));
      expect(row1.product.unit, equals('pcs'));

      // 5. Verify Row 2: Munchee Cream Cracker with $ symbol stripped
      final row2 = preview.parsedRows[1];
      expect(row2.status, equals(CsvRowValidationStatus.valid));
      expect(row2.product.price, equals(380.00));

      // 6. Verify Row 3: White Sugar has warning (missing barcode)
      final row3 = preview.parsedRows[2];
      expect(row3.status, equals(CsvRowValidationStatus.warning));
      expect(row3.warningMessages.any((w) => w.contains('Missing Barcode')), isTrue);
      expect(row3.product.unit, equals('kg'));

      // 7. Verify Row 4: Empty name is marked as ERROR
      final row4 = preview.parsedRows[3];
      expect(row4.status, equals(CsvRowValidationStatus.error));
      expect(row4.errorMessages.any((e) => e.contains('Missing Product Name')), isTrue);

      // 8. Verify Row 5: Invalid price is marked as ERROR
      final row5 = preview.parsedRows[4];
      expect(row5.status, equals(CsvRowValidationStatus.error));
      expect(row5.errorMessages.any((e) => e.contains('Selling Price')), isTrue);

      // Overall validation counts
      expect(preview.validCount, equals(2));
      expect(preview.warningCount, equals(1));
      expect(preview.errorCount, equals(2));
    });

    test('ConflictStrategy labels and descriptions are descriptive', () {
      expect(ImportConflictStrategy.updateAndAddStock.title, contains('Restock'));
      expect(ImportConflictStrategy.overwrite.title, contains('Overwrite'));
      expect(ImportConflictStrategy.skipExisting.title, contains('Skip Existing'));
    });
  });
}
