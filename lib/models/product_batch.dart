class ProductBatch {
  final int? id;
  final int branchId;
  final int productId;
  final String batchNumber;
  final String barcode;
  final String? factoryLocation;
  final String? supplierName;
  final DateTime? productionDate;
  final DateTime? expiryDate;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final double stock;
  final double? initialStock;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  ProductBatch({
    this.id,
    this.branchId = 1,
    required this.productId,
    required this.batchNumber,
    required this.barcode,
    this.factoryLocation,
    this.supplierName,
    this.productionDate,
    this.expiryDate,
    this.purchaseDate,
    this.purchasePrice,
    this.stock = 0,
    this.initialStock,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Check if batch is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  // Check if batch expires soon (within 30 days)
  bool get expiresSoon {
    if (expiryDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return expiryDate!.isBefore(thirtyDaysFromNow) && !isExpired;
  }

  // Days until expiry
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  // Stock status
  String get stockStatus {
    if (stock == 0) return 'empty';
    if (isExpired) return 'expired';
    if (expiresSoon) return 'expiring';
    return 'good';
  }

  // Generate batch number automatically
  static String generateBatchNumber(String factoryCode, DateTime date) {
    return '${factoryCode.toUpperCase()}-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.millisecondsSinceEpoch.toString().substring(8)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'product_id': productId,
      'batch_number': batchNumber,
      'barcode': barcode,
      'factory_location': factoryLocation,
      'supplier_name': supplierName,
      'production_date': productionDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'stock': stock,
      'initial_stock': initialStock,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory ProductBatch.fromMap(Map<String, dynamic> map) {
    return ProductBatch(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      productId: map['product_id'] as int? ?? 0,
      batchNumber: map['batch_number'] as String? ?? 'UNKNOWN',
      barcode: map['barcode'] as String? ?? 'UNKNOWN',
      factoryLocation: map['factory_location'] as String?,
      supplierName: map['supplier_name'] as String?,
      productionDate: map['production_date'] != null
          ? DateTime.parse(map['production_date'] as String)
          : null,
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
      purchaseDate: map['purchase_date'] != null
          ? DateTime.parse(map['purchase_date'] as String)
          : null,
      purchasePrice: map['purchase_price'] != null
          ? (map['purchase_price'] as num?)?.toDouble()
          : null,
      stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
      initialStock: (map['initial_stock'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      synced: (map['synced'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  ProductBatch copyWith({
    int? id,
    int? branchId,
    int? productId,
    String? batchNumber,
    String? barcode,
    DateTime? expiryDate,
    DateTime? productionDate,
    DateTime? purchaseDate,
    double? purchasePrice,
    double? stock,
    double? initialStock,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    bool? deleted,
    String? factoryLocation,
    String? supplierName,
  }) {
    return ProductBatch(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
      barcode: barcode ?? this.barcode,
      expiryDate: expiryDate ?? this.expiryDate,
      productionDate: productionDate ?? this.productionDate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      stock: stock ?? this.stock,
      initialStock: initialStock ?? this.initialStock,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
      factoryLocation: factoryLocation ?? this.factoryLocation,
      supplierName: supplierName ?? this.supplierName,
    );
  }
}
