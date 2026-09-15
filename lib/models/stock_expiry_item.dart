import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/unit_conversion_service.dart';

enum ExpiryStatus {
  expired,
  expiringSoon,
  valid,
}

/// Unified model representing an inventory item tracked for expiry.
/// Combines data from both `product_batches` (for batch-tracked products)
/// and direct `products` (for simple products with an expiry date).
class StockExpiryItem {
  final int productId;
  final int? batchId;
  final String productName;
  final String? nameSinhala;
  final String? nameEnglish;
  final String? category;
  final String? barcode;
  final String? batchNumber;
  final double stock;
  final String unit;
  final double price;
  final double? costPrice;
  final DateTime? purchaseDate;
  final DateTime expiryDate;
  final bool isBatchTracked;

  StockExpiryItem({
    required this.productId,
    this.batchId,
    required this.productName,
    this.nameSinhala,
    this.nameEnglish,
    this.category,
    this.barcode,
    this.batchNumber,
    required this.stock,
    this.unit = 'pcs',
    required this.price,
    this.costPrice,
    this.purchaseDate,
    required this.expiryDate,
    this.isBatchTracked = false,
  });

  /// Days remaining until expiry from current local calendar date (midnight to midnight).
  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.difference(today).inDays;
  }

  /// Whether product/batch has already expired (past midnight today).
  bool get isExpired => daysUntilExpiry < 0;

  /// Whether product/batch will expire within [thresholdDays] (default 30).
  bool isExpiringSoon([int thresholdDays = 30]) {
    return daysUntilExpiry >= 0 && daysUntilExpiry <= thresholdDays;
  }

  /// Determine status based on configurable alert threshold in days.
  ExpiryStatus getStatus([int thresholdDays = 30]) {
    if (isExpired) return ExpiryStatus.expired;
    if (isExpiringSoon(thresholdDays)) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.valid;
  }

  /// Display string for status.
  String statusLabel([int thresholdDays = 30]) {
    final days = daysUntilExpiry;
    if (days < 0) {
      final absDays = days.abs();
      return absDays == 0 ? 'Expired today' : 'Expired $absDays day${absDays == 1 ? '' : 's'} ago';
    } else if (days == 0) {
      return 'Expires today';
    } else if (days <= thresholdDays) {
      return 'Expires in $days day${days == 1 ? '' : 's'}';
    } else {
      return 'Valid ($days days left)';
    }
  }

  /// Visual status badge color.
  Color statusColor([int thresholdDays = 30]) {
    if (isExpired) return AppTheme.errorRed;
    if (isExpiringSoon(thresholdDays)) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF10B981); // Emerald Green
  }

  /// Display name preferring Sinhala name if present.
  String get displayName =>
      (nameSinhala != null && nameSinhala!.trim().isNotEmpty) ? nameSinhala! : productName;

  /// Formatted stock string (e.g. "15 pcs", "4.5 kg").
  String get formattedStock =>
      UnitConversionService.formatHumanReadableQuantity(stock, unit);

  factory StockExpiryItem.fromMap(Map<String, dynamic> map) {
    return StockExpiryItem(
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      batchId: (map['batch_id'] as num?)?.toInt(),
      productName: (map['product_name'] as String?) ?? 'Unknown Product',
      nameSinhala: map['name_sinhala'] as String?,
      nameEnglish: map['name_english'] as String?,
      category: map['category'] as String?,
      barcode: (map['batch_barcode'] as String?) ?? (map['base_barcode'] as String?),
      batchNumber: map['batch_number'] as String?,
      stock: (map['batch_stock'] as num?)?.toDouble() ?? 0.0,
      unit: (map['unit'] as String?) ?? 'pcs',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? (map['batch_purchase_price'] as num?)?.toDouble(),
      purchaseDate: map['batch_purchase_date'] != null
          ? DateTime.tryParse(map['batch_purchase_date'] as String)
          : null,
      expiryDate: DateTime.parse(map['batch_expiry_date'] as String),
      isBatchTracked: (map['track_batches'] as num?)?.toInt() == 1 || map['batch_id'] != null,
    );
  }
}
