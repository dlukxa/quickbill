class Customer {
  final int? id;
  final int branchId;
  final String name;
  final String? phone;
  final String? address;
  final double totalDebt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int synced;
  final int deleted;

  Customer({
    this.id,
    this.branchId = 1,
    required this.name,
    this.phone,
    this.address,
    this.totalDebt = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.synced = 0,
    this.deleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'branch_id': branchId,
      'name': name,
      'phone': phone,
      'address': address,
      'total_debt': totalDebt,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced,
      'deleted': deleted,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      name: map['name'] as String? ?? 'UNKNOWN',
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      synced: map['synced'] as int? ?? 0,
      deleted: map['deleted'] as int? ?? 0,
    );
  }

  Customer copyWith({
    int? id,
    int? branchId,
    String? name,
    String? phone,
    String? address,
    double? totalDebt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? synced,
    int? deleted,
  }) {
    return Customer(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalDebt: totalDebt ?? this.totalDebt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
