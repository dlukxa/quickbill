import 'product.dart';
import 'service.dart';
import '../services/unit_conversion_service.dart';

class CartItem {
  final Product? product; // Nullable for quick bill items and services
  final Service? serviceObj; // Nullable, populated if item is a service
  final bool isQuickItem; // True if this is a custom quick bill item
  final String itemType; // 'product' or 'service'
  final int? serviceId;
  final String? customItemName; // For quick bill items
  final double? customItemPrice; // For quick bill items
  
  double quantity; // Quantity of this item (in selectedUnit)
  final String? selectedUnit; // Active unit for this line item (e.g. 'g', 'kg', 'pack', 'pcs')
  final String? sellingMode; // 'weight' | 'pack' | 'piece' | 'liquid'
  final double? packSize; // Size per pack in packSizeUnit (e.g. 1.0)
  final String? packSizeUnit; // Unit of the pack (e.g. 'kg')
  final double? customSellingPrice; // Explicit price if different from base product price (e.g. Rs. 270 / pack)
  
  final int? batchId; // Batch ID if from a specific batch
  final String? batchNumber; // Batch number for display
  final double? batchStock; // Available stock in this batch
  double discount; // Discount amount for this item

  CartItem({
    this.product,
    this.serviceObj,
    this.isQuickItem = false,
    this.itemType = 'product',
    this.serviceId,
    this.customItemName,
    this.customItemPrice,
    this.quantity = 1,
    this.selectedUnit,
    this.sellingMode,
    this.packSize,
    this.packSizeUnit,
    this.customSellingPrice,
    this.batchId,
    this.batchNumber,
    this.batchStock,
    this.discount = 0.0,
  }) : assert(
          (isQuickItem && customItemName != null && customItemPrice != null) ||
          (!isQuickItem && itemType == 'product' && product != null) ||
          (!isQuickItem && itemType == 'service' && serviceObj != null),
          'Invalid CartItem configuration',
        );

  // Get item name (from product, service, or custom)
  String get itemName {
    if (isQuickItem) return customItemName!;
    if (itemType == 'service') return serviceObj!.name;
    return product!.name;
  }
  
  // Base unit of the product
  String get productBaseUnit {
    if (isQuickItem || itemType == 'service') return 'pcs';
    return product?.baseUnit ?? 'pcs';
  }

  // Active unit chosen for this line item (e.g. 'g', 'kg', 'pack', 'pcs')
  String get itemUnit {
    if (selectedUnit != null && selectedUnit!.isNotEmpty) {
      return UnitConversionService.normalizeUnit(selectedUnit!);
    }
    if (isQuickItem || itemType == 'service') return 'pcs';
    return product?.unit ?? 'pcs';
  }

  // Base quantity for inventory deduction and standard calculation
  // e.g. 1 pack of 1kg sugar -> 1.0kg
  //      500g of loose sugar -> 0.5kg
  double get baseQuantity {
    if (sellingMode == 'pack') {
      final size = packSize ?? product?.packSize ?? 1.0;
      final sizeUnit = packSizeUnit ?? product?.packSizeUnit ?? productBaseUnit;
      final packBaseSize = UnitConversionService.convertToBaseQuantity(size, sizeUnit, productBaseUnit);
      return quantity * packBaseSize;
    }
    return UnitConversionService.convertToBaseQuantity(quantity, itemUnit, productBaseUnit);
  }
  
  // Get active item price (per pack or per base unit)
  double get itemPrice {
    if (customSellingPrice != null) return customSellingPrice!;
    if (sellingMode == 'pack' && product?.packPrice != null) return product!.packPrice!;
    if (isQuickItem) return customItemPrice!;
    if (itemType == 'service') return serviceObj!.price;
    return product!.price;
  }
  
  // Formatted display quantity (e.g. "500g", "1.5kg", "1 pack", "2 packs", "1 piece", "2 pieces")
  String get formattedQuantity {
    if (sellingMode == 'pack' || itemUnit == 'pack' || itemUnit == 'box' || itemUnit == 'bottle') {
      final u = selectedUnit ?? itemUnit;
      final numStr = quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();
      return quantity == 1 ? '1 $u' : '$numStr ${u}s';
    }
    return UnitConversionService.formatSoldQuantity(quantity, itemUnit);
  }

  // Natural display phrasing
  String get naturalQuantity {
    if (sellingMode == 'pack' || itemUnit == 'pack' || itemUnit == 'box' || itemUnit == 'bottle') {
      return formattedQuantity;
    }
    return UnitConversionService.formatNaturalQuantity(quantity, itemUnit);
  }

  // Rate display (e.g. "Rs. 250.00 / kg" or "Rs. 270.00 / pack" or "Rs. 150.00 / piece")
  String get rateDisplay {
    if (sellingMode == 'pack') {
      return 'Rs. ${itemPrice.toStringAsFixed(2)} / ${selectedUnit ?? 'pack'}';
    }
    return 'Rs. ${itemPrice.toStringAsFixed(2)} / $productBaseUnit';
  }

  // Calculate total for this item: (Price * quantity) - Discount
  double get total {
    if (sellingMode == 'pack') {
      final subtotal = itemPrice * quantity;
      return (subtotal - discount).clamp(0.0, double.infinity);
    }
    return UnitConversionService.calculateLinePrice(
      itemPrice,
      quantity,
      itemUnit,
      productBaseUnit,
      discount: discount,
    );
  }

  // Max available stock in selectedUnit
  double get availableStock {
    if (isQuickItem || itemType == 'service') return double.infinity;
    if (product?.type == 'service' || product?.type == 'package') return double.infinity;
    final baseStock = batchStock ?? product!.calculatedStock;
    return UnitConversionService.convertFromBaseQuantity(baseStock, itemUnit, productBaseUnit);
  }

  // Increment quantity using retail step sizes
  void increment() {
    final step = UnitConversionService.getStepIncrement(quantity, itemUnit);
    if (quantity + step <= availableStock) {
      quantity += step;
    }
  }

  // Decrement quantity using retail step sizes
  void decrement() {
    final step = UnitConversionService.getStepDecrement(quantity, itemUnit);
    if (quantity > step) {
      quantity -= step;
    }
  }

  // Check if can add more
  bool get canIncrement => quantity < availableStock;

  CartItem copyWith({
    Product? product,
    Service? serviceObj,
    bool? isQuickItem,
    String? itemType,
    int? serviceId,
    String? customItemName,
    double? customItemPrice,
    double? quantity,
    String? selectedUnit,
    String? sellingMode,
    double? packSize,
    String? packSizeUnit,
    double? customSellingPrice,
    int? batchId,
    String? batchNumber,
    double? batchStock,
    double? discount,
  }) {
    return CartItem(
      product: product ?? this.product,
      serviceObj: serviceObj ?? this.serviceObj,
      isQuickItem: isQuickItem ?? this.isQuickItem,
      itemType: itemType ?? this.itemType,
      serviceId: serviceId ?? this.serviceId,
      customItemName: customItemName ?? this.customItemName,
      customItemPrice: customItemPrice ?? this.customItemPrice,
      quantity: quantity ?? this.quantity,
      selectedUnit: selectedUnit ?? this.selectedUnit,
      sellingMode: sellingMode ?? this.sellingMode,
      packSize: packSize ?? this.packSize,
      packSizeUnit: packSizeUnit ?? this.packSizeUnit,
      customSellingPrice: customSellingPrice ?? this.customSellingPrice,
      batchId: batchId ?? this.batchId,
      batchNumber: batchNumber ?? this.batchNumber,
      batchStock: batchStock ?? this.batchStock,
      discount: discount ?? this.discount,
    );
  }
}
