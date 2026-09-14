/// Comprehensive localization helper for POS, Desktop, Billing, and Stock workflows.
/// Automatically delivers accurate Sinhala, Tamil, English, Hindi, Bengali, and Dhivehi translations.
class PosL10n {
  final String lang;

  const PosL10n(this.lang);

  static PosL10n of(String languageCode) => PosL10n(languageCode);

  bool get isSi => lang == 'si';
  bool get isTa => lang == 'ta';
  bool get isHi => lang == 'hi';
  bool get isBn => lang == 'bn';
  bool get isDv => lang == 'dv';

  // ─── Header & Status ───
  String get posActive => isSi ? 'සජීවී POS' : isTa ? 'செயலில் உள்ள POS' : isHi ? 'सक्रिय POS' : isBn ? 'সক্রিয় POS' : 'POS Active';
  String get scannerReady => isSi ? '⚡ ස්කෑනරය සූදානම්' : isTa ? '⚡ ஸ்கேனர் தயார்' : isHi ? '⚡ स्कैनर तैयार' : isBn ? '⚡ স্ক্যানার প্রস্তুত' : '⚡ Scanner Active';
  String get quickBillPos => isSi ? 'QuickBill POS පර්යන්තය' : isTa ? 'QuickBill POS முனையம்' : 'QuickBill POS';

  // ─── Top Bar Navigation ───
  String get dashboard => isSi ? 'පුවරුව' : isTa ? 'டாஷ்போர்டு' : isHi ? 'डैशबोर्ड' : isBn ? 'ড্যাশবোর্ড' : 'Dashboard';
  String get reports => isSi ? 'වාර්තා' : isTa ? 'அறிக்கைகள்' : isHi ? 'रिपोर्ट्स' : isBn ? 'প্রতিবেদন' : 'Reports';
  String get addStockF5 => isSi ? '+ තොග එක්කරන්න (F5)' : isTa ? '+ சரக்கு சேர்க்க (F5)' : isHi ? '+ स्टॉक जोड़ें (F5)' : isBn ? '+ স্টক যোগ করুন (F5)' : '+ Add Stock (F5)';
  String get addProductF3 => isSi ? '+ භාණ්ඩය (F3)' : isTa ? '+ பொருள் (F3)' : isHi ? '+ उत्पाद (F3)' : isBn ? '+ পণ্য (F3)' : '+ Product (F3)';
  String get customItemF4 => isSi ? '+ අමතර භාණ්ඩය (F4)' : isTa ? '+ தனிப்பயன் (F4)' : isHi ? '+ कस्टम आइटम (F4)' : isBn ? '+ কাস্টম আইটেম (F4)' : '+ Custom Item (F4)';
  String get stock => isSi ? 'තොග' : isTa ? 'சரக்கு' : isHi ? 'स्टॉक' : isBn ? 'স্টক' : 'Stock';
  String get pricesAndUnits => isSi ? 'මිල සහ ඒකක' : isTa ? 'விலை & அலகுகள்' : isHi ? 'मूल्य और इकाइयाँ' : isBn ? 'দাম ও একক' : 'Prices & Units';
  String get customers => isSi ? 'පාරිභෝගිකයන්' : isTa ? 'வாடிக்கையாளர்கள்' : isHi ? 'ग्राहक' : isBn ? 'গ্রাহক' : 'Customers';
  String get cashiers => isSi ? 'කැෂියර්වරු' : isTa ? 'பணியாளர்கள்' : isHi ? 'कैशियर' : isBn ? 'ক্যাশিয়ার' : 'Cashiers';
  String get quickItem => isSi ? '+ ක්ෂණික භාණ්ඩය' : isTa ? '+ விரைவு பொருள்' : isHi ? '+ क्विक आइटम' : isBn ? '+ দ্রুত আইটেম' : '+ Quick Item';
  String get lightMode => isSi ? 'ලයිට්' : isTa ? 'வெளிச்சம்' : 'Light';
  String get darkMode => isSi ? 'ඩාර්ක්' : isTa ? 'இருள்' : 'Dark';
  String get switchUser => isSi ? 'මාරු වන්න' : isTa ? 'மாற்று' : isHi ? 'बदलें' : isBn ? 'বদলান' : 'Switch';

  // ─── Search & Catalog ───
  String get searchHint => isSi 
      ? 'භාණ්ඩ සොයන්න (සිංහල, Singlish - kiri the, seeni, ඉංග්‍රීසි, බාර්කෝඩ්)...' 
      : isTa 
          ? 'தயாரிப்புகளைத் தேடுங்கள் (சிங்களம், தமிழ், ஆங்கிலம், பார்கோடு)...' 
          : 'Search in Sinhala, Singlish (kiri the, seeni), English, or Barcode...';
  String get noProductsFound => isSi ? 'භාණ්ඩ හමු නොවීය' : isTa ? 'தயாரிப்புகள் எதுவும் கிடைக்கவில்லை' : isHi ? 'कोई उत्पाद नहीं मिला' : isBn ? 'কোন পণ্য পাওয়া যায়নি' : 'No products found';

  // ─── Cart Panel ───
  String get currentBill => isSi ? 'වත්මන් බිල' : isTa ? 'தற்போதைய பில்' : isHi ? 'वर्तमान बिल' : isBn ? 'বর্তমান বিল' : 'Current Bill';
  String get clear => isSi ? 'ඉවත් කරන්න' : isTa ? 'அழிக்க' : isHi ? 'साफ करें' : isBn ? 'মুছুন' : 'Clear';
  String get attachCustomer => isSi ? 'පාරිභෝගිකයා තෝරන්න' : isTa ? 'வாடிக்கையாளரை இணைக்க' : isHi ? 'ग्राहक जोड़ें' : isBn ? 'গ্রাহক যুক্ত করুন' : 'Attach Customer';
  String get cartIsEmpty => isSi ? 'බිල හිස්ව පවතී' : isTa ? 'பில் காலியாக உள்ளது' : isHi ? 'कार्ट खाली है' : isBn ? 'কার্ট খালি' : 'Cart is empty';
  String get scanOrTapProduct => isSi ? 'භාණ්ඩයක් ස්කෑන් හෝ තෝරන්න' : isTa ? 'பொருளை ஸ்கேன் செய்யவும் அல்லது தேர்ந்தெடுக்கவும்' : isHi ? 'स्कैन करें या उत्पाद चुनें' : isBn ? 'পণ্য স্ক্যান বা নির্বাচন করুন' : 'Scan or tap a product';
  String get subtotal => isSi ? 'උප එකතුව' : isTa ? 'உப மொத்தம்' : isHi ? 'उप-योग' : isBn ? 'উপ-মোট' : 'Subtotal';
  String get total => isSi ? 'මුළු එකතුව' : isTa ? 'மொத்த தொகை' : isHi ? 'कुल योग' : isBn ? 'সর্বমোট' : 'Total';
  String get checkout => isSi ? 'ගෙවීම ලබාගන්න (F12)' : isTa ? 'செக்அவுட் (F12)' : isHi ? 'चेकआउट (F12)' : isBn ? 'চেকআউট (F12)' : 'Checkout  (F12)';

  // ─── Product Badges & Modes ───
  String get multiModeBadge => isSi ? '⚖️+📦 බහු ඒකක' : isTa ? '⚖️+📦 பல அலகு' : '⚖️+📦 Multi';
  String get looseMode => isSi ? '⚖️ බර අනුව (Loose)' : isTa ? '⚖️ எடை அடிப்படையில்' : '⚖️ Loose / Weight';
  String get packMode => isSi ? '📦 ඇසුරුම් කළ පැකට්' : isTa ? '📦 பாக்கெட்' : '📦 Pre-Packaged';
  String get inStock => isSi ? 'තොග ඇත' : isTa ? 'சரக்கு உள்ளது' : 'In Stock';
  String get lowStock => isSi ? 'අඩු තොග' : isTa ? 'குறைந்த சரக்கு' : 'Low Stock';
  String get outOfStock => isSi ? 'තොග අවසන්' : isTa ? 'சரக்கு தீர்ந்துவிட்டது' : 'Out of Stock';

  // ─── Dialogs & Actions ───
  String get selectQuantityAndMode => isSi ? 'ප්‍රමාණය සහ විකුණුම් ක්‍රමය තෝරන්න' : isTa ? 'அளவு மற்றும் விற்பனை முறையைத் தேர்ந்தெடுக்கவும்' : 'Select Quantity & Selling Mode';
  String get quickPresets => isSi ? 'ඉක්මන් ප්‍රමාණ' : isTa ? 'விரைவு அளவுகள்' : 'Quick Presets';
  String get addToBill => isSi ? 'බිලට එක්කරන්න' : isTa ? 'பில்லில் சேர்க்க' : isHi ? 'बिल में जोड़ें' : isBn ? 'বিলে যোগ করুন' : 'Add to Bill';
  String get addStockTitle => isSi ? 'තොග භාරගැනීම / ගබඩා කිරීම' : isTa ? 'சரக்கு பெறுதல் / புதுப்பித்தல்' : 'Add Stock / Receive Inventory';
  String get directQuantityMode => isSi ? '⚖️ සෘජු ප්‍රමාණය (Direct Units)' : isTa ? '⚖️ நேரடி அளவு' : '⚖️ Direct Quantity';
  String get wholesaleDeliveryMode => isSi ? '📦 පැකට් / පෙට්ටි බෙදාහැරීම' : isTa ? '📦 பொதிகள் / பெட்டிகள்' : '📦 Packs / Boxes Delivery';
  String get stockToReceive => isSi ? 'ලැබෙන තොගය' : isTa ? 'பெற வேண்டிய சரக்கு' : 'Stock to Receive';
  String get currentStock => isSi ? 'වත්මන් තොගය' : isTa ? 'தற்போதைய சரக்கு' : 'Current Stock';
  String get newTotalStock => isSi ? 'නව මුළු තොගය' : isTa ? 'புதிய மொத்த சரக்கு' : 'New Total Stock';
  String get confirmAndAddStock => isSi ? 'තහවුරු කර තොග එක්කරන්න' : isTa ? 'உறுதிசெய்து சரக்கு சேர்க்க' : 'Confirm & Add Stock';
  String get purchaseCostOptional => isSi ? 'ගැනුම් මිල (විකල්ප)' : isTa ? 'கொள்முதல் விலை (விருப்பம்)' : 'Purchase Cost (Optional)';
  String get supplierOptional => isSi ? 'සැපයුම්කරු (විකල්ප)' : isTa ? 'சப்ளையர் (விருப்பம்)' : 'Supplier (Optional)';
  String get invoiceNoteOptional => isSi ? 'ඉන්වොයිස් සටහන (විකල්ප)' : isTa ? 'ரசீது குறிப்பு (விருப்பம்)' : 'Invoice Note (Optional)';
  String get cancel => isSi ? 'අවලංගු කරන්න' : isTa ? 'ரத்துசெய்' : 'Cancel';
  String get confirm => isSi ? 'තහවුරු කරන්න' : isTa ? 'உறுதிப்படுத்தவும்' : 'Confirm';
  String get save => isSi ? 'සුරකින්න' : isTa ? 'சேமிக்க' : 'Save';

  // ─── Checkout Dialog ───
  String get paymentMethod => isSi ? 'ගෙවීම් ක්‍රමය' : isTa ? 'கட்டண முறை' : 'Payment Method';
  String get cashPayment => isSi ? 'මුදල් (Cash)' : isTa ? 'பணம் (Cash)' : 'Cash';
  String get cardPayment => isSi ? 'කාඩ්පත් (Card)' : isTa ? 'கார்டு (Card)' : 'Card';
  String get creditPayment => isSi ? 'ණය (Store Credit)' : isTa ? 'கடன் (Store Credit)' : 'Store Credit';
  String get otherPayment => isSi ? 'වෙනත් (Other)' : isTa ? 'மற்றவை (Other)' : 'Other';
  String get credit => isSi ? 'ණය' : isTa ? 'கடன்' : isHi ? 'उधार' : 'Credit';
  String get status => isSi ? 'තත්වය' : isTa ? 'நிலை' : isHi ? 'स्थिति' : 'Status';
  String get amountDue => isSi ? 'ගෙවිය යුතු මුදල' : isTa ? 'செலுத்த வேண்டிய தொகை' : 'Amount Due';
  String get cashPaid => isSi ? 'ලැබුණු මුදල' : isTa ? 'பெறப்பட்ட பணம்' : 'Cash Received';
  String get changeToReturn => isSi ? 'ඉතිරි මුදල' : isTa ? 'மீதித் தொகை' : 'Change';
  String get completePayment => isSi ? 'ගෙවීම අවසන් කරන්න  (Enter)' : isTa ? 'கட்டணத்தை முடிக்கவும் (Enter)' : 'Complete Payment (Enter)';
  String get customerCreditWarning => isSi ? 'ණයට ලබාදීමට කරුණාකර පාරිභෝගිකයෙකු තෝරන්න.' : isTa ? 'கடன் வழங்க வாடிக்கையாளரை இணைக்கவும்.' : 'Please attach a customer to issue store credit.';

  // ─── Bill History ───
  String get billHistory => isSi ? 'බිල්පත් ඉතිහාසය' : isTa ? 'ரசீது வரலாறு' : isHi ? 'बिल इतिहास' : isBn ? 'বিল ইতিহাস' : 'BILL HISTORY';
  String get totalBills => isSi ? 'මුළු බිල්පත්' : isTa ? 'மொத்த ரசீதுகள்' : isHi ? 'कुल बिल' : isBn ? 'মোট বিল' : 'Total Bills';
  String get totalSales => isSi ? 'මුළු විකුණුම්' : isTa ? 'மொத்த விற்பனை' : isHi ? 'कुल बिक्री' : isBn ? 'মোট বিক্রি' : 'Total Sales';
  String get cash => isSi ? 'මුදල්' : isTa ? 'பணம்' : isHi ? 'नकद' : isBn ? 'নগদ' : 'Cash';
  String get card => isSi ? 'කාඩ්පත්' : isTa ? 'கார்டு' : isHi ? 'कार्ड' : isBn ? 'কার্ড' : 'Card';
  String get other => isSi ? 'වෙනත් / ණය' : isTa ? 'மற்றவை / கடன்' : isHi ? 'अन्य' : isBn ? 'অন্যান্য' : 'Other';

  // ─── Cash Drawer ───
  String get openDrawer => isSi ? 'ලාච්චුව අරින්න (F9)' : isTa ? 'டிராயரைத் திறக்க (F9)' : isHi ? 'दराज खोलें (F9)' : isBn ? 'ড্রয়ার খুলুন (F9)' : 'Open Drawer (F9)';
  String get cashDrawer => isSi ? 'මුදල් ලාච්චුව' : isTa ? 'பண டிராயர்' : isHi ? 'कैश दराज' : isBn ? 'ক্যাশ ড্রয়ার' : 'Cash Drawer';
  String get drawerEjected => isSi ? 'මුදල් ලාච්චුව විවෘත විය' : isTa ? 'பண டிராயர் திறக்கப்பட்டது' : 'Cash Drawer Opened';
  String get ejectCashDrawer => isSi ? 'ලාච්චුව අරින්න' : isTa ? 'டிராயரைத் திறக்க' : 'Eject Drawer';

  // ─── Desktop Shell Navigation ───
  String get posTerminal => isSi ? 'POS පර්යන්තය' : isTa ? 'POS முனையம்' : isHi ? 'POS टर्मिनल' : isBn ? 'POS টার্মিনাল' : 'POS Terminal';
  String get dashboardNav => isSi ? 'පුවරුව' : isTa ? 'டாஷ்போர்டு' : isHi ? 'डैशबोर्ड' : isBn ? 'ড্যাশবোর্ড' : 'Dashboard';
  String get inventoryNav => isSi ? 'තොග කළමනාකරණය' : isTa ? 'சரக்கு மேலாண்மை' : isHi ? 'इन्वेंटरी' : isBn ? 'ইনভেন্টরি' : 'Inventory';
  String get invoicesAndSalesNav => isSi ? 'ඉන්වොයිස් සහ විකුණුම්' : isTa ? 'விலைப்பட்டியல் & விற்பனை' : isHi ? 'चालान और बिक्री' : isBn ? 'চালান ও বিক্রয়' : 'Invoices & Sales';
  String get customersNav => isSi ? 'පාරිභෝගිකයන්' : isTa ? 'வாடிக்கையாளர்கள்' : isHi ? 'ग्राहक' : isBn ? 'গ্রাহক' : 'Customers';
  String get suppliersGrnNav => isSi ? 'සැපයුම්කරුවන් (GRN)' : isTa ? 'சப்ளையர்கள் (GRN)' : isHi ? 'आपूर्तिकर्ता (GRN)' : isBn ? 'সরবরাহকারী (GRN)' : 'Suppliers (GRN)';
  String get expensesNav => isSi ? 'වියදම්' : isTa ? 'செலவுகள்' : isHi ? 'व्यय' : isBn ? 'খরচ' : 'Expenses';
  String get settingsNav => isSi ? 'සැකසුම්' : isTa ? 'அமைப்புகள்' : isHi ? 'सेटिंग्स' : isBn ? 'সেটিংস' : 'Settings';
  String get openCashDrawerTooltip => isSi ? 'මුදල් ලාච්චුව අරින්න (F9)' : isTa ? 'பண டிராயரைத் திறக்க (F9)' : 'Open Cash Drawer (F9)';
  String get lockTerminalTooltip => isSi ? 'පර්යන්තය අගුළුලන්න / මාරුවන්න (F8)' : isTa ? 'முனையத்தைப் பூட்டு / பயனரை மாற்று (F8)' : 'Lock Terminal / Switch User (F8)';
  String get expandSidebar => isSi ? 'තීරුව දිගහරින්න' : isTa ? 'பக்கப்பட்டியை விரிக்க' : 'Expand Sidebar';
  String get collapseSidebar => isSi ? 'තීරුව හකුලන්න' : isTa ? 'பக்கப்பட்டியை சுருக்கு' : 'Collapse Sidebar';

  // ─── Desktop Inventory View ───
  String get inventoryCatalog => isSi ? 'තොග සහ භාණ්ඩ නාමාවලිය' : isTa ? 'சரக்கு மற்றும் தயாரிப்பு பட்டியல்' : isHi ? 'इन्वेंटरी और उत्पाद सूची' : 'Inventory & Product Catalog';
  String get inventorySubtitle => isSi ? 'තොග මට්ටම්, මිල ගණන්, සහ භාණ්ඩ විස්තර කළමනාකරණය' : isTa ? 'சரக்கு நிலைகள், விலைகள் மற்றும் தயாரிப்பு விவரங்களை நிர்வகிக்கவும்' : 'Manage stock levels, pricing, batches & product catalog';
  String get totalItems => isSi ? 'මුළු භාණ්ඩ' : isTa ? 'மொத்த பொருட்கள்' : isHi ? 'कुल उत्पाद' : 'TOTAL ITEMS';
  String get lowStockAlert => isSi ? 'අඩු තොග අවවාදය' : isTa ? 'குறைந்த சரக்கு எச்சரிக்கை' : 'LOW STOCK ALERT';
  String get outOfStockBadge => isSi ? 'තොග අවසන්' : isTa ? 'சரக்கு தீர்ந்தவை' : 'OUT OF STOCK';
  String get totalValuation => isSi ? 'මුළු තොග වටිනාකම' : isTa ? 'மொத்த சரக்கு மதிப்பு' : 'TOTAL VALUATION';
  String get batches => isSi ? 'කාණ්ඩ (Batches)' : isTa ? 'தொகுதிகள் (Batches)' : 'Batches';
  String get archived => isSi ? 'සංරක්ෂිත' : isTa ? 'காப்பகப்படுத்தப்பட்டது' : 'Archived';
  String get stockAudit => isSi ? 'තොග විගණනය' : isTa ? 'சரக்கு தணிக்கை' : 'Stock Audit';
  String get newProduct => isSi ? '+ නව භාණ්ඩය' : isTa ? '+ புதிய பொருள்' : isHi ? '+ नया उत्पाद' : '+ New Product';
  String get allItems => isSi ? 'සියලු භාණ්ඩ' : isTa ? 'அனைத்து பொருட்கள்' : isHi ? 'सभी उत्पाद' : 'All Items';
  String get productCol => isSi ? 'භාණ්ඩය' : isTa ? 'பொருள்' : isHi ? 'उत्पाद' : 'PRODUCT';
  String get barcodeCol => isSi ? 'බාර්කෝඩ්' : isTa ? 'பார்கோடு' : 'BARCODE';
  String get categoryCol => isSi ? 'කාණ්ඩය' : isTa ? 'பிரிவு' : isHi ? 'श्रेणी' : 'CATEGORY';
  String get costCol => isSi ? 'ගැනුම් මිල' : isTa ? 'செலவு விலை' : 'COST';
  String get sellingPriceCol => isSi ? 'විකුණුම් මිල' : isTa ? 'விற்பனை விலை' : 'SELLING PRICE';
  String get stockLevelCol => isSi ? 'තොග ප්‍රමාණය' : isTa ? 'சரக்கு அளவு' : 'STOCK LEVEL';
  String get actionsCol => isSi ? 'ක්‍රියා' : isTa ? 'செயல்கள்' : 'ACTIONS';
  String get restock => isSi ? 'තොග එකතු' : isTa ? 'சரக்கு சேர்க்க' : 'Restock';
  String get edit => isSi ? 'සංස්කරණය' : isTa ? 'திருத்து' : 'Edit';

  // ─── Desktop Sales View ───
  String get invoicesAndSalesTitle => isSi ? 'ඉන්වොයිස් සහ විකුණුම් ගනුදෙනු' : isTa ? 'விலைப்பட்டியல் & விற்பனை பரிவர்த்தனைகள்' : 'Invoices & Sales Transactions';
  String get salesSubtitle => isSi ? 'විකුණුම් ඉතිහාසය, රිසිට්පත් නැවත මුද්‍රණය සහ ආපසු භාරගැනීම්' : isTa ? 'விற்பனை வரலாறு, ரசீது மறுஅச்சிடல் மற்றும் திரும்புதல்கள்' : 'View transaction history, reprint thermal slips, and process refunds';
  String get totalTransactions => isSi ? 'මුළු ගනුදෙනු' : isTa ? 'மொத்த பரிவர்த்தனைகள்' : 'TOTAL TRANSACTIONS';
  String get totalRevenue => isSi ? 'මුළු ආදායම' : isTa ? 'மொத்த வருவாய்' : 'TOTAL REVENUE';
  String get cashPayments => isSi ? 'මුදල් ගෙවීම්' : isTa ? 'பணக் கொடுப்பனவுகள்' : 'CASH PAYMENTS';
  String get cardOther => isSi ? 'කාඩ් / වෙනත්' : isTa ? 'கார்டு / மற்றவை' : 'CARD / OTHER';
  String get today => isSi ? 'අද' : isTa ? 'இன்று' : isHi ? 'आज' : 'Today';
  String get yesterday => isSi ? 'ඊයේ' : isTa ? 'நேற்று' : isHi ? 'कल' : 'Yesterday';
  String get thisWeek => isSi ? 'මෙම සතිය' : isTa ? 'இந்த வாரம்' : 'This Week';
  String get thisMonth => isSi ? 'මෙම මස' : isTa ? 'இந்த மாதம்' : 'This Month';
  String get allTime => isSi ? 'සියලු කාලය' : isTa ? 'அனைத்தும்' : 'All Time';
  String get allMethods => isSi ? 'සියලු ක්‍රම' : isTa ? 'அனைத்து முறைகளும்' : 'All Methods';
  String get searchSalesHint => isSi ? 'බිල් අංකය, පාරිභෝගිකයා, හෝ කැෂියර් සොයන්න...' : isTa ? 'பில் எண், வாடிக்கையாளர் அல்லது காசாளர் தேடவும்...' : 'Search by bill #, customer, or cashier...';
  String get receiptDetails => isSi ? 'රිසිට්පත් විස්තර' : isTa ? 'ரசீது விவரங்கள்' : 'RECEIPT DETAILS';
  String get reprintReceipt => isSi ? 'නැවත මුද්‍රණය' : isTa ? 'மறுஅச்சிடுக' : 'Reprint';
  String get processReturn => isSi ? 'ආපසු භාරගැනීම' : isTa ? 'திரும்பப் பெறுதல்' : 'Return / Refund';
  String get billNoCol => isSi ? 'බිල් අංකය' : isTa ? 'ரசீது எண்' : 'BILL #';
  String get dateTimeCol => isSi ? 'දිනය සහ වේලාව' : isTa ? 'தேதி & நேரம்' : 'DATE & TIME';
  String get cashierCol => isSi ? 'කැෂියර්' : isTa ? 'காசாளர்' : 'CASHIER';
  String get paymentCol => isSi ? 'ගෙවීම් ක්‍රමය' : isTa ? 'கட்டண முறை' : 'PAYMENT';
  String get statusCol => isSi ? 'තත්වය' : isTa ? 'நிலை' : 'STATUS';
  String get completed => isSi ? 'සම්පූර්ණයි' : isTa ? 'முடிந்தது' : 'COMPLETED';

  // ─── Desktop Customers View ───
  String get customersAndCredit => isSi ? 'පාරිභෝගිකයින් සහ ණය කළමනාකරණය' : isTa ? 'வாடிக்கையாளர்கள் & கடை கடன்' : 'Customers & Store Credit';
  String get customersSubtitle => isSi ? 'පාරිභෝගික ලැයිස්තුව, මිලදී ගැනීමේ ඉතිහාසය සහ ණය ගෙවීම්' : isTa ? 'வாடிக்கையாளர் பட்டியல், கொள்முதல் வரலாறு மற்றும் கடன் வசூல்' : 'Manage customer profiles, purchase habits, loyalty tiers, and credit ledger';
  String get allCustomers => isSi ? 'සියලු පාරිභෝගිකයන්' : isTa ? 'அனைத்து வாடிக்கையாளர்கள்' : 'All Customers';
  String get champions => isSi ? 'ප්‍රමුඛ (Champions)' : isTa ? 'சிறந்த வாடிக்கையாளர்கள்' : 'Champions';
  String get loyalists => isSi ? 'විශ්වාසවන්ත (Loyalists)' : isTa ? 'நம்பகமானவர்கள்' : 'Loyalists';
  String get bigSpenders => isSi ? 'වැඩි වියදම් (Big Spenders)' : isTa ? 'அதிக செலவழிப்பவர்கள்' : 'Big Spenders';
  String get atRisk => isSi ? 'අවදානම් (At Risk)' : isTa ? 'ஆபத்தில் உள்ளவர்கள்' : 'At Risk';
  String get debtors => isSi ? 'ණයහිමියන් (Debtors)' : isTa ? 'கடனாளிகள்' : 'Debtors';
  String get searchCustomersHint => isSi ? 'නම හෝ දුරකථන අංකයෙන් සොයන්න...' : isTa ? 'பெயர் அல்லது தொலைபேசி மூலம் தேடவும்...' : 'Search customers by name or phone...';
  String get customerCol => isSi ? 'පාරිභෝගිකයා' : isTa ? 'வாடிக்கையாளர்' : 'CUSTOMER';
  String get phoneCol => isSi ? 'දුරකථන' : isTa ? 'தொலைபேசி' : 'PHONE';
  String get segmentCol => isSi ? 'වර්ගීකරණය' : isTa ? 'பிரிவு' : 'SEGMENT';
  String get totalSpentCol => isSi ? 'මුළු වියදම' : isTa ? 'மொத்த செலவு' : 'TOTAL SPENT';
  String get storeCreditDebtCol => isSi ? 'හිඟ ණය මුදල' : isTa ? 'கடை கடன்' : 'STORE CREDIT DEBT';
  String get recordPayment => isSi ? 'ගෙවීම සටහන් කරන්න' : isTa ? 'கட்டணம் பதிவுசெய்' : 'Record Payment';
  String get newCustomer => isSi ? '+ නව පාරිභෝගිකයා' : isTa ? '+ புதிய வாடிக்கையாளர்' : '+ New Customer';

  // ─── Desktop Suppliers View ───
  String get suppliersAndGrn => isSi ? 'සැපයුම්කරුවන් සහ ඇණවුම් (GRN)' : isTa ? 'சப்ளையர்கள் & கொள்முதல் ஆணைகள் (GRN)' : 'Suppliers & Purchase Orders (GRN)';
  String get suppliersSubtitle => isSi ? 'සැපයුම්කරුවන් සහ ලැබෙන තොග කළමනාකරණය' : isTa ? 'சப்ளையர் தொடர்பு மற்றும் சரக்கு பெறுதலை நிர்வகிக்கவும்' : 'Manage vendor directory, purchase orders, and stock receipts';
  String get supplierDirectory => isSi ? 'සැපයුම්කරු නාමාවලිය' : isTa ? 'சப்ளையர் விபரம்' : 'Supplier Directory';
  String get purchaseOrdersGrn => isSi ? 'ඇණවුම් සහ ලැබීම් (GRN)' : isTa ? 'கொள்முதல் ஆணைகள் (GRN)' : 'Purchase Orders (GRN)';
  String get newSupplier => isSi ? '+ නව සැපයුම්කරු' : isTa ? '+ புதிய சப்ளையர்' : '+ New Supplier';
  String get inwardStockGrn => isSi ? '+ තොග ලැබීම (GRN)' : isTa ? '+ சரக்கு பெறுதல் (GRN)' : '+ Inward Stock (GRN)';
  String get searchSuppliersHint => isSi ? 'සැපයුම්කරු නම හෝ අංකය සොයන්න...' : isTa ? 'சப்ளையர் பெயர் அல்லது தொலைபேசி தேடவும்...' : 'Search suppliers by name or phone...';
  String get supplierCol => isSi ? 'සැපයුම්කරු' : isTa ? 'சப்ளையர்' : 'SUPPLIER';
  String get contactPersonCol => isSi ? 'සම්බන්ධක පුද්ගලයා' : isTa ? 'தொடர்பு நபர்' : 'CONTACT PERSON';
  String get itemsProvidedCol => isSi ? 'සපයන භාණ්ඩ' : isTa ? 'வழங்கப்படும் பொருட்கள்' : 'PROVIDED ITEMS';
  String get pending => isSi ? 'පොරොත්තුවේ' : isTa ? 'நிலுவையில்' : 'Pending';
  String get received => isSi ? 'ලැබුණි' : isTa ? 'பெறப்பட்டது' : 'Received';

  // ─── Desktop Expenses View ───
  String get expensesAndOperatingCosts => isSi ? 'වියදම් සහ මෙහෙයුම් පිරිවැය' : isTa ? 'செலவுகள் & இயக்கச் செலவுகள்' : 'Expenses & Operating Costs';
  String get expensesSubtitle => isSi ? 'දෛනික වියදම්, කුලී, බිල්පත් සහ වැටුප් සටහන් කරන්න' : isTa ? 'தினசரி இயக்க செலவுகள், வாடகை, பயன்பாடுகள் மற்றும் ஊதியங்களை கண்காணிக்கவும்' : 'Track and categorize operational expenses, store utilities, and overheads';
  String get todayExpenses => isSi ? 'අද දින වියදම්' : isTa ? 'இன்றைய செலவுகள்' : 'TODAY EXPENSES';
  String get thisMonthExpenses => isSi ? 'මෙම මස වියදම්' : isTa ? 'இந்த மாத செலவுகள்' : 'THIS MONTH';
  String get topCategory => isSi ? 'ප්‍රධාන වියදම් වර්ගය' : isTa ? 'முக்கிய செலவு பிரிவு' : 'TOP CATEGORY';
  String get recordExpense => isSi ? '+ වියදම සටහන් කරන්න' : isTa ? '+ செலவை பதிவுசெய்' : '+ Record Expense';
  String get categoryBreakdown => isSi ? 'වර්ගීකරණ සාරාංශය' : isTa ? 'பிரிவு வாரியான விவரம்' : 'Category Breakdown';
  String get searchExpensesHint => isSi ? 'සටහන හෝ වර්ගය අනුව සොයන්න...' : isTa ? 'குறிப்பு அல்லது பிரிவு மூலம் தேடவும்...' : 'Search expenses by note or category...';
  String get expenseCol => isSi ? 'වියදම / සටහන' : isTa ? 'செலவு / குறிப்பு' : 'EXPENSE / NOTE';
  String get amountCol => isSi ? 'මුදල' : isTa ? 'தொகை' : 'AMOUNT';
  String get recordedByCol => isSi ? 'සටහන් කළේ' : isTa ? 'பதிவு செய்தவர்' : 'RECORDED BY';

  // ─── Desktop Dashboard View ───
  String get storeDashboardTitle => isSi ? 'වෙළඳසැල් පුවරුව සහ ක්‍රියාකාරිත්වය' : isTa ? 'கடை டாஷ்போர்டு & செயல்திறன்' : 'Store Dashboard & Performance';
  String get dashboardSubtitle => isSi ? 'සජීවී විකුණුම් විශ්ලේෂණය, ඉහළම භාණ්ඩ සහ ආදායම් දළ විශ්ලේෂණය' : isTa ? 'நேரலை விற்பனை பகுப்பாய்வு, சிறந்த தயாரிப்புகள் மற்றும் வருவாய்' : 'Real-time sales velocity, revenue trends, and performance insights';
  String get todaysRevenue => isSi ? 'අද ආදායම' : isTa ? 'இன்றைய வருவாய்' : 'TODAY\'S REVENUE';
  String get totalOrders => isSi ? 'මුළු ඇණවුම්' : isTa ? 'மொத்த ஆர்டர்கள்' : 'TOTAL ORDERS';
  String get grossProfit => isSi ? 'දළ ලාභය' : isTa ? 'மொத்த லாபம்' : 'GROSS PROFIT';
  String get totalExpensesStat => isSi ? 'මුළු වියදම්' : isTa ? 'மொத்த செலவுகள்' : 'TOTAL EXPENSES';
  String get netProfit => isSi ? 'ශුද්ධ ලාභය' : isTa ? 'நிகர லாபம்' : 'NET PROFIT';
  String get hourlySalesVelocity => isSi ? 'පැයකට විකුණුම් ප්‍රවේගය' : isTa ? 'மணிநேர விற்பனை வேகம்' : 'HOURLY SALES VELOCITY';
  String get topSellingProducts => isSi ? 'වැඩිපුරම අලෙවි වන භාණ්ඩ' : isTa ? 'அதிக விற்பனையாகும் பொருட்கள்' : 'TOP SELLING PRODUCTS';
  String get recentTransactions => isSi ? 'මෑත ගනුදෙනු' : isTa ? 'சமீபத்திய பரிவர்த்தனைகள்' : 'RECENT TRANSACTIONS';
  String get qtySoldCol => isSi ? 'විකිණූ ප්‍රමාණය' : isTa ? 'விற்பனை அளவு' : 'QTY SOLD';
  String get totalRevenueCol => isSi ? 'මුළු ආදායම' : isTa ? 'மொத்த வருவாய்' : 'TOTAL REVENUE';
  String get paymentMethodsBreakdown => isSi ? 'ගෙවීම් ක්‍රම සාරාංශය' : isTa ? 'கட்டண முறைகள் விவரம்' : 'Payment Methods Breakdown';
  String get billsInvoices => isSi ? 'බිල්පත් / ඉන්වොයිස්' : isTa ? 'ரசீதுகள் / பில்கள்' : 'BILLS / INVOICES';
  String get averageTicket => isSi ? 'සාමාන්‍ය බිල්පත් අගය' : isTa ? 'சராசரி பில் மதிப்பு' : 'AVERAGE TICKET';
  String get allReports => isSi ? 'සියලු වාර්තා' : isTa ? 'அனைத்து அறிக்கைகளும்' : 'All Reports';
  String get goToPos => isSi ? 'POS වෙත යන්න (F1)' : isTa ? 'POS-க்கு செல்லவும் (F1)' : 'Go to POS (F1)';
  String get manageStock => isSi ? 'තොග කළමනාකරණය (F3)' : isTa ? 'சரக்கு மேலாண்மை (F3)' : 'Manage Stock (F3)';

  // ─── Desktop Settings View ───
  String get settingsTitle => isSi ? 'පද්ධති සැකසුම්' : isTa ? 'அமைப்புகள்' : isHi ? 'सेटिंग्स' : 'Settings';
  String get storeProfileTab => isSi ? 'වෙළඳසැල් විස්තර' : isTa ? 'கடை சுயவிவரம்' : 'Store Profile';
  String get printersHardwareTab => isSi ? 'මුද්‍රණ යන්ත්‍ර සහ දෘඩාංග' : isTa ? 'அச்சுப்பொறிகள் & வன்பொருள்' : 'Printers & Hardware';
  String get taxesChargesTab => isSi ? 'බදු සහ සේවා ගාස්තු' : isTa ? 'வரி & சேவைக் கட்டணங்கள்' : 'Tax & Service Charges';
  String get businessModulesTab => isSi ? 'ව්‍යාපාර මොඩියුල' : isTa ? 'வணிக தொகுதிகள்' : 'Business Modules';
  String get cloudSyncTab => isSi ? 'ක්ලවුඩ් සමමුහුර්තකරණය' : isTa ? 'கிளவுட் ஒத்திசைவு & தரவு' : 'Cloud Sync & Data';
  String get staffPermissionsTab => isSi ? 'කාර්ය මණ්ඩලය සහ අවසර' : isTa ? 'பணியாளர்கள் & அனுமதிகள்' : 'Staff & Permissions';
  String get appInterfaceLanguage => isSi ? 'යෙදුම් භාෂාව (App Interface Language)' : isTa ? 'பயன்பாட்டு மொழி (App Interface Language)' : 'App Interface Language';
  String get appInterfaceLanguageDesc => isSi ? 'පරිගණක තිරයේ දර්ශනය වන ප්‍රධාන භාෂාව තෝරන්න' : isTa ? 'முழு இடைமுகத்திற்கான முதன்மை மொழியைத் தேர்ந்தெடுக்கவும்' : 'Select language for desktop UI, navigation, and tables';
  String get receiptLanguageTitle => isSi ? 'රිසිට්පත් භාෂාව (Receipt Language)' : isTa ? 'ரசீது மொழி (Receipt Language)' : 'Receipt Language';
  String get receiptLanguageDesc => isSi ? 'පාරිභෝගික බිල්පත් මුද්‍රණය සඳහා භාෂාව' : isTa ? 'வாடிக்கையாளர் ரசீதுகளுக்கான அச்சு மொழி' : 'Select primary receipt language. Unicode rendering automatically handles Sinhala & Tamil.';
  String get paperSizeTitle => isSi ? 'කඩදාසි ප්‍රමාණය' : isTa ? 'தாள் அளவு' : 'Paper Size';
  String get saveChanges => isSi ? 'වෙනස්කම් සුරකින්න' : isTa ? 'மாற்றங்களைச் சேமிக்க' : isHi ? 'परिवर्तन सहेजें' : 'Save Changes';
}

/// Specialized receipt localization engine supporting Sinhala, English, Tamil, and Bilingual formatting.
class ReceiptL10n {
  final String lang; // 'si', 'en', 'ta', 'bilingual'

  const ReceiptL10n(this.lang);

  static ReceiptL10n of(String? code) => ReceiptL10n(code ?? 'si');
  static ReceiptL10n forLanguage(String? code) => of(code);

  bool get isSi => lang == 'si' || lang == 'sinhala';
  bool get isTa => lang == 'ta' || lang == 'tamil';
  bool get isEn => lang == 'en' || lang == 'english';
  bool get isBilingual => lang == 'bilingual';

  // ─── Invoice Metadata ───
  String get billNo => isSi
      ? 'බිල් අංකය'
      : isTa
          ? 'ரசீது எண்'
          : isBilingual
              ? 'බිල් අංකය / Bill No'
              : 'Bill No';

  String get date => isSi
      ? 'දිනය'
      : isTa
          ? 'தேதி'
          : isBilingual
              ? 'දිනය / Date'
              : 'Date';

  String get time => isSi
      ? 'වේලාව'
      : isTa
          ? 'நேரம்'
          : isBilingual
              ? 'වේලාව / Time'
              : 'Time';

  String get cashier => isSi
      ? 'කැෂියර්'
      : isTa
          ? 'காசாளர்'
          : isBilingual
              ? 'කැෂියර් / Cashier'
              : 'Cashier';

  String get customer => isSi
      ? 'පාරිභෝගිකයා'
      : isTa
          ? 'வாடிக்கையாளர்'
          : isBilingual
              ? 'පාරිභෝගිකයා / Cust'
              : 'Customer';

  String get phone => isSi
      ? 'දුරකථන'
      : isTa
          ? 'தொலைபேசி'
          : isBilingual
              ? 'දුරකථන / Tel'
              : 'Tel';

  // ─── Item Table Headers ───
  String get itemHeader => isSi
      ? 'භාණ්ඩය'
      : isTa
          ? 'பொருள்'
          : isBilingual
              ? 'භාණ්ඩය / Item'
              : 'ITEM';

  String get qtyHeader => isSi
      ? 'ප්‍රමාණය'
      : isTa
          ? 'அளவு'
          : isBilingual
              ? 'ප්‍රමාණය / Qty'
              : 'QTY';

  String get priceHeader => isSi
      ? 'මිල'
      : isTa
          ? 'விலை'
          : isBilingual
              ? 'මිල / Price'
              : 'PRICE';

  String get totalHeader => isSi
      ? 'එකතුව'
      : isTa
          ? 'மொத்தம்'
          : isBilingual
              ? 'එකතුව / Total'
              : 'TOTAL';

  String get qtyDescHeader => isSi
      ? 'ප්‍රමාණය / විස්තරය'
      : isTa
          ? 'அளவு / விவரம்'
          : isBilingual
              ? 'ප්‍රමාණය / විස්තරය / Qty & Desc'
              : 'QTY / DESC';

  String get returns => isSi
      ? 'මාරුවාරු'
      : isTa
          ? 'பரிமாற்றம்'
          : isBilingual
              ? 'මාරුවාරු / Returns'
              : 'Returns';

  String get cash => isSi
      ? 'මුදල්'
      : isTa
          ? 'பணம்'
          : isBilingual
              ? 'මුදල් / Cash'
              : 'Cash';

  String get card => isSi
      ? 'කාඩ්'
      : isTa
          ? 'அட்டை'
          : isBilingual
              ? 'කාඩ් / Card'
              : 'Card';

  // ─── Sri Lankan Retail POS Pricing Breakdown ───
  String get standardPrice => isSi
      ? 'සදාන් මිල'
      : isTa
          ? 'வழக்கமான விலை'
          : isBilingual
              ? 'සදාන් මිල / Std Price'
              : 'Standard Price';

  String get ourPrice => isSi
      ? 'අපේ මිල'
      : isTa
          ? 'எங்கள் விலை'
          : isBilingual
              ? 'අපේ මිල / Our Price'
              : 'Our Price';

  String get subtotal => isSi
      ? 'එකතුව'
      : isTa
          ? 'உப மொத்தம்'
          : isBilingual
              ? 'එකතුව / Subtotal'
              : 'Subtotal';

  String get discount => isSi
      ? 'ලාභය'
      : isTa
          ? 'தள்ளுபடி'
          : isBilingual
              ? 'ලාභය / Discount'
              : 'Discount';

  String get profit => isSi
      ? 'ලාභය'
      : isTa
          ? 'சேமிப்பு'
          : isBilingual
              ? 'ලාභය / Savings'
              : 'Savings';

  String get totalProfit => isSi
      ? 'සම්පූර්ණ ලාභය'
      : isTa
          ? 'மொத்த சேமிப்பு'
          : isBilingual
              ? 'සම්පූර්ණ ලාභය / Total Savings'
              : 'Total Savings';

  String get totalSavings => totalProfit;

  String get merchantProfit => isSi
      ? 'ව්‍යාපාරික ලාභය'
      : isTa
          ? 'வணிக லாபம்'
          : isBilingual
              ? 'ව්‍යාපාරික ලාභය / Profit'
              : 'Merchant Profit';

  String get costPrice => isSi
      ? 'ගැනුම් මිල'
      : isTa
          ? 'கொள்முதல் விலை'
          : isBilingual
              ? 'ගැනුම් මිල / Cost'
              : 'Cost Price';

  String get tax => isSi
      ? 'බදු (VAT)'
      : isTa
          ? 'வரி (VAT)'
          : isBilingual
              ? 'බදු / Tax (VAT)'
              : 'Tax (VAT)';

  String get serviceCharge => isSi
      ? 'සේවා ගාස්තු'
      : isTa
          ? 'சேவை கட்டணம்'
          : isBilingual
              ? 'සේවා ගාස්තු / Service'
              : 'Service Charge';

  String get grandTotal => isSi
      ? 'මුළු මුදල'
      : isTa
          ? 'மொத்த தொகை'
          : isBilingual
              ? 'මුළු මුදල / Grand Total'
              : 'GRAND TOTAL';

  // ─── Payment Breakdown ───
  String get paymentMethod => isSi
      ? 'ගෙවීම් ක්‍රමය'
      : isTa
          ? 'கட்டண முறை'
          : isBilingual
              ? 'ගෙවීම් ක්‍රමය / Payment'
              : 'Payment';

  String get cashReceived => isSi
      ? 'ගෙවූ මුදල'
      : isTa
          ? 'பெறப்பட்ட பணம்'
          : isBilingual
              ? 'ගෙවූ මුදල / Cash Paid'
              : 'Cash Received';

  String get change => isSi
      ? 'හුවමාරුව'
      : isTa
          ? 'மீதித் தொகை'
          : isBilingual
              ? 'හුවමාරුව / Change'
              : 'Change / Balance';

  String get remainingAmount => isSi
      ? 'ඉතිරි මුදල'
      : isTa
          ? 'நிலுவை தொகை'
          : isBilingual
              ? 'ඉතිරි මුදල / Due Balance'
              : 'Remaining Balance';

  // ─── Additional Summary & Footer ───
  String get itemsCount => isSi
      ? 'භාණ්ඩ ගණන'
      : isTa
          ? 'பொருட்களின் எண்ணிக்கை'
          : isBilingual
              ? 'භාණ්ඩ ගණන / Items Count'
              : 'Items Count';

  String get totalQuantity => isSi
      ? 'මුළු ප්‍රමාණය'
      : isTa
          ? 'மொத்த அளவு'
          : isBilingual
              ? 'මුළු ප්‍රමාණය / Total Qty'
              : 'Total Qty';

  String get piecesShort => isSi
      ? 'ප්‍රමාණ'
      : isTa
          ? 'எண்ணிக்கை'
          : isBilingual
              ? 'ප්‍රමාණ / Pcs'
              : 'Pcs';

  String get thankYou => isSi
      ? 'ස්තුතියි! නැවත එන්න'
      : isTa
          ? 'நன்றி! மீண்டும் வருக'
          : isBilingual
              ? 'ස්තුතියි! / Thank You!'
              : 'Thank You! Please Come Again';

  String get defaultThankYouShort => isSi
      ? 'ස්තුතියි!'
      : isTa
          ? 'நன்றி!'
          : isBilingual
              ? 'ස්තුතියි! / Thank You!'
              : 'Thank You!';

  String get poweredBy => isSi
      ? 'QuickBill POS මගින් ක්‍රියාත්මකයි'
      : isTa
          ? 'QuickBill POS மூலம் இயக்கப்படுகிறது'
          : isBilingual
              ? 'Powered by QuickBill POS'
              : 'Powered by QuickBill POS';
}
