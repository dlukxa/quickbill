class SalesReturn {
  final int? id;
  final int saleId;
  final int branchId;
  final DateTime returnDate;
  final double refundAmount;
  final String refundType; // 'cash', 'credit'
  final String? reason;
  final int? employeeId;
  final bool synced;

  SalesReturn({
    this.id,
    required this.saleId,
    required this.branchId,
    required this.returnDate,
    required this.refundAmount,
    required this.refundType,
    this.reason,
    this.employeeId,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'branch_id': branchId,
      'return_date': returnDate.toIso8601String(),
      'refund_amount': refundAmount,
      'refund_type': refundType,
      'reason': reason,
      'employee_id': employeeId,
      'synced': synced ? 1 : 0,
    };
  }

  factory SalesReturn.fromMap(Map<String, dynamic> map) {
    return SalesReturn(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      branchId: map['branch_id'] as int? ?? 1,
      returnDate: DateTime.parse(map['return_date'] as String),
      refundAmount: (map['refund_amount'] as num).toDouble(),
      refundType: map['refund_type'] as String,
      reason: map['reason'] as String?,
      employeeId: map['employee_id'] as int?,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }
}
