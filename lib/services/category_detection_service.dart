import '../utils/category_constants.dart';

/// Detects the most likely main category for a product based on its name.
class CategoryDetectionService {
  static const Map<String, List<String>> _categoryKeywords = {
    // ── Food & Grocery ────────────────────────────────────────────────────
    'Rice & Grains': [
      'rice', 'basmati', 'jasmine', 'samba', 'red raw rice', 'rice flour',
      'wheat flour', 'all-purpose flour', 'semolina', 'rava', 'oats',
      'barley', 'millet', 'ragi', 'quinoa', 'cornflakes', 'poha',
      'wheat', 'maida', 'sooji',
    ],
    'Dal & Pulses': [
      'dal', 'dhal', 'lentils', 'chickpeas', 'chana', 'rajma', 'kidney beans',
      'black beans', 'moong', 'masoor', 'toor', 'urad', 'soya', 'peas',
      'gram', 'beans',
    ],
    'Cooking Oils & Fats': [
      'oil', 'coconut oil', 'vegetable oil', 'sunflower oil', 'palm oil',
      'sesame oil', 'groundnut oil', 'mustard oil', 'ghee', 'butter',
      'margarine', 'shortening', 'dalda',
    ],
    'Spices & Seasonings': [
      'turmeric', 'cumin', 'coriander', 'chilli', 'masala', 'curry',
      'pepper', 'cardamom', 'cinnamon', 'cloves', 'bay leaves', 'fenugreek',
      'mustard seeds', 'paprika', 'garam masala', 'sambhar', 'rasam',
      'chat masala', 'biryani masala', 'tandoori masala',
    ],
    'Salt, Sugar & Jaggery': [
      'salt', 'sugar', 'jaggery', 'brown sugar', 'icing sugar',
      'powdered sugar', 'rock salt', 'sea salt',
    ],
    'Flour & Baking': [
      'baking powder', 'baking soda', 'yeast', 'vanilla essence',
      'cocoa powder', 'corn starch', 'gelatin', 'cake mix',
    ],
    'Canned & Preserved Foods': [
      'canned', 'tuna', 'sardines', 'mackerel', 'corned beef',
      'condensed milk', 'evaporated milk', 'coconut milk', 'tomato paste',
      'fruit cocktail',
    ],
    'Sauces, Pickles & Condiments': [
      'ketchup', 'vinegar', 'soy sauce', 'fish sauce', 'oyster sauce',
      'chilli sauce', 'tomato sauce', 'mayonnaise', 'mustard sauce',
      'pickle', 'achar', 'mango pickle', 'jam', 'jelly', 'marmalade',
    ],
    'Noodles & Pasta': [
      'noodles', 'pasta', 'spaghetti', 'macaroni', 'maggi', 'ramen',
      'vermicelli', 'instant noodles',
    ],
    'Organic & Natural Foods': [
      'organic', 'natural', 'whole grain', 'multigrain', 'gluten-free',
      'vegan', 'raw honey', 'sprouts',
    ],

    // ── Beverages ─────────────────────────────────────────────────────────
    'Soft Drinks & Sodas': [
      'coca-cola', 'coke', 'pepsi', 'sprite', 'fanta', '7up', 'mirinda',
      'mountain dew', 'rc cola', 'soda', 'soft drink', 'carbonated',
    ],
    'Juices & Nectars': [
      'juice', 'zesto', 'minute maid', 'tropicana', 'real juice',
      'mango juice', 'orange juice', 'cordial', 'nectar',
    ],
    'Water & Sparkling': [
      'mineral water', 'drinking water', 'sparkling water', 'acqua',
      'evian', 'kinley', 'bisleri',
    ],
    'Energy & Sports Drinks': [
      'energy drink', 'monster', 'red bull', 'gatorade', 'sports drink',
      'electral', 'sting',
    ],
    'Tea & Coffee': [
      'tea', 'green tea', 'black tea', 'chai', 'coffee', 'instant coffee',
      'nescafe', 'bru', 'lipton', 'taj mahal', 'tetley',
    ],
    'Milk Drinks & Shakes': [
      'milo', 'ovaltine', 'horlicks', 'bournvita', 'complan', 'boost',
      'milk shake', 'flavoured milk', 'lassi',
    ],
    'Health & Nutrition Drinks': [
      'ensure', 'pediasure', 'glucon-d', 'glucon d', 'electrolyte',
      'protein drink', 'health drink',
    ],
    'Coconut Water': ['coconut water', 'tender coconut', 'nariyal pani'],

    // ── Dairy & Eggs ──────────────────────────────────────────────────────
    'Milk': ['milk', 'full cream milk', 'toned milk', 'skimmed milk', 'amul milk'],
    'Curd & Yoghurt': ['curd', 'yoghurt', 'yogurt', 'dahi'],
    'Cheese & Paneer': ['cheese', 'paneer', 'cottage cheese', 'cheddar', 'mozzarella'],
    'Butter & Ghee': ['butter', 'ghee', 'margarine', 'amul butter'],
    'Eggs': ['eggs', 'egg', 'hen egg'],
    'Ice Cream': ['ice cream', 'gelato', 'kulfi', 'kwality walls', 'amul ice cream'],
    'Condensed & Evaporated Milk': ['condensed milk', 'evaporated milk', 'milkmaid'],

    // ── Meat & Seafood ────────────────────────────────────────────────────
    'Chicken & Poultry': ['chicken', 'turkey', 'duck', 'broiler', 'poultry'],
    'Mutton & Lamb': ['mutton', 'lamb', 'goat meat', 'beef'],
    'Fish & Seafood': [
      'fish', 'salmon', 'tuna', 'prawn', 'shrimp', 'crab', 'lobster',
      'squid', 'sardine', 'mackerel', 'tilapia', 'catfish',
    ],
    'Processed Meat': ['sausage', 'salami', 'ham', 'pepperoni', 'hot dog', 'nuggets'],

    // ── Bakery & Snacks ───────────────────────────────────────────────────
    'Biscuits & Cookies': [
      'biscuits', 'marie', 'glucose biscuit', 'digestive', 'good day',
      'oreo', 'bourbon', 'hide & seek', 'cookies', 'crackers',
    ],
    'Chips & Namkeen': [
      'chips', 'lays', 'kurkure', 'bhujia', 'namkeen', 'fryums',
      'murukku', 'popcorn', 'nachos', 'puffed rice',
    ],
    'Chocolates & Candies': [
      'chocolate', 'dairy milk', 'kitkat', 'mars', 'twix', '5 star',
      'candy', 'toffee', 'lollipop', 'gum', 'chewing gum', 'mint',
      'mints', 'eclairs',
    ],
    'Cakes & Pastries': ['cake', 'pastry', 'muffin', 'brownie', 'donut', 'croissant'],
    'Bread & Bakery': [
      'bread', 'white bread', 'brown bread', 'whole wheat bread',
      'roti', 'pav', 'bun', 'toast',
    ],
    'Dry Fruits & Nuts': [
      'almonds', 'cashews', 'raisins', 'dates', 'walnuts', 'pistachios',
      'peanuts', 'trail mix', 'dried mango', 'figs', 'apricots',
    ],
    'Popcorn & Munchies': ['popcorn', 'pork rinds', 'trail mix'],
    'Confectionery & Sweets': [
      'halwa', 'ladoo', 'barfi', 'gulab jamun', 'rasgulla', 'jalebi',
      'soan papdi', 'indian sweets', 'mithai',
    ],

    // ── Personal Care ─────────────────────────────────────────────────────
    'Soaps & Body Wash': [
      'soap', 'dove', 'lifebuoy', 'dettol', 'lux', 'pears',
      'body wash', 'shower gel', 'glycerine soap',
    ],
    'Shampoo & Conditioner': [
      'shampoo', 'conditioner', 'head & shoulders', 'pantene', 'sunsilk',
      'dove shampoo', 'clinic plus',
    ],
    'Hair Care': ['hair oil', 'parachute', 'comb', 'hair gel', 'hair cream', 'serum'],
    'Skin Care & Moisturizers': [
      'moisturizer', 'lotion', 'face wash', 'face cream', 'vaseline',
      'nivea', 'fair & lovely', 'pond\'s',
    ],
    'Oral Care': [
      'toothpaste', 'colgate', 'sensodyne', 'pepsodent', 'toothbrush',
      'mouthwash', 'dental floss', 'listerine',
    ],
    'Deodorants & Perfumes': ['deodorant', 'perfume', 'deo', 'body spray', 'axe', 'rexona'],
    'Shaving & Grooming': ['razor', 'shaving cream', 'gillette', 'after shave', 'trimmer'],
    'Feminine Hygiene': ['sanitary', 'pad', 'whisper', 'stayfree', 'tampons'],
    'Sunscreen & Sun Care': ['sunscreen', 'spf', 'sun block', 'tanning'],
    'Tissue & Cotton': ['tissue', 'cotton', 'wipes', 'kitchen roll', 'napkins'],

    // ── Health & Medicine ─────────────────────────────────────────────────
    'OTC Medicines': ['paracetamol', 'crocin', 'disprin', 'antacid', 'iodine'],
    'Vitamins & Supplements': [
      'vitamins', 'calcium', 'iron tablet', 'omega-3', 'multivitamin',
      'supplement', 'zinc',
    ],
    'First Aid': ['bandage', 'plaster', 'band-aid', 'antiseptic', 'savlon'],
    'Ayurvedic & Herbal': ['chyawanprash', 'triphala', 'ashwagandha', 'ayurvedic'],
    'Protein & Fitness': ['protein powder', 'whey', 'creatine', 'bcaa', 'gym supplement'],

    // ── Household & Cleaning ──────────────────────────────────────────────
    'Detergent & Laundry': [
      'detergent', 'surf', 'ariel', 'tide', 'wheel', 'rin', 'fabric softener',
      'comfort', 'washing powder', 'liquid detergent',
    ],
    'Dish Wash': ['dish wash', 'dish soap', 'vim', 'pril', 'sunlight dish'],
    'Floor & Toilet Cleaners': [
      'floor cleaner', 'toilet cleaner', 'harpic', 'domex', 'phenyl',
      'bathroom cleaner', 'colin',
    ],
    'Air Fresheners & Repellents': [
      'air freshener', 'repellent', 'mosquito', 'good knight', 'hit',
      'odonil', 'room freshener', 'coil',
    ],
    'Brooms, Mops & Brushes': ['broom', 'mop', 'scrub', 'sponge', 'brush', 'duster'],
    'Trash Bags & Storage': ['trash bag', 'garbage bag', 'zip lock', 'container'],
    'Disinfectants & Bleach': ['bleach', 'disinfectant', 'dettol', 'savlon', 'sanitizer'],

    // ── Baby & Kids ───────────────────────────────────────────────────────
    'Baby Food & Formula': [
      'baby food', 'lactogen', 'nan', 'enfamil', 'formula', 'cerelac',
      'gerber', 'baby cereal',
    ],
    'Diapers & Wipes': [
      'diaper', 'pampers', 'huggies', 'dry love', 'baby wipes',
      'wet wipes', 'baby diaper',
    ],
    'Baby Bath & Skin': [
      'baby soap', 'baby shampoo', 'baby lotion', 'baby powder',
      'johnson\'s', 'himalaya baby',
    ],

    // ── Electronics & Electrical ──────────────────────────────────────────
    'Bulbs & Lighting': ['bulb', 'led bulb', 'cfl', 'tubelight', 'torch', 'flashlight'],
    'Batteries & Chargers': [
      'battery', 'duracell', 'eveready', 'charger', 'power bank',
      'usb charger',
    ],
    'Mobile Accessories': [
      'earphones', 'headphones', 'phone case', 'screen guard', 'usb cable',
      'data cable',
    ],
    'Cables & Adapters': ['hdmi', 'adapter', 'extension cord', 'cable', 'usb'],
    'Switches & Sockets': ['switch', 'socket', 'plug', 'mcb', 'fuse'],
    'Solar & Inverter': ['solar panel', 'inverter', 'ups', 'solar light'],

    // ── Stationery & Office ───────────────────────────────────────────────
    'Pens & Pencils': ['pen', 'pencil', 'ball pen', 'gel pen', 'reynolds'],
    'Notebooks & Paper': [
      'notebook', 'paper', 'register', 'notepad', 'envelope', 'memo',
      'memo block', 'sticky note', 'post-it', 'writing pad', 'diary',
      'ruled paper', 'a4 paper', 'copy paper', 'bond paper', 'legal pad',
    ],
    'Files & Folders': ['file', 'folder', 'binder', 'stapler', 'clips'],
    'Tapes & Glues': ['tape', 'glue', 'adhesive', 'fevicol', 'packing tape'],
    'Markers & Highlighters': ['marker', 'highlighter', 'whiteboard marker', 'sketch pen'],

    // ── Hardware & Tools ──────────────────────────────────────────────────
    'Nails, Screws & Fasteners': ['nail', 'screw', 'bolt', 'nut', 'washer', 'rivet'],
    'Hand Tools': ['hammer', 'screwdriver', 'pliers', 'wrench', 'chisel'],
    'Paints & Brushes': ['paint', 'enamel', 'emulsion', 'primer', 'paintbrush'],
    'Ropes & Wires': ['rope', 'wire', 'chain', 'copper wire', 'electrical wire'],
    'Plumbing Supplies': ['pipe', 'faucet', 'tap', 'pvc pipe', 'elbow', 'coupling'],
    'Locks & Security': ['lock', 'padlock', 'handle', 'hinge', 'door lock'],

    // ── Farming & Garden ──────────────────────────────────────────────────
    'Seeds': ['seeds', 'vegetable seeds', 'paddy seed', 'hybrid seeds'],
    'Fertilizers': ['fertilizer', 'urea', 'dap', 'compost', 'npk'],
    'Pesticides & Herbicides': ['pesticide', 'herbicide', 'insecticide', 'weedicide'],
    'Gardening Tools': ['trowel', 'rake', 'spade', 'shovel', 'garden tools'],
    'Pots & Soil': ['pot', 'planter', 'soil', 'cocopeat', 'mud pot'],
    'Irrigation': ['drip', 'sprinkler', 'hose', 'pipe fittings'],
    'Animal Feed': ['cattle feed', 'poultry feed', 'fish feed', 'animal feed'],

    // ── Pet Supplies ──────────────────────────────────────────────────────
    'Dog Food': ['dog food', 'puppy food', 'pedigree', 'royal canin dog'],
    'Cat Food': ['cat food', 'kitty food', 'whiskas', 'royal canin cat'],
    'Bird & Fish Supplies': ['bird seed', 'fish food', 'aquarium', 'parrot feed'],
    'Pet Accessories': ['pet collar', 'leash', 'pet toy', 'kennel'],

    // ── Automotive ────────────────────────────────────────────────────────
    'Engine Oils & Lubricants': [
      'engine oil', 'mobil', 'castrol', 'valvoline', 'gear oil',
      'coolant', 'brake fluid', 'lubricant',
    ],
    'Car Wash & Polish': ['car wash', 'wax', 'car polish', 'shampoo car'],
    'Tyres & Tubes': ['tyre', 'tube', 'tire'],

    // ── Fuel & Energy ─────────────────────────────────────────────────────
    'Kerosene': ['kerosene', 'lamp oil'],
    'Firewood & Charcoal': ['firewood', 'charcoal', 'coal'],
    'Candles & Matches': ['candle', 'matchbox', 'lighter'],
    'Gas Cylinders': ['gas cylinder', 'lpg', 'cooking gas', 'cylinder'],

    // ── Tobacco & Alcohol ─────────────────────────────────────────────────
    'Cigarettes': ['cigarette', 'wills', 'gold flake', 'classic mild'],
    'Tobacco & Betel': ['tobacco', 'betel', 'pan masala', 'gutka', 'hookah', 'areca'],
    'Beer & Wine': ['beer', 'wine', 'carlsberg', 'kingfisher', 'heineken'],
    'Spirits & Liquor': ['whisky', 'rum', 'vodka', 'gin', 'brandy', 'liquor'],

    // ── Frozen & Ready Foods ──────────────────────────────────────────────
    'Frozen Vegetables': ['frozen veg', 'frozen peas', 'frozen corn', 'frozen spinach'],
    'Frozen Meals': ['frozen meal', 'ready meal', 'frozen biryani'],
    'Ready-to-Cook': ['ready to cook', 'instant mix', 'ready mix', 'pre-mix'],
  };

  static String? detectCategory(String name) {
    if (name.isEmpty) return null;

    final lowerName = name.toLowerCase();

    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerName.contains(keyword)) {
          return CategoryConstants.getMainCategory(entry.key);
        }
      }
    }

    return null;
  }
}
