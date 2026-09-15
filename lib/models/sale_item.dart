import '../services/unit_conversion_service.dart';

class SaleItem {
  final int? id;
  final int saleId;
  final int productId;
  final String itemType;
  final int? serviceId;
  final String productName;
  final double quantity; // Base quantity (for inventory / standard calculation)
  final double unitPrice; // Price per base unit
  final double total;
  final double costPrice; // Cost price per base unit at time of sale
  final int? batchId;
  final String? batchNumber;
  final double discount;
  final String? soldUnit; // Unit chosen at sale (e.g. 'g', 'kg', 'ml', 'pack', 'pcs')
  final double? soldQuantity; // Quantity in soldUnit (e.g. 500 for 500g, 1 for 1 pack)
  final String? sellingMode; // 'weight' | 'pack' | 'piece'
  final double? packSize; // e.g. 1.0 (in kg)
  final String taxStatus; // 'taxable', 'zero_rated', 'exempt'
  final double taxRate;
  final double taxAmount;
  final double taxableAmount;

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    this.itemType = 'product',
    this.serviceId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.costPrice,
    this.batchId,
    this.batchNumber,
    this.discount = 0.0,
    this.soldUnit,
    this.soldQuantity,
    this.sellingMode,
    this.packSize,
    this.taxStatus = 'exempt',
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.taxableAmount = 0.0,
  });

  /// Formatted quantity display for receipts and invoices.
  /// Example: "500g", "1.5kg", "1 pack", "2 packs", "10 pcs"
  String get formattedQuantity {
    if (sellingMode == 'pack' || soldUnit == 'pack' || soldUnit == 'box' || soldUnit == 'bottle') {
      final u = soldUnit ?? 'pack';
      final qty = soldQuantity ?? quantity;
      final numStr = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
      return qty == 1 ? '1 $u' : '$numStr ${u}s';
    }
    final unit = soldUnit ?? 'pcs';
    final qty = soldQuantity ?? quantity;
    return UnitConversionService.formatSoldQuantity(qty, unit);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'item_type': itemType,
      'service_id': serviceId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
      'cost_price': costPrice,
      'batch_id': batchId,
      'batch_number': batchNumber,
      'discount': discount,
      'sold_unit': soldUnit,
      'sold_quantity': soldQuantity,
      'selling_mode': sellingMode,
      'pack_size': packSize,
      'tax_status': taxStatus,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'taxable_amount': taxableAmount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      itemType: map['item_type'] as String? ?? 'product',
      serviceId: map['service_id'] as int?,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      batchId: map['batch_id'] as int?,
      batchNumber: map['batch_number'] as String?,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      soldUnit: map['sold_unit'] as String?,
      soldQuantity: (map['sold_quantity'] as num?)?.toDouble(),
      sellingMode: map['selling_mode'] as String?,
      packSize: (map['pack_size'] as num?)?.toDouble(),
      taxStatus: map['tax_status'] as String? ?? 'taxable',
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (map['taxable_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => toMap();
}
