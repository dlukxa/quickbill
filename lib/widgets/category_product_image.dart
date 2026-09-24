import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/category_detection_service.dart';
import '../utils/category_constants.dart';
import '../utils/category_icon_util.dart';
import '../utils/l10n_extensions.dart';

/// A rich, category-specific visual placeholder rendered when a product has no custom photo.
/// Uses procedural multi-stop gradients, tilted watermark motifs, frosted glass icon emblems,
/// and localized Sinhala category pills.
class CategoryProductImage extends StatelessWidget {
  final String? category;
  final String? productName;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool? showLabel;
  final bool? isDark;

  const CategoryProductImage({
    super.key,
    this.category,
    this.productName,
    this.width,
    this.height,
    this.borderRadius,
    this.showLabel,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final themeDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    // Resolve the most specific category or subcategory
    final resolvedCat = _resolveCategory();
    final icon = CategoryIconUtil.getIconForCategory(resolvedCat);
    final gradientColors = _getGradientForCategory(resolvedCat, themeDark);

    // Check if we are in compact mode (e.g. 44x44 cart thumbnails or 32x32 tables)
    final isCompact = (width != null && width! <= 56) || (height != null && height! <= 56);
    final shouldShowLabel = (showLabel ?? (!isCompact && (height == null || height! >= 75)));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Ambient soft radial highlight ──
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer 2: Oversized tilted watermark icon ──
          if (!isCompact)
            Positioned(
              right: -10,
              bottom: -10,
              child: Transform.rotate(
                angle: -15 * math.pi / 180,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),
            ),

          // ── Layer 3: Central Elevated Frosted Icon Emblem ──
          Center(
            child: isCompact
                ? Icon(
                    icon,
                    size: math.min(width ?? 28, height ?? 28) * 0.52,
                    color: Colors.white.withValues(alpha: 0.95),
                  )
                : Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
          ),

          // ── Layer 4: Frosted localized category name pill ──
          if (shouldShowLabel)
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    context.getLocalizedCategory(resolvedCat),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Resolves the category by combining explicit category with name-based keyword detection.
  String _resolveCategory() {
    final rawCat = category?.trim();

    // If explicit category is valid and not generic
    if (rawCat != null &&
        rawCat.isNotEmpty &&
        rawCat != 'General' &&
        rawCat != 'Uncategorized' &&
        rawCat != 'Other') {
      return rawCat;
    }

    // Try detecting specific subcategory from product name
    if (productName != null && productName!.trim().isNotEmpty) {
      final detectedSub = CategoryDetectionService.detectSubcategory(productName!);
      if (detectedSub != null) return detectedSub;

      final detectedMain = CategoryDetectionService.detectCategory(productName!);
      if (detectedMain != null) return detectedMain;
    }

    // Fall back to original category if provided, else 'Food & Grocery'
    if (rawCat != null && rawCat.isNotEmpty) {
      return rawCat;
    }
    return 'Food & Grocery';
  }

  /// Curated multi-stop gradient color pairs for each category and subcategory.
  static List<Color> _getGradientForCategory(String category, bool isDark) {
    final main = CategoryConstants.getMainCategory(category);

    // Fine-grained subcategory palettes
    switch (category) {
      case 'Flour & Baking':
        return const [Color(0xFFD97706), Color(0xFFB45309), Color(0xFF78350F)]; // Warm oven flour amber
      case 'Noodles & Pasta':
        return const [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFC2410C)]; // Italian pasta orange
      case 'Cooking Oils & Fats':
        return const [Color(0xFFEAB308), Color(0xFFCA8A04), Color(0xFFA16207)]; // Golden oil drop
      case 'Rice & Grains':
        return const [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFF92400E)]; // Harvest grain gold
      case 'Dal & Pulses':
        return const [Color(0xFF84CC16), Color(0xFF65A30D), Color(0xFF4D7C0F)]; // Split pea green
      case 'Spices & Seasonings':
        return const [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF991B1B)]; // Chili crimson
      case 'Salt, Sugar & Jaggery':
        return const [Color(0xFF8D6E63), Color(0xFF6D4C41), Color(0xFF4E342E)]; // Cane sugar mocha
      case 'Sauces, Pickles & Condiments':
        return const [Color(0xFFEC407A), Color(0xFFD81B60), Color(0xFFAD1457)]; // Spicy sauce berry

      case 'Tea & Coffee':
        return const [Color(0xFF795548), Color(0xFF5D4037), Color(0xFF3E2723)]; // Roasted coffee brown
      case 'Soft Drinks & Sodas':
        return const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)]; // Fizzy soda blue
      case 'Juices & Nectars':
        return const [Color(0xFFF59E0B), Color(0xFFEA580C), Color(0xFFC2410C)]; // Tropical juice glow
      case 'Milk':
      case 'Dairy & Eggs':
        return const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF1E3A8A)]; // Creamy fresh milk blue
      case 'Curd & Yoghurt':
        return const [Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF5B21B6)]; // Royal curd violet
      case 'Ice Cream':
        return const [Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFF9D174D)]; // Strawberry pink

      case 'Biscuits & Cookies':
        return const [Color(0xFFB45309), Color(0xFF92400E), Color(0xFF78350F)]; // Crisp biscuit amber
      case 'Chocolates & Candies':
        return const [Color(0xFF5B21B6), Color(0xFF4C1D95), Color(0xFF2E1065)]; // Velvet cocoa purple
      case 'Bread & Bakery':
        return const [Color(0xFFD97706), Color(0xFFB45309), Color(0xFF854D0E)]; // Golden toasted bread

      case 'Hair Care':
        return const [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF5B21B6)]; // Hair salon violet
      case 'Soaps & Body Wash':
        return const [Color(0xFFA855F7), Color(0xFF9333EA), Color(0xFF7E22CE)]; // Lavender soap
      case 'Shampoo & Conditioner':
        return const [Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF4C1D95)]; // Deep shampoo indigo
      case 'Skin Care & Moisturizers':
        return const [Color(0xFFF472B6), Color(0xFFE11D48), Color(0xFFBE123C)]; // Radiant skin rose
      case 'Oral Care':
        return const [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0E7490)]; // Minty cyan
      case 'Deodorants & Perfumes':
        return const [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)]; // Fragrance indigo

      case 'OTC Medicines':
      case 'Health & Medicine':
        return const [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF115E59)]; // Clinical apothecary teal
      case 'Detergent & Laundry':
      case 'Household & Cleaning':
        return const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF1E3A8A)]; // Sparkling laundry sapphire
      case 'Chicken & Poultry':
      case 'Meat & Seafood':
        return const [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239)]; // Fresh butcher red
      case 'Fish & Seafood':
        return const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF0F766E)]; // Ocean fish cyan-blue
    }

    // Main category fallbacks
    switch (main) {
      case 'Food & Grocery':
        return const [Color(0xFF16A34A), Color(0xFF15803D), Color(0xFF166534)]; // Vibrant emerald
      case 'Beverages':
        return const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)]; // Deep sapphire
      case 'Dairy & Eggs':
        return const [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)]; // Fresh dairy
      case 'Meat & Seafood':
        return const [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239)]; // Crimson
      case 'Bakery & Snacks':
        return const [Color(0xFFB45309), Color(0xFF92400E), Color(0xFF78350F)]; // Warm bakery
      case 'Personal Care':
        return const [Color(0xFF9333EA), Color(0xFF7E22CE), Color(0xFF6B21A8)]; // Royal purple
      case 'Beauty & Cosmetics':
        return const [Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFFBE185D)]; // Glam rose
      case 'Health & Medicine':
        return const [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF115E59)]; // Healing teal
      case 'Household & Cleaning':
        return const [Color(0xFF0891B2), Color(0xFF0E7490), Color(0xFF155E75)]; // Fresh cyan
      case 'Baby & Kids':
        return const [Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFFE11D48)]; // Soft coral
      case 'Electronics & Electrical':
        return const [Color(0xFFD97706), Color(0xFFB45309), Color(0xFF92400E)]; // Electric amber
      case 'Stationery & Office':
        return const [Color(0xFF4F46E5), Color(0xFF4338CA), Color(0xFF3730A3)]; // Royal indigo
      case 'Hardware & Tools':
        return const [Color(0xFF475569), Color(0xFF334155), Color(0xFF1E293B)]; // Industrial slate
      case 'Farming & Garden':
        return const [Color(0xFF65A30D), Color(0xFF4D7C0F), Color(0xFF365314)]; // Lush foliage
      case 'Pet Supplies':
        return const [Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFF9A3412)]; // Pet orange
      case 'Automotive':
        return const [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)]; // Deep charcoal
      case 'Fuel & Energy':
        return const [Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF991B1B)]; // Energy red
      case 'Tobacco & Alcohol':
        return const [Color(0xFF57534E), Color(0xFF44403C), Color(0xFF292524)]; // Warm smoke
      default:
        return const [Color(0xFF475569), Color(0xFF334155), Color(0xFF1E293B)]; // Refined slate
    }
  }
}
