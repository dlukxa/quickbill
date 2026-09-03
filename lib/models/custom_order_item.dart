class CustomOrderItem {
  final int? id;
  final int orderId;
  final String description;
  final double quantity;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  CustomOrderItem({
    this.id,
    required this.orderId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory CustomOrderItem.fromMap(Map<String, dynamic> map) {
    return CustomOrderItem(
      id: map['id'],
      orderId: map['order_id'],
      description: map['description'],
      quantity: map['quantity']?.toDouble() ?? 1.0,
      unitPrice: map['unit_price']?.toDouble() ?? 0.0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      synced: (map['synced'] ?? 0) == 1,
      deleted: (map['deleted'] ?? 0) == 1,
    );
  }

  CustomOrderItem copyWith({
    int? id,
    int? orderId,
    String? description,
    double? quantity,
    double? unitPrice,
    bool? synced,
    bool? deleted,
  }) {
    return CustomOrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
    );
  }
}
