class AppConstants {
  // App Info
  static const String appName = 'QuickBill';
  static const String appVersion = '1.0.0';
  
  // Database
  static const String databaseName = 'quickbill.db';
  static const int databaseVersion = 1;
  
  // Default Values
  static const int defaultMinStock = 10;
  static const String defaultPaymentMethod = 'cash';
  static const String defaultCurrency = '\$';
  
  // Stock Thresholds
  static const int lowStockThreshold = 10;
  static const int outOfStockThreshold = 0;
  
  // Sync Settings
  static const int syncIntervalMinutes = 5;
  static const int maxSyncRetries = 3;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  
  // Receipt Settings
  static const String receiptPrefix = 'BILL';
  
  // Categories - flat list of ALL subcategories (for legacy usage).
  // For the full hierarchy use CategoryConstants from category_constants.dart.
  static List<String> get productCategories {
    // Dynamically generated from the hierarchy so they stay in sync.
    // Importing CategoryConstants here would create a circular dependency,
    // so we hard-code the same data. Actual hierarchy logic lives in
    // CategoryConstants.
    return [
      // Food & Grocery
      'Rice & Grains', 'Dal & Pulses', 'Cooking Oils & Fats',
      'Spices & Seasonings', 'Salt, Sugar & Jaggery', 'Flour & Baking',
      'Canned & Preserved Foods', 'Sauces, Pickles & Condiments',
      'Noodles & Pasta', 'Organic & Natural Foods',
      // Beverages
      'Soft Drinks & Sodas', 'Juices & Nectars', 'Water & Sparkling',
      'Energy & Sports Drinks', 'Tea & Coffee', 'Milk Drinks & Shakes',
      'Health & Nutrition Drinks', 'Coconut Water',
      // Dairy & Eggs
      'Milk', 'Curd & Yoghurt', 'Cheese & Paneer', 'Butter & Ghee',
      'Eggs', 'Ice Cream', 'Condensed & Evaporated Milk',
      // Meat & Seafood
      'Chicken & Poultry', 'Mutton & Lamb', 'Fish & Seafood',
      'Processed Meat',
      // Bakery & Snacks
      'Biscuits & Cookies', 'Chips & Namkeen', 'Chocolates & Candies',
      'Cakes & Pastries', 'Bread & Bakery', 'Dry Fruits & Nuts',
      'Popcorn & Munchies', 'Confectionery & Sweets',
      // Personal Care
      'Soaps & Body Wash', 'Shampoo & Conditioner', 'Hair Care',
      'Skin Care & Moisturizers', 'Oral Care', 'Deodorants & Perfumes',
      'Shaving & Grooming', 'Feminine Hygiene', 'Sunscreen & Sun Care',
      'Tissue & Cotton',
      // Health & Medicine
      'OTC Medicines', 'Vitamins & Supplements', 'First Aid',
      'Medical Devices', 'Ayurvedic & Herbal', 'Protein & Fitness',
      // Household & Cleaning
      'Detergent & Laundry', 'Dish Wash', 'Floor & Toilet Cleaners',
      'Air Fresheners & Repellents', 'Kitchen Essentials',
      'Brooms, Mops & Brushes', 'Trash Bags & Storage',
      'Disinfectants & Bleach',
      // Baby & Kids
      'Baby Food & Formula', 'Diapers & Wipes', 'Baby Bath & Skin',
      'Toys & Games', 'Kids Clothing', 'School Supplies',
      // Clothing & Apparel
      "Men's Clothing", "Women's Clothing", "Kids' Clothing",
      'Innerwear & Socks', 'Footwear', 'Accessories',
      // Electronics & Electrical
      'Bulbs & Lighting', 'Batteries & Chargers', 'Cables & Adapters',
      'Mobile Accessories', 'Small Appliances', 'Switches & Sockets',
      'Solar & Inverter', 'Fans & Cooling',
      // Stationery & Office
      'Pens & Pencils', 'Notebooks & Paper', 'Files & Folders',
      'Tapes & Glues', 'Markers & Highlighters', 'Printers & Ink',
      'Calculators',
      // Hardware & Tools
      'Nails, Screws & Fasteners', 'Hand Tools', 'Paints & Brushes',
      'Ropes & Wires', 'Plumbing Supplies', 'Safety & PPE',
      'Locks & Security',
      // Farming & Garden
      'Seeds', 'Fertilizers', 'Pesticides & Herbicides',
      'Gardening Tools', 'Pots & Soil', 'Irrigation', 'Animal Feed',
      // Pet Supplies
      'Dog Food', 'Cat Food', 'Bird & Fish Supplies',
      'Pet Accessories', 'Pet Health',
      // Automotive
      'Engine Oils & Lubricants', 'Car Wash & Polish', 'Spare Parts',
      'Tyres & Tubes', 'Batteries (Auto)',
      // Fuel & Energy
      'Kerosene', 'Firewood & Charcoal', 'Candles & Matches',
      'Gas Cylinders',
      // Tobacco & Alcohol
      'Cigarettes', 'Tobacco & Betel', 'Beer & Wine', 'Spirits & Liquor',
      // Frozen & Ready Foods
      'Frozen Vegetables', 'Frozen Meals', 'Ice Cream & Desserts',
      'Ready-to-Cook', 'Frozen Meat',
      // Other
      'Miscellaneous', 'Seasonal Items', 'Custom',
    ];
  }
  
  // Payment Methods
  static const List<String> paymentMethods = [
    'cash',
    'card',
    'upi',
    'credit',
  ];
}
