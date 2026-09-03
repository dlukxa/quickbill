class Expense {
  final int? id;
  final int branchId;
  final String category;
  final double amount;
  final String? note;
  final DateTime date;
  final int? employeeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  Expense({
    this.id,
    this.branchId = 1,
    required this.category,
    required this.amount,
    this.note,
    required this.date,
    this.employeeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'category': category,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
      'employee_id': employeeId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      employeeId: map['employee_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      synced: map['synced'] == 1,
      deleted: map['deleted'] == 1,
    );
  }

  Expense copyWith({
    int? id,
    int? branchId,
    String? category,
    double? amount,
    String? note,
    DateTime? date,
    int? employeeId,
    bool? synced,
    bool? deleted,
  }) {
    return Expense(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
      employeeId: employeeId ?? this.employeeId,
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
