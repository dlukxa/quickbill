import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/region_utils.dart';
import '../services/sync_service.dart';

class AppSettings {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final int lowStockThreshold;
  final String receiptFooter;
  final String languageCode;
  final String regionCode;
  final String businessType;
  final bool isSetupComplete;
  final bool autoSync;
  final String? shopLogoUrl;
  final bool isDarkMode;
  final String entityCode;
  final double serviceChargeRate;
  final double taxRate;
  final String cloudBackupFrequency;
  final String printerConnectionType; // 'bluetooth', 'network', 'system'
  final String printerPaperSize; // '80mm', '58mm'
  final String printerIpAddress; // e.g. '192.168.1.100'
  final int printerPort; // e.g. 9100
  final String? selectedPrinterName; // Name of OS-installed printer for Windows/macOS
  final bool autoPrintReceipt;
  final bool autoOpenCashDrawerOnCashStart;
  final bool autoOpenCashDrawerOnSaleComplete;
  final String cashDrawerTriggerType; // 'printer', 'com_port'
  final String cashDrawerComPort; // e.g. 'COM1'
  final String receiptTemplate; // 'sri_lankan_retail', 'classic'
  final String receiptLanguage; // 'si', 'en', 'ta', 'bilingual'
  final bool showReceiptLogo;
  final bool showReceiptBarcode;
  final bool showReceiptStandardPrice;
  final bool showReceiptOurPrice;
  final bool showReceiptDiscount;
  final bool showReceiptTax;
  final bool showReceiptPaymentDetails;
  final bool showReceiptCashier;
  final bool showReceiptCustomer;
  final bool showReceiptProfit; // Sensitive internal profit (default: false)
  final bool showReceiptCostPrice; // Sensitive internal cost (default: false)
  final bool? _hasSelectedLanguage;

  bool get hasSelectedLanguage => _hasSelectedLanguage ?? false;
  bool get is58mm => printerPaperSize == '58mm';

  AppSettings({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.lowStockThreshold,
    required this.receiptFooter,
    required this.languageCode,
    required this.regionCode,
    required this.businessType,
    required this.isSetupComplete,
    required this.autoSync,
    this.shopLogoUrl,
    this.isDarkMode = false,
    required this.entityCode,
    this.serviceChargeRate = 0.0,
    this.taxRate = 0.0,
    this.cloudBackupFrequency = 'Daily',
    this.printerConnectionType = 'bluetooth',
    this.printerPaperSize = '80mm',
    this.printerIpAddress = '192.168.1.100',
    this.printerPort = 9100,
    this.selectedPrinterName,
    this.autoPrintReceipt = false,
    this.autoOpenCashDrawerOnCashStart = true,
    this.autoOpenCashDrawerOnSaleComplete = true,
    this.cashDrawerTriggerType = 'printer',
    this.cashDrawerComPort = 'COM1',
    this.receiptTemplate = 'sri_lankan_retail',
    this.receiptLanguage = 'si',
    this.showReceiptLogo = true,
    this.showReceiptBarcode = true,
    this.showReceiptStandardPrice = true,
    this.showReceiptOurPrice = true,
    this.showReceiptDiscount = true,
    this.showReceiptTax = true,
    this.showReceiptPaymentDetails = true,
    this.showReceiptCashier = true,
    this.showReceiptCustomer = true,
    this.showReceiptProfit = false,
    this.showReceiptCostPrice = false,
    bool? hasSelectedLanguage,
  }) : _hasSelectedLanguage = hasSelectedLanguage;

  AppSettings copyWith({
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    int? lowStockThreshold,
    String? receiptFooter,
    String? languageCode,
    String? regionCode,
    String? businessType,
    bool? isSetupComplete,
    bool? autoSync,
    String? shopLogoUrl,
    bool? isDarkMode,
    String? entityCode,
    double? serviceChargeRate,
    double? taxRate,
    String? cloudBackupFrequency,
    String? printerConnectionType,
    String? printerPaperSize,
    String? printerIpAddress,
    int? printerPort,
    String? selectedPrinterName,
    bool? autoPrintReceipt,
    bool? autoOpenCashDrawerOnCashStart,
    bool? autoOpenCashDrawerOnSaleComplete,
    String? cashDrawerTriggerType,
    String? cashDrawerComPort,
    String? receiptTemplate,
    String? receiptLanguage,
    bool? showReceiptLogo,
    bool? showReceiptBarcode,
    bool? showReceiptStandardPrice,
    bool? showReceiptOurPrice,
    bool? showReceiptDiscount,
    bool? showReceiptTax,
    bool? showReceiptPaymentDetails,
    bool? showReceiptCashier,
    bool? showReceiptCustomer,
    bool? showReceiptProfit,
    bool? showReceiptCostPrice,
    bool? hasSelectedLanguage,
  }) {
    return AppSettings(
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      languageCode: languageCode ?? this.languageCode,
      regionCode: regionCode ?? this.regionCode,
      businessType: businessType ?? this.businessType,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      autoSync: autoSync ?? this.autoSync,
      shopLogoUrl: shopLogoUrl ?? this.shopLogoUrl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      entityCode: entityCode ?? this.entityCode,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
      taxRate: taxRate ?? this.taxRate,
      cloudBackupFrequency: cloudBackupFrequency ?? this.cloudBackupFrequency,
      printerConnectionType: printerConnectionType ?? this.printerConnectionType,
      printerPaperSize: printerPaperSize ?? this.printerPaperSize,
      printerIpAddress: printerIpAddress ?? this.printerIpAddress,
      printerPort: printerPort ?? this.printerPort,
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      autoOpenCashDrawerOnCashStart: autoOpenCashDrawerOnCashStart ?? this.autoOpenCashDrawerOnCashStart,
      autoOpenCashDrawerOnSaleComplete: autoOpenCashDrawerOnSaleComplete ?? this.autoOpenCashDrawerOnSaleComplete,
      cashDrawerTriggerType: cashDrawerTriggerType ?? this.cashDrawerTriggerType,
      cashDrawerComPort: cashDrawerComPort ?? this.cashDrawerComPort,
      receiptTemplate: receiptTemplate ?? this.receiptTemplate,
      receiptLanguage: receiptLanguage ?? this.receiptLanguage,
      showReceiptLogo: showReceiptLogo ?? this.showReceiptLogo,
      showReceiptBarcode: showReceiptBarcode ?? this.showReceiptBarcode,
      showReceiptStandardPrice: showReceiptStandardPrice ?? this.showReceiptStandardPrice,
      showReceiptOurPrice: showReceiptOurPrice ?? this.showReceiptOurPrice,
      showReceiptDiscount: showReceiptDiscount ?? this.showReceiptDiscount,
      showReceiptTax: showReceiptTax ?? this.showReceiptTax,
      showReceiptPaymentDetails: showReceiptPaymentDetails ?? this.showReceiptPaymentDetails,
      showReceiptCashier: showReceiptCashier ?? this.showReceiptCashier,
      showReceiptCustomer: showReceiptCustomer ?? this.showReceiptCustomer,
      showReceiptProfit: showReceiptProfit ?? this.showReceiptProfit,
      showReceiptCostPrice: showReceiptCostPrice ?? this.showReceiptCostPrice,
      hasSelectedLanguage: hasSelectedLanguage ?? _hasSelectedLanguage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_name': shopName,
      'shop_address': shopAddress,
      'shop_phone': shopPhone,
      'low_stock_threshold': lowStockThreshold,
      'receipt_footer': receiptFooter,
      'language_code': languageCode,
      'region_code': regionCode,
      'business_type': businessType,
      'is_setup_complete': isSetupComplete,
      'auto_sync': autoSync,
      'shop_logo_url': shopLogoUrl,
      'entity_code': entityCode,
      'service_charge_rate': serviceChargeRate,
      'tax_rate': taxRate,
      'cloud_backup_frequency': cloudBackupFrequency,
      'printer_connection_type': printerConnectionType,
      'printer_paper_size': printerPaperSize,
      'printer_ip_address': printerIpAddress,
      'printer_port': printerPort,
      'selected_printer_name': selectedPrinterName,
      'auto_print_receipt': autoPrintReceipt,
      'auto_open_cash_drawer_on_cash_start': autoOpenCashDrawerOnCashStart,
      'auto_open_cash_drawer_on_sale_complete': autoOpenCashDrawerOnSaleComplete,
      'cash_drawer_trigger_type': cashDrawerTriggerType,
      'cash_drawer_com_port': cashDrawerComPort,
      'receipt_template': receiptTemplate,
      'receipt_language': receiptLanguage,
      'show_receipt_logo': showReceiptLogo,
      'show_receipt_barcode': showReceiptBarcode,
      'show_receipt_standard_price': showReceiptStandardPrice,
      'show_receipt_our_price': showReceiptOurPrice,
      'show_receipt_discount': showReceiptDiscount,
      'show_receipt_tax': showReceiptTax,
      'show_receipt_payment_details': showReceiptPaymentDetails,
      'show_receipt_cashier': showReceiptCashier,
      'show_receipt_customer': showReceiptCustomer,
      'show_receipt_profit': showReceiptProfit,
      'show_receipt_cost_price': showReceiptCostPrice,
      'has_selected_language': hasSelectedLanguage,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const String _keyShopName = 'shop_name';
  static const String _keyShopAddress = 'shop_address';
  static const String _keyShopPhone = 'shop_phone';
  static const String _keyLowStockThreshold = 'low_stock_threshold';
  static const String _keyReceiptFooter = 'receipt_footer';
  static const String _keyLanguageCode = 'language_code';
  static const String _keyRegionCode = 'region_code';
  static const String _keyBusinessType = 'business_type';
  static const String _keyIsSetupComplete = 'is_setup_complete';
  static const String _keyAutoSync = 'auto_sync';
  static const String _keyLastEmployeeId = 'last_employee_id';
  static const String _keyShopLogoUrl = 'shop_logo_url';
  static const String _keyIsDarkMode = 'is_dark_mode_v2'; // Changed to bypass Auto Backup
  static const String _keyEntityCode = 'entity_code';
  static const String _keyServiceChargeRate = 'service_charge_rate';
  static const String _keyTaxRate = 'tax_rate';
  static const String _keyCloudBackupFrequency = 'cloud_backup_frequency';
  static const String _keyPrinterConnectionType = 'printer_connection_type';
  static const String _keyPrinterPaperSize = 'printer_paper_size';
  static const String _keyPrinterIpAddress = 'printer_ip_address';
  static const String _keyPrinterPort = 'printer_port';
  static const String _keySelectedPrinterName = 'selected_printer_name';
  static const String _keyAutoPrintReceipt = 'auto_print_receipt';
  static const String _keyAutoOpenCashDrawerOnCashStart = 'auto_open_cash_drawer_on_cash_start';
  static const String _keyAutoOpenCashDrawerOnSaleComplete = 'auto_open_cash_drawer_on_sale_complete';
  static const String _keyCashDrawerTriggerType = 'cash_drawer_trigger_type';
  static const String _keyCashDrawerComPort = 'cash_drawer_com_port';
  static const String _keyReceiptTemplate = 'receipt_template';
  static const String _keyReceiptLanguage = 'receipt_language';
  static const String _keyShowReceiptLogo = 'show_receipt_logo';
  static const String _keyShowReceiptBarcode = 'show_receipt_barcode';
  static const String _keyShowReceiptStandardPrice = 'show_receipt_standard_price';
  static const String _keyShowReceiptOurPrice = 'show_receipt_our_price';
  static const String _keyShowReceiptDiscount = 'show_receipt_discount';
  static const String _keyShowReceiptTax = 'show_receipt_tax';
  static const String _keyShowReceiptPaymentDetails = 'show_receipt_payment_details';
  static const String _keyShowReceiptCashier = 'show_receipt_cashier';
  static const String _keyShowReceiptCustomer = 'show_receipt_customer';
  static const String _keyShowReceiptProfit = 'show_receipt_profit';
  static const String _keyShowReceiptCostPrice = 'show_receipt_cost_price';

  late SharedPreferences _prefs;

  @override
  AppSettings build() {
    // Initial state is hardcoded defaults, will be updated by init()
    return AppSettings(
      shopName: 'QuickBill Store',
      shopAddress: '',
      shopPhone: '',
      lowStockThreshold: 10,
      receiptFooter: 'Thank you for shopping!',
      languageCode: 'en',
      regionCode: 'LK',
      businessType: 'Retail',
      isSetupComplete: false,
      autoSync: true,
      shopLogoUrl: null,
      isDarkMode: false,
      entityCode: '1',
      serviceChargeRate: 0.0,
      taxRate: 0.0,
      cloudBackupFrequency: 'Daily',
      printerConnectionType: 'bluetooth',
      printerPaperSize: '80mm',
      printerIpAddress: '192.168.1.100',
      printerPort: 9100,
      selectedPrinterName: null,
      autoPrintReceipt: false,
      autoOpenCashDrawerOnCashStart: true,
      autoOpenCashDrawerOnSaleComplete: true,
      cashDrawerTriggerType: 'printer',
      cashDrawerComPort: 'COM1',
      receiptTemplate: 'sri_lankan_retail',
      receiptLanguage: 'si',
      showReceiptLogo: true,
      showReceiptBarcode: true,
      showReceiptStandardPrice: true,
      showReceiptOurPrice: true,
      showReceiptDiscount: true,
      showReceiptTax: true,
      showReceiptPaymentDetails: true,
      showReceiptCashier: true,
      showReceiptCustomer: true,
      showReceiptProfit: false,
      showReceiptCostPrice: false,
      hasSelectedLanguage: false,
    );
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    final loadedRegion = _prefs.getString(_keyRegionCode) ?? 'LK';
    globalAppRegion = RegionUtils.fromCode(loadedRegion);

    state = AppSettings(
      shopName: _prefs.getString(_keyShopName) ?? 'QuickBill Store',
      shopAddress: _prefs.getString(_keyShopAddress) ?? '',
      shopPhone: _prefs.getString(_keyShopPhone) ?? '',
      lowStockThreshold: _prefs.getInt(_keyLowStockThreshold) ?? 10,
      receiptFooter: _prefs.getString(_keyReceiptFooter) ?? 'Thank you for shopping!',
      languageCode: _prefs.getString(_keyLanguageCode) ?? 'en',
      regionCode: loadedRegion,
      businessType: _prefs.getString(_keyBusinessType) ?? 'Retail',
      isSetupComplete: _prefs.getBool(_keyIsSetupComplete) ?? false,
      autoSync: _prefs.getBool(_keyAutoSync) ?? true,
      shopLogoUrl: _prefs.getString(_keyShopLogoUrl),
      isDarkMode: _prefs.getBool(_keyIsDarkMode) ?? false,
      entityCode: _prefs.getString(_keyEntityCode) ?? '1',
      serviceChargeRate: _prefs.getDouble(_keyServiceChargeRate) ?? 0.0,
      taxRate: _prefs.getDouble(_keyTaxRate) ?? 0.0,
      cloudBackupFrequency: _prefs.getString(_keyCloudBackupFrequency) ?? 'Daily',
      printerConnectionType: _prefs.getString(_keyPrinterConnectionType) ?? 'bluetooth',
      printerPaperSize: _prefs.getString(_keyPrinterPaperSize) ?? '80mm',
      printerIpAddress: _prefs.getString(_keyPrinterIpAddress) ?? '192.168.1.100',
      printerPort: _prefs.getInt(_keyPrinterPort) ?? 9100,
      selectedPrinterName: _prefs.getString(_keySelectedPrinterName),
      autoPrintReceipt: _prefs.getBool(_keyAutoPrintReceipt) ?? false,
      autoOpenCashDrawerOnCashStart: _prefs.getBool(_keyAutoOpenCashDrawerOnCashStart) ?? true,
      autoOpenCashDrawerOnSaleComplete: _prefs.getBool(_keyAutoOpenCashDrawerOnSaleComplete) ?? true,
      cashDrawerTriggerType: _prefs.getString(_keyCashDrawerTriggerType) ?? 'printer',
      cashDrawerComPort: _prefs.getString(_keyCashDrawerComPort) ?? 'COM1',
      receiptTemplate: _prefs.getString(_keyReceiptTemplate) ?? 'sri_lankan_retail',
      receiptLanguage: _prefs.getString(_keyReceiptLanguage) ?? 'si',
      showReceiptLogo: _prefs.getBool(_keyShowReceiptLogo) ?? true,
      showReceiptBarcode: _prefs.getBool(_keyShowReceiptBarcode) ?? true,
      showReceiptStandardPrice: _prefs.getBool(_keyShowReceiptStandardPrice) ?? true,
      showReceiptOurPrice: _prefs.getBool(_keyShowReceiptOurPrice) ?? true,
      showReceiptDiscount: _prefs.getBool(_keyShowReceiptDiscount) ?? true,
      showReceiptTax: _prefs.getBool(_keyShowReceiptTax) ?? true,
      showReceiptPaymentDetails: _prefs.getBool(_keyShowReceiptPaymentDetails) ?? true,
      showReceiptCashier: _prefs.getBool(_keyShowReceiptCashier) ?? true,
      showReceiptCustomer: _prefs.getBool(_keyShowReceiptCustomer) ?? true,
      showReceiptProfit: _prefs.getBool(_keyShowReceiptProfit) ?? false,
      showReceiptCostPrice: _prefs.getBool(_keyShowReceiptCostPrice) ?? false,
      hasSelectedLanguage: _prefs.getString(_keyLanguageCode) != null,
    );
  }

  Future<void> _syncToCloud() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.pushSettings(state);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> updateShopLogo(String? url) async {
    if (url != null) {
      await _prefs.setString(_keyShopLogoUrl, url);
    } else {
      await _prefs.remove(_keyShopLogoUrl);
    }
    state = state.copyWith(shopLogoUrl: url);
    await _syncToCloud();
  }

  Future<void> updateShopName(String name) async {
    await _prefs.setString(_keyShopName, name);
    state = state.copyWith(shopName: name);
    await _syncToCloud();
  }

  Future<void> updateShopAddress(String address) async {
    await _prefs.setString(_keyShopAddress, address);
    state = state.copyWith(shopAddress: address);
    await _syncToCloud();
  }

  Future<void> updateShopPhone(String phone) async {
    await _prefs.setString(_keyShopPhone, phone);
    state = state.copyWith(shopPhone: phone);
    await _syncToCloud();
  }

  Future<void> updateLowStockThreshold(int threshold) async {
    await _prefs.setInt(_keyLowStockThreshold, threshold);
    state = state.copyWith(lowStockThreshold: threshold);
    await _syncToCloud();
  }

  Future<void> updateReceiptFooter(String footer) async {
    await _prefs.setString(_keyReceiptFooter, footer);
    state = state.copyWith(receiptFooter: footer);
    await _syncToCloud();
  }

  Future<void> updateLanguage(String code) async {
    await _prefs.setString(_keyLanguageCode, code);
    state = state.copyWith(languageCode: code, hasSelectedLanguage: true);
    await _syncToCloud();
  }

  Future<void> updateRegion(String code) async {
    await _prefs.setString(_keyRegionCode, code);
    globalAppRegion = RegionUtils.fromCode(code);
    state = state.copyWith(regionCode: code);
    await _syncToCloud();
  }

  Future<void> updateBusinessType(String type) async {
    await _prefs.setString(_keyBusinessType, type);
    state = state.copyWith(businessType: type);
    await _syncToCloud();
  }

  Future<void> completeSetup() async {
    await _prefs.setBool(_keyIsSetupComplete, true);
    state = state.copyWith(isSetupComplete: true);
    await _syncToCloud();
  }

  Future<void> updateAutoSync(bool enabled) async {
    await _prefs.setBool(_keyAutoSync, enabled);
    state = state.copyWith(autoSync: enabled);
    await _syncToCloud();
  }

  Future<void> updateDarkMode(bool isDark) async {
    await _prefs.setBool(_keyIsDarkMode, isDark);
    state = state.copyWith(isDarkMode: isDark);
    await _syncToCloud();
  }

  Future<void> updateEntityCode(String code) async {
    final clean = code.trim().replaceAll(' ', '');
    await _prefs.setString(_keyEntityCode, clean);
    state = state.copyWith(entityCode: clean);
    await _syncToCloud();
  }

  Future<void> updateServiceChargeRate(double rate) async {
    await _prefs.setDouble(_keyServiceChargeRate, rate);
    state = state.copyWith(serviceChargeRate: rate);
    await _syncToCloud();
  }

  Future<void> updateTaxRate(double rate) async {
    await _prefs.setDouble(_keyTaxRate, rate);
    state = state.copyWith(taxRate: rate);
    await _syncToCloud();
  }

  Future<void> updateCloudBackupFrequency(String frequency) async {
    await _prefs.setString(_keyCloudBackupFrequency, frequency);
    state = state.copyWith(cloudBackupFrequency: frequency);
    await _syncToCloud();
  }

  Future<void> updatePrinterConnectionType(String type) async {
    await _prefs.setString(_keyPrinterConnectionType, type);
    state = state.copyWith(printerConnectionType: type);
  }

  Future<void> updatePrinterPaperSize(String size) async {
    await _prefs.setString(_keyPrinterPaperSize, size);
    state = state.copyWith(printerPaperSize: size);
  }

  Future<void> updatePrinterNetworkConfig({required String ip, required int port}) async {
    await _prefs.setString(_keyPrinterIpAddress, ip.trim());
    await _prefs.setInt(_keyPrinterPort, port);
    state = state.copyWith(printerIpAddress: ip.trim(), printerPort: port);
  }

  Future<void> updateSelectedPrinterName(String? name) async {
    if (name != null) {
      await _prefs.setString(_keySelectedPrinterName, name);
    } else {
      await _prefs.remove(_keySelectedPrinterName);
    }
    state = state.copyWith(selectedPrinterName: name);
  }

  Future<void> updateAutoPrintReceipt(bool enabled) async {
    await _prefs.setBool(_keyAutoPrintReceipt, enabled);
    state = state.copyWith(autoPrintReceipt: enabled);
  }

  Future<void> updateAutoOpenCashDrawerOnCashStart(bool enabled) async {
    await _prefs.setBool(_keyAutoOpenCashDrawerOnCashStart, enabled);
    state = state.copyWith(autoOpenCashDrawerOnCashStart: enabled);
  }

  Future<void> updateAutoOpenCashDrawerOnSaleComplete(bool enabled) async {
    await _prefs.setBool(_keyAutoOpenCashDrawerOnSaleComplete, enabled);
    state = state.copyWith(autoOpenCashDrawerOnSaleComplete: enabled);
  }

  Future<void> updateCashDrawerTriggerType(String type) async {
    await _prefs.setString(_keyCashDrawerTriggerType, type);
    state = state.copyWith(cashDrawerTriggerType: type);
  }

  Future<void> updateCashDrawerComPort(String port) async {
    final clean = port.trim().toUpperCase();
    await _prefs.setString(_keyCashDrawerComPort, clean);
    state = state.copyWith(cashDrawerComPort: clean);
  }

  Future<void> updateReceiptTemplate(String template) async {
    await _prefs.setString(_keyReceiptTemplate, template);
    state = state.copyWith(receiptTemplate: template);
    await _syncToCloud();
  }

  Future<void> updateReceiptLanguage(String lang) async {
    await _prefs.setString(_keyReceiptLanguage, lang);
    state = state.copyWith(receiptLanguage: lang);
    await _syncToCloud();
  }

  Future<void> updateReceiptToggles({
    bool? showLogo,
    bool? showBarcode,
    bool? showStandardPrice,
    bool? showOurPrice,
    bool? showDiscount,
    bool? showTax,
    bool? showPaymentDetails,
    bool? showCashier,
    bool? showCustomer,
    bool? showProfit,
    bool? showCostPrice,
  }) async {
    if (showLogo != null) await _prefs.setBool(_keyShowReceiptLogo, showLogo);
    if (showBarcode != null) await _prefs.setBool(_keyShowReceiptBarcode, showBarcode);
    if (showStandardPrice != null) await _prefs.setBool(_keyShowReceiptStandardPrice, showStandardPrice);
    if (showOurPrice != null) await _prefs.setBool(_keyShowReceiptOurPrice, showOurPrice);
    if (showDiscount != null) await _prefs.setBool(_keyShowReceiptDiscount, showDiscount);
    if (showTax != null) await _prefs.setBool(_keyShowReceiptTax, showTax);
    if (showPaymentDetails != null) await _prefs.setBool(_keyShowReceiptPaymentDetails, showPaymentDetails);
    if (showCashier != null) await _prefs.setBool(_keyShowReceiptCashier, showCashier);
    if (showCustomer != null) await _prefs.setBool(_keyShowReceiptCustomer, showCustomer);
    if (showProfit != null) await _prefs.setBool(_keyShowReceiptProfit, showProfit);
    if (showCostPrice != null) await _prefs.setBool(_keyShowReceiptCostPrice, showCostPrice);

    state = state.copyWith(
      showReceiptLogo: showLogo ?? state.showReceiptLogo,
      showReceiptBarcode: showBarcode ?? state.showReceiptBarcode,
      showReceiptStandardPrice: showStandardPrice ?? state.showReceiptStandardPrice,
      showReceiptOurPrice: showOurPrice ?? state.showReceiptOurPrice,
      showReceiptDiscount: showDiscount ?? state.showReceiptDiscount,
      showReceiptTax: showTax ?? state.showReceiptTax,
      showReceiptPaymentDetails: showPaymentDetails ?? state.showReceiptPaymentDetails,
      showReceiptCashier: showCashier ?? state.showReceiptCashier,
      showReceiptCustomer: showCustomer ?? state.showReceiptCustomer,
      showReceiptProfit: showProfit ?? state.showReceiptProfit,
      showReceiptCostPrice: showCostPrice ?? state.showReceiptCostPrice,
    );
    await _syncToCloud();
  }

  Future<void> updateFromMap(Map<String, dynamic> data) async {
    if (data.containsKey(_keyShopName)) {
      await _prefs.setString(_keyShopName, data[_keyShopName]);
    }
    if (data.containsKey(_keyShopAddress)) {
      await _prefs.setString(_keyShopAddress, data[_keyShopAddress]);
    }
    if (data.containsKey(_keyShopPhone)) {
      await _prefs.setString(_keyShopPhone, data[_keyShopPhone]);
    }
    if (data.containsKey(_keyLowStockThreshold)) {
      await _prefs.setInt(_keyLowStockThreshold, data[_keyLowStockThreshold]);
    }
    if (data.containsKey(_keyReceiptFooter)) {
      await _prefs.setString(_keyReceiptFooter, data[_keyReceiptFooter]);
    }
    if (data.containsKey(_keyLanguageCode)) {
      await _prefs.setString(_keyLanguageCode, data[_keyLanguageCode]);
    }
    if (data.containsKey(_keyRegionCode)) {
      await _prefs.setString(_keyRegionCode, data[_keyRegionCode]);
    }
    if (data.containsKey(_keyBusinessType)) {
      await _prefs.setString(_keyBusinessType, data[_keyBusinessType]);
    }
    if (data.containsKey(_keyIsSetupComplete) && data[_keyIsSetupComplete] != null) {
      final val = data[_keyIsSetupComplete];
      final bool isComplete = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyIsSetupComplete, isComplete);
    }
    if (data.containsKey(_keyAutoSync) && data[_keyAutoSync] != null) {
      final val = data[_keyAutoSync];
      final bool autoSync = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyAutoSync, autoSync);
    }
    if (data.containsKey(_keyEntityCode)) {
      await _prefs.setString(_keyEntityCode, data[_keyEntityCode]);
    }
    if (data.containsKey(_keyServiceChargeRate)) {
      final rate = (data[_keyServiceChargeRate] as num).toDouble();
      await _prefs.setDouble(_keyServiceChargeRate, rate);
    }
    if (data.containsKey(_keyTaxRate)) {
      final rate = (data[_keyTaxRate] as num).toDouble();
      await _prefs.setDouble(_keyTaxRate, rate);
    }
    if (data.containsKey(_keyCloudBackupFrequency)) {
      await _prefs.setString(_keyCloudBackupFrequency, data[_keyCloudBackupFrequency]);
    }
    if (data.containsKey(_keyPrinterConnectionType)) {
      await _prefs.setString(_keyPrinterConnectionType, data[_keyPrinterConnectionType]);
    }
    if (data.containsKey(_keyPrinterPaperSize)) {
      await _prefs.setString(_keyPrinterPaperSize, data[_keyPrinterPaperSize]);
    }
    if (data.containsKey(_keyPrinterIpAddress)) {
      await _prefs.setString(_keyPrinterIpAddress, data[_keyPrinterIpAddress]);
    }
    if (data.containsKey(_keyPrinterPort)) {
      await _prefs.setInt(_keyPrinterPort, data[_keyPrinterPort]);
    }
    if (data.containsKey(_keySelectedPrinterName)) {
      await _prefs.setString(_keySelectedPrinterName, data[_keySelectedPrinterName]);
    }
    if (data.containsKey(_keyAutoPrintReceipt)) {
      final val = data[_keyAutoPrintReceipt];
      final bool autoPrint = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyAutoPrintReceipt, autoPrint);
    }
    if (data.containsKey(_keyAutoOpenCashDrawerOnCashStart)) {
      final val = data[_keyAutoOpenCashDrawerOnCashStart];
      final bool autoOpen = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyAutoOpenCashDrawerOnCashStart, autoOpen);
    }
    if (data.containsKey(_keyAutoOpenCashDrawerOnSaleComplete)) {
      final val = data[_keyAutoOpenCashDrawerOnSaleComplete];
      final bool autoOpen = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyAutoOpenCashDrawerOnSaleComplete, autoOpen);
    }
    if (data.containsKey(_keyCashDrawerTriggerType)) {
      await _prefs.setString(_keyCashDrawerTriggerType, data[_keyCashDrawerTriggerType]);
    }
    if (data.containsKey(_keyCashDrawerComPort)) {
      await _prefs.setString(_keyCashDrawerComPort, data[_keyCashDrawerComPort]);
    }
    if (data.containsKey(_keyReceiptTemplate)) {
      await _prefs.setString(_keyReceiptTemplate, data[_keyReceiptTemplate]);
    }
    if (data.containsKey(_keyReceiptLanguage)) {
      await _prefs.setString(_keyReceiptLanguage, data[_keyReceiptLanguage]);
    }
    if (data.containsKey(_keyShowReceiptLogo)) {
      final val = data[_keyShowReceiptLogo];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptLogo, show);
    }
    if (data.containsKey(_keyShowReceiptBarcode)) {
      final val = data[_keyShowReceiptBarcode];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptBarcode, show);
    }
    if (data.containsKey(_keyShowReceiptStandardPrice)) {
      final val = data[_keyShowReceiptStandardPrice];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptStandardPrice, show);
    }
    if (data.containsKey(_keyShowReceiptOurPrice)) {
      final val = data[_keyShowReceiptOurPrice];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptOurPrice, show);
    }
    if (data.containsKey(_keyShowReceiptDiscount)) {
      final val = data[_keyShowReceiptDiscount];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptDiscount, show);
    }
    if (data.containsKey(_keyShowReceiptTax)) {
      final val = data[_keyShowReceiptTax];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptTax, show);
    }
    if (data.containsKey(_keyShowReceiptPaymentDetails)) {
      final val = data[_keyShowReceiptPaymentDetails];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptPaymentDetails, show);
    }
    if (data.containsKey(_keyShowReceiptCashier)) {
      final val = data[_keyShowReceiptCashier];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptCashier, show);
    }
    if (data.containsKey(_keyShowReceiptCustomer)) {
      final val = data[_keyShowReceiptCustomer];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptCustomer, show);
    }
    if (data.containsKey(_keyShowReceiptProfit)) {
      final val = data[_keyShowReceiptProfit];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptProfit, show);
    }
    if (data.containsKey(_keyShowReceiptCostPrice)) {
      final val = data[_keyShowReceiptCostPrice];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptCostPrice, show);
    }
    
    // Refresh local state
    await init();
  }

  // Biometric Auth: Save last logged-in employee
  Future<void> saveLastEmployeeId(int employeeId) async {
    await _prefs.setInt(_keyLastEmployeeId, employeeId);
  }

  // Biometric Auth: Get last logged-in employee
  int? getLastEmployeeId() {
    return _prefs.getInt(_keyLastEmployeeId);
  }

  // Biometric Auth: Clear last employee (on logout)
  Future<void> clearLastEmployeeId() async {
    await _prefs.remove(_keyLastEmployeeId);
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(() {
  return AppSettingsNotifier();
});
