class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int productId;
  final String productName;
  final double quantity;
  final double costPrice;
  final String? batchNumber;
  final DateTime? expiryDate;

  PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    this.batchNumber,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'cost_price': costPrice,
      'batch_number': batchNumber,
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseId: map['purchase_id'],
      productId: map['product_id'],
      productName: map['product_name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      batchNumber: map['batch_number'],
      expiryDate: map['expiry_date'] != null ? DateTime.parse(map['expiry_date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return toMap();
  }
}
