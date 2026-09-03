import 'product_batch.dart';
import 'product_selling_mode.dart';
import '../services/unit_conversion_service.dart';

class Product {
  final int? id;
  final String name;
  final String? nameSinhala; // NEW: Explicit Sinhala Name (e.g. කිරි තේ)
  final String? nameEnglish; // NEW: Explicit English Name (e.g. Milk Tea)
  final String? searchAliases; // NEW: Custom / auto-generated aliases (e.g. "kiri the, milk tea")
  final String? normalizedTerms; // NEW: Precomputed search tokens for sub-ms search
  final String? baseBarcode;  // Renamed from barcode
  final double price;
  final double? costPrice;
  final double stock;  // For non-batch products only
  final double minStock;
  final String? category;
  final String unit;  // pcs, kg, L, etc. (Canonical base unit)
  final String type;  // 'product', 'service', 'package'
  final String? imageUrl;
  final bool trackBatches;  // Enable batch tracking
  final int branchId;
  final int? supplierId; // Link product to a default supplier
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final bool deleted;

  // Multiple Selling Modes (Loose vs Packaged)
  final bool allowLoose; // Can be sold loose / by weight
  final bool allowPack; // Can be sold as packaged item (e.g. 1kg pack)
  final double? packPrice; // Selling price per pack (e.g. Rs. 270 / pack)
  final double? packCostPrice; // Cost price per pack
  final double? packSize; // Size per pack in packSizeUnit (e.g. 1.0)
  final String packUnit; // Pack unit label (e.g. 'pack', 'box', 'bottle')
  final String packSizeUnit; // Unit of the pack size (e.g. 'kg', 'g', 'L', 'ml')
 
  // Runtime data (not stored in DB)
  final double? totalStock;  // Calculated from batches
  final List<ProductBatch>? batches;  // Associated batches
 
  Product({
    this.id,
    this.branchId = 1,
    required this.name,
    this.nameSinhala,
    this.nameEnglish,
    this.searchAliases,
    this.normalizedTerms,
    this.baseBarcode,
    required this.price,
    this.costPrice,
    this.stock = 0.0,
    this.minStock = 10.0,
    this.category,
    this.unit = 'pcs',
    this.type = 'product',
    this.imageUrl,
    this.trackBatches = false,
    this.supplierId,
    this.allowLoose = true,
    this.allowPack = false,
    this.packPrice,
    this.packCostPrice,
    this.packSize = 1.0,
    this.packUnit = 'pack',
    this.packSizeUnit = 'kg',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.deleted = false,
    this.totalStock,
    this.batches,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Returns canonical base unit (e.g. 'kg', 'L', 'pcs', 'm').
  String get baseUnit => UnitConversionService.normalizeUnit(unit);

  /// Unit category ('weight', 'liquid', 'count', 'packaging', 'length').
  String get unitCategory => UnitConversionService.getUnitCategory(unit);

  /// Whether this product is sold in variable fractional quantities (e.g. weight / liquid).
  bool get isVariableQuantity => UnitConversionService.isVariableQuantityUnit(unit);

  /// Compatible selling units (e.g. ['kg', 'g'] for sugar, ['L', 'ml'] for oil).
  List<String> get compatibleSellingUnits => UnitConversionService.getCompatibleUnits(unit);

  /// Formatted stock string (e.g. "50kg", "49.5kg", "500g", "12 pcs").
  String get formattedStock => UnitConversionService.formatHumanReadableQuantity(calculatedStock, unit);

  /// Whether this product supports both loose and packaged selling modes.
  bool get hasMultipleSellingModes => allowLoose && allowPack && packPrice != null && packPrice! > 0;

  /// Formatted pack size string (e.g. "1kg", "500g", "1.5L").
  String get formattedPackSize {
    final size = packSize ?? 1.0;
    final numStr = size == size.roundToDouble() ? size.toInt().toString() : size.toString();
    return '$numStr$packSizeUnit';
  }

  /// List of available selling modes for this product.
  List<ProductSellingMode> get sellingModes {
    final list = <ProductSellingMode>[];
    if (allowLoose) {
      list.add(ProductSellingMode(
        id: 'loose',
        name: isVariableQuantity ? 'Loose / Weight' : 'Single Item',
        modeType: isVariableQuantity ? 'weight' : 'piece',
        unit: isVariableQuantity ? (unitCategory == 'weight' ? 'g' : 'ml') : baseUnit,
        price: price,
        costPrice: costPrice,
        isDefault: true,
      ));
    }
    if (allowPack && packPrice != null && packPrice! > 0) {
      list.add(ProductSellingMode(
        id: 'pack',
        name: '$formattedPackSize $packUnit',
        modeType: 'pack',
        unit: packUnit,
        packSize: packSize ?? 1.0,
        packSizeUnit: packSizeUnit,
        price: packPrice!,
        costPrice: packCostPrice,
        isDefault: !allowLoose,
      ));
    }
    if (list.isEmpty) {
      list.add(ProductSellingMode(
        id: 'standard',
        name: 'Standard',
        modeType: 'piece',
        unit: baseUnit,
        price: price,
        costPrice: costPrice,
        isDefault: true,
      ));
    }
    return list;
  }

  /// Profit per base unit (Price - Cost).
  double get profitPerBaseUnit => costPrice != null ? (price - costPrice!) : price;

  /// Profit margin percentage per base unit.
  double get profitMarginPercent => (price > 0 && costPrice != null)
      ? (((price - costPrice!) / price) * 100)
      : (price > 0 ? 100.0 : 0.0);

  /// Returns Sinhala name if available, otherwise base name.
  String get sinhalaOrName => (nameSinhala != null && nameSinhala!.trim().isNotEmpty) ? nameSinhala! : name;

  /// Returns English name if available, otherwise base name.
  String get englishOrName => (nameEnglish != null && nameEnglish!.trim().isNotEmpty) ? nameEnglish! : name;
 
  // Get total stock across all batches or simple stock
  double get calculatedStock {
    if (type == 'service' || type == 'package') {
      return double.infinity;
    }
    if (trackBatches) {
      if (batches != null && batches!.isNotEmpty) {
        return batches!.fold(0.0, (sum, batch) => sum + batch.stock);
      }
      return totalStock ?? 0.0;
    }
    return stock;
  }

  // Check if stock is low
  bool get isLowStock => type == 'product' && calculatedStock > 0 && calculatedStock < minStock;
  
  // Check if out of stock
  bool get isOutOfStock => type == 'product' && calculatedStock <= 0;
  
  // Stock status color
  String get stockStatus {
    if (isOutOfStock) return 'out';
    if (isLowStock) return 'low';
    return 'good';
  }

  // Get batches sorted by expiry (FEFO - First Expire First Out)
  List<ProductBatch> get batchesByExpiry {
    if (batches == null) return [];
    final sorted = [...batches!];
    sorted.sort((a, b) {
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
    return sorted;
  }

  // Get batches expiring soon (within 30 days)
  List<ProductBatch> get batchesExpiringSoon {
    if (batches == null) return [];
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
    return batches!.where((batch) {
      if (batch.expiryDate == null) return false;
      return batch.expiryDate!.isBefore(thirtyDaysFromNow) && !batch.isExpired;
    }).toList();
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'name_sinhala': nameSinhala,
      'name_english': nameEnglish,
      'search_aliases': searchAliases,
      'normalized_terms': normalizedTerms,
      'base_barcode': baseBarcode,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'min_stock': minStock,
      'category': category,
      'unit': unit,
      'type': type,
      'image_url': imageUrl,
      'track_batches': trackBatches ? 1 : 0,
      'supplier_id': supplierId,
      'allow_loose': allowLoose ? 1 : 0,
      'allow_pack': allowPack ? 1 : 0,
      'pack_price': packPrice,
      'pack_cost_price': packCostPrice,
      'pack_size': packSize,
      'pack_unit': packUnit,
      'pack_size_unit': packSizeUnit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  // Create from Map (database)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int? ?? 1,
      name: map['name'] as String,
      nameSinhala: map['name_sinhala'] as String?,
      nameEnglish: map['name_english'] as String?,
      searchAliases: map['search_aliases'] as String?,
      normalizedTerms: map['normalized_terms'] as String?,
      baseBarcode: map['base_barcode'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: map['cost_price'] != null 
        ? (map['cost_price'] as num).toDouble() 
        : null,
      stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 10.0,
      category: map['category'] as String?,
      unit: map['unit'] as String? ?? 'pcs',
      type: map['type'] as String? ?? 'product',
      imageUrl: map['image_url'] as String?,
      trackBatches: (map['track_batches'] as int? ?? 0) == 1,
      supplierId: map['supplier_id'] as int?,
      allowLoose: (map['allow_loose'] as int? ?? 1) == 1,
      allowPack: (map['allow_pack'] as int? ?? 0) == 1,
      packPrice: (map['pack_price'] as num?)?.toDouble(),
      packCostPrice: (map['pack_cost_price'] as num?)?.toDouble(),
      packSize: (map['pack_size'] as num?)?.toDouble() ?? 1.0,
      packUnit: map['pack_unit'] as String? ?? 'pack',
      packSizeUnit: map['pack_size_unit'] as String? ?? 'kg',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      synced: (map['synced'] as int? ?? 0) == 1,
      deleted: (map['deleted'] as int? ?? 0) == 1,
      totalStock: (map['total_stock'] as num?)?.toDouble(),
    );
  }

  // Convert to JSON for cloud sync
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'name_sinhala': nameSinhala,
      'name_english': nameEnglish,
      'search_aliases': searchAliases,
      'normalized_terms': normalizedTerms,
      'base_barcode': baseBarcode,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'min_stock': minStock,
      'category': category,
      'unit': unit,
      'type': type,
      'image_url': imageUrl,
      'track_batches': trackBatches,
      'supplier_id': supplierId,
      'allow_loose': allowLoose,
      'allow_pack': allowPack,
      'pack_price': packPrice,
      'pack_cost_price': packCostPrice,
      'pack_size': packSize,
      'pack_unit': packUnit,
      'pack_size_unit': packSizeUnit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

 // Create copy with modifications
  Product copyWith({
    int? id,
    int? branchId,
    String? name,
    String? nameSinhala,
    String? nameEnglish,
    String? searchAliases,
    String? normalizedTerms,
    String? baseBarcode,
    double? price,
    double? costPrice,
    double? stock,
    double? minStock,
    String? category,
    String? unit,
    String? type,
    String? imageUrl,
    bool? trackBatches,
    int? supplierId,
    bool? allowLoose,
    bool? allowPack,
    double? packPrice,
    double? packCostPrice,
    double? packSize,
    String? packUnit,
    String? packSizeUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    bool? deleted,
    double? totalStock,
    List<ProductBatch>? batches,
  }) {
    return Product(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      name: name ?? this.name,
      nameSinhala: nameSinhala ?? this.nameSinhala,
      nameEnglish: nameEnglish ?? this.nameEnglish,
      searchAliases: searchAliases ?? this.searchAliases,
      normalizedTerms: normalizedTerms ?? this.normalizedTerms,
      baseBarcode: baseBarcode ?? this.baseBarcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      trackBatches: trackBatches ?? this.trackBatches,
      supplierId: supplierId ?? this.supplierId,
      allowLoose: allowLoose ?? this.allowLoose,
      allowPack: allowPack ?? this.allowPack,
      packPrice: packPrice ?? this.packPrice,
      packCostPrice: packCostPrice ?? this.packCostPrice,
      packSize: packSize ?? this.packSize,
      packUnit: packUnit ?? this.packUnit,
      packSizeUnit: packSizeUnit ?? this.packSizeUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
      totalStock: totalStock ?? this.totalStock,
      batches: batches ?? this.batches,
    );
  }

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price, stock: $stock, allowPack: $allowPack)';
}

