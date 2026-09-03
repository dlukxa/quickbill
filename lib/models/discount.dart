class Discount {
  final int? id;
  final int branchId;
  final int? productId;
  final String? category;
  final double discountValue;
  final String discountType; // 'percentage' or 'fixed'
  final DateTime startDate;
  final DateTime endDate;
  final bool isClearance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

   Discount({
    this.id,
    this.branchId = 1,
    this.productId,
    this.category,
    required this.discountValue,
    required this.discountType,
    required this.startDate,
    required this.endDate,
    this.isClearance = false,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'product_id': productId,
      'category': category,
      'discount_value': discountValue,
      'discount_type': discountType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_clearance': isClearance ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Discount.fromMap(Map<String, dynamic> map) {
    return Discount(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      productId: map['product_id'] as int?,
      category: map['category'] as String?,
      discountValue: (map['discount_value'] as num).toDouble(),
      discountType: map['discount_type'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isClearance: (map['is_clearance'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      synced: (map['synced'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
    );
  }

  bool get isCurrentlyActive {
    if (!isActive || deleted) return false;
    if (isClearance) return true;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate.add(const Duration(days: 1)));
  }

  Discount copyWith({
    int? id,
    int? branchId,
    int? productId,
    String? category,
    double? discountValue,
    String? discountType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isClearance,
    bool? isActive,
    bool? synced,
    bool? deleted,
  }) {
    return Discount(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      productId: productId ?? this.productId,
      category: category ?? this.category,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isClearance: isClearance ?? this.isClearance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
