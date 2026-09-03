/// Hierarchical category system for QuickBill POS.
///
/// Each main category contains multiple subcategories (sub-categories).
/// [Product.category] stores the **subcategory** string (backward compatible).
/// Use [CategoryConstants.getMainCategory] to derive the parent from any sub.
class CategoryConstants {
  // ── Business Types (for Shop Setup / Settings) ───────────────────────────
  static const List<String> businessTypes = [
    'Retail',
    'Grocery & Mart',
    'Pharmacy',
    'Electronics',
    'Restaurant & Cafe',
    'Salon & Spa',
    'Fashion & Apparel',
    'Bakery',
    'Services',
    'Other',
  ];

  // ── Main categories (ordered for display) ────────────────────────────────
  static const List<String> mainCategories = [
    'Food & Grocery',
    'Fruits & Vegetables',
    'Beverages',
    'Dairy & Eggs',
    'Meat & Seafood',
    'Bakery & Snacks',
    'Prepared Foods & Deli',
    'Personal Care',
    'Beauty & Cosmetics',
    'Health & Medicine',
    'Household & Cleaning',
    'Baby & Kids',
    'Home & Kitchen',
    'Clothing & Apparel',
    'Toys & Hobbies',
    'Electronics & Electrical',
    'Stationery & Office',
    'Hardware & Tools',
    'Farming & Garden',
    'Pet Supplies',
    'Automotive',
    'Fuel & Energy',
    'Tobacco & Alcohol',
    'Frozen & Ready Foods',
    'Books & Media',
    'Gifts & Crafts',
    'Services',
    'Other',
  ];

  // ── Subcategory hierarchy ────────────────────────────────────────────────
  static const Map<String, List<String>> subcategories = {
    'Food & Grocery': [
      'Rice & Grains',
      'Dal & Pulses',
      'Cooking Oils & Fats',
      'Spices & Seasonings',
      'Salt, Sugar & Jaggery',
      'Flour & Baking',
      'Canned & Preserved Foods',
      'Sauces, Pickles & Condiments',
      'Noodles & Pasta',
      'Organic & Natural Foods',
    ],
    'Beverages': [
      'Soft Drinks & Sodas',
      'Juices & Nectars',
      'Water & Sparkling',
      'Energy & Sports Drinks',
      'Tea & Coffee',
      'Milk Drinks & Shakes',
      'Health & Nutrition Drinks',
      'Coconut Water',
    ],
    'Dairy & Eggs': [
      'Milk',
      'Curd & Yoghurt',
      'Cheese & Paneer',
      'Butter & Ghee',
      'Eggs',
      'Ice Cream',
      'Condensed & Evaporated Milk',
    ],
    'Meat & Seafood': [
      'Chicken & Poultry',
      'Mutton & Lamb',
      'Fish & Seafood',
      'Eggs (Meat Counter)',
      'Processed Meat',
    ],
    'Bakery & Snacks': [
      'Biscuits & Cookies',
      'Chips & Namkeen',
      'Chocolates & Candies',
      'Cakes & Pastries',
      'Bread & Bakery',
      'Dry Fruits & Nuts',
      'Popcorn & Munchies',
      'Confectionery & Sweets',
    ],
    'Personal Care': [
      'Soaps & Body Wash',
      'Shampoo & Conditioner',
      'Hair Care',
      'Skin Care & Moisturizers',
      'Oral Care',
      'Deodorants & Perfumes',
      'Shaving & Grooming',
      'Feminine Hygiene',
      'Sunscreen & Sun Care',
      'Tissue & Cotton',
    ],
    'Health & Medicine': [
      'OTC Medicines',
      'Vitamins & Supplements',
      'First Aid',
      'Medical Devices',
      'Ayurvedic & Herbal',
      'Protein & Fitness',
    ],
    'Household & Cleaning': [
      'Detergent & Laundry',
      'Dish Wash',
      'Floor & Toilet Cleaners',
      'Air Fresheners & Repellents',
      'Kitchen Essentials',
      'Brooms, Mops & Brushes',
      'Trash Bags & Storage',
      'Disinfectants & Bleach',
    ],
    'Baby & Kids': [
      'Baby Food & Formula',
      'Diapers & Wipes',
      'Baby Bath & Skin',
      'Toys & Games',
      'Kids Clothing',
      'School Supplies',
    ],
    'Clothing & Apparel': [
      'Men\'s Clothing',
      'Women\'s Clothing',
      'Kids\' Clothing',
      'Innerwear & Socks',
      'Footwear',
      'Accessories',
    ],
    'Electronics & Electrical': [
      'Bulbs & Lighting',
      'Batteries & Chargers',
      'Cables & Adapters',
      'Mobile Accessories',
      'Small Appliances',
      'Switches & Sockets',
      'Solar & Inverter',
      'Fans & Cooling',
    ],
    'Stationery & Office': [
      'Pens & Pencils',
      'Notebooks & Paper',
      'Files & Folders',
      'Tapes & Glues',
      'Markers & Highlighters',
      'Printers & Ink',
      'Calculators',
    ],
    'Hardware & Tools': [
      'Nails, Screws & Fasteners',
      'Hand Tools',
      'Paints & Brushes',
      'Ropes & Wires',
      'Plumbing Supplies',
      'Safety & PPE',
      'Locks & Security',
    ],
    'Farming & Garden': [
      'Seeds',
      'Fertilizers',
      'Pesticides & Herbicides',
      'Gardening Tools',
      'Pots & Soil',
      'Irrigation',
      'Animal Feed',
    ],
    'Pet Supplies': [
      'Dog Food',
      'Cat Food',
      'Bird & Fish Supplies',
      'Pet Accessories',
      'Pet Health',
    ],
    'Automotive': [
      'Engine Oils & Lubricants',
      'Car Wash & Polish',
      'Spare Parts',
      'Tyres & Tubes',
      'Batteries (Auto)',
      'Accessories',
    ],
    'Fuel & Energy': [
      'Kerosene',
      'Firewood & Charcoal',
      'Candles & Matches',
      'Gas Cylinders',
    ],
    'Tobacco & Alcohol': [
      'Cigarettes',
      'Tobacco & Betel',
      'Beer & Wine',
      'Spirits & Liquor',
    ],
    'Frozen & Ready Foods': [
      'Frozen Vegetables',
      'Frozen Meals',
      'Ice Cream & Desserts',
      'Ready-to-Cook',
      'Frozen Meat',
    ],
    'Books & Media': [
      'Books',
      'Magazines',
      'Music & DVDs',
      'Educational Media',
    ],
    'Gifts & Crafts': [
      'Gift Cards',
      'Handmade Crafts',
      'Wrapping Paper',
      'Party Supplies',
    ],
    'Services': [
      'Repair & Maintenance',
      'Consultation',
      'Delivery & Shipping',
      'Labor & Installation',
      'Custom Services',
    ],
    'Other': [
      'Miscellaneous',
      'Seasonal Items',
      'Custom',
    ],
  };

  // ── Reverse lookup: subcategory → main category ─────────────────────────
  static final Map<String, String> _subToMain = () {
    final map = <String, String>{};
    for (final entry in subcategories.entries) {
      for (final sub in entry.value) {
        map[sub] = entry.key;
      }
    }
    return map;
  }();

  /// Returns the main/parent category for a given subcategory string.
  /// Returns [sub] itself if not found (handles legacy / custom values).
  static String getMainCategory(String? sub) {
    if (sub == null || sub.isEmpty) return 'Other';
    // Direct match as subcategory
    if (_subToMain.containsKey(sub)) return _subToMain[sub]!;
    // Check if it's already a main category
    if (mainCategories.contains(sub)) return sub;
    // Legacy flat categories that map to a main
    return _legacyFallback(sub);
  }

  /// Maps old flat category names (pre-hierarchy) to the new main categories.
  static String _legacyFallback(String old) {
    const legacy = <String, String>{
      'Beverages': 'Beverages',
      'Rice & Grains': 'Food & Grocery',
      'Dal & Pulses': 'Food & Grocery',
      'Cooking Oils & Fats': 'Food & Grocery',
      'Spices & Seasonings': 'Food & Grocery',
      'Canned & Preserved Foods': 'Food & Grocery',
      'Snacks & Biscuits': 'Bakery & Snacks',
      'Confectionery & Sweets': 'Bakery & Snacks',
      'Baby & Infant Products': 'Baby & Kids',
      'Personal Care': 'Personal Care',
      'Household Cleaning': 'Household & Cleaning',
      'Stationery & Office': 'Stationery & Office',
      'Cigarettes & Tobacco': 'Tobacco & Alcohol',
      'Firewood & Fuel': 'Fuel & Energy',
      'Hardware & Tools': 'Hardware & Tools',
      'Farming & Garden': 'Farming & Garden',
      'Pet Food & Supplies': 'Pet Supplies',
      'Electrical & Lighting': 'Electronics & Electrical',
      'Automotive': 'Automotive',
      'Other': 'Other',
    };
    return legacy[old] ?? 'Other';
  }

  /// Flat list of ALL subcategories across all main categories (for search/filter).
  static List<String> get allSubcategories =>
      subcategories.values.expand((list) => list).toList();

  /// Returns subcategories for a given main category, or empty list.
  static List<String> subsFor(String mainCategory) =>
      subcategories[mainCategory] ?? [];
}
