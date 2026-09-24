import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/csv_import_model.dart';
import 'csv_inventory_import_service.dart';

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
    try {
      final preview = await CsvInventoryImportService.instance.parseAndValidateCsv(
        filePath: filePath,
        branchId: branchId,
      );

      if (preview.parsedRows.isEmpty) return 0;

      final summary = await CsvInventoryImportService.instance.executeBatchImport(
        branchId: branchId,
        rows: preview.parsedRows,
        conflictStrategy: ImportConflictStrategy.updateAndAddStock,
        autoGenerateBarcodes: true,
      );

      return summary.newCreated + summary.existingUpdated;
    } catch (e) {
      debugPrint('ImportService error: $e');
      return 0;
    }
  }
}
