class CustomOrder {
  final int? id;
  final int branchId;
  final int? customerId;
  final DateTime dueDate;
  final double depositAmount;
  final int depositPaid;
  final double totalAmount;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  CustomOrder({
    this.id,
    this.branchId = 1,
    this.customerId,
    required this.dueDate,
    this.depositAmount = 0.0,
    this.depositPaid = 0,
    required this.totalAmount,
    this.status = 'placed',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'branch_id': branchId,
      'customer_id': customerId,
      'due_date': dueDate.toIso8601String(),
      'deposit_amount': depositAmount,
      'deposit_paid': depositPaid,
      'total_amount': totalAmount,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory CustomOrder.fromMap(Map<String, dynamic> map) {
    return CustomOrder(
      id: map['id'],
      branchId: map['branch_id'] ?? 1,
      customerId: map['customer_id'],
      dueDate: DateTime.parse(map['due_date']),
      depositAmount: map['deposit_amount']?.toDouble() ?? 0.0,
      depositPaid: map['deposit_paid'] ?? 0,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'placed',
      notes: map['notes'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      synced: (map['synced'] ?? 0) == 1,
      deleted: (map['deleted'] ?? 0) == 1,
    );
  }

  CustomOrder copyWith({
    int? id,
    int? branchId,
    int? customerId,
    DateTime? dueDate,
    double? depositAmount,
    int? depositPaid,
    double? totalAmount,
    String? status,
    String? notes,
    bool? synced,
    bool? deleted,
  }) {
    return CustomOrder(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      customerId: customerId ?? this.customerId,
      dueDate: dueDate ?? this.dueDate,
      depositAmount: depositAmount ?? this.depositAmount,
      depositPaid: depositPaid ?? this.depositPaid,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
