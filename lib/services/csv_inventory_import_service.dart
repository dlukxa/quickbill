import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../models/csv_import_model.dart';
import '../models/product.dart';
import 'ai/ai_engine_service.dart';
import 'database_service.dart';
import 'sinhala_search_service.dart';
import 'unit_conversion_service.dart';

class CsvInventoryImportService {
  static final CsvInventoryImportService instance = CsvInventoryImportService._init();
  CsvInventoryImportService._init();

  // ---------------------------------------------------------------------------
  // 1. FAULT-TOLERANT CSV PARSING & INTELLIGENT VALIDATION
  // ---------------------------------------------------------------------------

  /// Reads a CSV file, detects delimiters, performs heuristic column auto-mapping,
  /// cross-checks against current inventory in SQLite, and returns a detailed preview.
  Future<CsvPreviewData> parseAndValidateCsv({
    required String filePath,
    required int branchId,
    Map<int, CsvColumnType>? manualColumnMapping,
    bool hasHeaderRow = true,
  }) async {
    final file = File(filePath);
    final rawBytes = await file.readAsBytes();

    // Strip UTF-8 BOM if present (0xEF, 0xBB, 0xBF)
    List<int> bytesToDecode = rawBytes;
    if (rawBytes.length >= 3 &&
        rawBytes[0] == 0xEF &&
        rawBytes[1] == 0xBB &&
        rawBytes[2] == 0xBF) {
      bytesToDecode = rawBytes.sublist(3);
    }

    String content;
    try {
      content = utf8.decode(bytesToDecode);
    } catch (_) {
      content = latin1.decode(bytesToDecode);
    }

    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    // Auto-detect delimiter (inspect first 5 non-empty lines)
    final detectedDelimiter = _detectDelimiter(content);

    // Convert CSV into rows with explicit \n EOL without auto-parsing numbers
    final converter = CsvToListConverter(
      fieldDelimiter: detectedDelimiter,
      eol: '\n',
      shouldParseNumbers: false,
    );
    final List<List<dynamic>> allRawRows = converter
        .convert(content)
        .where((r) => r.isNotEmpty && r.any((cell) => cell.toString().trim().isNotEmpty))
        .toList();

    if (allRawRows.isEmpty) {
      return CsvPreviewData(
        headers: [],
        sampleRows: [],
        columnMapping: {},
        parsedRows: [],
        totalRows: 0,
        validCount: 0,
        warningCount: 0,
        errorCount: 0,
        existingCount: 0,
        newCount: 0,
        detectedDelimiter: detectedDelimiter,
      );
    }

    List<String> headers = [];
    int dataStartIndex = 0;

    if (hasHeaderRow && allRawRows.isNotEmpty) {
      headers = allRawRows.first.map((e) => e.toString().trim()).toList();
      dataStartIndex = 1;
    } else {
      // Synthetic headers Column 1, Column 2...
      final colCount = allRawRows.first.length;
      headers = List.generate(colCount, (i) => 'Column ${i + 1}');
    }

    // Determine column mapping: Use manual if supplied, otherwise auto-detect
    Map<int, CsvColumnType> columnMapping;
    if (manualColumnMapping != null && manualColumnMapping.isNotEmpty) {
      columnMapping = Map.from(manualColumnMapping);
    } else {
      columnMapping = await _autoDetectColumnMapping(
        headers: headers,
        firstDataRow: allRawRows.length > 1 ? allRawRows[1] : null,
      );
    }

    // Fetch existing branch products to cross-reference barcodes and names
    final existingProducts = await DatabaseService.instance.getAllProducts(branchId);
    final Map<String, Product> existingByBarcode = {};
    final Map<String, Product> existingByName = {};

    for (final p in existingProducts) {
      if (p.baseBarcode != null && p.baseBarcode!.trim().isNotEmpty) {
        existingByBarcode[p.baseBarcode!.trim().toLowerCase()] = p;
      }
      existingByName[p.name.trim().toLowerCase()] = p;
    }

    // Track barcodes seen inside this CSV to warn about duplicates within the file itself
    final Set<String> seenBarcodesInFile = {};
    final List<CsvParsedRow> parsedRows = [];

    int validCount = 0;
    int warningCount = 0;
    int errorCount = 0;
    int existingCount = 0;
    int newCount = 0;

    for (var i = dataStartIndex; i < allRawRows.length; i++) {
      final rawRow = allRawRows[i];
      if (rawRow.isEmpty || (rawRow.length == 1 && rawRow.first.toString().trim().isEmpty)) {
        continue; // Skip blank lines
      }

      final errorMessages = <String>[];
      final warningMessages = <String>[];

      String name = '';
      String? nameSinhala;
      String? nameEnglish;
      String? barcode;
      double? sellingPrice;
      double? costPrice;
      double stock = 0.0;
      double minStock = 10.0;
      String category = 'General';
      String unit = 'pcs';
      DateTime? expiryDate;

      // Extract values according to current mapping
      for (var colIdx = 0; colIdx < rawRow.length; colIdx++) {
        final colType = columnMapping[colIdx] ?? CsvColumnType.ignore;
        final rawVal = rawRow[colIdx]?.toString().trim() ?? '';
        if (rawVal.isEmpty) continue;

        switch (colType) {
          case CsvColumnType.name:
            name = rawVal;
            break;
          case CsvColumnType.nameSinhala:
            nameSinhala = rawVal;
            break;
          case CsvColumnType.nameEnglish:
            nameEnglish = rawVal;
            break;
          case CsvColumnType.barcode:
            barcode = rawVal;
            break;
          case CsvColumnType.sellingPrice:
            sellingPrice = _cleanAndParseDouble(rawVal);
            break;
          case CsvColumnType.costPrice:
            costPrice = _cleanAndParseDouble(rawVal);
            break;
          case CsvColumnType.stock:
            stock = _cleanAndParseDouble(rawVal) ?? 0.0;
            break;
          case CsvColumnType.minStock:
            minStock = _cleanAndParseDouble(rawVal) ?? 10.0;
            break;
          case CsvColumnType.category:
            category = rawVal;
            break;
          case CsvColumnType.unit:
            unit = UnitConversionService.normalizeUnit(rawVal);
            break;
          case CsvColumnType.expiryDate:
            expiryDate = _parseDate(rawVal);
            break;
          case CsvColumnType.ignore:
            break;
        }
      }

      // ── VALIDATION RULES ──
      // 1. Product Name is required
      if (name.isEmpty) {
        errorMessages.add('Missing Product Name');
      }

      // 2. Selling Price is required and must be positive
      if (sellingPrice == null || sellingPrice <= 0) {
        errorMessages.add('Invalid or missing Selling Price');
      }

      // 3. Cost Price check
      if (costPrice != null && sellingPrice != null && costPrice > sellingPrice) {
        warningMessages.add('Cost (Rs. $costPrice) is higher than Selling Price (Rs. $sellingPrice)');
      }

      // 4. Barcode checks & duplicates in file
      if (barcode == null || barcode.isEmpty) {
        warningMessages.add('Missing Barcode (Auto-generate available)');
      } else {
        final normBarcode = barcode.toLowerCase();
        if (seenBarcodesInFile.contains(normBarcode)) {
          warningMessages.add('Duplicate barcode in CSV: "$barcode"');
        } else {
          seenBarcodesInFile.add(normBarcode);
        }
      }

      // 5. Negative stock warning
      if (stock < 0) {
        warningMessages.add('Negative stock ($stock)');
      }

      // 6. Cross-reference existing items in POS DB
      Product? existingMatch;
      if (barcode != null && barcode.isNotEmpty && existingByBarcode.containsKey(barcode.toLowerCase())) {
        existingMatch = existingByBarcode[barcode.toLowerCase()];
      } else if (name.isNotEmpty && existingByName.containsKey(name.toLowerCase())) {
        existingMatch = existingByName[name.toLowerCase()];
      }

      final isExisting = existingMatch != null;
      if (isExisting) {
        existingCount++;
      } else if (errorMessages.isEmpty) {
        newCount++;
      }

      CsvRowValidationStatus status;
      if (errorMessages.isNotEmpty) {
        status = CsvRowValidationStatus.error;
        errorCount++;
      } else if (warningMessages.isNotEmpty) {
        status = CsvRowValidationStatus.warning;
        warningCount++;
      } else {
        status = CsvRowValidationStatus.valid;
        validCount++;
      }

      final product = Product(
        branchId: branchId,
        name: name,
        nameSinhala: nameSinhala,
        nameEnglish: nameEnglish,
        baseBarcode: barcode?.isNotEmpty == true ? barcode : null,
        price: sellingPrice ?? 0.0,
        costPrice: costPrice,
        stock: stock,
        minStock: minStock,
        category: category.isNotEmpty ? category : 'General',
        unit: unit.isNotEmpty ? unit : 'pcs',
        expiryDate: expiryDate,
      );

      parsedRows.add(CsvParsedRow(
        rowIndex: i + 1,
        rawValues: rawRow,
        product: product,
        status: status,
        errorMessages: errorMessages,
        warningMessages: warningMessages,
        isExisting: isExisting,
        existingProduct: existingMatch,
      ));
    }

    // Sample data rows (up to 3 for preview)
    final sampleRows = allRawRows.sublist(
      dataStartIndex,
      allRawRows.length > dataStartIndex + 3 ? dataStartIndex + 3 : allRawRows.length,
    );

    return CsvPreviewData(
      headers: headers,
      sampleRows: sampleRows,
      columnMapping: columnMapping,
      parsedRows: parsedRows,
      totalRows: parsedRows.length,
      validCount: validCount,
      warningCount: warningCount,
      errorCount: errorCount,
      existingCount: existingCount,
      newCount: newCount,
      detectedDelimiter: detectedDelimiter,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. HIGH-SPEED CHUNKED BATCH EXECUTION
  // ---------------------------------------------------------------------------

  /// Executes database insertions/updates in high-speed transactions with real-time UI progress updates.
  Future<CsvImportSummary> executeBatchImport({
    required int branchId,
    required List<CsvParsedRow> rows,
    required ImportConflictStrategy conflictStrategy,
    required bool autoGenerateBarcodes,
    void Function(CsvImportProgress)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final validRows = rows.where((r) => r.status != CsvRowValidationStatus.error).toList();

    int totalProcessed = 0;
    int newCreated = 0;
    int existingUpdated = 0;
    int skipped = 0;
    int failed = 0;
    final List<String> errorMessages = [];

    final db = await DatabaseService.instance.database;
    const int batchSize = 50;

    for (var i = 0; i < validRows.length; i += batchSize) {
      final end = (i + batchSize < validRows.length) ? i + batchSize : validRows.length;
      final currentChunk = validRows.sublist(i, end);

      await db.transaction((txn) async {
        for (var rowIdx = 0; rowIdx < currentChunk.length; rowIdx++) {
          final row = currentChunk[rowIdx];
          final overallIdx = i + rowIdx + 1;

          try {
            // Check if item already exists in POS
            if (row.isExisting && row.existingProduct != null) {
              final existing = row.existingProduct!;

              if (conflictStrategy == ImportConflictStrategy.skipExisting) {
                skipped++;
                totalProcessed++;
                continue;
              }

              if (conflictStrategy == ImportConflictStrategy.updateAndAddStock) {
                // Restock mode: keep existing info, add new stock, update selling and cost price
                final double newStock = existing.stock + row.product.stock;
                final double newPrice = row.product.price > 0 ? row.product.price : existing.price;
                final double? newCost = row.product.costPrice ?? existing.costPrice;

                // Log price change if changed
                if (existing.price != newPrice || existing.costPrice != newCost) {
                  await txn.insert('price_history', {
                    'product_id': existing.id,
                    'branch_id': branchId,
                    'old_price': existing.price,
                    'new_price': newPrice,
                    'old_cost_price': existing.costPrice,
                    'new_cost_price': newCost,
                    'old_unit': existing.unit,
                    'new_unit': existing.unit,
                    'reason': 'CSV Restock Import Adjustment',
                    'changed_by': 'Admin',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                }

                // Log stock history for incoming stock
                if (row.product.stock != 0 && existing.id != null) {
                  await txn.insert('stock_history', {
                    'branch_id': branchId,
                    'product_id': existing.id,
                    'quantity_change': row.product.stock,
                    'type': 'restock',
                    'notes': 'CSV Restock Import',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                }

                // Update product table
                await txn.update(
                  'products',
                  {
                    'price': newPrice,
                    'cost_price': newCost,
                    'stock': newStock,
                    if (row.product.nameSinhala != null) 'name_sinhala': row.product.nameSinhala,
                    if (row.product.category != null && row.product.category != 'General')
                      'category': row.product.category,
                    'updated_at': DateTime.now().toIso8601String(),
                    'synced': 0,
                  },
                  where: 'id = ?',
                  whereArgs: [existing.id],
                );

                existingUpdated++;
              } else if (conflictStrategy == ImportConflictStrategy.overwrite) {
                // Overwrite mode: replace stock and details completely
                if (existing.price != row.product.price || existing.costPrice != row.product.costPrice) {
                  await txn.insert('price_history', {
                    'product_id': existing.id,
                    'branch_id': branchId,
                    'old_price': existing.price,
                    'new_price': row.product.price,
                    'old_cost_price': existing.costPrice,
                    'new_cost_price': row.product.costPrice,
                    'old_unit': existing.unit,
                    'new_unit': row.product.unit,
                    'reason': 'CSV Overwrite Import',
                    'changed_by': 'Admin',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                }

                if (existing.id != null) {
                  await txn.insert('stock_history', {
                    'branch_id': branchId,
                    'product_id': existing.id,
                    'quantity_change': row.product.stock - existing.stock,
                    'type': 'adjustment',
                    'notes': 'CSV Overwrite Import',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                }

                await txn.update(
                  'products',
                  {
                    'name': row.product.name,
                    if (row.product.nameSinhala != null) 'name_sinhala': row.product.nameSinhala,
                    if (row.product.nameEnglish != null) 'name_english': row.product.nameEnglish,
                    'price': row.product.price,
                    'cost_price': row.product.costPrice,
                    'stock': row.product.stock,
                    'min_stock': row.product.minStock,
                    'category': row.product.category,
                    'unit': row.product.unit,
                    if (row.product.expiryDate != null)
                      'expiry_date': row.product.expiryDate!.toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                    'synced': 0,
                  },
                  where: 'id = ?',
                  whereArgs: [existing.id],
                );

                existingUpdated++;
              }
            } else {
              // ── INSERT BRAND NEW PRODUCT ──
              String? barcode = row.product.baseBarcode;
              if ((barcode == null || barcode.isEmpty) && autoGenerateBarcodes) {
                // Generate unique EAN-like 13-digit local barcode (Prefix 29 + timestamp millis + index)
                final ts = DateTime.now().millisecondsSinceEpoch.toString();
                final seq = (overallIdx % 999).toString().padLeft(3, '0');
                barcode = '29${ts.substring(ts.length - 8)}$seq';
              }

              // Compute search tokens for instant Sinhala/English sub-ms searches
              final tokens = SinhalaSearchService.generateSearchTokens(
                name: row.product.name,
                nameSinhala: row.product.nameSinhala,
                nameEnglish: row.product.nameEnglish,
                searchAliases: row.product.searchAliases,
                baseBarcode: barcode,
              );

              final productToInsert = row.product.copyWith(
                baseBarcode: barcode,
                normalizedTerms: tokens.join(','),
              );

              final productMap = productToInsert.toMap();
              productMap.remove('id'); // Let SQLite auto-increment

              final newId = await txn.insert('products', productMap);

              // Set barcode lookup cache
              if (barcode != null && barcode.isNotEmpty) {
                await txn.insert(
                  'barcode_lookup',
                  {
                    'barcode': barcode,
                    'product_id': newId,
                    'batch_id': null,
                    'branch_id': branchId,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }

              // Insert initial stock history
              if (productToInsert.stock > 0) {
                await txn.insert('stock_history', {
                  'branch_id': branchId,
                  'product_id': newId,
                  'quantity_change': productToInsert.stock,
                  'type': 'adjustment',
                  'notes': 'Initial Stock from CSV Import',
                  'created_at': DateTime.now().toIso8601String(),
                });
              }

              // Queue for cloud sync
              await txn.insert('sync_queue', {
                'table_name': 'products',
                'record_id': newId,
                'action': 'INSERT',
                'created_at': DateTime.now().toIso8601String(),
                'status': 'PENDING',
              });

              newCreated++;
            }

            totalProcessed++;
          } catch (e) {
            failed++;
            errorMessages.add('Row ${row.rowIndex} (${row.product.name}): $e');
            debugPrint('Failed to import row ${row.rowIndex}: $e');
          }
        }
      });

      // Notify progress
      if (onProgress != null) {
        final currentItemName = currentChunk.last.product.name;
        onProgress(CsvImportProgress(
          total: validRows.length,
          processed: end,
          currentName: currentItemName,
          progress: end / validRows.length,
        ));
      }

      // Yield event loop to prevent UI ANR/stutter
      await Future.delayed(const Duration(milliseconds: 8));
    }

    final duration = DateTime.now().difference(startTime);

    return CsvImportSummary(
      totalProcessed: totalProcessed,
      newCreated: newCreated,
      existingUpdated: existingUpdated,
      skipped: skipped,
      failed: failed,
      errorMessages: errorMessages,
      duration: duration,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SAMPLE CSV TEMPLATE GENERATOR & DOWNLOADER
  // ---------------------------------------------------------------------------

  /// Generates a ready-to-use sample CSV template featuring common Sri Lankan retail items
  /// with Sinhala and English names, barcodes, prices, stock, and units.
  Future<void> generateAndDownloadSampleCsv() async {
    final List<List<dynamic>> rows = [
      [
        'Barcode',
        'Product Name',
        'Sinhala Name',
        'Category',
        'Selling Price',
        'Cost Price',
        'Stock Qty',
        'Min Stock Alert',
        'Unit',
        'Expiry Date'
      ],
      [
        '4792015000101',
        'Anchor Full Cream Milk Powder 400g',
        'ඇන්කර් කිරිපිටි 400g',
        'Dairy & Milk',
        1150.00,
        1020.00,
        45,
        10,
        'pcs',
        '2027-06-30'
      ],
      [
        '4791001000215',
        'Munchee Super Cream Cracker 490g',
        'මන්චි ක්‍රීම් ක්‍රැකර් 490g',
        'Biscuits',
        380.00,
        340.00,
        60,
        15,
        'pcs',
        '2026-12-15'
      ],
      [
        '4792024000312',
        'White Sugar (සුදු සීනි)',
        'සුදු සීනි',
        'Grocery & Staples',
        260.00,
        240.00,
        150.0,
        25,
        'kg',
        ''
      ],
      [
        '4792024000429',
        'Red Raw Rice (රතු කැකුළු)',
        'රතු කැකුළු සහල්',
        'Rice & Grains',
        220.00,
        195.00,
        200.0,
        30,
        'kg',
        ''
      ],
      [
        '4792011000543',
        'Mysoor Dhal (පරිප්පු)',
        'මයිසූර් පරිප්පු',
        'Grocery & Staples',
        340.00,
        310.00,
        80.0,
        20,
        'kg',
        ''
      ],
      [
        '4792019000650',
        'Keells Chicken Sausages 500g',
        'කීල්ස් චිකන් සොසේජස් 500g',
        'Meat & Frozen',
        750.00,
        660.00,
        30,
        5,
        'pcs',
        '2026-11-20'
      ],
      [
        '4791023000781',
        'Sunlight Lemon Soap 110g',
        'සන්ලයිට් සබන් 110g',
        'Household',
        120.00,
        105.00,
        120,
        20,
        'pcs',
        ''
      ],
      [
        '4792018000892',
        'Dilmah Premium Ceylon Tea 100g',
        'දිල්මා තේ කොළ 100g',
        'Beverages',
        290.00,
        255.00,
        50,
        10,
        'pcs',
        '2027-08-10'
      ],
      [
        '4792015000999',
        'Fortune Sunflower Oil 1L',
        'ෆෝචූන් සූරියකාන්ත තෙල් 1L',
        'Oil & Fats',
        890.00,
        810.00,
        40,
        8,
        'L',
        '2027-03-31'
      ],
    ];

    final csvString = const ListToCsvConverter().convert(rows);

    // Prepend UTF-8 BOM so Microsoft Excel renders Sinhala characters without corrupting
    final List<int> utf8Bom = [0xEF, 0xBB, 0xBF];
    final List<int> bytesWithBom = [...utf8Bom, ...utf8.encode(csvString)];

    try {
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sample Inventory CSV Template',
        fileName: 'quickbill_inventory_sample_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(bytesWithBom),
      );

      if (selectedPath != null) {
        final file = File(selectedPath);
        await file.writeAsBytes(bytesWithBom);
        return;
      }
    } catch (_) {
      // Fallback to sharing the file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/quickbill_inventory_sample_template.csv');
      await file.writeAsBytes(bytesWithBom);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'QuickBill Inventory Sample CSV Template',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 4. SMART AUTO-DETECTION & HEURISTICS
  // ---------------------------------------------------------------------------

  /// Inspects header strings and sample values to automatically map CSV columns.
  Future<Map<int, CsvColumnType>> _autoDetectColumnMapping({
    required List<String> headers,
    List<dynamic>? firstDataRow,
  }) async {
    final Map<int, CsvColumnType> mapping = {};
    final Set<CsvColumnType> assignedTypes = {};

    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_\u0D80-\u0DFF]'), '_');

      // Sinhala Name
      if (_matches(h, ['sinhala', 'name_sinhala', 'sinhala_name', 'නම_සිංහල', 'සිංහල'])) {
        mapping[i] = CsvColumnType.nameSinhala;
        assignedTypes.add(CsvColumnType.nameSinhala);
        continue;
      }

      // English Name
      if (_matches(h, ['english', 'name_en', 'english_name', 'name_english', 'en_name'])) {
        mapping[i] = CsvColumnType.nameEnglish;
        assignedTypes.add(CsvColumnType.nameEnglish);
        continue;
      }

      // Barcode / SKU
      if (!assignedTypes.contains(CsvColumnType.barcode) &&
          _matches(h, ['barcode', 'base_barcode', 'sku', 'upc', 'ean', 'code', 'item_code', 'බාර්කෝඩ්'])) {
        mapping[i] = CsvColumnType.barcode;
        assignedTypes.add(CsvColumnType.barcode);
        continue;
      }

      // Selling Price (Retail Price / Price / MRP)
      if (!assignedTypes.contains(CsvColumnType.sellingPrice) &&
          _matches(h, [
            'selling_price',
            'sell_price',
            'retail_price',
            'retail',
            'unit_price',
            'mrp',
            'price',
            'sales_price',
            'විකුණුම්_මිල',
            'මිල'
          ])) {
        mapping[i] = CsvColumnType.sellingPrice;
        assignedTypes.add(CsvColumnType.sellingPrice);
        continue;
      }

      // Cost Price (Buying Price / Purchase Price)
      if (!assignedTypes.contains(CsvColumnType.costPrice) &&
          _matches(h, [
            'cost_price',
            'cost',
            'buying_price',
            'buy_price',
            'purchase_price',
            'wholesale_price',
            'ගැනුම්_මිල'
          ])) {
        mapping[i] = CsvColumnType.costPrice;
        assignedTypes.add(CsvColumnType.costPrice);
        continue;
      }

      // Stock / Quantity
      if (!assignedTypes.contains(CsvColumnType.stock) &&
          _matches(h, [
            'stock',
            'qty',
            'quantity',
            'current_stock',
            'stock_qty',
            'inventory',
            'count',
            'ප්‍රමාණය',
            'තොගය'
          ])) {
        mapping[i] = CsvColumnType.stock;
        assignedTypes.add(CsvColumnType.stock);
        continue;
      }

      // Min Stock / Reorder Level
      if (!assignedTypes.contains(CsvColumnType.minStock) &&
          _matches(h, ['min_stock', 'reorder_level', 'low_stock', 'alert_qty', 'min_qty', 'alert'])) {
        mapping[i] = CsvColumnType.minStock;
        assignedTypes.add(CsvColumnType.minStock);
        continue;
      }

      // Category
      if (!assignedTypes.contains(CsvColumnType.category) &&
          _matches(h, ['category', 'cat', 'department', 'group', 'වර්ගය', 'කාණ්ඩය'])) {
        mapping[i] = CsvColumnType.category;
        assignedTypes.add(CsvColumnType.category);
        continue;
      }

      // Unit
      if (!assignedTypes.contains(CsvColumnType.unit) &&
          _matches(h, ['unit', 'uom', 'unit_type', 'measure', 'ඒකකය'])) {
        mapping[i] = CsvColumnType.unit;
        assignedTypes.add(CsvColumnType.unit);
        continue;
      }

      // Expiry Date
      if (!assignedTypes.contains(CsvColumnType.expiryDate) &&
          _matches(h, ['expiry', 'exp_date', 'expiry_date', 'expiration', 'best_before', 'exp'])) {
        mapping[i] = CsvColumnType.expiryDate;
        assignedTypes.add(CsvColumnType.expiryDate);
        continue;
      }

      // Primary Product Name
      if (!assignedTypes.contains(CsvColumnType.name) &&
          _matches(h, ['name', 'product_name', 'item_name', 'product', 'item', 'description', 'title', 'නම'])) {
        mapping[i] = CsvColumnType.name;
        assignedTypes.add(CsvColumnType.name);
        continue;
      }
    }

    // Fallback: If primary name is still unmapped, map the first available string column
    if (!assignedTypes.contains(CsvColumnType.name) && headers.isNotEmpty) {
      mapping[0] = CsvColumnType.name;
      assignedTypes.add(CsvColumnType.name);
    }

    // Try AI Header Mapping fallback if critical fields (name or selling price) are missing and Gemma AI is active
    if ((!assignedTypes.contains(CsvColumnType.name) || !assignedTypes.contains(CsvColumnType.sellingPrice)) &&
        AIEngineService.instance.isGemmaLoaded) {
      try {
        final sampleRowStrings = firstDataRow?.map((e) => e.toString()).toList();
        final aiMapping = await _mapHeadersWithGemma(headers, sampleRowStrings);
        aiMapping.forEach((type, colIndex) {
          if (!assignedTypes.contains(type) && colIndex < headers.length) {
            mapping[colIndex] = type;
            assignedTypes.add(type);
          }
        });
      } catch (e) {
        debugPrint('Gemma header mapping fallback error: $e');
      }
    }

    // Default remaining columns to ignore
    for (var i = 0; i < headers.length; i++) {
      mapping.putIfAbsent(i, () => CsvColumnType.ignore);
    }

    return mapping;
  }

  bool _matches(String header, List<String> patterns) {
    for (final p in patterns) {
      if (header == p || header.contains(p)) return true;
    }
    return false;
  }

  /// Optional AI inference fallback for unorthodox or cryptic headers
  Future<Map<CsvColumnType, int>> _mapHeadersWithGemma(
    List<String> headers, [
    List<String>? sampleRow,
  ]) async {
    final Map<CsvColumnType, int> result = {};
    if (!AIEngineService.instance.isGemmaLoaded) return result;

    final prompt = StringBuffer();
    prompt.writeln('Task: Map CSV column headers to inventory fields.');
    prompt.writeln('Fields: name, barcode, sellingPrice, costPrice, stock, category, unit');
    prompt.writeln('Headers: $headers');
    if (sampleRow != null) prompt.writeln('Sample Row: $sampleRow');
    prompt.writeln('Output a JSON map where keys are field names and values are 0-based header integer indices.');
    prompt.writeln('Example: {"name": 0, "sellingPrice": 2}');
    prompt.writeln('JSON:');

    try {
      final responseText = await AIEngineService.instance.askGemmaDirect(prompt.toString());
      final clean = responseText.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> decoded = jsonDecode(clean);

      void bind(String key, CsvColumnType type) {
        if (decoded.containsKey(key) && decoded[key] is int) {
          result[type] = decoded[key] as int;
        }
      }

      bind('name', CsvColumnType.name);
      bind('barcode', CsvColumnType.barcode);
      bind('sellingPrice', CsvColumnType.sellingPrice);
      bind('costPrice', CsvColumnType.costPrice);
      bind('stock', CsvColumnType.stock);
      bind('category', CsvColumnType.category);
      bind('unit', CsvColumnType.unit);
    } catch (_) {}

    return result;
  }

  // ---------------------------------------------------------------------------
  // 5. PARSING UTILITIES
  // ---------------------------------------------------------------------------

  /// Auto-detects whether the CSV is separated by comma, semicolon, tab, or pipe.
  String _detectDelimiter(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).take(5).toList();
    if (lines.isEmpty) return ',';

    final candidates = [',', ';', '\t', '|'];
    String bestDelimiter = ',';
    int maxConsistentCols = 0;

    for (final delimiter in candidates) {
      final counts = lines.map((l) => l.split(delimiter).length).toList();
      // Check if delimiter splits into at least 2 columns and is consistent across lines
      if (counts.first > 1 && counts.every((c) => c == counts.first)) {
        if (counts.first > maxConsistentCols) {
          maxConsistentCols = counts.first;
          bestDelimiter = delimiter;
        }
      }
    }

    return bestDelimiter;
  }

  /// Strips currency indicators (Rs., LKR, $), commas, and spaces to safely parse double values.
  double? _cleanAndParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    String str = value.toString().trim();
    if (str.isEmpty) return null;

    // Remove currency prefixes/suffixes and commas: e.g. "Rs. 1,500.00" -> "1500.00"
    str = str
        .replaceAll(RegExp(r'^(rs\.?|lkr|\$|€|£)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(rs\.?|lkr|\$|€|£)$', caseSensitive: false), '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(str);
  }

  /// Attempts to parse common date formats for expiry dates.
  DateTime? _parseDate(String dateStr) {
    final clean = dateStr.trim();
    if (clean.isEmpty) return null;

    // Try standard ISO parse (YYYY-MM-DD)
    final direct = DateTime.tryParse(clean);
    if (direct != null) return direct;

    // Try DD/MM/YYYY or DD-MM-YYYY
    final parts = clean.split(RegExp(r'[/.-]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        // YYYY/MM/DD
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else {
        // DD/MM/YYYY
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }

    return null;
  }
}
