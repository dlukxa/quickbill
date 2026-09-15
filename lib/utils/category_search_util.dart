import 'package:flutter/widgets.dart';
import '../services/sinhala_search_service.dart';
import '../services/sinhala_transliteration_service.dart';
import 'category_constants.dart';
import 'category_translations.dart';
import 'l10n_extensions.dart';

/// Intelligent category search engine for QuickBill POS.
/// Seamlessly matches categories across:
/// 1. English names (exact and substring)
/// 2. Sinhala Unicode translations (from [CategoryTranslations])
/// 3. Tamil Unicode translations
/// 4. Singlish (Romanized Sinhala, e.g. "kiri", "parippu", "mas", "elawalu", "pan", "the", "biththara")
/// 5. Phonetic Latin representations generated via [SinhalaSearchService.sinhalaToSinglish]
/// 6. Curated Sri Lankan POS colloquial Singlish keywords / synonyms
class CategorySearchUtil {
  CategorySearchUtil._();

  // ---------------------------------------------------------------------------
  // CURATED SRI LANKAN POS SINGLISH KEYWORDS & SYNONYMS
  // ---------------------------------------------------------------------------
  static const Map<String, List<String>> _categoryKeywords = {
    // Main Categories
    'Food & Grocery': [
      'kema', 'kaama', 'groceries', 'badu', 'kadai', 'grocery', 'bath', 'baath',
      'rice', 'haal', 'hal', 'seeni', 'sini', 'lunu', 'parippu', 'dhal', 'tel',
      'thel', 'piti', 'flour', 'samba', 'kakulu', 'kekulu',
    ],
    'Fruits & Vegetables': [
      'elawalu', 'elavalu', 'palathuru', 'palaturu', 'fruits', 'vegetables',
      'gedi', 'kola', 'thakkali', 'ala', 'miris', 'lunu', 'karapincha', 'inguru',
    ],
    'Beverages': [
      'bima', 'beema', 'beemawarga', 'drinks', 'cool drinks', 'soft drinks',
      'tea', 'the', 'thee', 'kopi', 'coffee', 'juice', 'wathura', 'water', 'soda',
    ],
    'Dairy & Eggs': [
      'kiri', 'dairy', 'milk', 'biththara', 'bittara', 'eggs', 'yoghurt',
      'yogurt', 'curd', 'meekiri', 'cheese', 'butter', 'ghee',
    ],
    'Meat & Seafood': [
      'mas', 'meat', 'kukul mas', 'kukulmas', 'chicken', 'malu', 'maalu',
      'fish', 'seafood', 'karawala', 'issa', 'dello', 'prawns', 'mutton', 'elumas',
    ],
    'Bakery & Snacks': [
      'paan', 'pan', 'bread', 'biscuit', 'biscuits', 'biskat', 'kek', 'cake',
      'bakery', 'snacks', 'roti', 'kottu', 'buns', 'pastry', 'short eats', 'bites',
    ],
    'Prepared Foods & Deli': [
      'kottu', 'fried rice', 'curry', 'bath packet', 'short eats', 'deli', 'fast food',
    ],
    'Personal Care': [
      'saban', 'soap', 'shampoo', 'suwanda', 'body wash', 'toothpaste', 'dath',
      'shaving', 'lotion', 'cream', 'perfume',
    ],
    'Beauty & Cosmetics': [
      'cosmetics', 'beauty', 'makeup', 'lipstick', 'cream', 'face wash', 'lotion',
    ],
    'Health & Medicine': [
      'beheth', 'osu', 'medicine', 'pharmacy', 'health', 'panadol', 'siddhalepa',
      'samahan', 'vitamins', 'aspy', 'balm', 'paspanguwa',
    ],
    'Household & Cleaning': [
      'cleaning', 'redhi', 'redi', 'harpic', 'vim', 'sunlight', 'surf', 'detergent',
      'mop', 'broom', 'rin',
    ],
    'Baby & Kids': [
      'baba', 'babala', 'podi', 'baby', 'kids', 'diaper', 'pampers', 'cerelac', 'cheramy',
    ],
    'Home & Kitchen': [
      'kussiya', 'kitchen', 'home', 'kettle', 'plate', 'cup', 'pan', 'koppa',
    ],
    'Clothing & Apparel': [
      'adum', 'aandhum', 'clothes', 'clothing', 'shirt', 'tshirt', 't-shirt',
      'sarong', 'frock', 'saree', 'redi',
    ],
    'Toys & Hobbies': [
      'sellam', 'sellam badu', 'toys', 'games', 'car',
    ],
    'Electronics & Electrical': [
      'viduli', 'plug', 'bulb', 'wire', 'charger', 'cable', 'battery', 'electrical',
    ],
    'Stationery & Office': [
      'poth', 'books', 'stationery', 'pen', 'pencil', 'cr book', 'paper', 'file', 'kole',
    ],
    'Hardware & Tools': [
      'hardware', 'tools', 'yakada', 'ani', 'paint', 'cement', 'saw', 'hammer', 'nails',
    ],
    'Farming & Garden': [
      'govi', 'gewathu', 'govithan', 'pohora', 'waga', 'fertilizer', 'seeds', 'biija',
    ],
    'Pet Supplies': [
      'balla', 'poosa', 'pets', 'dog food', 'cat food', 'pedigree', 'whiskas',
    ],
    'Automotive': [
      'wahana', 'motor', 'bike', 'car', 'tyre', 'engine oil', 'helmet',
    ],
    'Fuel & Energy': [
      'thel', 'petrol', 'diesel', 'gas', 'kerosene', 'dara', 'currant', 'battery', 'fuel',
    ],
    'Tobacco & Alcohol': [
      'dumkola', 'sigarat', 'cigarettes', 'gold leaf', 'dunhill', 'arakku', 'beer', 'alcohol',
    ],
    'Frozen & Ready Foods': [
      'frozen', 'ice', 'shitha', 'sausage', 'meatballs', 'fries',
    ],
    'Books & Media': [
      'poth', 'books', 'magazine', 'newspaper', 'paththara',
    ],
    'Gifts & Crafts': [
      'thegi', 'gifts', 'crafts', 'greeting card',
    ],
    'Services': [
      'sewa', 'services', 'repair', 'delivery', 'labor',
    ],
    'Other': [
      'wenath', 'other', 'general', 'misc',
    ],

    // Subcategories
    'Rice & Grains': [
      'haal', 'hal', 'bath', 'baath', 'rice', 'samba', 'kakulu', 'kekulu',
      'keeri', 'nadu', 'suwandel', 'kurakkan', 'dhaanya', 'grain',
    ],
    'Dal & Pulses': [
      'parippu', 'dhal', 'dahl', 'kadala', 'mun ata', 'kollu', 'kawupi',
      'ata warga', 'pulses', 'gram',
    ],
    'Cooking Oils & Fats': [
      'tel', 'thel', 'pol thel', 'poltel', 'oil', 'fats', 'sunflower oil',
      'palm oil', 'elagitel', 'ghee',
    ],
    'Spices & Seasonings': [
      'kaha', 'miris', 'gamiris', 'thunapaha', 'kulubadu', 'goraka',
      'karapincha', 'inguru', 'sudulunu', 'kurundu', 'spices',
    ],
    'Salt, Sugar & Jaggery': [
      'lunu', 'seeni', 'sini', 'sudu seeni', 'rathu seeni', 'hakuru',
      'sukiri', 'sugar', 'salt', 'jaggery',
    ],
    'Flour & Baking': [
      'piti', 'flour', 'pan piti', 'haal piti', 'kurakkan piti', 'atta',
      'baking powder', 'yeast',
    ],
    'Canned & Preserved Foods': [
      'tin', 'tin malu', 'salmon', 'sardine', 'canned foods', 'tin fish',
    ],
    'Sauces, Pickles & Condiments': [
      'sos', 'sauce', 'tomato sauce', 'chilli sauce', 'achcharu', 'pickle',
      'chutney', 'soya sauce', 'sambal',
    ],
    'Noodles & Pasta': [
      'noodles', 'noodls', 'pasta', 'macaroni', 'spaghetti', 'kottu mee', 'maggi',
    ],
    'Soft Drinks & Sodas': [
      'soda', 'cool bima', 'coke', 'sprite', 'fanta', 'elephant house',
      'egb', 'ginger beer', 'cream soda', 'drinks',
    ],
    'Juices & Nectars': [
      'juice', 'fruit juice', 'cordial', 'nectar', 'smak', 'md',
    ],
    'Water & Sparkling': [
      'wathura', 'water', 'mineral water', 'bottled water',
    ],
    'Tea & Coffee': [
      'the', 'thee', 'tea', 'kopi', 'coffee', 'kahata', 'plain tea',
      'dilmah', 'watawala', 'nescafe',
    ],
    'Milk Drinks & Shakes': [
      'kiri bima', 'milk shake', 'milo', 'nestomalt', 'faluda', 'shake',
    ],
    'Milk': [
      'kiri', 'milk', 'fresh milk', 'elakiri', 'kiri piti', 'anchor',
      'pelwatte', 'highland', 'maliban kiri',
    ],
    'Curd & Yoghurt': [
      'curd', 'yoghurt', 'yogurt', 'meekiri', 'mee kiri', 'highland yoghurt',
    ],
    'Cheese & Paneer': [
      'cheese', 'paneer', 'happy cow',
    ],
    'Butter & Ghee': [
      'butter', 'ghee', 'elagitel', 'flora', 'astra',
    ],
    'Eggs': [
      'biththara', 'bittara', 'egg', 'eggs', 'kukul biththara',
    ],
    'Ice Cream': [
      'ice cream', 'icecream', 'elephant house', 'cargills',
    ],
    'Condensed & Evaporated Milk': [
      'uku kiri', 'condensed milk', 'evaporated milk',
    ],
    'Chicken & Poultry': [
      'kukul mas', 'kukulmas', 'chicken', 'broiler', 'bairaha', 'poultry',
    ],
    'Mutton & Lamb': [
      'elu mas', 'elumas', 'mutton', 'lamb',
    ],
    'Fish & Seafood': [
      'malu', 'maalu', 'fish', 'kelawalla', 'balaya', 'salaya', 'hurulla',
      'karawala', 'issa', 'dello', 'prawns', 'cuttlefish',
    ],
    'Eggs (Meat Counter)': [
      'biththara', 'bittara', 'eggs',
    ],
    'Processed Meat': [
      'sausage', 'sausages', 'meatballs', 'ham', 'bacon',
    ],
    'Biscuits & Cookies': [
      'biscuit', 'biscuits', 'biskat', 'munchee', 'maliban', 'cream cracker',
      'marie', 'lemon puff', 'chocolate puff', 'cookies',
    ],
    'Chips & Namkeen': [
      'chips', 'bites', 'namkeen', 'murukku', 'mixture', 'cassava chips',
    ],
    'Chocolates & Candies': [
      'chocolate', 'chocolates', 'toffee', 'candy', 'kandies', 'slabs', 'edna', 'kandos',
    ],
    'Cakes & Pastries': [
      'cake', 'cakes', 'kek', 'pastry', 'pastries', 'cupcake', 'swiss roll',
    ],
    'Bread & Bakery': [
      'paan', 'pan', 'bread', 'roti', 'buns', 'kimbula banis', 'sandwich bread',
    ],
    'Soaps & Body Wash': [
      'saban', 'soap', 'body wash', 'lifebuoy', 'lux', 'sunlight', 'dettol', 'kohomba',
    ],
    'Shampoo & Conditioner': [
      'shampoo', 'conditioner', 'sunsilk', 'dove', 'head and shoulders',
    ],
    'Oral Care': [
      'dath', 'toothpaste', 'toothbrush', 'signal', 'clogard', 'supirivicky',
    ],
    'OTC Medicines': [
      'panadol', 'paracetamol', 'aspy', 'disprin', 'cough syrup', 'balm',
    ],
    'Ayurvedic & Herbal': [
      'ayurveda', 'ayurvedic', 'siddhalepa', 'samahan', 'paspanguwa',
      'link samahan', 'suwadharani',
    ],
  };

  // ---------------------------------------------------------------------------
  // MATCHING & SCORING ALGORITHM
  // ---------------------------------------------------------------------------

  /// Determines if [category] matches the [rawQuery].
  /// Supports English, Sinhala Unicode, Tamil, Singlish, and colloquial synonyms.
  static bool matchesCategory({
    required String category,
    required String rawQuery,
    BuildContext? context,
  }) {
    final score = calculateScore(category: category, rawQuery: rawQuery, context: context);
    return score > 0;
  }

  /// Calculates a match score for [category] against [rawQuery].
  /// Returns 0 if no match, higher values indicate better match.
  static int calculateScore({
    required String category,
    required String rawQuery,
    BuildContext? context,
  }) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return 100; // empty query matches all

    final queryNoSpace = query.replaceAll(RegExp(r'\s+'), '');
    final catLower = category.toLowerCase();
    final catNoSpace = catLower.replaceAll(RegExp(r'\s+'), '');

    // 1. Exact English match
    if (catLower == query || catNoSpace == queryNoSpace) return 1000;

    // 2. English prefix match
    if (catLower.startsWith(query) || catNoSpace.startsWith(queryNoSpace)) return 800;

    // 3. English substring match
    if (catLower.contains(query) || catNoSpace.contains(queryNoSpace)) return 600;

    // 4. Sinhala Unicode translation match
    final catSinhala = CategoryTranslations.translate(category, 'si').toLowerCase();
    final catSinhalaNoSpace = catSinhala.replaceAll(RegExp(r'\s+'), '');

    if (catSinhala.isNotEmpty) {
      if (catSinhala == query || catSinhalaNoSpace == queryNoSpace) return 950;
      if (catSinhala.startsWith(query) || catSinhalaNoSpace.startsWith(queryNoSpace)) return 750;
      if (catSinhala.contains(query) || catSinhalaNoSpace.contains(queryNoSpace)) return 550;
    }

    // 5. Tamil Unicode translation match
    final catTamil = CategoryTranslations.translate(category, 'ta').toLowerCase();
    final catTamilNoSpace = catTamil.replaceAll(RegExp(r'\s+'), '');

    if (catTamil.isNotEmpty) {
      if (catTamil == query || catTamilNoSpace == queryNoSpace) return 900;
      if (catTamil.startsWith(query) || catTamilNoSpace.startsWith(queryNoSpace)) return 700;
      if (catTamil.contains(query) || catTamilNoSpace.contains(queryNoSpace)) return 500;
    }

    // 6. Localized context match (if active locale differs)
    if (context != null) {
      final loc = context.getLocalizedCategory(category).toLowerCase();
      final locNoSpace = loc.replaceAll(RegExp(r'\s+'), '');
      if (loc.contains(query) || locNoSpace.contains(queryNoSpace)) return 500;
    }

    // 7. Singlish (Romanized Sinhala) transliteration of user's query -> Sinhala
    // Example: "kiri" -> "කිරි", "parippu" -> "පරිප්පු", "mas" -> "මස්"
    if (catSinhala.isNotEmpty) {
      final sinhala1 = SinhalaSearchService.singlishToSinhala(query);
      final sinhala2 = SinhalaTransliterationService.transliterate(query);

      for (final sQuery in {sinhala1, sinhala2}) {
        if (sQuery.isNotEmpty && SinhalaSearchService.isSinhala(sQuery)) {
          final sQueryNorm = SinhalaSearchService.normalizeSinhala(sQuery);
          final catSinhalaNorm = SinhalaSearchService.normalizeSinhala(catSinhala);

          if (catSinhalaNorm == sQueryNorm) return 900;
          if (catSinhalaNorm.startsWith(sQueryNorm)) return 700;
          if (catSinhalaNorm.contains(sQueryNorm)) return 500;

          // Word-level check
          final words = catSinhalaNorm.split(RegExp(r'\s+'));
          for (final w in words) {
            if (w == sQueryNorm || w.startsWith(sQueryNorm)) return 650;
          }
        }
      }

      // 8. Reverse: Sinhala category -> Singlish representations
      // Example: "කිරි තේ" -> ["kiri the", "kiri thee", "kirithe"]
      final singlishVariants = SinhalaSearchService.sinhalaToSinglish(catSinhala);
      for (final variant in singlishVariants) {
        final vNorm = variant.toLowerCase();
        final vNoSpace = vNorm.replaceAll(RegExp(r'\s+'), '');

        if (vNorm == query || vNoSpace == queryNoSpace) return 850;
        if (vNorm.startsWith(query) || vNoSpace.startsWith(queryNoSpace)) return 650;
        if (vNorm.contains(query) || vNoSpace.contains(queryNoSpace)) return 450;
      }
    }

    // 9. Curated Sri Lankan POS Singlish Keywords & Synonyms
    final keywords = _categoryKeywords[category];
    if (keywords != null) {
      for (final kw in keywords) {
        final kwLower = kw.toLowerCase();
        final kwNoSpace = kwLower.replaceAll(RegExp(r'\s+'), '');

        if (kwLower == query || kwNoSpace == queryNoSpace) return 800;
        if (kwLower.startsWith(query) || kwNoSpace.startsWith(queryNoSpace)) return 600;
        if (query.startsWith(kwLower) || queryNoSpace.startsWith(kwNoSpace)) return 550;
        if (kwLower.contains(query) || kwNoSpace.contains(queryNoSpace)) return 400;
        if (query.contains(kwLower)) return 350;
      }
    }

    // 10. Parent / Child category association
    // If this is a main category, check if any of its subcategories have high match
    if (CategoryConstants.mainCategories.contains(category)) {
      final subs = CategoryConstants.subsFor(category);
      for (final sub in subs) {
        final subScore = calculateScore(category: sub, rawQuery: query, context: context);
        if (subScore >= 600) return 300; // Boost main category if subcategory is a strong match
      }
    }

    return 0;
  }

  // ---------------------------------------------------------------------------
  // FILTERING HELPERS
  // ---------------------------------------------------------------------------

  /// Filters and ranks a list of [categories] based on Singlish/Sinhala/English query.
  static List<String> filterCategories({
    required List<String> categories,
    required String query,
    BuildContext? context,
  }) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return List.from(categories);

    final scored = <MapEntry<String, int>>[];
    for (final cat in categories) {
      final score = calculateScore(category: cat, rawQuery: cleanQuery, context: context);
      if (score > 0) {
        scored.add(MapEntry(cat, score));
      }
    }

    // Sort descending by score, maintaining stable order for ties
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Filters [CategoryConstants.mainCategories] with Singlish/Sinhala/English support.
  static List<String> filterMainCategories(String query, {BuildContext? context}) {
    return filterCategories(
      categories: CategoryConstants.mainCategories,
      query: query,
      context: context,
    );
  }

  /// Filters [CategoryConstants.allSubcategories] with Singlish/Sinhala/English support.
  static List<String> filterSubcategories(String query, {BuildContext? context}) {
    return filterCategories(
      categories: CategoryConstants.allSubcategories,
      query: query,
      context: context,
    );
  }
}
