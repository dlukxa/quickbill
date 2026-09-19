import 'dart:convert';
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
  final bool showReceiptCostPrice;
  final bool? _hasSelectedLanguage;

  // ─── Sri Lanka VAT & Tax Settings ───
  final bool? _isVatEnabled;
  final bool? _isVatRegistered;
  final String? _taxIdentificationNumber; // TIN
  final String? _vatRegistrationNumber; // VAT Reg No
  final double? _defaultVatRate; // default 18.0
  final String? _vatPricingType; // 'inclusive' or 'exclusive'
  final String? _vatInvoiceMode; // 'normal' or 'tax_invoice'

  // ─── Thermal Receipt Printing Customization ───
  // Paper & Roll Dimensions
  final double? _printerPaperWidthMm;
  final bool? _isCustomPaperWidth;

  // Margins (in mm)
  final double? _receiptMarginLeftMm;
  final double? _receiptMarginRightMm;
  final double? _receiptMarginTopMm;
  final double? _receiptMarginBottomMm;

  // Typography & Font Sizes (in pt)
  final double? _receiptFontScale;
  final double? _receiptMainFontSize;
  final double? _receiptStoreNameFontSize;
  final double? _receiptProductNameFontSize;
  final double? _receiptQtyPriceFontSize;
  final double? _receiptSubtotalFontSize;
  final double? _receiptDiscountFontSize;
  final double? _receiptGrandTotalFontSize;
  final double? _receiptFooterFontSize;
  final double? _receiptLineSpacing;
  final bool? _receiptBoldText;

  // Layout & Alignment
  final String? _receiptHeaderAlignment; // 'left', 'center', 'right'
  final String? _receiptFooterAlignment; // 'left', 'center', 'right'
  final bool? _receiptWrapProductName;
  final double? _receiptItemSpacing;
  final double? _receiptHeaderSpacing;
  final double? _receiptFooterSpacing;
  final bool? _showReceiptAddress;
  final bool? _showReceiptPhone;
  final bool? _showReceiptDateTime;

  // Presets
  final String? _receiptActivePreset; // 'standard', 'large', 'extra_large', 'jumbo_2x', 'compact', 'custom'
  final String? _receiptCustomPresetsJson;

  bool get hasSelectedLanguage => _hasSelectedLanguage ?? false;
  bool get isVatEnabled => _isVatEnabled ?? false;
  bool get isVatRegistered => _isVatRegistered ?? false;
  String get taxIdentificationNumber => _taxIdentificationNumber ?? '';
  String get vatRegistrationNumber => _vatRegistrationNumber ?? '';
  double get defaultVatRate => _defaultVatRate ?? 18.0;
  String get vatPricingType => _vatPricingType ?? 'inclusive';
  String get vatInvoiceMode => _vatInvoiceMode ?? 'normal';

  double get printerPaperWidthMm => _printerPaperWidthMm ?? 80.0;
  bool get isCustomPaperWidth => _isCustomPaperWidth ?? false;
  double get receiptMarginLeftMm => _receiptMarginLeftMm ?? 3.0;
  double get receiptMarginRightMm => _receiptMarginRightMm ?? 3.0;
  double get receiptMarginTopMm => _receiptMarginTopMm ?? 4.0;
  double get receiptMarginBottomMm => _receiptMarginBottomMm ?? 6.0;
  double get receiptFontScale => _receiptFontScale ?? 1.0;
  double get receiptMainFontSize => _receiptMainFontSize ?? 12.0;
  double get receiptStoreNameFontSize => _receiptStoreNameFontSize ?? 18.0;
  double get receiptProductNameFontSize => _receiptProductNameFontSize ?? 12.0;
  double get receiptQtyPriceFontSize => _receiptQtyPriceFontSize ?? 11.0;
  double get receiptSubtotalFontSize => _receiptSubtotalFontSize ?? 12.0;
  double get receiptDiscountFontSize => _receiptDiscountFontSize ?? 13.0;
  double get receiptGrandTotalFontSize => _receiptGrandTotalFontSize ?? 17.0;
  double get receiptFooterFontSize => _receiptFooterFontSize ?? 11.0;
  double get receiptLineSpacing => _receiptLineSpacing ?? 1.25;
  bool get receiptBoldText => _receiptBoldText ?? false;
  String get receiptHeaderAlignment => _receiptHeaderAlignment ?? 'center';
  String get receiptFooterAlignment => _receiptFooterAlignment ?? 'center';
  bool get receiptWrapProductName => _receiptWrapProductName ?? true;
  double get receiptItemSpacing => _receiptItemSpacing ?? 4.0;
  double get receiptHeaderSpacing => _receiptHeaderSpacing ?? 8.0;
  double get receiptFooterSpacing => _receiptFooterSpacing ?? 8.0;
  bool get showReceiptAddress => _showReceiptAddress ?? true;
  bool get showReceiptPhone => _showReceiptPhone ?? true;
  bool get showReceiptDateTime => _showReceiptDateTime ?? true;
  String get receiptActivePreset => _receiptActivePreset ?? 'standard';
  String get receiptCustomPresetsJson => _receiptCustomPresetsJson ?? '{}';

  bool get is58mm => (!isCustomPaperWidth && printerPaperSize == '58mm');
  double get effectivePaperWidthMm =>
      isCustomPaperWidth ? printerPaperWidthMm : (printerPaperSize == '58mm' ? 58.0 : 80.0);
  double get effectiveReceiptWidthPx => isCustomPaperWidth
      ? (printerPaperWidthMm * 7.2).clamp(250.0, 900.0)
      : (printerPaperSize == '58mm' ? 384.0 : 576.0);
  double get marginLeftPx => receiptMarginLeftMm * 7.2;
  double get marginRightPx => receiptMarginRightMm * 7.2;
  double get marginTopPx => receiptMarginTopMm * 7.2;
  double get marginBottomPx => receiptMarginBottomMm * 7.2;

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
    bool isVatEnabled = false,
    bool isVatRegistered = false,
    String taxIdentificationNumber = '',
    String vatRegistrationNumber = '',
    double defaultVatRate = 18.0,
    String vatPricingType = 'inclusive',
    String vatInvoiceMode = 'normal',
    double printerPaperWidthMm = 80.0,
    bool isCustomPaperWidth = false,
    double receiptMarginLeftMm = 3.0,
    double receiptMarginRightMm = 3.0,
    double receiptMarginTopMm = 4.0,
    double receiptMarginBottomMm = 6.0,
    double receiptFontScale = 1.0,
    double receiptMainFontSize = 12.0,
    double receiptStoreNameFontSize = 18.0,
    double receiptProductNameFontSize = 12.0,
    double receiptQtyPriceFontSize = 11.0,
    double receiptSubtotalFontSize = 12.0,
    double receiptDiscountFontSize = 13.0,
    double receiptGrandTotalFontSize = 17.0,
    double receiptFooterFontSize = 11.0,
    double receiptLineSpacing = 1.25,
    bool receiptBoldText = false,
    String receiptHeaderAlignment = 'center',
    String receiptFooterAlignment = 'center',
    bool receiptWrapProductName = true,
    double receiptItemSpacing = 4.0,
    double receiptHeaderSpacing = 8.0,
    double receiptFooterSpacing = 8.0,
    bool showReceiptAddress = true,
    bool showReceiptPhone = true,
    bool showReceiptDateTime = true,
    String receiptActivePreset = 'standard',
    String receiptCustomPresetsJson = '{}',
    bool? hasSelectedLanguage,
  })  : _isVatEnabled = isVatEnabled,
        _isVatRegistered = isVatRegistered,
        _taxIdentificationNumber = taxIdentificationNumber,
        _vatRegistrationNumber = vatRegistrationNumber,
        _defaultVatRate = defaultVatRate,
        _vatPricingType = vatPricingType,
        _vatInvoiceMode = vatInvoiceMode,
        _printerPaperWidthMm = printerPaperWidthMm,
        _isCustomPaperWidth = isCustomPaperWidth,
        _receiptMarginLeftMm = receiptMarginLeftMm,
        _receiptMarginRightMm = receiptMarginRightMm,
        _receiptMarginTopMm = receiptMarginTopMm,
        _receiptMarginBottomMm = receiptMarginBottomMm,
        _receiptFontScale = receiptFontScale,
        _receiptMainFontSize = receiptMainFontSize,
        _receiptStoreNameFontSize = receiptStoreNameFontSize,
        _receiptProductNameFontSize = receiptProductNameFontSize,
        _receiptQtyPriceFontSize = receiptQtyPriceFontSize,
        _receiptSubtotalFontSize = receiptSubtotalFontSize,
        _receiptDiscountFontSize = receiptDiscountFontSize,
        _receiptGrandTotalFontSize = receiptGrandTotalFontSize,
        _receiptFooterFontSize = receiptFooterFontSize,
        _receiptLineSpacing = receiptLineSpacing,
        _receiptBoldText = receiptBoldText,
        _receiptHeaderAlignment = receiptHeaderAlignment,
        _receiptFooterAlignment = receiptFooterAlignment,
        _receiptWrapProductName = receiptWrapProductName,
        _receiptItemSpacing = receiptItemSpacing,
        _receiptHeaderSpacing = receiptHeaderSpacing,
        _receiptFooterSpacing = receiptFooterSpacing,
        _showReceiptAddress = showReceiptAddress,
        _showReceiptPhone = showReceiptPhone,
        _showReceiptDateTime = showReceiptDateTime,
        _receiptActivePreset = receiptActivePreset,
        _receiptCustomPresetsJson = receiptCustomPresetsJson,
        _hasSelectedLanguage = hasSelectedLanguage;

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
    bool clearShopLogo = false,
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
    double? printerPaperWidthMm,
    bool? isCustomPaperWidth,
    double? receiptMarginLeftMm,
    double? receiptMarginRightMm,
    double? receiptMarginTopMm,
    double? receiptMarginBottomMm,
    double? receiptFontScale,
    double? receiptMainFontSize,
    double? receiptStoreNameFontSize,
    double? receiptProductNameFontSize,
    double? receiptQtyPriceFontSize,
    double? receiptSubtotalFontSize,
    double? receiptDiscountFontSize,
    double? receiptGrandTotalFontSize,
    double? receiptFooterFontSize,
    double? receiptLineSpacing,
    bool? receiptBoldText,
    String? receiptHeaderAlignment,
    String? receiptFooterAlignment,
    bool? receiptWrapProductName,
    double? receiptItemSpacing,
    double? receiptHeaderSpacing,
    double? receiptFooterSpacing,
    bool? showReceiptAddress,
    bool? showReceiptPhone,
    bool? showReceiptDateTime,
    String? receiptActivePreset,
    String? receiptCustomPresetsJson,
    bool? hasSelectedLanguage,
    bool? isVatEnabled,
    bool? isVatRegistered,
    String? taxIdentificationNumber,
    String? vatRegistrationNumber,
    double? defaultVatRate,
    String? vatPricingType,
    String? vatInvoiceMode,
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
      shopLogoUrl: clearShopLogo ? null : (shopLogoUrl ?? this.shopLogoUrl),
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
      isVatEnabled: isVatEnabled ?? this.isVatEnabled,
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      taxIdentificationNumber: taxIdentificationNumber ?? this.taxIdentificationNumber,
      vatRegistrationNumber: vatRegistrationNumber ?? this.vatRegistrationNumber,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      vatPricingType: vatPricingType ?? this.vatPricingType,
      vatInvoiceMode: vatInvoiceMode ?? this.vatInvoiceMode,
      printerPaperWidthMm: printerPaperWidthMm ?? this.printerPaperWidthMm,
      isCustomPaperWidth: isCustomPaperWidth ?? this.isCustomPaperWidth,
      receiptMarginLeftMm: receiptMarginLeftMm ?? this.receiptMarginLeftMm,
      receiptMarginRightMm: receiptMarginRightMm ?? this.receiptMarginRightMm,
      receiptMarginTopMm: receiptMarginTopMm ?? this.receiptMarginTopMm,
      receiptMarginBottomMm: receiptMarginBottomMm ?? this.receiptMarginBottomMm,
      receiptFontScale: receiptFontScale ?? this.receiptFontScale,
      receiptMainFontSize: receiptMainFontSize ?? this.receiptMainFontSize,
      receiptStoreNameFontSize: receiptStoreNameFontSize ?? this.receiptStoreNameFontSize,
      receiptProductNameFontSize: receiptProductNameFontSize ?? this.receiptProductNameFontSize,
      receiptQtyPriceFontSize: receiptQtyPriceFontSize ?? this.receiptQtyPriceFontSize,
      receiptSubtotalFontSize: receiptSubtotalFontSize ?? this.receiptSubtotalFontSize,
      receiptDiscountFontSize: receiptDiscountFontSize ?? this.receiptDiscountFontSize,
      receiptGrandTotalFontSize: receiptGrandTotalFontSize ?? this.receiptGrandTotalFontSize,
      receiptFooterFontSize: receiptFooterFontSize ?? this.receiptFooterFontSize,
      receiptLineSpacing: receiptLineSpacing ?? this.receiptLineSpacing,
      receiptBoldText: receiptBoldText ?? this.receiptBoldText,
      receiptHeaderAlignment: receiptHeaderAlignment ?? this.receiptHeaderAlignment,
      receiptFooterAlignment: receiptFooterAlignment ?? this.receiptFooterAlignment,
      receiptWrapProductName: receiptWrapProductName ?? this.receiptWrapProductName,
      receiptItemSpacing: receiptItemSpacing ?? this.receiptItemSpacing,
      receiptHeaderSpacing: receiptHeaderSpacing ?? this.receiptHeaderSpacing,
      receiptFooterSpacing: receiptFooterSpacing ?? this.receiptFooterSpacing,
      showReceiptAddress: showReceiptAddress ?? this.showReceiptAddress,
      showReceiptPhone: showReceiptPhone ?? this.showReceiptPhone,
      showReceiptDateTime: showReceiptDateTime ?? this.showReceiptDateTime,
      receiptActivePreset: receiptActivePreset ?? this.receiptActivePreset,
      receiptCustomPresetsJson: receiptCustomPresetsJson ?? this.receiptCustomPresetsJson,
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
      'is_vat_enabled': isVatEnabled,
      'is_vat_registered': isVatRegistered,
      'tax_identification_number': taxIdentificationNumber,
      'vat_registration_number': vatRegistrationNumber,
      'default_vat_rate': defaultVatRate,
      'vat_pricing_type': vatPricingType,
      'vat_invoice_mode': vatInvoiceMode,
      'printer_paper_width_mm': printerPaperWidthMm,
      'is_custom_paper_width': isCustomPaperWidth,
      'receipt_margin_left_mm': receiptMarginLeftMm,
      'receipt_margin_right_mm': receiptMarginRightMm,
      'receipt_margin_top_mm': receiptMarginTopMm,
      'receipt_margin_bottom_mm': receiptMarginBottomMm,
      'receipt_font_scale': receiptFontScale,
      'receipt_main_font_size': receiptMainFontSize,
      'receipt_store_name_font_size': receiptStoreNameFontSize,
      'receipt_product_name_font_size': receiptProductNameFontSize,
      'receipt_qty_price_font_size': receiptQtyPriceFontSize,
      'receipt_subtotal_font_size': receiptSubtotalFontSize,
      'receipt_discount_font_size': receiptDiscountFontSize,
      'receipt_grand_total_font_size': receiptGrandTotalFontSize,
      'receipt_footer_font_size': receiptFooterFontSize,
      'receipt_line_spacing': receiptLineSpacing,
      'receipt_bold_text': receiptBoldText,
      'receipt_header_alignment': receiptHeaderAlignment,
      'receipt_footer_alignment': receiptFooterAlignment,
      'receipt_wrap_product_name': receiptWrapProductName,
      'receipt_item_spacing': receiptItemSpacing,
      'receipt_header_spacing': receiptHeaderSpacing,
      'receipt_footer_spacing': receiptFooterSpacing,
      'show_receipt_address': showReceiptAddress,
      'show_receipt_phone': showReceiptPhone,
      'show_receipt_date_time': showReceiptDateTime,
      'receipt_active_preset': receiptActivePreset,
      'receipt_custom_presets_json': receiptCustomPresetsJson,
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
  static const String _keyHasSelectedLanguage = 'has_selected_language';
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
  static const String _keyIsVatEnabled = 'is_vat_enabled';
  static const String _keyIsVatRegistered = 'is_vat_registered';
  static const String _keyTaxIdentificationNumber = 'tax_identification_number';
  static const String _keyVatRegistrationNumber = 'vat_registration_number';
  static const String _keyDefaultVatRate = 'default_vat_rate';
  static const String _keyVatPricingType = 'vat_pricing_type';
  static const String _keyVatInvoiceMode = 'vat_invoice_mode';
  static const String _keyPrinterPaperWidthMm = 'printer_paper_width_mm';
  static const String _keyIsCustomPaperWidth = 'is_custom_paper_width';
  static const String _keyReceiptMarginLeftMm = 'receipt_margin_left_mm';
  static const String _keyReceiptMarginRightMm = 'receipt_margin_right_mm';
  static const String _keyReceiptMarginTopMm = 'receipt_margin_top_mm';
  static const String _keyReceiptMarginBottomMm = 'receipt_margin_bottom_mm';
  static const String _keyReceiptFontScale = 'receipt_font_scale';
  static const String _keyReceiptMainFontSize = 'receipt_main_font_size';
  static const String _keyReceiptStoreNameFontSize = 'receipt_store_name_font_size';
  static const String _keyReceiptProductNameFontSize = 'receipt_product_name_font_size';
  static const String _keyReceiptQtyPriceFontSize = 'receipt_qty_price_font_size';
  static const String _keyReceiptSubtotalFontSize = 'receipt_subtotal_font_size';
  static const String _keyReceiptDiscountFontSize = 'receipt_discount_font_size';
  static const String _keyReceiptGrandTotalFontSize = 'receipt_grand_total_font_size';
  static const String _keyReceiptFooterFontSize = 'receipt_footer_font_size';
  static const String _keyReceiptLineSpacing = 'receipt_line_spacing';
  static const String _keyReceiptBoldText = 'receipt_bold_text';
  static const String _keyReceiptHeaderAlignment = 'receipt_header_alignment';
  static const String _keyReceiptFooterAlignment = 'receipt_footer_alignment';
  static const String _keyReceiptWrapProductName = 'receipt_wrap_product_name';
  static const String _keyReceiptItemSpacing = 'receipt_item_spacing';
  static const String _keyReceiptHeaderSpacing = 'receipt_header_spacing';
  static const String _keyReceiptFooterSpacing = 'receipt_footer_spacing';
  static const String _keyShowReceiptAddress = 'show_receipt_address';
  static const String _keyShowReceiptPhone = 'show_receipt_phone';
  static const String _keyShowReceiptDateTime = 'show_receipt_date_time';
  static const String _keyReceiptActivePreset = 'receipt_active_preset';
  static const String _keyReceiptCustomPresetsJson = 'receipt_custom_presets_json';

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
      isVatEnabled: false,
      isVatRegistered: false,
      taxIdentificationNumber: '',
      vatRegistrationNumber: '',
      defaultVatRate: 18.0,
      vatPricingType: 'inclusive',
      vatInvoiceMode: 'normal',
      printerPaperWidthMm: 80.0,
      isCustomPaperWidth: false,
      receiptMarginLeftMm: 3.0,
      receiptMarginRightMm: 3.0,
      receiptMarginTopMm: 4.0,
      receiptMarginBottomMm: 6.0,
      receiptFontScale: 1.0,
      receiptMainFontSize: 12.0,
      receiptStoreNameFontSize: 18.0,
      receiptProductNameFontSize: 12.0,
      receiptQtyPriceFontSize: 11.0,
      receiptSubtotalFontSize: 12.0,
      receiptDiscountFontSize: 13.0,
      receiptGrandTotalFontSize: 17.0,
      receiptFooterFontSize: 11.0,
      receiptLineSpacing: 1.25,
      receiptBoldText: false,
      receiptHeaderAlignment: 'center',
      receiptFooterAlignment: 'center',
      receiptWrapProductName: true,
      receiptItemSpacing: 4.0,
      receiptHeaderSpacing: 8.0,
      receiptFooterSpacing: 8.0,
      showReceiptAddress: true,
      showReceiptPhone: true,
      showReceiptDateTime: true,
      receiptActivePreset: 'standard',
      receiptCustomPresetsJson: '{}',
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
      isVatEnabled: _prefs.getBool(_keyIsVatEnabled) ?? false,
      isVatRegistered: _prefs.getBool(_keyIsVatRegistered) ?? false,
      taxIdentificationNumber: _prefs.getString(_keyTaxIdentificationNumber) ?? '',
      vatRegistrationNumber: _prefs.getString(_keyVatRegistrationNumber) ?? '',
      defaultVatRate: _prefs.getDouble(_keyDefaultVatRate) ?? 18.0,
      vatPricingType: _prefs.getString(_keyVatPricingType) ?? 'inclusive',
      vatInvoiceMode: _prefs.getString(_keyVatInvoiceMode) ?? 'normal',
      printerPaperWidthMm: _prefs.getDouble(_keyPrinterPaperWidthMm) ?? 80.0,
      isCustomPaperWidth: _prefs.getBool(_keyIsCustomPaperWidth) ?? false,
      receiptMarginLeftMm: _prefs.getDouble(_keyReceiptMarginLeftMm) ?? 3.0,
      receiptMarginRightMm: _prefs.getDouble(_keyReceiptMarginRightMm) ?? 3.0,
      receiptMarginTopMm: _prefs.getDouble(_keyReceiptMarginTopMm) ?? 4.0,
      receiptMarginBottomMm: _prefs.getDouble(_keyReceiptMarginBottomMm) ?? 6.0,
      receiptFontScale: _prefs.getDouble(_keyReceiptFontScale) ?? 1.0,
      receiptMainFontSize: _prefs.getDouble(_keyReceiptMainFontSize) ?? 12.0,
      receiptStoreNameFontSize: _prefs.getDouble(_keyReceiptStoreNameFontSize) ?? 18.0,
      receiptProductNameFontSize: _prefs.getDouble(_keyReceiptProductNameFontSize) ?? 12.0,
      receiptQtyPriceFontSize: _prefs.getDouble(_keyReceiptQtyPriceFontSize) ?? 11.0,
      receiptSubtotalFontSize: _prefs.getDouble(_keyReceiptSubtotalFontSize) ?? 12.0,
      receiptDiscountFontSize: _prefs.getDouble(_keyReceiptDiscountFontSize) ?? 13.0,
      receiptGrandTotalFontSize: _prefs.getDouble(_keyReceiptGrandTotalFontSize) ?? 17.0,
      receiptFooterFontSize: _prefs.getDouble(_keyReceiptFooterFontSize) ?? 11.0,
      receiptLineSpacing: _prefs.getDouble(_keyReceiptLineSpacing) ?? 1.25,
      receiptBoldText: _prefs.getBool(_keyReceiptBoldText) ?? false,
      receiptHeaderAlignment: _prefs.getString(_keyReceiptHeaderAlignment) ?? 'center',
      receiptFooterAlignment: _prefs.getString(_keyReceiptFooterAlignment) ?? 'center',
      receiptWrapProductName: _prefs.getBool(_keyReceiptWrapProductName) ?? true,
      receiptItemSpacing: _prefs.getDouble(_keyReceiptItemSpacing) ?? 4.0,
      receiptHeaderSpacing: _prefs.getDouble(_keyReceiptHeaderSpacing) ?? 8.0,
      receiptFooterSpacing: _prefs.getDouble(_keyReceiptFooterSpacing) ?? 8.0,
      showReceiptAddress: _prefs.getBool(_keyShowReceiptAddress) ?? true,
      showReceiptPhone: _prefs.getBool(_keyShowReceiptPhone) ?? true,
      showReceiptDateTime: _prefs.getBool(_keyShowReceiptDateTime) ?? true,
      receiptActivePreset: _prefs.getString(_keyReceiptActivePreset) ?? 'standard',
      receiptCustomPresetsJson: _prefs.getString(_keyReceiptCustomPresetsJson) ?? '{}',
      hasSelectedLanguage: _prefs.getBool(_keyHasSelectedLanguage) ?? (_prefs.getString(_keyLanguageCode) != null),
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
      state = state.copyWith(shopLogoUrl: url);
    } else {
      await _prefs.remove(_keyShopLogoUrl);
      state = state.copyWith(clearShopLogo: true);
    }
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
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_keyLanguageCode, code);
    await prefs.setBool(_keyHasSelectedLanguage, true);
    state = state.copyWith(languageCode: code, hasSelectedLanguage: true);
    _syncToCloud();
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

  Future<void> updateVatSettings({
    bool? isVatEnabled,
    bool? isVatRegistered,
    String? taxIdentificationNumber,
    String? vatRegistrationNumber,
    double? defaultVatRate,
    String? vatPricingType,
    String? vatInvoiceMode,
  }) async {
    if (isVatEnabled != null) await _prefs.setBool(_keyIsVatEnabled, isVatEnabled);
    if (isVatRegistered != null) await _prefs.setBool(_keyIsVatRegistered, isVatRegistered);
    if (taxIdentificationNumber != null) await _prefs.setString(_keyTaxIdentificationNumber, taxIdentificationNumber.trim());
    if (vatRegistrationNumber != null) await _prefs.setString(_keyVatRegistrationNumber, vatRegistrationNumber.trim());
    if (defaultVatRate != null) await _prefs.setDouble(_keyDefaultVatRate, defaultVatRate);
    if (vatPricingType != null) await _prefs.setString(_keyVatPricingType, vatPricingType);
    if (vatInvoiceMode != null) await _prefs.setString(_keyVatInvoiceMode, vatInvoiceMode);

    state = state.copyWith(
      isVatEnabled: isVatEnabled ?? state.isVatEnabled,
      isVatRegistered: isVatRegistered ?? state.isVatRegistered,
      taxIdentificationNumber: taxIdentificationNumber?.trim() ?? state.taxIdentificationNumber,
      vatRegistrationNumber: vatRegistrationNumber?.trim() ?? state.vatRegistrationNumber,
      defaultVatRate: defaultVatRate ?? state.defaultVatRate,
      vatPricingType: vatPricingType ?? state.vatPricingType,
      vatInvoiceMode: vatInvoiceMode ?? state.vatInvoiceMode,
    );
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

  Future<void> updateReceiptPaper({
    required double widthMm,
    required bool isCustom,
    String? standardSize,
  }) async {
    await _prefs.setDouble(_keyPrinterPaperWidthMm, widthMm);
    await _prefs.setBool(_keyIsCustomPaperWidth, isCustom);
    if (standardSize != null) {
      await _prefs.setString(_keyPrinterPaperSize, standardSize);
    }
    state = state.copyWith(
      printerPaperWidthMm: widthMm,
      isCustomPaperWidth: isCustom,
      printerPaperSize: standardSize ?? state.printerPaperSize,
    );
    await _syncToCloud();
  }

  Future<void> updateReceiptMargins({
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) async {
    if (left != null) await _prefs.setDouble(_keyReceiptMarginLeftMm, left);
    if (right != null) await _prefs.setDouble(_keyReceiptMarginRightMm, right);
    if (top != null) await _prefs.setDouble(_keyReceiptMarginTopMm, top);
    if (bottom != null) await _prefs.setDouble(_keyReceiptMarginBottomMm, bottom);

    state = state.copyWith(
      receiptMarginLeftMm: left ?? state.receiptMarginLeftMm,
      receiptMarginRightMm: right ?? state.receiptMarginRightMm,
      receiptMarginTopMm: top ?? state.receiptMarginTopMm,
      receiptMarginBottomMm: bottom ?? state.receiptMarginBottomMm,
    );
    await _syncToCloud();
  }

  Future<void> updateReceiptFontScale(double scale) async {
    final clamped = scale.clamp(0.7, 3.0);
    await _prefs.setDouble(_keyReceiptFontScale, clamped);
    state = state.copyWith(receiptFontScale: clamped);
    await _syncToCloud();
  }

  Future<void> updateReceiptFontSizes({
    double? scale,
    double? main,
    double? storeName,
    double? productName,
    double? qtyPrice,
    double? subtotal,
    double? discount,
    double? grandTotal,
    double? footer,
    double? lineSpacing,
    bool? boldText,
  }) async {
    if (scale != null) await _prefs.setDouble(_keyReceiptFontScale, scale.clamp(0.7, 3.0));
    if (main != null) await _prefs.setDouble(_keyReceiptMainFontSize, main);
    if (storeName != null) await _prefs.setDouble(_keyReceiptStoreNameFontSize, storeName);
    if (productName != null) await _prefs.setDouble(_keyReceiptProductNameFontSize, productName);
    if (qtyPrice != null) await _prefs.setDouble(_keyReceiptQtyPriceFontSize, qtyPrice);
    if (subtotal != null) await _prefs.setDouble(_keyReceiptSubtotalFontSize, subtotal);
    if (discount != null) await _prefs.setDouble(_keyReceiptDiscountFontSize, discount);
    if (grandTotal != null) await _prefs.setDouble(_keyReceiptGrandTotalFontSize, grandTotal);
    if (footer != null) await _prefs.setDouble(_keyReceiptFooterFontSize, footer);
    if (lineSpacing != null) await _prefs.setDouble(_keyReceiptLineSpacing, lineSpacing);
    if (boldText != null) await _prefs.setBool(_keyReceiptBoldText, boldText);

    state = state.copyWith(
      receiptFontScale: scale ?? state.receiptFontScale,
      receiptMainFontSize: main ?? state.receiptMainFontSize,
      receiptStoreNameFontSize: storeName ?? state.receiptStoreNameFontSize,
      receiptProductNameFontSize: productName ?? state.receiptProductNameFontSize,
      receiptQtyPriceFontSize: qtyPrice ?? state.receiptQtyPriceFontSize,
      receiptSubtotalFontSize: subtotal ?? state.receiptSubtotalFontSize,
      receiptDiscountFontSize: discount ?? state.receiptDiscountFontSize,
      receiptGrandTotalFontSize: grandTotal ?? state.receiptGrandTotalFontSize,
      receiptFooterFontSize: footer ?? state.receiptFooterFontSize,
      receiptLineSpacing: lineSpacing ?? state.receiptLineSpacing,
      receiptBoldText: boldText ?? state.receiptBoldText,
    );
    await _syncToCloud();
  }

  Future<void> updateReceiptLayout({
    String? headerAlignment,
    String? footerAlignment,
    bool? wrapProductName,
    double? itemSpacing,
    double? headerSpacing,
    double? footerSpacing,
    bool? showAddress,
    bool? showPhone,
    bool? showDateTime,
    bool? showBarcode,
    bool? showCashier,
  }) async {
    if (headerAlignment != null) await _prefs.setString(_keyReceiptHeaderAlignment, headerAlignment);
    if (footerAlignment != null) await _prefs.setString(_keyReceiptFooterAlignment, footerAlignment);
    if (wrapProductName != null) await _prefs.setBool(_keyReceiptWrapProductName, wrapProductName);
    if (itemSpacing != null) await _prefs.setDouble(_keyReceiptItemSpacing, itemSpacing);
    if (headerSpacing != null) await _prefs.setDouble(_keyReceiptHeaderSpacing, headerSpacing);
    if (footerSpacing != null) await _prefs.setDouble(_keyReceiptFooterSpacing, footerSpacing);
    if (showAddress != null) await _prefs.setBool(_keyShowReceiptAddress, showAddress);
    if (showPhone != null) await _prefs.setBool(_keyShowReceiptPhone, showPhone);
    if (showDateTime != null) await _prefs.setBool(_keyShowReceiptDateTime, showDateTime);
    if (showBarcode != null) await _prefs.setBool(_keyShowReceiptBarcode, showBarcode);
    if (showCashier != null) await _prefs.setBool(_keyShowReceiptCashier, showCashier);

    state = state.copyWith(
      receiptHeaderAlignment: headerAlignment ?? state.receiptHeaderAlignment,
      receiptFooterAlignment: footerAlignment ?? state.receiptFooterAlignment,
      receiptWrapProductName: wrapProductName ?? state.receiptWrapProductName,
      receiptItemSpacing: itemSpacing ?? state.receiptItemSpacing,
      receiptHeaderSpacing: headerSpacing ?? state.receiptHeaderSpacing,
      receiptFooterSpacing: footerSpacing ?? state.receiptFooterSpacing,
      showReceiptAddress: showAddress ?? state.showReceiptAddress,
      showReceiptPhone: showPhone ?? state.showReceiptPhone,
      showReceiptDateTime: showDateTime ?? state.showReceiptDateTime,
      showReceiptBarcode: showBarcode ?? state.showReceiptBarcode,
      showReceiptCashier: showCashier ?? state.showReceiptCashier,
    );
    await _syncToCloud();
  }

  Future<void> applyReceiptPreset(String presetKey) async {
    if (presetKey == 'standard') {
      await updateReceiptPaper(widthMm: 80.0, isCustom: false, standardSize: '80mm');
      await updateReceiptMargins(left: 3.0, right: 3.0, top: 4.0, bottom: 6.0);
      await updateReceiptFontSizes(
        scale: 1.0,
        main: 12.0,
        storeName: 18.0,
        productName: 12.0,
        qtyPrice: 11.0,
        subtotal: 12.0,
        discount: 13.0,
        grandTotal: 17.0,
        footer: 11.0,
        lineSpacing: 1.25,
        boldText: false,
      );
      await updateReceiptLayout(
        headerAlignment: 'center',
        footerAlignment: 'center',
        wrapProductName: true,
        itemSpacing: 4.0,
        headerSpacing: 8.0,
        footerSpacing: 8.0,
      );
    } else if (presetKey == 'large') {
      await updateReceiptPaper(widthMm: 80.0, isCustom: false, standardSize: '80mm');
      await updateReceiptMargins(left: 2.0, right: 2.0, top: 4.0, bottom: 6.0);
      await updateReceiptFontSizes(
        scale: 1.3,
        main: 14.0,
        storeName: 22.0,
        productName: 14.0,
        qtyPrice: 13.0,
        subtotal: 14.0,
        discount: 15.0,
        grandTotal: 21.0,
        footer: 13.0,
        lineSpacing: 1.35,
        boldText: true,
      );
      await updateReceiptLayout(
        headerAlignment: 'center',
        footerAlignment: 'center',
        wrapProductName: true,
        itemSpacing: 6.0,
        headerSpacing: 10.0,
        footerSpacing: 10.0,
      );
    } else if (presetKey == 'extra_large' || presetKey == 'xl') {
      await updateReceiptPaper(widthMm: 80.0, isCustom: false, standardSize: '80mm');
      await updateReceiptMargins(left: 2.0, right: 2.0, top: 4.0, bottom: 6.0);
      await updateReceiptFontSizes(
        scale: 1.6,
        main: 16.0,
        storeName: 26.0,
        productName: 16.0,
        qtyPrice: 15.0,
        subtotal: 16.0,
        discount: 17.0,
        grandTotal: 25.0,
        footer: 14.0,
        lineSpacing: 1.35,
        boldText: true,
      );
      await updateReceiptLayout(
        headerAlignment: 'center',
        footerAlignment: 'center',
        wrapProductName: true,
        itemSpacing: 7.0,
        headerSpacing: 12.0,
        footerSpacing: 12.0,
      );
    } else if (presetKey == 'jumbo_2x' || presetKey == '2x') {
      await updateReceiptPaper(widthMm: 80.0, isCustom: false, standardSize: '80mm');
      await updateReceiptMargins(left: 1.5, right: 1.5, top: 4.0, bottom: 6.0);
      await updateReceiptFontSizes(
        scale: 2.0,
        main: 18.0,
        storeName: 30.0,
        productName: 19.0,
        qtyPrice: 17.0,
        subtotal: 18.0,
        discount: 19.0,
        grandTotal: 28.0,
        footer: 16.0,
        lineSpacing: 1.45,
        boldText: true,
      );
      await updateReceiptLayout(
        headerAlignment: 'center',
        footerAlignment: 'center',
        wrapProductName: true,
        itemSpacing: 8.0,
        headerSpacing: 14.0,
        footerSpacing: 14.0,
      );
    } else if (presetKey == 'compact') {
      await updateReceiptPaper(widthMm: 58.0, isCustom: false, standardSize: '58mm');
      await updateReceiptMargins(left: 1.5, right: 1.5, top: 2.0, bottom: 3.0);
      await updateReceiptFontSizes(
        scale: 0.95,
        main: 10.0,
        storeName: 15.0,
        productName: 10.5,
        qtyPrice: 9.5,
        subtotal: 10.5,
        discount: 11.0,
        grandTotal: 14.5,
        footer: 9.5,
        lineSpacing: 1.15,
        boldText: false,
      );
      await updateReceiptLayout(
        headerAlignment: 'center',
        footerAlignment: 'center',
        wrapProductName: false,
        itemSpacing: 2.5,
        headerSpacing: 4.0,
        footerSpacing: 4.0,
      );
    } else {
      // Check custom presets
      try {
        final Map<String, dynamic> customMap = jsonDecode(state.receiptCustomPresetsJson);
        if (customMap.containsKey(presetKey)) {
          final data = Map<String, dynamic>.from(customMap[presetKey]);
          if (data.containsKey('paper_width')) {
            await updateReceiptPaper(
              widthMm: (data['paper_width'] as num).toDouble(),
              isCustom: data['is_custom_paper'] ?? false,
              standardSize: data['paper_size'],
            );
          }
          await updateReceiptMargins(
            left: (data['margin_left'] as num?)?.toDouble(),
            right: (data['margin_right'] as num?)?.toDouble(),
            top: (data['margin_top'] as num?)?.toDouble(),
            bottom: (data['margin_bottom'] as num?)?.toDouble(),
          );
          await updateReceiptFontSizes(
            main: (data['main_font'] as num?)?.toDouble(),
            storeName: (data['store_name_font'] as num?)?.toDouble(),
            productName: (data['product_name_font'] as num?)?.toDouble(),
            qtyPrice: (data['qty_price_font'] as num?)?.toDouble(),
            subtotal: (data['subtotal_font'] as num?)?.toDouble(),
            discount: (data['discount_font'] as num?)?.toDouble(),
            grandTotal: (data['grand_total_font'] as num?)?.toDouble(),
            footer: (data['footer_font'] as num?)?.toDouble(),
            lineSpacing: (data['line_spacing'] as num?)?.toDouble(),
            boldText: data['bold_text'] as bool?,
          );
          await updateReceiptLayout(
            headerAlignment: data['header_alignment'] as String?,
            footerAlignment: data['footer_alignment'] as String?,
            wrapProductName: data['wrap_product_name'] as bool?,
            itemSpacing: (data['item_spacing'] as num?)?.toDouble(),
            headerSpacing: (data['header_spacing'] as num?)?.toDouble(),
            footerSpacing: (data['footer_spacing'] as num?)?.toDouble(),
            showAddress: data['show_address'] as bool?,
            showPhone: data['show_phone'] as bool?,
            showDateTime: data['show_date_time'] as bool?,
          );
        }
      } catch (e) {
        // Ignore custom preset decoding error
      }
    }
    await _prefs.setString(_keyReceiptActivePreset, presetKey);
    state = state.copyWith(receiptActivePreset: presetKey);
    await _syncToCloud();
  }

  Future<void> saveCustomReceiptPreset(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    Map<String, dynamic> customMap = {};
    try {
      customMap = Map<String, dynamic>.from(jsonDecode(state.receiptCustomPresetsJson));
    } catch (_) {}

    customMap[cleanName] = {
      'paper_width': state.printerPaperWidthMm,
      'is_custom_paper': state.isCustomPaperWidth,
      'paper_size': state.printerPaperSize,
      'margin_left': state.receiptMarginLeftMm,
      'margin_right': state.receiptMarginRightMm,
      'margin_top': state.receiptMarginTopMm,
      'margin_bottom': state.receiptMarginBottomMm,
      'main_font': state.receiptMainFontSize,
      'store_name_font': state.receiptStoreNameFontSize,
      'product_name_font': state.receiptProductNameFontSize,
      'qty_price_font': state.receiptQtyPriceFontSize,
      'subtotal_font': state.receiptSubtotalFontSize,
      'discount_font': state.receiptDiscountFontSize,
      'grand_total_font': state.receiptGrandTotalFontSize,
      'footer_font': state.receiptFooterFontSize,
      'line_spacing': state.receiptLineSpacing,
      'bold_text': state.receiptBoldText,
      'header_alignment': state.receiptHeaderAlignment,
      'footer_alignment': state.receiptFooterAlignment,
      'wrap_product_name': state.receiptWrapProductName,
      'item_spacing': state.receiptItemSpacing,
      'header_spacing': state.receiptHeaderSpacing,
      'footer_spacing': state.receiptFooterSpacing,
      'show_address': state.showReceiptAddress,
      'show_phone': state.showReceiptPhone,
      'show_date_time': state.showReceiptDateTime,
    };

    final jsonStr = jsonEncode(customMap);
    await _prefs.setString(_keyReceiptCustomPresetsJson, jsonStr);
    await _prefs.setString(_keyReceiptActivePreset, cleanName);
    state = state.copyWith(
      receiptCustomPresetsJson: jsonStr,
      receiptActivePreset: cleanName,
    );
    await _syncToCloud();
  }

  Future<void> deleteCustomReceiptPreset(String name) async {
    Map<String, dynamic> customMap = {};
    try {
      customMap = Map<String, dynamic>.from(jsonDecode(state.receiptCustomPresetsJson));
    } catch (_) {}

    customMap.remove(name);
    final jsonStr = jsonEncode(customMap);
    await _prefs.setString(_keyReceiptCustomPresetsJson, jsonStr);

    String newActive = state.receiptActivePreset;
    if (newActive == name) {
      newActive = 'standard';
      await _prefs.setString(_keyReceiptActivePreset, newActive);
    }

    state = state.copyWith(
      receiptCustomPresetsJson: jsonStr,
      receiptActivePreset: newActive,
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
    if (data.containsKey(_keyIsVatEnabled)) {
      final val = data[_keyIsVatEnabled];
      await _prefs.setBool(_keyIsVatEnabled, (val is bool) ? val : (val == 1 || val == 'true'));
    }
    if (data.containsKey(_keyIsVatRegistered)) {
      final val = data[_keyIsVatRegistered];
      await _prefs.setBool(_keyIsVatRegistered, (val is bool) ? val : (val == 1 || val == 'true'));
    }
    if (data.containsKey(_keyTaxIdentificationNumber)) {
      await _prefs.setString(_keyTaxIdentificationNumber, data[_keyTaxIdentificationNumber]?.toString() ?? '');
    }
    if (data.containsKey(_keyVatRegistrationNumber)) {
      await _prefs.setString(_keyVatRegistrationNumber, data[_keyVatRegistrationNumber]?.toString() ?? '');
    }
    if (data.containsKey(_keyDefaultVatRate)) {
      await _prefs.setDouble(_keyDefaultVatRate, (data[_keyDefaultVatRate] as num).toDouble());
    }
    if (data.containsKey(_keyVatPricingType)) {
      await _prefs.setString(_keyVatPricingType, data[_keyVatPricingType]?.toString() ?? 'inclusive');
    }
    if (data.containsKey(_keyVatInvoiceMode)) {
      await _prefs.setString(_keyVatInvoiceMode, data[_keyVatInvoiceMode]?.toString() ?? 'normal');
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
    if (data.containsKey(_keyPrinterPaperWidthMm)) {
      await _prefs.setDouble(_keyPrinterPaperWidthMm, (data[_keyPrinterPaperWidthMm] as num).toDouble());
    }
    if (data.containsKey(_keyIsCustomPaperWidth)) {
      final val = data[_keyIsCustomPaperWidth];
      final bool isCustom = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyIsCustomPaperWidth, isCustom);
    }
    if (data.containsKey(_keyReceiptMarginLeftMm)) {
      await _prefs.setDouble(_keyReceiptMarginLeftMm, (data[_keyReceiptMarginLeftMm] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptMarginRightMm)) {
      await _prefs.setDouble(_keyReceiptMarginRightMm, (data[_keyReceiptMarginRightMm] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptMarginTopMm)) {
      await _prefs.setDouble(_keyReceiptMarginTopMm, (data[_keyReceiptMarginTopMm] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptMarginBottomMm)) {
      await _prefs.setDouble(_keyReceiptMarginBottomMm, (data[_keyReceiptMarginBottomMm] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptMainFontSize)) {
      await _prefs.setDouble(_keyReceiptMainFontSize, (data[_keyReceiptMainFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptStoreNameFontSize)) {
      await _prefs.setDouble(_keyReceiptStoreNameFontSize, (data[_keyReceiptStoreNameFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptProductNameFontSize)) {
      await _prefs.setDouble(_keyReceiptProductNameFontSize, (data[_keyReceiptProductNameFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptQtyPriceFontSize)) {
      await _prefs.setDouble(_keyReceiptQtyPriceFontSize, (data[_keyReceiptQtyPriceFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptSubtotalFontSize)) {
      await _prefs.setDouble(_keyReceiptSubtotalFontSize, (data[_keyReceiptSubtotalFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptDiscountFontSize)) {
      await _prefs.setDouble(_keyReceiptDiscountFontSize, (data[_keyReceiptDiscountFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptGrandTotalFontSize)) {
      await _prefs.setDouble(_keyReceiptGrandTotalFontSize, (data[_keyReceiptGrandTotalFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptFooterFontSize)) {
      await _prefs.setDouble(_keyReceiptFooterFontSize, (data[_keyReceiptFooterFontSize] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptLineSpacing)) {
      await _prefs.setDouble(_keyReceiptLineSpacing, (data[_keyReceiptLineSpacing] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptBoldText)) {
      final val = data[_keyReceiptBoldText];
      final bool bold = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyReceiptBoldText, bold);
    }
    if (data.containsKey(_keyReceiptHeaderAlignment)) {
      await _prefs.setString(_keyReceiptHeaderAlignment, data[_keyReceiptHeaderAlignment]);
    }
    if (data.containsKey(_keyReceiptFooterAlignment)) {
      await _prefs.setString(_keyReceiptFooterAlignment, data[_keyReceiptFooterAlignment]);
    }
    if (data.containsKey(_keyReceiptWrapProductName)) {
      final val = data[_keyReceiptWrapProductName];
      final bool wrap = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyReceiptWrapProductName, wrap);
    }
    if (data.containsKey(_keyReceiptItemSpacing)) {
      await _prefs.setDouble(_keyReceiptItemSpacing, (data[_keyReceiptItemSpacing] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptHeaderSpacing)) {
      await _prefs.setDouble(_keyReceiptHeaderSpacing, (data[_keyReceiptHeaderSpacing] as num).toDouble());
    }
    if (data.containsKey(_keyReceiptFooterSpacing)) {
      await _prefs.setDouble(_keyReceiptFooterSpacing, (data[_keyReceiptFooterSpacing] as num).toDouble());
    }
    if (data.containsKey(_keyShowReceiptAddress)) {
      final val = data[_keyShowReceiptAddress];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptAddress, show);
    }
    if (data.containsKey(_keyShowReceiptPhone)) {
      final val = data[_keyShowReceiptPhone];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptPhone, show);
    }
    if (data.containsKey(_keyShowReceiptDateTime)) {
      final val = data[_keyShowReceiptDateTime];
      final bool show = (val is bool) ? val : (val == 1 || val == 'true');
      await _prefs.setBool(_keyShowReceiptDateTime, show);
    }
    if (data.containsKey(_keyReceiptActivePreset)) {
      await _prefs.setString(_keyReceiptActivePreset, data[_keyReceiptActivePreset]);
    }
    if (data.containsKey(_keyReceiptCustomPresetsJson)) {
      await _prefs.setString(_keyReceiptCustomPresetsJson, data[_keyReceiptCustomPresetsJson]);
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
