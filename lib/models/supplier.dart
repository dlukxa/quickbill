class Supplier {
  final int? id;
  final int branchId;
  final String name;
  final String? phone;
  final String? address;
  final String? category;
  final String? providedItems;
  final double totalPending;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    this.id,
    this.branchId = 1,
    required this.name,
    this.phone,
    this.address,
    this.category,
    this.providedItems,
    this.totalPending = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'phone': phone,
      'address': address,
      'category': category,
      'provided_items': providedItems,
      'total_pending': totalPending,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      name: map['name'] as String? ?? 'UNKNOWN',
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      category: map['category'] as String?,
      providedItems: map['provided_items'] as String?,
      totalPending: (map['total_pending'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Supplier copyWith({
    int? id,
    int? branchId,
    String? name,
    String? phone,
    String? address,
    String? category,
    String? providedItems,
    double? totalPending,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      category: category ?? this.category,
      providedItems: providedItems ?? this.providedItems,
      totalPending: totalPending ?? this.totalPending,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
