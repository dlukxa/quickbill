import 'package:flutter/material.dart';

class CategoryIconUtil {
  // ── Main category icons ──────────────────────────────────────────────────
  static IconData getIconForMainCategory(String? mainCat) {
    switch (mainCat) {
      case 'Food & Grocery':       return Icons.local_grocery_store;
      case 'Fruits & Vegetables':  return Icons.grass;
      case 'Beverages':            return Icons.local_drink;
      case 'Dairy & Eggs':         return Icons.egg_alt;
      case 'Meat & Seafood':       return Icons.set_meal;
      case 'Bakery & Snacks':      return Icons.cookie;
      case 'Prepared Foods & Deli': return Icons.flatware;
      case 'Personal Care':        return Icons.face_retouching_natural;
      case 'Beauty & Cosmetics':   return Icons.brush;
      case 'Health & Medicine':    return Icons.medical_services;
      case 'Household & Cleaning': return Icons.cleaning_services;
      case 'Baby & Kids':          return Icons.child_care;
      case 'Home & Kitchen':       return Icons.home;
      case 'Clothing & Apparel':   return Icons.checkroom;
      case 'Toys & Hobbies':       return Icons.sports_esports;
      case 'Electronics & Electrical': return Icons.electrical_services;
      case 'Stationery & Office':  return Icons.edit_note;
      case 'Hardware & Tools':     return Icons.handyman;
      case 'Farming & Garden':     return Icons.yard;
      case 'Pet Supplies':         return Icons.pets;
      case 'Automotive':           return Icons.directions_car;
      case 'Fuel & Energy':        return Icons.local_fire_department;
      case 'Tobacco & Alcohol':    return Icons.smoking_rooms;
      case 'Frozen & Ready Foods': return Icons.ac_unit;
      case 'Books & Media':        return Icons.menu_book;
      case 'Gifts & Crafts':       return Icons.card_giftcard;
      case 'Services':             return Icons.miscellaneous_services;
      case 'Other':                return Icons.category;
      default:                     return Icons.inventory_2;
    }
  }

  // ── Main category colors ─────────────────────────────────────────────────
  static Color getColorForMainCategory(String? mainCat) {
    switch (mainCat) {
      case 'Food & Grocery':       return const Color(0xFF4CAF50);
      case 'Fruits & Vegetables':  return const Color(0xFF2E7D32);
      case 'Beverages':            return const Color(0xFF2196F3);
      case 'Dairy & Eggs':         return const Color(0xFFFFEB3B);
      case 'Meat & Seafood':       return const Color(0xFFE53935);
      case 'Bakery & Snacks':      return const Color(0xFF795548);
      case 'Prepared Foods & Deli': return const Color(0xFFD84315);
      case 'Personal Care':        return const Color(0xFF9C27B0);
      case 'Beauty & Cosmetics':   return const Color(0xFFE91E63);
      case 'Health & Medicine':    return const Color(0xFF00BCD4);
      case 'Household & Cleaning': return const Color(0xFF009688);
      case 'Baby & Kids':          return const Color(0xFFFF80AB);
      case 'Home & Kitchen':       return const Color(0xFF1565C0);
      case 'Clothing & Apparel':   return const Color(0xFFE91E63);
      case 'Toys & Hobbies':       return const Color(0xFFFFB300);
      case 'Electronics & Electrical': return const Color(0xFFFF9800);
      case 'Stationery & Office':  return const Color(0xFF3F51B5);
      case 'Hardware & Tools':     return const Color(0xFF607D8B);
      case 'Farming & Garden':     return const Color(0xFF8BC34A);
      case 'Pet Supplies':         return const Color(0xFFFF7043);
      case 'Automotive':           return const Color(0xFF455A64);
      case 'Fuel & Energy':        return const Color(0xFFF44336);
      case 'Tobacco & Alcohol':    return const Color(0xFF6D4C41);
      case 'Frozen & Ready Foods': return const Color(0xFF00ACC1);
      case 'Books & Media':        return const Color(0xFF673AB7);
      case 'Gifts & Crafts':       return const Color(0xFFE91E63);
      case 'Services':             return const Color(0xFF00796B);
      case 'Other':                return const Color(0xFF9E9E9E);
      default:                     return const Color(0xFF78909C);
    }
  }

  // ── Subcategory icons (detailed) ─────────────────────────────────────────
  static IconData getIconForCategory(String? category) {
    if (category == null) return Icons.inventory_2;

    switch (category) {
      // Food & Grocery
      case 'Rice & Grains':        return Icons.rice_bowl;
      case 'Dal & Pulses':         return Icons.spa;
      case 'Cooking Oils & Fats':  return Icons.water_drop;
      case 'Spices & Seasonings':  return Icons.scatter_plot;
      case 'Salt, Sugar & Jaggery':return Icons.grain;
      case 'Flour & Baking':       return Icons.bakery_dining;
      case 'Canned & Preserved Foods': return Icons.kitchen;
      case 'Sauces, Pickles & Condiments': return Icons.local_dining;
      case 'Noodles & Pasta':      return Icons.ramen_dining;
      case 'Organic & Natural Foods': return Icons.eco;

      // Beverages
      case 'Soft Drinks & Sodas':  return Icons.local_drink;
      case 'Juices & Nectars':     return Icons.local_bar;
      case 'Water & Sparkling':    return Icons.water;
      case 'Energy & Sports Drinks': return Icons.sports;
      case 'Tea & Coffee':         return Icons.coffee;
      case 'Milk Drinks & Shakes': return Icons.local_cafe;
      case 'Health & Nutrition Drinks': return Icons.health_and_safety;
      case 'Coconut Water':        return Icons.spa;

      // Dairy & Eggs
      case 'Milk':                 return Icons.local_drink;
      case 'Curd & Yoghurt':       return Icons.local_dining;
      case 'Cheese & Paneer':      return Icons.lunch_dining;
      case 'Butter & Ghee':        return Icons.water_drop;
      case 'Eggs':                 return Icons.egg;
      case 'Ice Cream':            return Icons.icecream;
      case 'Condensed & Evaporated Milk': return Icons.kitchen;

      // Meat & Seafood
      case 'Chicken & Poultry':    return Icons.set_meal;
      case 'Mutton & Lamb':        return Icons.restaurant;
      case 'Fish & Seafood':       return Icons.phishing;
      case 'Processed Meat':       return Icons.lunch_dining;

      // Bakery & Snacks
      case 'Biscuits & Cookies':   return Icons.cookie;
      case 'Chips & Namkeen':      return Icons.fastfood;
      case 'Chocolates & Candies': return Icons.cake;
      case 'Cakes & Pastries':     return Icons.cake;
      case 'Bread & Bakery':       return Icons.bakery_dining;
      case 'Dry Fruits & Nuts':    return Icons.grass;
      case 'Popcorn & Munchies':   return Icons.movie;
      case 'Confectionery & Sweets': return Icons.icecream;

      // Personal Care
      case 'Soaps & Body Wash':    return Icons.soap;
      case 'Shampoo & Conditioner':return Icons.shower;
      case 'Hair Care':            return Icons.face;
      case 'Skin Care & Moisturizers': return Icons.face_retouching_natural;
      case 'Oral Care':            return Icons.clean_hands;
      case 'Deodorants & Perfumes':return Icons.air;
      case 'Shaving & Grooming':   return Icons.content_cut;
      case 'Feminine Hygiene':     return Icons.health_and_safety;
      case 'Sunscreen & Sun Care': return Icons.wb_sunny;
      case 'Tissue & Cotton':      return Icons.layers;

      // Health & Medicine
      case 'OTC Medicines':        return Icons.medication;
      case 'Vitamins & Supplements': return Icons.medical_services;
      case 'First Aid':            return Icons.healing;
      case 'Medical Devices':      return Icons.monitor_heart;
      case 'Ayurvedic & Herbal':   return Icons.eco;
      case 'Protein & Fitness':    return Icons.fitness_center;

      // Household & Cleaning
      case 'Detergent & Laundry':  return Icons.local_laundry_service;
      case 'Dish Wash':            return Icons.kitchen;
      case 'Floor & Toilet Cleaners': return Icons.cleaning_services;
      case 'Air Fresheners & Repellents': return Icons.air;
      case 'Kitchen Essentials':   return Icons.kitchen;
      case 'Brooms, Mops & Brushes': return Icons.brush;
      case 'Trash Bags & Storage': return Icons.delete_outline;
      case 'Disinfectants & Bleach': return Icons.sanitizer;

      // Baby & Kids
      case 'Baby Food & Formula':  return Icons.child_care;
      case 'Diapers & Wipes':      return Icons.baby_changing_station;
      case 'Baby Bath & Skin':     return Icons.bathtub;
      case 'Toys & Games':         return Icons.toys;
      case 'Kids Clothing':        return Icons.checkroom;
      case 'School Supplies':      return Icons.school;

      // Clothing & Apparel
      case 'Men\'s Clothing':      return Icons.man;
      case 'Women\'s Clothing':    return Icons.woman;
      case 'Kids\' Clothing':      return Icons.child_care;
      case 'Innerwear & Socks':    return Icons.checkroom;
      case 'Footwear':             return Icons.directions_walk;
      case 'Accessories':          return Icons.watch;

      // Electronics & Electrical
      case 'Bulbs & Lighting':     return Icons.lightbulb;
      case 'Batteries & Chargers': return Icons.battery_charging_full;
      case 'Cables & Adapters':    return Icons.cable;
      case 'Mobile Accessories':   return Icons.phone_android;
      case 'Small Appliances':     return Icons.kitchen;
      case 'Switches & Sockets':   return Icons.electrical_services;
      case 'Solar & Inverter':     return Icons.solar_power;
      case 'Fans & Cooling':       return Icons.wind_power;

      // Stationery & Office
      case 'Pens & Pencils':       return Icons.edit;
      case 'Notebooks & Paper':    return Icons.note;
      case 'Files & Folders':      return Icons.folder;
      case 'Tapes & Glues':        return Icons.sticky_note_2;
      case 'Markers & Highlighters': return Icons.highlight;
      case 'Printers & Ink':       return Icons.print;
      case 'Calculators':          return Icons.calculate;

      // Hardware & Tools
      case 'Nails, Screws & Fasteners': return Icons.hardware;
      case 'Hand Tools':           return Icons.handyman;
      case 'Paints & Brushes':     return Icons.format_paint;
      case 'Ropes & Wires':        return Icons.cable;
      case 'Plumbing Supplies':    return Icons.plumbing;
      case 'Safety & PPE':         return Icons.safety_divider;
      case 'Locks & Security':     return Icons.lock;

      // Farming & Garden
      case 'Seeds':                return Icons.grass;
      case 'Fertilizers':          return Icons.eco;
      case 'Pesticides & Herbicides': return Icons.pest_control;
      case 'Gardening Tools':      return Icons.yard;
      case 'Pots & Soil':          return Icons.local_florist;
      case 'Irrigation':           return Icons.water;
      case 'Animal Feed':          return Icons.pets;

      // Pet Supplies
      case 'Dog Food':             return Icons.pets;
      case 'Cat Food':             return Icons.pets;
      case 'Bird & Fish Supplies': return Icons.set_meal;
      case 'Pet Accessories':      return Icons.toys;
      case 'Pet Health':           return Icons.medical_services;

      // Automotive
      case 'Engine Oils & Lubricants': return Icons.oil_barrel;
      case 'Car Wash & Polish':    return Icons.local_car_wash;
      case 'Spare Parts':          return Icons.settings;
      case 'Tyres & Tubes':        return Icons.tire_repair;
      case 'Batteries (Auto)':     return Icons.battery_full;

      // Fuel & Energy
      case 'Kerosene':             return Icons.local_fire_department;
      case 'Firewood & Charcoal':  return Icons.local_fire_department;
      case 'Candles & Matches':    return Icons.whatshot;
      case 'Gas Cylinders':        return Icons.propane_tank;

      // Tobacco & Alcohol
      case 'Cigarettes':           return Icons.smoking_rooms;
      case 'Tobacco & Betel':      return Icons.smoking_rooms;
      case 'Beer & Wine':          return Icons.wine_bar;
      case 'Spirits & Liquor':     return Icons.local_bar;

      // Frozen & Ready Foods
      case 'Frozen Vegetables':    return Icons.ac_unit;
      case 'Frozen Meals':         return Icons.microwave;
      case 'Ice Cream & Desserts': return Icons.icecream;
      case 'Ready-to-Cook':        return Icons.restaurant_menu;
      case 'Frozen Meat':          return Icons.set_meal;

      // Books & Media
      case 'Books':                return Icons.book;
      case 'Magazines':            return Icons.article;
      case 'Music & DVDs':         return Icons.album;
      case 'Educational Media':    return Icons.school;

      // Gifts & Crafts
      case 'Gift Cards':           return Icons.card_membership;
      case 'Handmade Crafts':      return Icons.brush;
      case 'Wrapping Paper':       return Icons.gif_box;
      case 'Party Supplies':       return Icons.celebration;

      // Services
      case 'Repair & Maintenance': return Icons.build;
      case 'Consultation':         return Icons.support_agent;
      case 'Delivery & Shipping':  return Icons.local_shipping;
      case 'Labor & Installation': return Icons.engineering;
      case 'Custom Services':      return Icons.design_services;

      // Other / Misc
      case 'Miscellaneous':        return Icons.category;
      case 'Seasonal Items':       return Icons.event;
      case 'Custom':               return Icons.tune;

      // ── Legacy flat categories (backward compat) ─────────────────────────
      case 'Snacks & Biscuits':    return Icons.cookie;
      // 'Confectionery & Sweets' is already handled above as a new subcategory
      case 'Baby & Infant Products': return Icons.child_care;
      case 'Household Cleaning':   return Icons.cleaning_services;
      case 'Stationery & Office':  return Icons.edit;
      case 'Cigarettes & Tobacco': return Icons.smoking_rooms;
      case 'Firewood & Fuel':      return Icons.local_fire_department;
      case 'Hardware & Tools':     return Icons.handyman;
      case 'Farming & Garden':     return Icons.yard;
      case 'Pet Food & Supplies':  return Icons.pets;
      case 'Electrical & Lighting':return Icons.lightbulb;
      case 'Automotive':           return Icons.directions_car;
      case 'Other':                return Icons.category;

      default: return Icons.inventory_2;
    }
  }

  // ── Subcategory colors ───────────────────────────────────────────────────
  static Color getColorForCategory(String? category) {
    if (category == null) return const Color(0xFF78909C);

    switch (category) {
      case 'Rice & Grains':        return const Color(0xFFFFA726);
      case 'Dal & Pulses':         return const Color(0xFF9CCC65);
      case 'Cooking Oils & Fats':  return const Color(0xFFFFCA28);
      case 'Spices & Seasonings':  return const Color(0xFFEF5350);
      case 'Salt, Sugar & Jaggery':return const Color(0xFF8D6E63);
      case 'Flour & Baking':       return const Color(0xFFFFCC80);
      case 'Canned & Preserved Foods': return const Color(0xFF26A69A);
      case 'Sauces, Pickles & Condiments': return const Color(0xFFEC407A);
      case 'Noodles & Pasta':      return const Color(0xFFAB47BC);
      case 'Organic & Natural Foods': return const Color(0xFF66BB6A);
      case 'Soft Drinks & Sodas':  return const Color(0xFF42A5F5);
      case 'Juices & Nectars':     return const Color(0xFFFFCA28);
      case 'Water & Sparkling':    return const Color(0xFF80DEEA);
      case 'Energy & Sports Drinks': return const Color(0xFF66BB6A);
      case 'Tea & Coffee':         return const Color(0xFF8D6E63);
      case 'Milk Drinks & Shakes': return const Color(0xFFCE93D8);
      case 'Health & Nutrition Drinks': return const Color(0xFF4DB6AC);
      case 'Coconut Water':        return const Color(0xFFA5D6A7);
      case 'Milk':                 return const Color(0xFFE3F2FD);
      case 'Curd & Yoghurt':       return const Color(0xFFEDE7F6);
      case 'Cheese & Paneer':      return const Color(0xFFFFF9C4);
      case 'Butter & Ghee':        return const Color(0xFFFFECB3);
      case 'Eggs':                 return const Color(0xFFFFE0B2);
      case 'Ice Cream':            return const Color(0xFFF8BBD0);
      case 'Biscuits & Cookies':   return const Color(0xFFBCAAA4);
      case 'Chips & Namkeen':      return const Color(0xFFFFA726);
      case 'Chocolates & Candies': return const Color(0xFF6D4C41);
      case 'Cakes & Pastries':     return const Color(0xFFF48FB1);
      case 'Bread & Bakery':       return const Color(0xFFFFCC80);
      case 'Dry Fruits & Nuts':    return const Color(0xFFA1887F);
      case 'Soaps & Body Wash':    return const Color(0xFFCE93D8);
      case 'Shampoo & Conditioner':return const Color(0xFFBA68C8);
      case 'Hair Care':            return const Color(0xFF9575CD);
      case 'Skin Care & Moisturizers': return const Color(0xFFF48FB1);
      case 'Oral Care':            return const Color(0xFF81D4FA);
      case 'Deodorants & Perfumes':return const Color(0xFFB39DDB);
      case 'OTC Medicines':        return const Color(0xFFEF9A9A);
      case 'Vitamins & Supplements': return const Color(0xFF80CBC4);
      case 'First Aid':            return const Color(0xFFEF5350);
      case 'Detergent & Laundry':  return const Color(0xFF4FC3F7);
      case 'Dish Wash':            return const Color(0xFF80DEEA);
      case 'Floor & Toilet Cleaners': return const Color(0xFF80CBC4);
      case 'Baby Food & Formula':  return const Color(0xFFF48FB1);
      case 'Diapers & Wipes':      return const Color(0xFFFFCC80);
      case 'Bulbs & Lighting':     return const Color(0xFFFFEE58);
      case 'Batteries & Chargers': return const Color(0xFF78909C);
      case 'Mobile Accessories':   return const Color(0xFF42A5F5);
      case 'Pens & Pencils':       return const Color(0xFF5C6BC0);
      case 'Notebooks & Paper':    return const Color(0xFF7986CB);
      case 'Hand Tools':           return const Color(0xFF78909C);
      case 'Seeds':                return const Color(0xFFA5D6A7);
      case 'Fertilizers':          return const Color(0xFF81C784);
      case 'Dog Food':             return const Color(0xFFFF8A65);
      case 'Cat Food':             return const Color(0xFFFFAB91);
      case 'Engine Oils & Lubricants': return const Color(0xFF546E7A);
      case 'Kerosene':             return const Color(0xFFEF9A9A);
      case 'Firewood & Charcoal':  return const Color(0xFFBCAAA4);
      case 'Cigarettes':           return const Color(0xFFA1887F);
      case 'Beer & Wine':          return const Color(0xFFFFCC80);
      case 'Spirits & Liquor':     return const Color(0xFFFFA726);
      case 'Frozen Meals':         return const Color(0xFF80DEEA);

      // Books & Media
      case 'Books':                return const Color(0xFF673AB7);
      case 'Magazines':            return const Color(0xFF7E57C2);
      case 'Music & DVDs':         return const Color(0xFF9575CD);
      case 'Educational Media':    return const Color(0xFFB39DDB);

      // Gifts & Crafts
      case 'Gift Cards':           return const Color(0xFFE91E63);
      case 'Handmade Crafts':      return const Color(0xFFEC407A);
      case 'Wrapping Paper':       return const Color(0xFFF48FB1);
      case 'Party Supplies':       return const Color(0xFFFF4081);

      // Services
      case 'Repair & Maintenance': return const Color(0xFF00796B);
      case 'Consultation':         return const Color(0xFF00897B);
      case 'Delivery & Shipping':  return const Color(0xFF009688);
      case 'Labor & Installation': return const Color(0xFF26A69A);
      case 'Custom Services':      return const Color(0xFF4DB6AC);

      // ── Legacy flat categories ────────────────────────────────────────────
      case 'Beverages':            return const Color(0xFF42A5F5);
      case 'Snacks & Biscuits':    return const Color(0xFFA1887F);
      case 'Confectionery & Sweets': return const Color(0xFFF48FB1);
      case 'Baby & Infant Products': return const Color(0xFF80DEEA);
      case 'Personal Care':        return const Color(0xFFCE93D8);
      case 'Household Cleaning':   return const Color(0xFF80CBC4);
      case 'Stationery & Office':  return const Color(0xFF7986CB);
      case 'Cigarettes & Tobacco': return const Color(0xFFA1887F);
      case 'Firewood & Fuel':      return const Color(0xFFEF5350);
      case 'Hardware & Tools':     return const Color(0xFF90A4AE);
      case 'Farming & Garden':     return const Color(0xFF81C784);
      case 'Pet Food & Supplies':  return const Color(0xFFFF8A65);
      case 'Electrical & Lighting':return const Color(0xFFFFEE58);
      case 'Automotive':           return const Color(0xFF546E7A);
      case 'Other':                return const Color(0xFF9E9E9E);

      default: return const Color(0xFF78909C);
    }
  }
}
