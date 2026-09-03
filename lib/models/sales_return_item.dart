class SalesReturnItem {
  final int? id;
  final int returnId;
  final int productId;
  final int? batchId;
  final double quantity;
  final double refundAmount;
  final String condition; // 'restockable', 'damaged'

  SalesReturnItem({
    this.id,
    required this.returnId,
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.refundAmount,
    required this.condition,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'return_id': returnId,
      'product_id': productId,
      'batch_id': batchId,
      'quantity': quantity,
      'refund_amount': refundAmount,
      'condition': condition,
    };
  }

  factory SalesReturnItem.fromMap(Map<String, dynamic> map) {
    return SalesReturnItem(
      id: map['id'] as int?,
      returnId: map['return_id'] as int,
      productId: map['product_id'] as int,
      batchId: map['batch_id'] as int?,
      quantity: (map['quantity'] as num).toDouble(),
      refundAmount: (map['refund_amount'] as num).toDouble(),
      condition: map['condition'] as String,
    );
  }
}
