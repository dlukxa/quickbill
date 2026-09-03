/// Represents a distinct selling mode for a product (e.g. Weight/Loose vs 1kg Pre-Packaged).
class ProductSellingMode {
  final String id;
  final String name; // e.g. 'Loose / Weight', '1kg Pack', '500g Pack'
  final String modeType; // 'weight' | 'pack' | 'piece' | 'liquid'
  final String unit; // 'g', 'kg', 'pack', 'box', 'bottle', 'pcs'
  final double packSize; // e.g. 1.0 (in packSizeUnit)
  final String packSizeUnit; // e.g. 'kg', 'g', 'L', 'ml'
  final double price; // e.g. 250.0 / kg or 270.0 / pack
  final double? costPrice;
  final bool isDefault;

  const ProductSellingMode({
    required this.id,
    required this.name,
    required this.modeType,
    required this.unit,
    this.packSize = 1.0,
    this.packSizeUnit = 'kg',
    required this.price,
    this.costPrice,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mode_type': modeType,
      'unit': unit,
      'pack_size': packSize,
      'pack_size_unit': packSizeUnit,
      'price': price,
      'cost_price': costPrice,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory ProductSellingMode.fromMap(Map<String, dynamic> map) {
    return ProductSellingMode(
      id: map['id']?.toString() ?? 'loose',
      name: map['name']?.toString() ?? 'Standard',
      modeType: map['mode_type']?.toString() ?? 'weight',
      unit: map['unit']?.toString() ?? 'kg',
      packSize: (map['pack_size'] as num?)?.toDouble() ?? 1.0,
      packSizeUnit: map['pack_size_unit']?.toString() ?? 'kg',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble(),
      isDefault: (map['is_default'] == 1 || map['is_default'] == true),
    );
  }
}
