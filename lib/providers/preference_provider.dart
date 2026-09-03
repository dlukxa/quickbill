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
