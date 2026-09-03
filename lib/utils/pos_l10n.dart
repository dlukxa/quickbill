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
}
