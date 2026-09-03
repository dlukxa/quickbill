import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'database_service.dart';
import 'ai/ai_engine_service.dart';

class ImportService {
  static final ImportService instance = ImportService._init();
  ImportService._init();

  Future<int> importProducts(int branchId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return 0;
    return await importProductsFromPath(branchId, result.files.single.path!);
  }

  Future<int> importProductsFromPath(int branchId, String filePath) async {
    final file = File(filePath);
    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter())
        .toList();

    if (fields.isEmpty) return 0;

    // Default indices if headers not detected (fallback to old index-based order)
    int nameCol = 0;
    int categoryCol = 1;
    int stockCol = 2;
    int priceCol = 3;
    int costPriceCol = 4;
    int barcodeCol = 5;
    int unitCol = -1;

    bool headersDetected = false;
    if (fields.isNotEmpty) {
      final firstRowRaw = fields.first.map((e) => e.toString()).toList();
      final firstRow = firstRowRaw.map((e) => e.trim().toLowerCase()).toList();
      
      // Try heuristic mapping first
      nameCol = firstRow.indexOf('name');
      barcodeCol = firstRow.contains('barcode') ? firstRow.indexOf('barcode') : firstRow.indexOf('base_barcode');
      categoryCol = firstRow.indexOf('category');
      unitCol = firstRow.indexOf('unit');
      priceCol = firstRow.indexOf('price');
      costPriceCol = firstRow.contains('cost price') ? firstRow.indexOf('cost price') : firstRow.indexOf('cost_price');
      
      stockCol = -1;
      for (var i = 0; i < firstRow.length; i++) {
        final h = firstRow[i];
        if (h.contains('stock') || h.contains('qty') || h.contains('quantity')) {
          stockCol = i;
          break;
        }
      }

      if (nameCol != -1 || priceCol != -1 || barcodeCol != -1) {
        headersDetected = true;
      }

      // If heuristic mapping missed critical fields (name or price), try AI mapping as fallback
      if (nameCol == -1 || priceCol == -1) {
        debugPrint('Heuristic header mapping failed to find name/price. Invoking Gemma AI...');
        List<String>? sampleDataRow;
        if (fields.length > 1) {
          sampleDataRow = fields[1].map((e) => e.toString()).toList();
        }
        final aiMapping = await _mapHeadersWithAI(firstRowRaw, sampleDataRow);
        if (aiMapping.containsKey('name')) {
          nameCol = aiMapping['name']!;
          headersDetected = true;
        }
        if (aiMapping.containsKey('price')) {
          priceCol = aiMapping['price']!;
          headersDetected = true;
        }
        if (aiMapping.containsKey('barcode') && barcodeCol == -1) {
          barcodeCol = aiMapping['barcode']!;
        }
        if (aiMapping.containsKey('category') && categoryCol == -1) {
          categoryCol = aiMapping['category']!;
        }
        if (aiMapping.containsKey('unit') && unitCol == -1) {
          unitCol = aiMapping['unit']!;
        }
        if (aiMapping.containsKey('costPrice') && costPriceCol == -1) {
          costPriceCol = aiMapping['costPrice']!;
        }
        if (aiMapping.containsKey('stock') && stockCol == -1) {
          stockCol = aiMapping['stock']!;
        }
      }
    }

    int startRow = headersDetected ? 1 : 0;
    final List<Product> productsToImport = [];

    for (var i = startRow; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty) continue;

      try {
        final name = nameCol != -1 && nameCol < row.length ? row[nameCol].toString().trim() : '';
        if (name.isEmpty) continue;

        final price = priceCol != -1 && priceCol < row.length ? double.tryParse(row[priceCol].toString()) ?? 0.0 : 0.0;
        final costPrice = costPriceCol != -1 && costPriceCol < row.length ? double.tryParse(row[costPriceCol].toString()) : null;
        final stock = stockCol != -1 && stockCol < row.length ? double.tryParse(row[stockCol].toString()) ?? 0.0 : 0.0;
        final category = categoryCol != -1 && categoryCol < row.length ? row[categoryCol].toString().trim() : 'Uncategorized';
        final barcode = barcodeCol != -1 && barcodeCol < row.length ? row[barcodeCol].toString().trim() : null;
        final unit = unitCol != -1 && unitCol < row.length ? row[unitCol].toString().trim() : 'pcs';

        final product = Product(
          branchId: branchId,
          name: name,
          price: price,
          costPrice: costPrice,
          stock: stock,
          category: category.isEmpty ? 'Uncategorized' : category,
          baseBarcode: barcode != null && barcode.isEmpty ? null : barcode,
          unit: unit.isEmpty ? 'pcs' : unit,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        productsToImport.add(product);
      } catch (e) {
        debugPrint('Error parsing CSV row $i: $e');
      }
    }

    if (productsToImport.isEmpty) return 0;
    return await DatabaseService.instance.insertProductsBatch(productsToImport);
  }

  /// Queries the local Gemma model to analyze the CSV headers and sample data to produce a field mapping.
  Future<Map<String, int>> _mapHeadersWithAI(List<String> firstRowRaw, [List<String>? sampleRow]) async {
    final Map<String, int> mapping = {};
    
    // Check if Gemma is downloaded and loaded
    if (!AIEngineService.instance.isGemmaLoaded) {
      try {
        await AIEngineService.instance.initGemmaIfAvailable();
      } catch (_) {}
    }
    
    if (!AIEngineService.instance.isGemmaLoaded) {
      return mapping; // Fallback immediately if local model isn't active
    }

    final headersList = firstRowRaw.map((e) => e.trim()).toList();
    final prompt = StringBuffer();
    prompt.writeln('Task: Map CSV headers to standard product database fields.');
    prompt.writeln('Standard Fields: name, price, costPrice, stock, category, barcode, unit');
    prompt.writeln('CSV Headers: $headersList');
    if (sampleRow != null) {
      prompt.writeln('Sample Data Row: $sampleRow');
      prompt.writeln('Note: Use the sample data to better understand what each header represents (e.g. if "Product_ID" contains numbers like "29-205", it might be a barcode. If "Unit_Price" contains "\$4.50", it is the price).');
    }
    prompt.writeln('Instructions: Identify which CSV header matches each standard field.');
    prompt.writeln('Respond with a single JSON map of standard field keys to header index integers.');
    prompt.writeln('Example: {"name": 0, "price": 2, "stock": 3}');
    prompt.writeln('Do not include markdown format, explanation, or code blocks. Output JSON only.');
    prompt.writeln('JSON:');

    try {
      final responseText = await AIEngineService.instance.askGemmaDirect(prompt.toString());
      debugPrint('AI Header Mapping Response: $responseText');
      
      // Clean markdown code blocks if any (e.g. ```json ... ```)
      String cleanJson = responseText.trim();
      if (cleanJson.contains('```')) {
        final matches = RegExp(r'\{[\s\S]*\}').allMatches(cleanJson);
        if (matches.isNotEmpty) {
          cleanJson = matches.first.group(0) ?? '';
        }
      }
      
      final Map<String, dynamic> decoded = jsonDecode(cleanJson);
      decoded.forEach((key, value) {
        if (value is int && value >= 0 && value < firstRowRaw.length) {
          mapping[key] = value;
        }
      });
    } catch (e) {
      debugPrint('AI Header Mapping Failed: $e');
    }

    return mapping;
  }
}
