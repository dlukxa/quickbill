import 'package:flutter/material.dart';
import 'product.dart';

/// Available column field mappings for CSV product import.
enum CsvColumnType {
  name,
  nameSinhala,
  nameEnglish,
  barcode,
  sellingPrice,
  costPrice,
  stock,
  minStock,
  category,
  unit,
  expiryDate,
  ignore;

  String get label {
    switch (this) {
      case CsvColumnType.name:
        return 'Product Name (Primary)';
      case CsvColumnType.nameSinhala:
        return 'Sinhala Name';
      case CsvColumnType.nameEnglish:
        return 'English Name';
      case CsvColumnType.barcode:
        return 'Barcode / SKU';
      case CsvColumnType.sellingPrice:
        return 'Selling Price (MRP)';
      case CsvColumnType.costPrice:
        return 'Cost / Buying Price';
      case CsvColumnType.stock:
        return 'Stock Quantity';
      case CsvColumnType.minStock:
        return 'Min Stock Alert';
      case CsvColumnType.category:
        return 'Category';
      case CsvColumnType.unit:
        return 'Unit (pcs, kg, etc.)';
      case CsvColumnType.expiryDate:
        return 'Expiry Date';
      case CsvColumnType.ignore:
        return 'Ignore Column';
    }
  }

  IconData get icon {
    switch (this) {
      case CsvColumnType.name:
        return Icons.shopping_bag_outlined;
      case CsvColumnType.nameSinhala:
        return Icons.translate_rounded;
      case CsvColumnType.nameEnglish:
        return Icons.language_rounded;
      case CsvColumnType.barcode:
        return Icons.qr_code_scanner_rounded;
      case CsvColumnType.sellingPrice:
        return Icons.sell_outlined;
      case CsvColumnType.costPrice:
        return Icons.payments_outlined;
      case CsvColumnType.stock:
        return Icons.inventory_2_outlined;
      case CsvColumnType.minStock:
        return Icons.notification_important_outlined;
      case CsvColumnType.category:
        return Icons.category_outlined;
      case CsvColumnType.unit:
        return Icons.straighten_outlined;
      case CsvColumnType.expiryDate:
        return Icons.event_outlined;
      case CsvColumnType.ignore:
        return Icons.block_outlined;
    }
  }

  bool get isRequired => this == CsvColumnType.name || this == CsvColumnType.sellingPrice;
}

/// Merge strategy when an imported item matches an existing item (by barcode or name).
enum ImportConflictStrategy {
  updateAndAddStock,
  overwrite,
  skipExisting;

  String get title {
    switch (this) {
      case ImportConflictStrategy.updateAndAddStock:
        return 'Update Prices & Add Stock (Restock)';
      case ImportConflictStrategy.overwrite:
        return 'Overwrite All Existing Details';
      case ImportConflictStrategy.skipExisting:
        return 'Skip Existing Items (New Only)';
    }
  }

  String get description {
    switch (this) {
      case ImportConflictStrategy.updateAndAddStock:
        return 'Adds incoming stock quantity to your current stock and updates selling & cost prices.';
      case ImportConflictStrategy.overwrite:
        return 'Replaces existing product stock, prices, and categories with the CSV values.';
      case ImportConflictStrategy.skipExisting:
        return 'Leaves existing products untouched and only imports brand new products.';
    }
  }

  IconData get icon {
    switch (this) {
      case ImportConflictStrategy.updateAndAddStock:
        return Icons.add_circle_outline_rounded;
      case ImportConflictStrategy.overwrite:
        return Icons.sync_rounded;
      case ImportConflictStrategy.skipExisting:
        return Icons.skip_next_rounded;
    }
  }
}

/// Status of each parsed CSV row after validation.
enum CsvRowValidationStatus {
  valid,
  warning,
  error;

  Color get color {
    switch (this) {
      case CsvRowValidationStatus.valid:
        return const Color(0xFF10B981);
      case CsvRowValidationStatus.warning:
        return const Color(0xFFF59E0B);
      case CsvRowValidationStatus.error:
        return const Color(0xFFEF4444);
    }
  }

  String get label {
    switch (this) {
      case CsvRowValidationStatus.valid:
        return 'Ready';
      case CsvRowValidationStatus.warning:
        return 'Warning';
      case CsvRowValidationStatus.error:
        return 'Invalid';
    }
  }
}

/// Represents a single validated CSV row with resolved product model and status.
class CsvParsedRow {
  final int rowIndex;
  final List<dynamic> rawValues;
  final Product product;
  final CsvRowValidationStatus status;
  final List<String> errorMessages;
  final List<String> warningMessages;
  final bool isExisting;
  final Product? existingProduct;

  const CsvParsedRow({
    required this.rowIndex,
    required this.rawValues,
    required this.product,
    required this.status,
    this.errorMessages = const [],
    this.warningMessages = const [],
    this.isExisting = false,
    this.existingProduct,
  });

  bool get isValid => status == CsvRowValidationStatus.valid || status == CsvRowValidationStatus.warning;
  bool get hasError => status == CsvRowValidationStatus.error;

  CsvParsedRow copyWith({
    Product? product,
    CsvRowValidationStatus? status,
    List<String>? errorMessages,
    List<String>? warningMessages,
    bool? isExisting,
    Product? existingProduct,
  }) {
    return CsvParsedRow(
      rowIndex: rowIndex,
      rawValues: rawValues,
      product: product ?? this.product,
      status: status ?? this.status,
      errorMessages: errorMessages ?? this.errorMessages,
      warningMessages: warningMessages ?? this.warningMessages,
      isExisting: isExisting ?? this.isExisting,
      existingProduct: existingProduct ?? this.existingProduct,
    );
  }
}

/// Pre-import aggregated analysis for the user preview.
class CsvPreviewData {
  final List<String> headers;
  final List<List<dynamic>> sampleRows;
  final Map<int, CsvColumnType> columnMapping;
  final List<CsvParsedRow> parsedRows;
  final int totalRows;
  final int validCount;
  final int warningCount;
  final int errorCount;
  final int existingCount;
  final int newCount;
  final String detectedDelimiter;

  const CsvPreviewData({
    required this.headers,
    required this.sampleRows,
    required this.columnMapping,
    required this.parsedRows,
    required this.totalRows,
    required this.validCount,
    required this.warningCount,
    required this.errorCount,
    required this.existingCount,
    required this.newCount,
    required this.detectedDelimiter,
  });
}

/// Real-time progress updates during batch database execution.
class CsvImportProgress {
  final int total;
  final int processed;
  final String currentName;
  final double progress;

  const CsvImportProgress({
    required this.total,
    required this.processed,
    required this.currentName,
    required this.progress,
  });
}

/// Comprehensive summary after the import process finishes.
class CsvImportSummary {
  final int totalProcessed;
  final int newCreated;
  final int existingUpdated;
  final int skipped;
  final int failed;
  final List<String> errorMessages;
  final Duration duration;

  const CsvImportSummary({
    required this.totalProcessed,
    required this.newCreated,
    required this.existingUpdated,
    required this.skipped,
    required this.failed,
    this.errorMessages = const [],
    required this.duration,
  });
}
