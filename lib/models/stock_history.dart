class StockHistory {
  final int? id;
  final int branchId;
  final int productId;
  final double quantityChange;
  final String type; // sale, purchase, return, adjustment
  final int? referenceId;
  final int? employeeId;
  final String? notes;
  final DateTime createdAt;

  StockHistory({
    this.id,
    this.branchId = 1,
    required this.productId,
    required this.quantityChange,
    required this.type,
    this.referenceId,
    this.employeeId,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'product_id': productId,
      'quantity_change': quantityChange,
      'type': type,
      'reference_id': referenceId,
      'employee_id': employeeId,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StockHistory.fromMap(Map<String, dynamic> map) {
    return StockHistory(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      productId: map['product_id'] as int,
      quantityChange: (map['quantity_change'] as num).toDouble(),
      type: map['type'] as String,
      referenceId: map['reference_id'] as int?,
      employeeId: map['employee_id'] as int?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
