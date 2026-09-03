class PriceHistory {
  final int? id;
  final int productId;
  final int branchId;
  final double oldPrice;
  final double newPrice;
  final double? oldCostPrice;
  final double? newCostPrice;
  final String? oldUnit;
  final String? newUnit;
  final String? reason;
  final String? changedBy;
  final DateTime createdAt;
  final bool synced;
  final bool deleted;

  PriceHistory({
    this.id,
    required this.productId,
    this.branchId = 1,
    required this.oldPrice,
    required this.newPrice,
    this.oldCostPrice,
    this.newCostPrice,
    this.oldUnit,
    this.newUnit,
    this.reason,
    this.changedBy,
    DateTime? createdAt,
    this.synced = false,
    this.deleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  double get priceDifference => newPrice - oldPrice;
  bool get isIncrease => newPrice > oldPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'branch_id': branchId,
      'old_price': oldPrice,
      'new_price': newPrice,
      'old_cost_price': oldCostPrice,
      'new_cost_price': newCostPrice,
      'old_unit': oldUnit,
      'new_unit': newUnit,
      'reason': reason,
      'changed_by': changedBy,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory PriceHistory.fromMap(Map<String, dynamic> map) {
    return PriceHistory(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      branchId: map['branch_id'] as int? ?? 1,
      oldPrice: (map['old_price'] as num?)?.toDouble() ?? 0.0,
      newPrice: (map['new_price'] as num?)?.toDouble() ?? 0.0,
      oldCostPrice: (map['old_cost_price'] as num?)?.toDouble(),
      newCostPrice: (map['new_cost_price'] as num?)?.toDouble(),
      oldUnit: map['old_unit'] as String?,
      newUnit: map['new_unit'] as String?,
      reason: map['reason'] as String?,
      changedBy: map['changed_by'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      synced: map['synced'] == 1,
      deleted: map['deleted'] == 1,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory PriceHistory.fromJson(Map<String, dynamic> json) => PriceHistory.fromMap(json);
}
