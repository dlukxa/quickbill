import '../utils/category_constants.dart';

/// Detects the most likely category or subcategory for a product based on its name.
/// Supports English, Sinhala, Singlish, and common local brands.
class CategoryDetectionService {
  static const Map<String, List<String>> _categoryKeywords = {
    // ── Food & Grocery ────────────────────────────────────────────────────
    'Flour & Baking': [
      // Sinhala
      'පිටි', 'පාන් පිටි', 'හාල් පිටි', 'කුරක්කන් පිටි', 'අප්ප පිටි', 'ඉඳිආප්ප පිටි',
      'උඳුපිටි', 'උඳු පිටි', 'කඩල පිටි', 'ඉඩ්ලි', 'තෝසේ', 'මික්ස්', 'බේකිං', 'යීස්ට්',
      'වැනිලා', 'කොකෝවා', 'කේක් මික්ස්',
      // English & Singlish
      'flour', 'wheat flour', 'rice flour', 'atta', 'maida', 'sooji', 'semolina',
      'all-purpose flour', 'baking powder', 'baking soda', 'yeast', 'vanilla essence',
      'cocoa powder', 'corn starch', 'gelatin', 'cake mix', 'kurakkan', 'appa piti',
      'piti', 'idli', 'thosai', 'hopper mix',
    ],
    'Noodles & Pasta': [
      // Sinhala
      'නූඩ්ල්ස්', 'වැකෑස්', 'පැස්ටා', 'මැකරෝනි', 'ස්පැගටි', 'කොත්තු', 'මැගී', 'විකන්',
      'ඩ්‍රයි නූඩ්ල්ස්',
      // English & Singlish
      'noodles', 'pasta', 'spaghetti', 'macaroni', 'maggi', 'ramen', 'vermicelli',
      'instant noodles', 'vakas', 'kottu', 'noodles pack',
    ],
    'Cooking Oils & Fats': [
      // Sinhala
      'පොල්තෙල්', 'එළවළු තෙල්', 'තෙල්', 'ඔයිල්', 'සූරියකාන්ත තෙල්', 'එළඟිතෙල්', 'මාජරින්',
      // English & Singlish
      'coconut oil', 'vegetable oil', 'sunflower oil', 'palm oil', 'sesame oil',
      'groundnut oil', 'mustard oil', 'ghee', 'cooking oil', 'margarine', 'shortening',
      'dalda', 'polthel', 'thele', 'thel', 'oil',
    ],
    'Rice & Grains': [
      // Sinhala
      'සහල්', 'හාල්', 'සම්බා', 'කැකුළු', 'නාඩු', 'බාස්මතී', 'සුවඳැල්', 'කීර සම්බා',
      'රතු කැකුළු', 'සුදු කැකුළු', 'ඕට්ස්', 'කුරක්කන්', 'තල',
      // English & Singlish
      'rice', 'basmati', 'jasmine', 'samba', 'nadu', 'kekulu', 'keeri samba',
      'red raw rice', 'white raw rice', 'oats', 'barley', 'millet', 'ragi',
      'quinoa', 'cornflakes', 'poha', 'wheat', 'haal', 'sahal',
    ],
    'Dal & Pulses': [
      // Sinhala
      'පරිප්පු', 'කඩල', 'මුං ඇට', 'කවුපි', 'සෝයා', 'මෑ ඇට', 'බෝංචි ඇට',
      // English & Singlish
      'dal', 'dhal', 'lentils', 'chickpeas', 'chana', 'rajma', 'kidney beans',
      'black beans', 'moong', 'masoor', 'toor', 'urad', 'soya', 'soya meat',
      'peas', 'gram', 'beans', 'parippu', 'kadala', 'mung', 'cowpea',
    ],
    'Spices & Seasonings': [
      // Sinhala
      'මිරිස්', 'තුනපහ', 'කහ', 'ගම්මිරිස්', 'කුරුඳු', 'කරාබුනැටි', 'එනසාල්', 'උළුහාල්',
      'අබ', 'මාදුරු', 'සූදුරු', 'කරපිංචා', 'ගොරකා', 'සියඹලා', 'කෑලි මිරිස්', 'මිරිස් කුඩු',
      'තුනපහ කුඩු', 'රසකාරක', 'අජිනමොටෝ',
      // English & Singlish
      'turmeric', 'cumin', 'coriander', 'chilli', 'chili', 'masala', 'curry powder',
      'pepper', 'cardamom', 'cinnamon', 'cloves', 'bay leaves', 'fenugreek',
      'mustard seeds', 'paprika', 'garam masala', 'sambhar', 'miris', 'thunapaha',
      'kaha', 'gam miris', 'goraka',
    ],
    'Salt, Sugar & Jaggery': [
      // Sinhala
      'සීනි', 'ලුණු', 'හකුරු', 'දුඹුරු සීනි', 'අයිසිං සීනි', 'පැණි', 'කිතුල් පැණි',
      // English & Singlish
      'salt', 'sugar', 'jaggery', 'brown sugar', 'icing sugar', 'powdered sugar',
      'rock salt', 'sea salt', 'seeni', 'lunu', 'hakuru', 'pani', 'treacle',
    ],
    'Canned & Preserved Foods': [
      // Sinhala
      'ටින් මාළු', 'සැමන්', 'මැකරල්', 'ටූනා', 'පොල්කිරි', 'ටින්',
      // English & Singlish
      'canned', 'tuna', 'sardines', 'mackerel', 'corned beef', 'condensed milk',
      'evaporated milk', 'coconut milk', 'tomato paste', 'fruit cocktail', 'salmon',
      'tin fish', 'tin maalu',
    ],
    'Sauces, Pickles & Condiments': [
      // Sinhala
      'සෝස්', 'තක්කාලි සෝස්', 'චිලි සෝස්', 'සෝයා සෝස්', 'විනාකිරි', 'අච්චාරු', 'ජෑම්',
      'මාමලේඩ්', 'චට්නි', 'මයොනීස්',
      // English & Singlish
      'ketchup', 'vinegar', 'soy sauce', 'fish sauce', 'oyster sauce', 'chilli sauce',
      'tomato sauce', 'mayonnaise', 'mustard sauce', 'pickle', 'achar', 'mango pickle',
      'jam', 'jelly', 'marmalade', 'chutney', 'sauce',
    ],
    'Organic & Natural Foods': [
      'organic', 'natural', 'whole grain', 'multigrain', 'gluten-free', 'vegan',
      'raw honey', 'sprouts',
    ],

    // ── Beverages ─────────────────────────────────────────────────────────
    'Soft Drinks & Sodas': [
      // Sinhala
      'සෝඩා', 'කොකා කෝලා', 'පෙප්සි', 'ස්ප්‍රයිට්', 'ෆැන්ටා', 'නෙක්ටෝ', 'ක්‍රීම් සෝඩා',
      'ජින්ජර් බියර්', 'ඊබීබී',
      // English & Singlish
      'coca-cola', 'coke', 'pepsi', 'sprite', 'fanta', '7up', 'mirinda', 'mountain dew',
      'rc cola', 'soda', 'soft drink', 'carbonated', 'cream soda', 'necto', 'ebb',
      'ginger beer', 'elephant house',
    ],
    'Juices & Nectars': [
      // Sinhala
      'ජූස්', 'යුෂ', 'කෝඩියල්', 'පළතුරු යුෂ', 'මැංගෝ', 'ඔරේන්ජ්',
      // English & Singlish
      'juice', 'zesto', 'minute maid', 'tropicana', 'real juice', 'mango juice',
      'orange juice', 'cordial', 'nectar', 'md cordial', 'sunquick',
    ],
    'Water & Sparkling': [
      // Sinhala
      'ජලය', 'වතුර', 'මිනරල් වෝටර්', 'පානීය ජලය',
      // English & Singlish
      'mineral water', 'drinking water', 'sparkling water', 'acqua', 'evian',
      'kinley', 'bisleri', 'knuckles', 'water bottle',
    ],
    'Energy & Sports Drinks': [
      'energy drink', 'monster', 'red bull', 'gatorade', 'sports drink', 'electral', 'sting',
    ],
    'Tea & Coffee': [
      // Sinhala
      'තේ', 'කෝපි', 'තේ කොළ', 'නෙස්කැෆේ', 'තේ කුඩු', 'රණකහ', 'වටවල', 'දිල්මා',
      // English & Singlish
      'tea', 'green tea', 'black tea', 'chai', 'coffee', 'instant coffee', 'nescafe',
      'bru', 'lipton', 'dilmah', 'watawala', 'zesta', 'tea bag', 'tea leaves',
    ],
    'Milk Drinks & Shakes': [
      // Sinhala
      'මයිලෝ', 'හයිලන්ඩ්', 'මිලෝ', 'හොර්ලික්ස්', 'ෆ්ලේවර්ඩ් මිල්ක්',
      // English & Singlish
      'milo', 'ovaltine', 'horlicks', 'bournvita', 'complan', 'boost', 'milk shake',
      'flavoured milk', 'lassi', 'chocolate milk', 'vanilla milk',
    ],
    'Health & Nutrition Drinks': [
      'ensure', 'pediasure', 'glucon-d', 'glucon d', 'electrolyte', 'protein drink',
      'health drink',
    ],
    'Coconut Water': [
      // Sinhala
      'තැඹිලි', 'කුරුම්බා',
      // English
      'coconut water', 'tender coconut', 'thambili',
    ],

    // ── Dairy & Eggs ──────────────────────────────────────────────────────
    'Milk': [
      // Sinhala
      'කිරි', 'පිටිකිරි', 'ඇන්කර්', 'රත්ති', 'පැල්වත්ත', 'හයිලන්ඩ් කිරි', 'ඇන්ලීන්',
      'අන්ලන්', 'නැංගර්', 'නෙස්ටමෝල්ට්',
      // English & Singlish
      'milk', 'full cream milk', 'toned milk', 'skimmed milk', 'milk powder',
      'anchor', 'rathi', 'pelwatte', 'highland', 'anlene', 'maliban milk',
      'liquid milk', 'fresh milk',
    ],
    'Curd & Yoghurt': [
      // Sinhala
      'යෝගට්', 'මුදවපු කිරි', 'මී කිරි', 'කිරි පැණි',
      // English & Singlish
      'curd', 'yoghurt', 'yogurt', 'dahi', 'meekiri', 'rich life', 'ambewela',
    ],
    'Cheese & Paneer': [
      // Sinhala
      'චීස්', 'පනීර්',
      // English & Singlish
      'cheese', 'paneer', 'cottage cheese', 'cheddar', 'mozzarella', 'happy cow',
      'kraft', 'cheese wedges',
    ],
    'Butter & Ghee': [
      // Sinhala
      'බටර්', 'එළඟිතෙල්',
      // English & Singlish
      'butter', 'ghee', 'margarine', 'anchor butter', 'pelwatte butter', 'astra',
    ],
    'Eggs': [
      // Sinhala
      'බිත්තර',
      // English
      'eggs', 'egg', 'hen egg', 'biththara',
    ],
    'Ice Cream': [
      // Sinhala
      'අයිස්ක්‍රීම්', 'අයිස් ක්‍රීම්', 'කෝන්',
      // English & Singlish
      'ice cream', 'gelato', 'kulfi', 'elephant house ice cream', 'cargills ice cream',
    ],
    'Condensed & Evaporated Milk': [
      'condensed milk', 'evaporated milk', 'milkmaid',
    ],

    // ── Meat & Seafood ────────────────────────────────────────────────────
    'Chicken & Poultry': [
      // Sinhala
      'චිකන්', 'කුකුල් මස්', 'කුකුළු මස්',
      // English & Singlish
      'chicken', 'turkey', 'duck', 'broiler', 'poultry', 'bairaha', 'crysbro',
    ],
    'Mutton & Lamb': [
      // Sinhala
      'එළු මස්', 'හරක් මස්', 'ගව මස්',
      // English
      'mutton', 'lamb', 'goat meat', 'beef',
    ],
    'Fish & Seafood': [
      // Sinhala
      'මාළු', 'සැමන්', 'ඉස්සෝ', 'දැල්ලෝ', 'කකුළුවෝ', 'තෝරා', 'කෙලවල්ලා', 'බලයා', 'සාලයා',
      // English & Singlish
      'fish', 'salmon', 'tuna', 'prawn', 'shrimp', 'crab', 'lobster', 'squid',
      'sardine', 'mackerel', 'seafood', 'maalu', 'isso', 'dello',
    ],
    'Processed Meat': [
      // Sinhala
      'සොසේජස්', 'මීට් බෝල්ස්', 'හැම්',
      // English
      'sausage', 'salami', 'ham', 'pepperoni', 'hot dog', 'nuggets', 'meatballs', 'keells sausage',
    ],

    // ── Bakery & Snacks ───────────────────────────────────────────────────
    'Biscuits & Cookies': [
      // Sinhala
      'බිස්කට්', 'ක්‍රැකර්', 'කුකීස්', 'ටික් ටික්', 'හවායන් කුකීස්', 'ලෙමන් පෆ්',
      'චොක්ලට් පෆ්', 'මැරී', 'ක්‍රීම් ක්‍රැකර්', 'මංචි', 'මැලිබන්',
      // English & Singlish
      'biscuits', 'marie', 'glucose biscuit', 'digestive', 'good day', 'oreo',
      'bourbon', 'cookies', 'crackers', 'munchee', 'maliban', 'lemon puff',
      'cream cracker', 'chocolate puff', 'biscuit',
    ],
    'Chips & Namkeen': [
      // Sinhala
      'චිප්ස්', 'බයිට්', 'මික්ස්චර්', 'මුරුක්කු', 'කඩල බැදපු', 'පොප්කෝන්',
      // English & Singlish
      'chips', 'lays', 'kurkure', 'bhujia', 'namkeen', 'fryums', 'murukku',
      'popcorn', 'nachos', 'puffed rice', 'bite', 'cassava chips', 'potato chips',
    ],
    'Chocolates & Candies': [
      // Sinhala
      'චොකලට්', 'ටොෆි', 'පැණිරස', 'චුයින්ගම්', 'ලොලිපොප්', 'කැන්ඩි',
      // English & Singlish
      'chocolate', 'dairy milk', 'kitkat', 'mars', 'twix', '5 star', 'candy',
      'toffee', 'lollipop', 'gum', 'chewing gum', 'mint', 'mints', 'kandos',
      'edna', 'ferrero',
    ],
    'Cakes & Pastries': [
      // Sinhala
      'කේක්', 'පේස්ට්‍රි', 'ඩෝනට්', 'රෝල්ස්', 'මෆින්', 'කප් කේක්',
      // English
      'cake', 'pastry', 'muffin', 'brownie', 'donut', 'croissant', 'cupcake',
    ],
    'Bread & Bakery': [
      // Sinhala
      'පාන්', 'බනිස්', 'රෝස් පාන්', 'සැන්ඩ්විච්', 'රොටි', 'ටෝස්ට්',
      // English & Singlish
      'bread', 'white bread', 'brown bread', 'whole wheat bread', 'roti', 'bun',
      'toast', 'paan', 'banis',
    ],
    'Dry Fruits & Nuts': [
      // Sinhala
      'කජු', 'රටකජු', 'වියළි මිදි', 'රටඉඳි',
      // English & Singlish
      'almonds', 'cashews', 'raisins', 'dates', 'walnuts', 'pistachios', 'peanuts',
      'trail mix', 'dried mango', 'figs', 'apricots', 'kaju', 'rata indi',
    ],
    'Popcorn & Munchies': ['popcorn', 'pork rinds', 'trail mix'],
    'Confectionery & Sweets': [
      // Sinhala
      'දොදොල්', 'ආස්මි', 'කොණ්ඩ කැවුම්', 'කැවුම්', 'කොකිස්', 'තල කැරලි', 'හල්පිටි',
      // English
      'halwa', 'ladoo', 'barfi', 'gulab jamun', 'mithai', 'dodol', 'sweet',
    ],

    // ── Personal Care ─────────────────────────────────────────────────────
    'Hair Care': [
      // Sinhala
      'හෙයාර්', 'කලර්', 'හෙයාර් කලර්', 'තෙල් කොණ්ඩ', 'කොණ්ඩෙ', 'ඩයි', 'හෙනා', 'කුමාරිකා',
      // English & Singlish
      'hair oil', 'hair color', 'hair colour', 'hair dye', 'parachute', 'comb',
      'hair gel', 'hair cream', 'hair serum', 'kumarika', 'henna', 'hair spray',
      'hair mask', 'hair', 'dye',
    ],
    'Soaps & Body Wash': [
      // Sinhala
      'සබන්', 'ලක්ස්', 'ලයිෆ්බෝයි', 'ඩෙටෝල්', 'කොහොඹ', 'බේබි සබන්', 'රැන්ඩොල්',
      // English & Singlish
      'soap', 'dove', 'lifebuoy', 'dettol', 'lux', 'pears', 'body wash',
      'shower gel', 'glycerine soap', 'kohomba', 'soap bar',
    ],
    'Shampoo & Conditioner': [
      // Sinhala
      'ෂැම්පු', 'සන්සිල්ක්', 'හෙඩ් ඇන්ඩ් ෂෝල්ඩර්ස්', 'ඩෝව්',
      // English & Singlish
      'shampoo', 'conditioner', 'head & shoulders', 'pantene', 'sunsilk',
      'dove shampoo', 'clinic plus',
    ],
    'Skin Care & Moisturizers': [
      // Sinhala
      'ක්‍රීම්', 'ලෝෂන්', 'ෆේස් වොෂ්', 'වැස්ලින්', 'ෆෙයාර් ඇන්ඩ් ලව්ලි', 'ග්ලෝ ඇන්ඩ් ලව්ලි',
      // English & Singlish
      'moisturizer', 'lotion', 'face wash', 'face cream', 'vaseline', 'nivea',
      'fair & lovely', 'glow & lovely', 'pond\'s', 'body lotion',
    ],
    'Oral Care': [
      // Sinhala
      'දත් බෙහෙත්', 'දත් බුරුසු', 'සිග්නල්', 'ක්ලෝස් අප්', 'කොල්ගේට්', 'දන්තාලේප',
      // English & Singlish
      'toothpaste', 'colgate', 'sensodyne', 'pepsodent', 'toothbrush', 'mouthwash',
      'signal', 'clove toothpaste',
    ],
    'Deodorants & Perfumes': [
      // Sinhala
      'සුවඳ විලවුන්', 'බොඩි ස්ප්‍රේ', 'ඩියෝ', 'අයිස් කූල්',
      // English & Singlish
      'deodorant', 'perfume', 'deo', 'body spray', 'axe', 'rexona', 'ice cool',
      'cologne', 'attar',
    ],
    'Shaving & Grooming': ['razor', 'shaving cream', 'gillette', 'after shave', 'trimmer'],
    'Feminine Hygiene': ['sanitary', 'pad', 'whisper', 'stayfree', 'tampons', 'eva'],
    'Sunscreen & Sun Care': ['sunscreen', 'spf', 'sun block', 'tanning'],
    'Tissue & Cotton': [
      // Sinhala
      'ටිෂූ', 'පුළුන්',
      // English
      'tissue', 'cotton', 'wipes', 'kitchen roll', 'napkins', 'facial tissue',
    ],

    // ── Health & Medicine ─────────────────────────────────────────────────
    'OTC Medicines': [
      // Sinhala
      'පැනඩෝල්', 'පැරසිටමෝල්', 'අයිඩෙක්ස්', 'බාම්', 'සිද්ධාලේප', 'වික්ස්', 'ඇස්ප්‍රින්',
      'පෙති', 'සිරප්', 'අසමෝදගම්', 'ජීවනී', 'වේදනා නාශක',
      // English & Singlish
      'paracetamol', 'panadol', 'iodex', 'balm', 'siddhalepa', 'vicks', 'crocin',
      'disprin', 'antacid', 'iodine', 'pain balm', 'pain killer', 'cough syrup',
      'jeewani', 'asmodagam', 'lozenge',
    ],
    'Vitamins & Supplements': [
      // Sinhala
      'විටමින්', 'කැල්සියම්', 'අයර්න්',
      // English
      'vitamins', 'calcium', 'iron tablet', 'omega-3', 'multivitamin', 'supplement', 'zinc',
    ],
    'First Aid': [
      // Sinhala
      'ප්ලාස්ටර්', 'බැන්ඩේජ්', 'ගෝස්',
      // English
      'bandage', 'plaster', 'band-aid', 'antiseptic', 'savlon', 'surgical spirit',
    ],
    'Ayurvedic & Herbal': [
      // Sinhala
      'ආයුර්වේද', 'පස්පංගුව', 'කොත්තමල්ලි', 'වෙනිවැල්ගැට', 'සූවාරණ',
      // English & Singlish
      'chyawanprash', 'triphala', 'ashwagandha', 'ayurvedic', 'paspanguwa',
      'koththamalli', 'herbal',
    ],
    'Protein & Fitness': ['protein powder', 'whey', 'creatine', 'bcaa', 'gym supplement'],

    // ── Household & Cleaning ──────────────────────────────────────────────
    'Detergent & Laundry': [
      // Sinhala
      'රෙදි සෝදන', 'සබන් කුඩු', 'සන්ලයිට්', 'රින්', 'සර්ෆ් එක්සෙල්',
      // English & Singlish
      'detergent', 'surf', 'ariel', 'tide', 'wheel', 'rin', 'fabric softener',
      'comfort', 'washing powder', 'liquid detergent', 'sunlight soap',
    ],
    'Dish Wash': [
      // Sinhala
      'පිඟන් සෝදන', 'ඩිෂ් වොෂ්', 'විම් බාර්', 'විම් ලික්විඩ්', 'විම්',
      // English & Singlish
      'dish wash', 'dish soap', 'vim', 'pril', 'sunlight dish', 'dish liquid',
    ],
    'Floor & Toilet Cleaners': [
      // Sinhala
      'හාපික්', 'ඩොමෙක්ස්', 'ටොයිලට් ක්ලීනර්', 'පොළොව පිරිසිදු කරන',
      // English
      'floor cleaner', 'toilet cleaner', 'harpic', 'domex', 'phenyl', 'colin',
    ],
    'Air Fresheners & Repellents': [
      // Sinhala
      'මදුරු', 'හිට්', 'කොයිල්', 'වපොරයිසර්', 'මදුරු දඟර',
      // English & Singlish
      'air freshener', 'repellent', 'mosquito', 'good knight', 'hit', 'odonil',
      'room freshener', 'coil', 'mosquito net',
    ],
    'Brooms, Mops & Brushes': [
      // Sinhala
      'කොස්ස', 'මොප්', 'බුරුසු',
      // English
      'broom', 'mop', 'scrub', 'sponge', 'brush', 'duster', 'wiper',
    ],
    'Trash Bags & Storage': ['trash bag', 'garbage bag', 'zip lock', 'container'],
    'Disinfectants & Bleach': ['bleach', 'disinfectant', 'dettol', 'savlon', 'sanitizer'],

    // ── Baby & Kids ───────────────────────────────────────────────────────
    'Baby Food & Formula': [
      // Sinhala
      'ලැක්ටෝජන්', 'නැන්', 'සෙරලැක්', 'බේබි ෆුඩ්',
      // English
      'baby food', 'lactogen', 'nan', 'enfamil', 'formula', 'cerelac', 'gerber',
    ],
    'Diapers & Wipes': [
      // Sinhala
      'ඩයපර්', 'පැම්පස්', 'බේබි වයිප්ස්',
      // English
      'diaper', 'pampers', 'huggies', 'dry love', 'baby wipes', 'wet wipes',
    ],
    'Baby Bath & Skin': [
      // Sinhala
      'චෙරමි', 'බේබි ෂැම්පු', 'බේබි ක්‍රීම්', 'බේබි කොලෝන්', 'කොහොඹ බේබි',
      // English
      'baby soap', 'baby shampoo', 'baby lotion', 'baby powder', 'johnson\'s',
      'cheramy', 'baby cheramy',
    ],

    // ── Electronics & Electrical ──────────────────────────────────────────
    'Bulbs & Lighting': [
      // Sinhala
      'බල්බ්', 'ලයිට්', 'ටෝච්', 'එල්ඊඩී',
      // English
      'bulb', 'led bulb', 'cfl', 'tubelight', 'torch', 'flashlight', 'cfl bulb',
    ],
    'Batteries & Chargers': [
      // Sinhala
      'බැටරි', 'චාජර්',
      // English
      'battery', 'duracell', 'eveready', 'charger', 'power bank', 'aa battery', 'aaa battery',
    ],
    'Mobile Accessories': ['earphones', 'headphones', 'phone case', 'screen guard', 'usb cable'],
    'Cables & Adapters': ['hdmi', 'adapter', 'extension cord', 'cable', 'usb'],
    'Switches & Sockets': ['switch', 'socket', 'plug', 'mcb', 'fuse'],

    // ── Stationery & Office ───────────────────────────────────────────────
    'Pens & Pencils': [
      // Sinhala
      'පෑන', 'පැන්සල්', 'ඇට්ලස්', 'පෑන්',
      // English
      'pen', 'pencil', 'ball pen', 'gel pen', 'reynolds', 'atlas pen',
    ],
    'Notebooks & Paper': [
      // Sinhala
      'පොත්', 'CR පොත්', 'අභ්‍යාස පොත්', 'A4 කොළ',
      // English
      'notebook', 'paper', 'register', 'notepad', 'envelope', 'memo', 'a4 paper', 'cr book',
    ],
    'Files & Folders': ['file', 'folder', 'binder', 'stapler', 'clips'],
    'Tapes & Glues': ['tape', 'glue', 'adhesive', 'fevicol', 'packing tape'],

    // ── Hardware & Tools ──────────────────────────────────────────────────
    'Nails, Screws & Fasteners': ['nail', 'screw', 'bolt', 'nut', 'washer'],
    'Hand Tools': ['hammer', 'screwdriver', 'pliers', 'wrench', 'chisel'],
    'Paints & Brushes': ['paint', 'enamel', 'emulsion', 'primer', 'paintbrush'],
    'Plumbing Supplies': ['pipe', 'faucet', 'tap', 'pvc pipe'],
    'Locks & Security': ['lock', 'padlock', 'handle', 'hinge', 'door lock'],

    // ── Farming & Garden ──────────────────────────────────────────────────
    'Seeds': ['seeds', 'vegetable seeds', 'paddy seed'],
    'Fertilizers': ['fertilizer', 'urea', 'dap', 'compost', 'npk'],
    'Pesticides & Herbicides': ['pesticide', 'herbicide', 'insecticide', 'weedicide'],

    // ── Pet Supplies ──────────────────────────────────────────────────────
    'Dog Food': ['dog food', 'puppy food', 'pedigree'],
    'Cat Food': ['cat food', 'kitty food', 'whiskas'],

    // ── Automotive ────────────────────────────────────────────────────────
    'Engine Oils & Lubricants': [
      'engine oil', 'mobil', 'castrol', 'valvoline', 'gear oil', 'coolant',
      'brake fluid', 'lubricant', 'motor oil',
    ],
    'Tyres & Tubes': ['tyre', 'tube', 'tire'],

    // ── Fuel & Energy ─────────────────────────────────────────────────────
    'Kerosene': ['kerosene', 'භූමිතෙල්'],
    'Firewood & Charcoal': ['firewood', 'charcoal', 'දැව', 'අඟුරු'],
    'Candles & Matches': [
      // Sinhala
      'ඉටිපන්දම්', 'ගිනිකූරු', 'ගිනिपෙට්ටි',
      // English
      'candle', 'matchbox', 'lighter', 'matches',
    ],
    'Gas Cylinders': ['gas cylinder', 'lpg', 'cooking gas', 'litro', 'laugfs'],

    // ── Tobacco & Alcohol ─────────────────────────────────────────────────
    'Cigarettes': [
      // Sinhala
      'සිගරට්', 'දුම්වැටි', 'ජෝන් ප්ලේයර්', 'ගෝල්ඩ් ලීෆ්', 'බීඩි',
      // English & Singlish
      'cigarette', 'wills', 'gold flake', 'classic mild', 'john player', 'gold leaf',
      'dunhill', 'benson', 'beedi',
    ],
    'Tobacco & Betel': [
      // Sinhala
      'බුලත්', 'පුවක්', 'දුම්කොළ',
      // English
      'tobacco', 'betel', 'pan masala', 'areca',
    ],
    'Beer & Wine': ['beer', 'wine', 'carlsberg', 'heineken', 'lion beer', 'lion stout'],
    'Spirits & Liquor': ['whisky', 'rum', 'vodka', 'gin', 'brandy', 'arrack', 'gal arrack'],
  };

  /// Returns the fine-grained subcategory for a product name, or null if unclassified.
  /// Uses longest-keyword matching so specific terms (e.g. 'කිරිපිටි') take precedence over general roots (e.g. 'පිටි').
  static String? detectSubcategory(String name) {
    if (name.isEmpty) return null;

    final lowerName = name.toLowerCase();
    String? bestCategory;
    int bestLength = 0;

    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        final kw = keyword.toLowerCase();
        if (lowerName.contains(kw) && kw.length > bestLength) {
          bestLength = kw.length;
          bestCategory = entry.key;
        }
      }
    }

    return bestCategory;
  }

  /// Returns the top-level main category for a product name based on keywords.
  static String? detectCategory(String name) {
    final sub = detectSubcategory(name);
    if (sub != null) {
      return CategoryConstants.getMainCategory(sub);
    }
    return null;
  }
}
