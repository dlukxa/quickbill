class Service {
  final int? id;
  final int branchId;
  final String name;
  final String? category;
  final double price;
  final int durationMinutes;
  final bool requiresBooking;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  Service({
    this.id,
    this.branchId = 1,
    required this.name,
    this.category,
    required this.price,
    this.durationMinutes = 30,
    this.requiresBooking = true,
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
      'name': name,
      'category': category,
      'price': price,
      'duration_minutes': durationMinutes,
      'requires_booking': requiresBooking ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'],
      branchId: map['branch_id'] ?? 1,
      name: map['name'],
      category: map['category'],
      price: map['price']?.toDouble() ?? 0.0,
      durationMinutes: map['duration_minutes'] ?? 30,
      requiresBooking: (map['requires_booking'] ?? 1) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      synced: (map['synced'] ?? 0) == 1,
      deleted: (map['deleted'] ?? 0) == 1,
    );
  }

  Service copyWith({
    int? id,
    int? branchId,
    String? name,
    String? category,
    double? price,
    int? durationMinutes,
    bool? requiresBooking,
    bool? synced,
    bool? deleted,
  }) {
    return Service(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      requiresBooking: requiresBooking ?? this.requiresBooking,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
