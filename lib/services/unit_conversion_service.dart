/// Result of parsing a quantity and unit from user input (e.g. "500g", "1.5kg", "250ml", "1 dozen").
class ParsedQuantityUnit {
  final double quantity;
  final String unit;
  final String? raw;

  const ParsedQuantityUnit({
    required this.quantity,
    required this.unit,
    this.raw,
  });

  @override
  String toString() => '$quantity $unit';
}

/// Core Unit System and Conversion Service for Sri Lankan POS.
/// Accurately manages weight, liquid, count, and length measurements with zero data loss.
class UnitConversionService {
  UnitConversionService._();
  static final UnitConversionService instance = UnitConversionService._();

  // ---------------------------------------------------------------------------
  // UNIT CATEGORIES & RATIOS RELATIVE TO CATEGORY BASE UNIT
  // ---------------------------------------------------------------------------

  // Category Base Units:
  // Weight: 'kg'
  // Liquid: 'L'
  // Count: 'pcs'
  // Length: 'm'

  static const Map<String, double> _weightUnits = {
    'kg': 1.0,
    'g': 0.001,
    'gram': 0.001,
    'grams': 0.001,
    'kilogram': 1.0,
    'kilograms': 1.0,
  };

  static const Map<String, double> _liquidUnits = {
    'l': 1.0,
    'ltr': 1.0,
    'liter': 1.0,
    'liters': 1.0,
    'litre': 1.0,
    'litres': 1.0,
    'ml': 0.001,
    'milliliter': 0.001,
    'milliliters': 0.001,
  };

  static const Map<String, double> _countUnits = {
    'pcs': 1.0,
    'pc': 1.0,
    'piece': 1.0,
    'pieces': 1.0,
    'item': 1.0,
    'items': 1.0,
    'dozen': 12.0,
    'doz': 12.0,
  };

  static const Map<String, double> _packagingUnits = {
    'pack': 1.0,
    'packet': 1.0,
    'box': 1.0,
    'boxes': 1.0,
    'bottle': 1.0,
    'bottles': 1.0,
    'can': 1.0,
    'cans': 1.0,
    'cup': 1.0,
    'tin': 1.0,
    'bag': 1.0,
  };

  static const Map<String, double> _lengthUnits = {
    'm': 1.0,
    'meter': 1.0,
    'meters': 1.0,
    'cm': 0.01,
    'centimeter': 0.01,
    'centimeters': 0.01,
    'mm': 0.001,
    'millimeter': 0.001,
    'ft': 0.3048,
    'feet': 0.3048,
    'in': 0.0254,
    'inch': 0.0254,
    'inches': 0.0254,
  };

  /// Normalizes a unit string to standard canonical representation.
  /// e.g. 'KG' -> 'kg', 'gram' -> 'g', 'liter' -> 'L', 'pieces' -> 'pcs', 'dozen' -> 'dozen'
  static String normalizeUnit(String unit) {
    final clean = unit.trim().toLowerCase();
    if (_weightUnits.containsKey(clean)) {
      if (clean == 'kg' || clean.startsWith('kilo')) return 'kg';
      return 'g';
    }
    if (_liquidUnits.containsKey(clean)) {
      if (clean == 'ml' || clean.startsWith('milli')) return 'ml';
      return 'L';
    }
    if (_countUnits.containsKey(clean)) {
      if (clean == 'dozen' || clean == 'doz') return 'dozen';
      return 'pcs';
    }
    if (_packagingUnits.containsKey(clean)) {
      if (clean == 'box' || clean == 'boxes') return 'box';
      if (clean == 'bottle' || clean == 'bottles') return 'bottle';
      if (clean == 'can' || clean == 'cans') return 'can';
      return 'pack';
    }
    if (_lengthUnits.containsKey(clean)) {
      if (clean == 'cm' || clean.startsWith('centi')) return 'cm';
      if (clean == 'mm' || clean.startsWith('milli')) return 'mm';
      if (clean == 'ft' || clean == 'feet') return 'ft';
      if (clean == 'in' || clean.startsWith('inch')) return 'in';
      return 'm';
    }
    return clean.isEmpty ? 'pcs' : clean;
  }

  /// Identifies the measurement category of a unit: 'weight', 'liquid', 'count', 'packaging', or 'length'.
  static String getUnitCategory(String unit) {
    final clean = unit.trim().toLowerCase();
    if (_weightUnits.containsKey(clean)) return 'weight';
    if (_liquidUnits.containsKey(clean)) return 'liquid';
    if (_countUnits.containsKey(clean)) return 'count';
    if (_packagingUnits.containsKey(clean)) return 'packaging';
    if (_lengthUnits.containsKey(clean)) return 'length';
    return 'count';
  }

  /// Checks whether a unit represents a variable / fractional quantity (like weight, liquid, or length).
  static bool isVariableQuantityUnit(String unit) {
    final cat = getUnitCategory(unit);
    return cat == 'weight' || cat == 'liquid' || cat == 'length';
  }

  /// Returns list of compatible selling units for a given base unit.
  /// - Weight ('kg') -> ['kg', 'g']
  /// - Liquid ('L')  -> ['L', 'ml']
  /// - Count ('pcs') -> ['pcs', 'dozen']
  /// - Packaging ('pack', 'box', 'bottle', 'can') -> specific package set
  /// - Length ('m')  -> ['m', 'cm']
  static List<String> getCompatibleUnits(String baseUnit) {
    final normBase = normalizeUnit(baseUnit);
    final cat = getUnitCategory(normBase);
    switch (cat) {
      case 'weight':
        return const ['kg', 'g'];
      case 'liquid':
        return const ['L', 'ml'];
      case 'count':
        return const ['pcs', 'dozen'];
      case 'packaging':
        if (normBase == 'bottle') return const ['bottle'];
        if (normBase == 'can') return const ['can'];
        if (normBase == 'box') return const ['box', 'pack'];
        if (normBase == 'pack') return const ['pack', 'box'];
        return [normBase];
      case 'length':
        return const ['m', 'cm'];
      default:
        return const ['pcs', 'dozen'];
    }
  }

  /// Gets the conversion multiplier from a given unit to its category base unit.
  static double getFactorToBase(String unit) {
    final clean = unit.trim().toLowerCase();
    if (_weightUnits.containsKey(clean)) return _weightUnits[clean]!;
    if (_liquidUnits.containsKey(clean)) return _liquidUnits[clean]!;
    if (_countUnits.containsKey(clean)) return _countUnits[clean]!;
    if (_packagingUnits.containsKey(clean)) return _packagingUnits[clean]!;
    if (_lengthUnits.containsKey(clean)) return _lengthUnits[clean]!;
    return 1.0;
  }

  /// Converts a quantity from one unit to another within the same category.
  /// Example: convertQuantity(500, 'g', 'kg') -> 0.5
  ///          convertQuantity(1, 'dozen', 'pcs') -> 12.0
  ///          convertQuantity(250, 'ml', 'L') -> 0.25
  static double convertQuantity(double quantity, String fromUnit, String toUnit) {
    final normFrom = normalizeUnit(fromUnit);
    final normTo = normalizeUnit(toUnit);
    if (normFrom == normTo) return quantity;

    final catFrom = getUnitCategory(normFrom);
    final catTo = getUnitCategory(normTo);

    // If different incompatible categories (e.g. weight to liquid), return raw quantity
    if (catFrom != catTo) {
      return quantity;
    }

    final fromFactor = getFactorToBase(normFrom);
    final toFactor = getFactorToBase(normTo);

    if (toFactor == 0) return quantity;

    // Convert from -> category base -> target
    final baseQty = quantity * fromFactor;
    return baseQty / toFactor;
  }

  /// Converts a sold quantity into the product's base unit quantity (for inventory deduction & pricing).
  /// Example: convertToBaseQuantity(500, 'g', 'kg') -> 0.5
  static double convertToBaseQuantity(double quantity, String soldUnit, String productBaseUnit) {
    return convertQuantity(quantity, soldUnit, productBaseUnit);
  }

  /// Converts a base unit quantity into a target selling unit quantity.
  /// Example: convertFromBaseQuantity(0.5, 'g', 'kg') -> 500.0
  static double convertFromBaseQuantity(double baseQuantity, String targetUnit, String productBaseUnit) {
    return convertQuantity(baseQuantity, productBaseUnit, targetUnit);
  }

  /// Calculates total selling price for a sold quantity in any compatible unit.
  /// Example: calculateLinePrice(250.0, 500, 'g', 'kg') -> 125.0
  ///          calculateLinePrice(10.0, 1, 'dozen', 'pcs') -> 120.0 (where 1 pc is Rs.10)
  static double calculateLinePrice(
    double pricePerBaseUnit,
    double quantity,
    String soldUnit,
    String productBaseUnit, {
    double discount = 0.0,
  }) {
    final baseQty = convertToBaseQuantity(quantity, soldUnit, productBaseUnit);
    final rawTotal = (pricePerBaseUnit * baseQty) - discount;
    // Round to 2 decimal places for financial accuracy
    return ((rawTotal * 100).round() / 100).clamp(0.0, double.infinity);
  }

  /// Calculates total price for a given quantity and unit against base price.
  static double calculatePriceForQuantity({
    required double quantity,
    required String selectedUnit,
    required double basePrice,
    required String baseUnit,
  }) {
    return calculateLinePrice(basePrice, quantity, selectedUnit, baseUnit);
  }

  /// Calculates total cost for a sold quantity in any compatible unit.
  /// Example: calculateLineCost(220.0, 500, 'g', 'kg') -> 110.0
  static double calculateLineCost(
    double costPerBaseUnit,
    double quantity,
    String soldUnit,
    String productBaseUnit,
  ) {
    final baseQty = convertToBaseQuantity(quantity, soldUnit, productBaseUnit);
    final rawCost = costPerBaseUnit * baseQty;
    return (rawCost * 100).round() / 100;
  }

  /// Calculates profit and margin for a sold quantity.
  /// Returns Map with {'profit': double, 'marginPercent': double}
  static Map<String, double> calculateProfitAndMargin({
    required double pricePerBaseUnit,
    required double? costPerBaseUnit,
    required double quantity,
    required String soldUnit,
    required String productBaseUnit,
    double discount = 0.0,
  }) {
    final linePrice = calculateLinePrice(pricePerBaseUnit, quantity, soldUnit, productBaseUnit, discount: discount);
    if (costPerBaseUnit == null || costPerBaseUnit <= 0) {
      return {
        'profit': linePrice,
        'marginPercent': 100.0,
      };
    }

    final lineCost = calculateLineCost(costPerBaseUnit, quantity, soldUnit, productBaseUnit);
    final profit = linePrice - lineCost;
    final marginPercent = linePrice > 0 ? ((profit / linePrice) * 100) : 0.0;

    return {
      'profit': (profit * 100).round() / 100,
      'marginPercent': (marginPercent * 10).round() / 10,
    };
  }

  /// Formats quantity and unit in human-friendly Sri Lankan notation.
  /// Examples:
  ///   0.5kg -> "500g"
  ///   0.25kg -> "250g"
  ///   0.75kg -> "750g"
  ///   1.0kg -> "1kg"
  ///   1.5kg -> "1.5kg"
  ///   0.5L -> "500ml"
  ///   0.25L -> "250ml"
  ///   1.0L -> "1L"
  ///   12pcs -> "12 pcs"
  static String formatHumanReadableQuantity(double baseQuantity, String baseUnit) {
    final normBase = normalizeUnit(baseUnit);
    final cat = getUnitCategory(normBase);

    if (cat == 'weight') {
      if (normBase == 'kg') {
        if (baseQuantity < 1.0 && baseQuantity > 0) {
          final grams = (baseQuantity * 1000).round();
          return '${grams}g';
        }
        final formattedKg = _formatNumber(baseQuantity);
        return '$formattedKg kg';
      }
      return '${_formatNumber(baseQuantity)} $normBase';
    }

    if (cat == 'liquid') {
      if (normBase == 'L') {
        if (baseQuantity < 1.0 && baseQuantity > 0) {
          final ml = (baseQuantity * 1000).round();
          return '${ml}ml';
        }
        final formattedL = _formatNumber(baseQuantity);
        return '$formattedL L';
      }
      return '${_formatNumber(baseQuantity)} $normBase';
    }

    if (cat == 'count') {
      return '${_formatNumber(baseQuantity)} $normBase';
    }

    return '${_formatNumber(baseQuantity)} $normBase';
  }

  /// Formats a line item quantity on receipts / cart items with natural Sri Lankan phrasing.
  /// Examples:
  ///   (500, 'g') -> "500 g"
  ///   (1.5, 'kg') -> "1.5 kg"
  ///   (500, 'ml') -> "500 ml"
  ///   (1, 'L') -> "1 L"
  ///   (1, 'pcs') -> "1 piece"
  ///   (2, 'pcs') -> "2 pieces"
  ///   (6, 'pcs') -> "6 pieces"
  ///   (1, 'dozen') -> "1 dozen"
  ///   (2, 'dozen') -> "2 dozen"
  ///   (1, 'pack') -> "1 pack"
  ///   (2, 'pack') -> "2 packs"
  ///   (1, 'box') -> "1 box"
  ///   (2, 'box') -> "2 boxes"
  static String formatNaturalQuantity(double quantity, String unit) {
    final normUnit = normalizeUnit(unit);
    final numStr = _formatNumber(quantity);

    switch (normUnit) {
      case 'g':
        return '$numStr g';
      case 'kg':
        return '$numStr kg';
      case 'ml':
        return '$numStr ml';
      case 'L':
        return '$numStr L';
      case 'pcs':
      case 'piece':
        return quantity == 1 ? '1 piece' : '$numStr pieces';
      case 'pack':
      case 'packet':
        return quantity == 1 ? '1 pack' : '$numStr packs';
      case 'box':
        return quantity == 1 ? '1 box' : '$numStr boxes';
      case 'dozen':
        return quantity == 1 ? '1 dozen' : '$numStr dozen';
      case 'bottle':
        return quantity == 1 ? '1 bottle' : '$numStr bottles';
      case 'can':
        return quantity == 1 ? '1 can' : '$numStr cans';
      case 'm':
        return '$numStr m';
      case 'cm':
        return '$numStr cm';
      default:
        return '$numStr $normUnit';
    }
  }

  /// Compact line item formatted quantity (e.g. "500g", "1.5kg", "1 piece", "2 pieces").
  static String formatSoldQuantity(double soldQuantity, String soldUnit) {
    final normUnit = normalizeUnit(soldUnit);
    final numStr = _formatNumber(soldQuantity);
    if (normUnit == 'g' || normUnit == 'ml' || normUnit == 'kg' || normUnit == 'L') {
      return '$numStr$normUnit';
    }
    return formatNaturalQuantity(soldQuantity, soldUnit);
  }

  /// Determines appropriate step size for retail quantity incrementing.
  static double getStepIncrement(double currentQuantity, String unit) {
    final normUnit = normalizeUnit(unit);
    if (normUnit == 'g' || normUnit == 'ml') {
      if (currentQuantity < 100) return 50.0;
      if (currentQuantity < 500) return 100.0;
      return 250.0;
    }
    if (normUnit == 'kg' || normUnit == 'L') {
      if (currentQuantity < 1.0) return 0.25;
      return 0.5;
    }
    return 1.0;
  }

  /// Determines appropriate step size for retail quantity decrementing.
  static double getStepDecrement(double currentQuantity, String unit) {
    final normUnit = normalizeUnit(unit);
    if (normUnit == 'g' || normUnit == 'ml') {
      if (currentQuantity <= 100) return 50.0;
      if (currentQuantity <= 500) return 100.0;
      return 250.0;
    }
    if (normUnit == 'kg' || normUnit == 'L') {
      if (currentQuantity <= 1.0) return 0.25;
      return 0.5;
    }
    return 1.0;
  }

  /// Parses a combined string containing quantity and unit (e.g. "500g", "1.5kg", "250ml", "10 pcs").
  static ParsedQuantityUnit? parseQuantityAndUnit(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final regex = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)$');
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final qty = double.tryParse(match.group(1)!);
      final rawUnit = match.group(2)!;
      if (qty != null && qty > 0) {
        return ParsedQuantityUnit(
          quantity: qty,
          unit: normalizeUnit(rawUnit),
          raw: trimmed,
        );
      }
    }

    // Single number with no unit (defaults to 'pcs')
    final singleNum = double.tryParse(trimmed);
    if (singleNum != null && singleNum > 0) {
      return ParsedQuantityUnit(
        quantity: singleNum,
        unit: 'pcs',
        raw: trimmed,
      );
    }

    return null;
  }

  static String _formatNumber(double number) {
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : (number * 10 == (number * 10).roundToDouble() ? 1 : 2));
  }
}
