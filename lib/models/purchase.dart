import 'package:quickbill/models/purchase_item.dart';

class Purchase {
  final int? id;
  final int branchId;
  final int supplierId;
  final double totalAmount;
  final DateTime date;
  final String status; // "Received", "Pending", "Cancelled"
  final String? notes;
  final int? employeeId; // New: tracking who made the purchase
  final List<PurchaseItem> items;

  Purchase({
    this.id,
    this.branchId = 1,
    required this.supplierId,
    required this.totalAmount,
    required this.date,
    this.status = "Received",
    this.notes,
    this.employeeId,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'supplier_id': supplierId,
      'total_amount': totalAmount,
      'date': date.toIso8601String(),
      'status': status,
      'notes': notes,
      'employee_id': employeeId,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) {
    return Purchase(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      supplierId: map['supplier_id'] as int,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date'] as String),
      status: map['status'] as String? ?? "Received",
      notes: map['notes'] as String?,
      employeeId: map['employee_id'] as int?,
      items: items,
    );
  }

  Purchase copyWith({
    int? id,
    int? branchId,
    int? supplierId,
    double? totalAmount,
    DateTime? date,
    String? status,
    String? notes,
    int? employeeId,
    List<PurchaseItem>? items,
  }) {
    return Purchase(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      supplierId: supplierId ?? this.supplierId,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      employeeId: employeeId ?? this.employeeId,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...toMap(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
