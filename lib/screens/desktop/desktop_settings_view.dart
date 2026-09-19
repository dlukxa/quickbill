import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/theme.dart';
import '../../models/employee.dart';
import '../../providers/branch_provider.dart';
import '../../providers/business_modules_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/preference_provider.dart';
import 'package:printing/printing.dart';
import '../../services/backup_service.dart';
import '../../services/cash_drawer_service.dart';
import '../../services/export_service.dart';
import '../../services/local_media_storage_service.dart';
import '../../services/printing_service.dart';
import '../../services/sync_service.dart';
import '../../services/windows_update_service.dart';
import '../../widgets/update_dialog.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../utils/pos_l10n.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import '../../widgets/receipt/receipt_preview_dialog.dart';
import '../../widgets/store_logo_widget.dart';
import '../settings/receipt_print_settings_screen.dart';

/// Comprehensive tabbed desktop settings view
class DesktopSettingsView extends ConsumerStatefulWidget {
  const DesktopSettingsView({super.key});

  @override
  ConsumerState<DesktopSettingsView> createState() => _DesktopSettingsViewState();
}

class _DesktopSettingsViewState extends ConsumerState<DesktopSettingsView> {
  int _selectedTab = 0;

  // Controllers for Store Profile
  late TextEditingController _shopNameCtrl;
  late TextEditingController _shopPhoneCtrl;
  late TextEditingController _shopAddressCtrl;
  late TextEditingController _receiptFooterCtrl;

  // Controllers for Tax & Pricing
  late TextEditingController _taxRateCtrl;
  late TextEditingController _serviceChargeCtrl;
  late TextEditingController _lowStockCtrl;

  // Sri Lanka VAT & Tax Configuration
  late bool _isVatEnabled;
  late bool _isVatRegistered;
  late TextEditingController _tinCtrl;
  late TextEditingController _vatNumberCtrl;
  late TextEditingController _defaultVatRateCtrl;
  late String _vatPricingType;
  late String _vatInvoiceMode;

  // Controllers for Printer
  late TextEditingController _printerIpCtrl;
  late TextEditingController _printerPortCtrl;

  bool _isSyncing = false;
  String? _syncMessage;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _shopNameCtrl = TextEditingController(text: settings.shopName);
    _shopPhoneCtrl = TextEditingController(text: settings.shopPhone);
    _shopAddressCtrl = TextEditingController(text: settings.shopAddress);
    _receiptFooterCtrl = TextEditingController(text: settings.receiptFooter);

    _taxRateCtrl = TextEditingController(text: settings.taxRate.toString());
    _serviceChargeCtrl = TextEditingController(text: settings.serviceChargeRate.toString());
    _lowStockCtrl = TextEditingController(text: settings.lowStockThreshold.toString());

    _isVatEnabled = settings.isVatEnabled;
    _isVatRegistered = settings.isVatRegistered;
    _tinCtrl = TextEditingController(text: settings.taxIdentificationNumber);
    _vatNumberCtrl = TextEditingController(text: settings.vatRegistrationNumber);
    _defaultVatRateCtrl = TextEditingController(text: settings.defaultVatRate.toString());
    _vatPricingType = settings.vatPricingType;
    _vatInvoiceMode = settings.vatInvoiceMode;

    _printerIpCtrl = TextEditingController(text: settings.printerIpAddress);
    _printerPortCtrl = TextEditingController(text: settings.printerPort.toString());

    _loadSystemPrinters();
  }

  List<Printer> _systemPrinters = [];
  bool _loadingPrinters = false;

  Future<void> _loadSystemPrinters() async {
    if (!mounted) return;
    setState(() => _loadingPrinters = true);
    try {
      final printers = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _systemPrinters = printers;
          _loadingPrinters = false;
        });
      }
    } catch (e) {
      debugPrint('Error listing system printers: $e');
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _taxRateCtrl.dispose();
    _serviceChargeCtrl.dispose();
    _lowStockCtrl.dispose();
    _tinCtrl.dispose();
    _vatNumberCtrl.dispose();
    _defaultVatRateCtrl.dispose();
    _printerIpCtrl.dispose();
    _printerPortCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // Settings Navigation Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryGreen, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        posL10n.settingsTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    children: [
                      _buildNavItem(0, posL10n.storeProfileTab, Icons.storefront_rounded),
                      _buildNavItem(1, posL10n.printersHardwareTab, Icons.print_rounded),
                      _buildNavItem(2, posL10n.taxesChargesTab, Icons.percent_rounded),
                      _buildNavItem(3, posL10n.businessModulesTab, Icons.dashboard_customize_rounded),
                      _buildNavItem(4, posL10n.cloudSyncTab, Icons.cloud_sync_rounded),
                      _buildNavItem(5, posL10n.staffPermissionsTab, Icons.badge_rounded),
                      _buildNavItem(6, 'System & Updates', Icons.system_update_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(32),
              child: _buildSelectedTabContent(cardBg, borderColor, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryGreen : Colors.grey,
          size: 20,
        ),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppTheme.primaryGreen : null,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => setState(() => _selectedTab = index),
      ),
    );
  }

  Widget _buildSelectedTabContent(Color cardBg, Color borderColor, bool isDark) {
    switch (_selectedTab) {
      case 0: return _buildStoreProfileTab(cardBg, borderColor, isDark);
      case 1: return _buildPrintersTab(cardBg, borderColor, isDark);
      case 2: return _buildTaxesTab(cardBg, borderColor, isDark);
      case 3: return _buildModulesTab(cardBg, borderColor, isDark);
      case 4: return _buildSyncTab(cardBg, borderColor, isDark);
      case 5: return _buildStaffTab(cardBg, borderColor, isDark);
      case 6: return _buildSystemUpdateTab(cardBg, borderColor, isDark);
      default: return const SizedBox.shrink();
    }
  }

  // ==========================================
  // TAB 0: STORE PROFILE & RECEIPT BRANDING
  // ==========================================
  Widget _buildStoreProfileTab(Color cardBg, Color borderColor, bool isDark) {
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final notifier = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader(
            posL10n.storeProfileTab,
            posL10n.appInterfaceLanguageDesc,
          ),
          const SizedBox(height: 24),

          // 1. Store Logo Card
          _buildCard(cardBg, borderColor, [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Avatar / Preview Box
                StoreLogoWidget(
                  logoUrl: settings.shopLogoUrl,
                  size: 90,
                  borderRadius: 12,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.all(6),
                ),
                const SizedBox(width: 20),
                // Logo Info and Actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Store Logo (ආයතනයේ ලාංඡනය)',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (settings.shopLogoUrl != null && settings.shopLogoUrl!.isNotEmpty)
                                  ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (settings.shopLogoUrl != null && settings.shopLogoUrl!.isNotEmpty)
                                  ? 'Custom Logo Active'
                                  : 'Default Logo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (settings.shopLogoUrl != null && settings.shopLogoUrl!.isNotEmpty)
                                    ? AppTheme.primaryGreen
                                    : Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This logo appears on customer receipts (thermal & PDF), invoices, and the desktop application header. PNG or JPG recommended.',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                allowMultiple: false,
                              );
                              if (result != null && result.files.single.path != null) {
                                final sourceFile = File(result.files.single.path!);
                                try {
                                  final savedPath = await LocalMediaStorageService.instance
                                      .saveLocalImagePermanently(sourceFile, customPrefix: 'shop_logo');
                                  await notifier.updateShopLogo(savedPath);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Store logo updated successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to save logo: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Upload / Change Logo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          if (settings.shopLogoUrl != null && settings.shopLogoUrl!.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                await notifier.updateShopLogo(null);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Store logo removed. Using default template logo.')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              label: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _previewReceipt(settings),
                            icon: const Icon(Icons.receipt_long_rounded, size: 18),
                            label: const Text('Preview on Receipt'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Print Logo on Receipts (බිල්පතේ ලාංඡනය මුද්‍රණය කරන්න)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'When enabled, the logo is printed at the top of customer bills',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.showReceiptLogo,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showLogo: val),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 24),

          // 2. Business Info Card
          _buildCard(cardBg, borderColor, [
            Text(
              'Store Information',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'This information appears at the top and bottom of customer receipts',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SinglishTextField(
              controller: _shopNameCtrl,
              decoration: const InputDecoration(labelText: 'Store / Company Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shopPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Store Phone Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SinglishTextField(
              controller: _shopAddressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Business Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SinglishTextField(
              controller: _receiptFooterCtrl,
              decoration: const InputDecoration(labelText: 'Receipt Footer Thank-You Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await notifier.updateShopName(_shopNameCtrl.text.trim());
                await notifier.updateShopPhone(_shopPhoneCtrl.text.trim());
                await notifier.updateShopAddress(_shopAddressCtrl.text.trim());
                await notifier.updateReceiptFooter(_receiptFooterCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store profile saved successfully!')),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(posL10n.saveChanges, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // 2. Receipt Design Template Card
          _buildCard(cardBg, borderColor, [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt Design Template',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose the visual format for thermal printing and PDF receipts',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _previewReceipt(settings),
                  icon: const Icon(Icons.preview_rounded, size: 18),
                  label: const Text('Live Preview'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDesktopTemplateCard(
                    title: 'Template 2 — Sri Lankan Retail POS',
                    subtitle: 'Itemized superstore receipt layout with standard price, our price, customer savings & localized labels.',
                    badgeText: 'POPULAR / DEFAULT',
                    badgeColor: AppTheme.primaryGreen,
                    isSelected: settings.receiptTemplate == 'sri_lankan_retail',
                    onTap: () => notifier.updateReceiptTemplate('sri_lankan_retail'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDesktopTemplateCard(
                    title: 'Template 1 — QuickBill Classic',
                    subtitle: 'Compact 4-column POS slip (ITEM, QTY, PRICE, TOTAL) with prominent boxed totals.',
                    badgeText: 'CLASSIC',
                    badgeColor: Colors.blueGrey,
                    isSelected: settings.receiptTemplate == 'classic',
                    onTap: () => notifier.updateReceiptTemplate('classic'),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),

          // 3. Language & Paper Size Card
          _buildCard(cardBg, borderColor, [
            Text(
              posL10n.appInterfaceLanguage,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              posL10n.appInterfaceLanguageDesc,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // App UI Language
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              posL10n.appInterfaceLanguage,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: settings.languageCode,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English (English)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'si', child: Text('සිංහල (Sinhala)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'bn', child: Text('বাংলা (Bengali)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'dv', child: Text('ދިވެހි (Dhivehi)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) notifier.updateLanguage(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Receipt Language
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              posL10n.receiptLanguageTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: settings.receiptLanguage,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'si', child: Text('සිංහල (Sinhala) — Default', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'en', child: Text('English', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'bilingual', child: Text('ද්විභාෂා (Bilingual)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) notifier.updateReceiptLanguage(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Paper Size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.print_outlined, size: 18, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              posL10n.paperSizeTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: settings.printerPaperSize,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: '80mm', child: Text('80mm (Standard POS)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: '58mm', child: Text('58mm (Mobile Roll)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            notifier.updatePrinterPaperSize(val);
                            notifier.updateReceiptPaper(widthMm: val == '58mm' ? 58.0 : 80.0, isCustom: false);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Margins, Fonts & Live Preview', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReceiptPrintSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),

          // 4. Field Visibility Switches Card
          _buildCard(cardBg, borderColor, [
            Text(
              'Visible Receipt Fields',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Show or hide specific fields to match your retail business requirements',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Store Logo'),
                    subtitle: const Text('Print store logo at top of receipt'),
                    value: settings.showReceiptLogo,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showLogo: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('1D Barcode'),
                    subtitle: const Text('Print Code128 barcode at bottom'),
                    value: settings.showReceiptBarcode,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showBarcode: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Standard Price (සදාන් මිල)'),
                    subtitle: const Text('Show original / gross item price'),
                    value: settings.showReceiptStandardPrice,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showStandardPrice: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Our Price (අපේ මිල)'),
                    subtitle: const Text('Show discounted sale price'),
                    value: settings.showReceiptOurPrice,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showOurPrice: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Customer Savings (සම්පූර්ණ ලාභය)'),
                    subtitle: const Text('Display customer profit / total savings breakdown'),
                    value: settings.showReceiptDiscount,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showDiscount: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tax (VAT) Breakdown'),
                    subtitle: const Text('Show tax breakdown when applicable'),
                    value: settings.showReceiptTax,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showTax: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payment & Change Details'),
                    subtitle: const Text('Show cash received & change returned'),
                    value: settings.showReceiptPaymentDetails,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showPaymentDetails: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cashier Name'),
                    subtitle: const Text('Show cashier / operator name on slip'),
                    value: settings.showReceiptCashier,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showCashier: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Customer Details'),
                    subtitle: const Text('Show customer name and telephone'),
                    value: settings.showReceiptCustomer,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => notifier.updateReceiptToggles(showCustomer: val),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),

          // 5. Sensitive Merchant Internal Margins Card
          _buildCard(cardBg, borderColor, [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sensitive Merchant Margins: Keep disabled for customer receipts. Only enable for internal back-office audit slips.',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 24,
              children: [
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Cost Price (ගැනුම් මිල)'),
                    subtitle: const Text('Print product cost price per item'),
                    value: settings.showReceiptCostPrice,
                    activeThumbColor: Colors.amber.shade800,
                    onChanged: (val) => notifier.updateReceiptToggles(showCostPrice: val),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Business Profit (ව්‍යාපාරික ලාභය)'),
                    subtitle: const Text('Print business margin on receipt'),
                    value: settings.showReceiptProfit,
                    activeThumbColor: Colors.amber.shade800,
                    onChanged: (val) => notifier.updateReceiptToggles(showProfit: val),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 24),

          // 6. Test Print Button
          ElevatedButton.icon(
            onPressed: () => _previewReceipt(settings),
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            label: const Text('Preview & Test Print Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PRINTERS & HARDWARE
  // ==========================================
  Widget _buildPrintersTab(Color cardBg, Color borderColor, bool isDark) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader('Printers & POS Hardware', 'Thermal receipt printer (58mm/80mm), cash drawer & auto-print'),
          const SizedBox(height: 24),
          _buildCard(cardBg, borderColor, [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thermal Paper Width & Receipt Margins', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Supports 80mm, 58mm & custom roll widths with mm margins, font scaling, and zero A4 paper waste',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Print Settings & Live Roll Preview'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReceiptPrintSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildPaperSizeOption('80mm (Standard POS)', '80mm', settings.printerPaperSize == '80mm' && !settings.isCustomPaperWidth, () {
                  notifier.updatePrinterPaperSize('80mm');
                  notifier.updateReceiptPaper(widthMm: 80.0, isCustom: false);
                }),
                const SizedBox(width: 16),
                _buildPaperSizeOption('58mm (Compact Mobile)', '58mm', settings.printerPaperSize == '58mm' && !settings.isCustomPaperWidth, () {
                  notifier.updatePrinterPaperSize('58mm');
                  notifier.updateReceiptPaper(widthMm: 58.0, isCustom: false);
                }),
                if (settings.isCustomPaperWidth) ...[
                  const SizedBox(width: 16),
                  _buildPaperSizeOption('Custom (${settings.effectivePaperWidthMm.toInt()}mm)', 'custom', true, () {}),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Text('Printer Connection Type', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings.printerConnectionType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System Printer (Windows/macOS Print Dialog / Driver)')),
                DropdownMenuItem(value: 'network', child: Text('Network / LAN ESC-POS Thermal Printer (Ethernet/WiFi IP)')),
                DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth ESC-POS Printer')),
              ],
              onChanged: (val) {
                if (val != null) notifier.updatePrinterConnectionType(val);
              },
            ),
            if (settings.printerConnectionType == 'system') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _systemPrinters.any((p) => p.name == settings.selectedPrinterName)
                          ? settings.selectedPrinterName
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Installed POS / Windows Thermal Printer',
                        border: OutlineInputBorder(),
                        helperText: 'Select your thermal printer for direct printing without print dialogs',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('System Default / Prompt with Dialog'),
                        ),
                        ..._systemPrinters.map((p) => DropdownMenuItem<String?>(
                          value: p.name,
                          child: Text('${p.name}${p.isDefault ? ' (Default)' : ''}'),
                        )),
                      ],
                      onChanged: (val) {
                        notifier.updateSelectedPrinterName(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    tooltip: 'Refresh Printers',
                    icon: _loadingPrinters
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                    onPressed: _loadSystemPrinters,
                  ),
                ],
              ),
            ],
            if (settings.printerConnectionType == 'network') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _printerIpCtrl,
                      decoration: const InputDecoration(labelText: 'Printer IP Address (e.g. 192.168.1.100)', border: OutlineInputBorder()),
                      onChanged: (val) => notifier.updatePrinterNetworkConfig(ip: val, port: int.tryParse(_printerPortCtrl.text) ?? 9100),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _printerPortCtrl,
                      decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                      onChanged: (val) => notifier.updatePrinterNetworkConfig(ip: _printerIpCtrl.text, port: int.tryParse(val) ?? 9100),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Automation toggles
            SwitchListTile(
              title: const Text('Auto-Print Receipt on Sale Complete', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Automatically triggers receipt print as soon as payment is confirmed'),
              value: settings.autoPrintReceipt,
              onChanged: (val) => notifier.updateAutoPrintReceipt(val),
            ),
            SwitchListTile(
              title: const Text('Kick Cash Drawer on Cash Sale', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Sends pulse signal to open connected cash drawer automatically'),
              value: settings.autoOpenCashDrawerOnSaleComplete,
              onChanged: (val) => notifier.updateAutoOpenCashDrawerOnSaleComplete(val),
            ),
            const SizedBox(height: 24),

            // Test Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      if (settings.printerConnectionType == 'network') {
                        final res = await PrintingService.instance.testNetworkPrinter(
                          ip: settings.printerIpAddress,
                          port: settings.printerPort,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.success ? AppTheme.primaryGreen : Colors.red,
                            ),
                          );
                        }
                      } else {
                        final testSale = Sale(
                          billNumber: 'INV000001',
                          total: 145.0,
                          discount: 5.0,
                          itemsCount: 1,
                          paymentMethod: 'cash',
                          cashierName: 'Harshana',
                          customerName: 'Kusal Mendis',
                          customerPhone: '077 123 4567',
                          createdAt: DateTime.now(),
                          notes: 'Cash: 200.00\nChange: 55.00',
                        );
                        final sampleItems = [
                          SaleItem(
                            saleId: 0,
                            productId: 0,
                            productName: 'කිරි තේ (Milk Tea)',
                            quantity: 1,
                            unitPrice: 150.0,
                            costPrice: 85.0,
                            discount: 5.0,
                            total: 145.0,
                          ),
                        ];
                        await PrintingService.instance.printReceiptUnified(
                          testSale,
                          sampleItems,
                          settings,
                          cashReceived: 200.0,
                          change: 55.0,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Test print failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Test Thermal Print'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final res = await CashDrawerService.instance.openCashDrawer(settings, isManual: true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.success ? 'Cash drawer command sent!' : res.message),
                            backgroundColor: res.success ? AppTheme.primaryGreen : Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cash drawer error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.point_of_sale_outlined),
                  label: const Text('Test Cash Drawer Kick'),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPaperSizeOption(String label, String value, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey,
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: TAXES & CHARGES
  // ==========================================
  Widget _buildTaxesTab(Color cardBg, Color borderColor, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader(
            'Sri Lanka VAT & Tax Configuration',
            'Configure VAT registration, TIN, 18% standard rate, pricing models (inclusive/exclusive), and invoice modes',
          ),
          const SizedBox(height: 24),

          // ─── CARD 1: SRI LANKA VAT SYSTEM ───
          _buildCard(cardBg, borderColor, [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Value Added Tax (VAT) System',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Compliant with Sri Lanka Inland Revenue Department (IRD) specifications',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // VAT Enabled Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primaryGreen,
              title: const Text('Enable VAT / Tax System', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Calculate and record VAT across product inventory, POS register, and receipts', style: TextStyle(fontSize: 12)),
              value: _isVatEnabled,
              onChanged: (val) => setState(() => _isVatEnabled = val),
            ),
            const SizedBox(height: 8),

            // VAT Registered Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primaryGreen,
              title: const Text('VAT Registered Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Turn ON if business has an official VAT Registration Number from IRD', style: TextStyle(fontSize: 12)),
              value: _isVatRegistered,
              onChanged: (val) => setState(() => _isVatRegistered = val),
            ),
            const SizedBox(height: 16),

            // Tax Numbers Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Taxpayer Identification Number (TIN)',
                      hintText: 'e.g. 102345678',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _vatNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'VAT Registration Number',
                      hintText: 'e.g. 102345678-7000',
                      prefixIcon: Icon(Icons.receipt_long_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Default VAT Rate & Quick Selection Chips
            Text('Default VAT Rate (%)', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155))),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _defaultVatRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '18.0',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      _taxRateCtrl.text = val;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.flash_on_rounded, size: 14, color: AppTheme.primaryGreen),
                      label: const Text('18% (Standard Rate)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _defaultVatRateCtrl.text = '18.0';
                          _taxRateCtrl.text = '18.0';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('0% (Zero-Rated)', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _defaultVatRateCtrl.text = '0.0';
                          _taxRateCtrl.text = '0.0';
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('8% (Simplified)', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _defaultVatRateCtrl.text = '8.0';
                          _taxRateCtrl.text = '8.0';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pricing Model (Inclusive vs Exclusive)
            Text('Pricing Architecture', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    activeColor: AppTheme.primaryGreen,
                    title: const Text('VAT-Inclusive Pricing (Recommended for Retail & Supermarkets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Catalog and shelf prices already include VAT. Tax is backed out cleanly without price inflation at checkout.', style: TextStyle(fontSize: 12)),
                    value: 'inclusive',
                    groupValue: _vatPricingType,
                    onChanged: (val) => setState(() => _vatPricingType = val ?? 'inclusive'),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    activeColor: AppTheme.primaryGreen,
                    title: const Text('VAT-Exclusive Pricing (Common for B2B & Wholesale)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Shelf prices are net of tax. VAT is added on top at the register.', style: TextStyle(fontSize: 12)),
                    value: 'exclusive',
                    groupValue: _vatPricingType,
                    onChanged: (val) => setState(() => _vatPricingType = val ?? 'exclusive'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Default Invoice Printing Mode
            Text('Default Receipt / Invoice Mode', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    activeColor: AppTheme.primaryGreen,
                    title: const Text('Normal POS Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Standard retail slip without mandatory tax invoice headers.', style: TextStyle(fontSize: 12)),
                    value: 'normal',
                    groupValue: _vatInvoiceMode,
                    onChanged: (val) => setState(() => _vatInvoiceMode = val ?? 'normal'),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    activeColor: AppTheme.primaryGreen,
                    title: const Text('Official VAT / Tax Invoice (IRD Compliant)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Prints "TAX INVOICE", Business TIN, VAT Reg No, Customer TIN, and itemized VAT breakdown.', style: TextStyle(fontSize: 12)),
                    value: 'tax_invoice',
                    groupValue: _vatInvoiceMode,
                    onChanged: (val) => setState(() => _vatInvoiceMode = val ?? 'tax_invoice'),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ─── CARD 2: SERVICE CHARGE & INVENTORY LIMITS ───
          _buildCard(cardBg, borderColor, [
            Text('Service Charges & Stock Triggers', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serviceChargeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Default Service Charge Rate (%)',
                      hintText: '10.0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _lowStockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Low Stock Alert Threshold',
                      hintText: '10',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final notifier = ref.read(settingsProvider.notifier);
                final defaultVat = double.tryParse(_defaultVatRateCtrl.text.trim()) ?? 18.0;
                final sc = double.tryParse(_serviceChargeCtrl.text.trim()) ?? 0.0;
                final threshold = int.tryParse(_lowStockCtrl.text.trim()) ?? 10;

                await notifier.updateVatSettings(
                  isVatEnabled: _isVatEnabled,
                  isVatRegistered: _isVatRegistered,
                  taxIdentificationNumber: _tinCtrl.text.trim(),
                  vatRegistrationNumber: _vatNumberCtrl.text.trim(),
                  defaultVatRate: defaultVat,
                  vatPricingType: _vatPricingType,
                  vatInvoiceMode: _vatInvoiceMode,
                );
                await notifier.updateTaxRate(defaultVat);
                await notifier.updateServiceChargeRate(sc);
                await notifier.updateLowStockThreshold(threshold);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tax and VAT configuration updated successfully!')),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: const Text('Save Tax / VAT Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: BUSINESS MODULES
  // ==========================================
  Widget _buildModulesTab(Color cardBg, Color borderColor, bool isDark) {
    final modules = ref.watch(businessModulesProvider);
    final notifier = ref.read(businessModulesProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader('Business Modules & Custom Workflows', 'Activate specialized capabilities to tailor QuickBill to your business type'),
          const SizedBox(height: 24),
          _buildCard(cardBg, borderColor, [
            SwitchListTile(
              title: const Text('Product Inventory & Barcode POS', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Standard retail selling with stock counts, cost prices & barcode scanning'),
              value: modules.enableProducts,
              onChanged: (val) => notifier.toggleModule('module_products', val),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Services Mode (Salon, Repair & Professional)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Enables billing for time and service tasks without decrementing physical inventory'),
              value: modules.enableServices,
              onChanged: (val) => notifier.toggleModule('module_services', val),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Appointment Scheduling Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Client booking calendar and direct conversion of appointments into POS invoices'),
              value: modules.enableAppointments,
              onChanged: modules.enableServices ? (val) => notifier.toggleModule('module_appointments', val) : null,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Custom Tailoring / Job Orders', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Track custom tailoring measurements, repair job orders, deposits & delivery dates'),
              value: modules.enableCustomOrders,
              onChanged: (val) => notifier.toggleModule('module_custom_orders', val),
            ),
          ]),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: CLOUD SYNC & DATA MANAGEMENT
  // ==========================================
  Widget _buildSyncTab(Color cardBg, Color borderColor, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader('Cloud Sync & Data Exports', 'Real-time synchronization across devices and offline database backups'),
          const SizedBox(height: 24),
          _buildCard(cardBg, borderColor, [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: AppTheme.primaryGreen, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Sync Status: Active',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Multi-device 2-way sync with Google Cloud Firestore',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _triggerManualSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, color: Colors.white),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Now', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                ),
              ],
            ),
            if (_syncMessage != null) ...[
              const SizedBox(height: 12),
              Text(_syncMessage!, style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Text('Data Exports & Reports', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                    await ExportService.instance.exportSales(branchId);
                  },
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('Export Invoices (CSV)'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                    await ExportService.instance.exportProducts(branchId);
                  },
                  icon: const Icon(Icons.inventory_rounded),
                  label: const Text('Export Inventory (CSV)'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                    await ExportService.instance.exportCustomers(branchId);
                  },
                  icon: const Icon(Icons.people_alt_rounded),
                  label: const Text('Export Customers (CSV)'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await BackupService.instance.createBackup(context);
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Backup SQLite Database'),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _triggerManualSync() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    try {
      await ref.read(syncServiceProvider).syncEssentialData();
      setState(() => _syncMessage = 'Sync completed successfully!');
    } catch (e) {
      setState(() => _syncMessage = 'Sync error: $e');
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  // ==========================================
  // TAB 5: STAFF & PERMISSIONS
  // ==========================================
  Widget _buildStaffTab(Color cardBg, Color borderColor, bool isDark) {
    final employeesAsync = ref.watch(employeeListProvider);
    final currentEmp = ref.watch(currentEmployeeProvider).value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTabHeader('Staff & PIN Security', 'Manage cashier accounts, manager roles and access PIN codes'),
              ElevatedButton.icon(
                onPressed: () => _openAddEmployeeDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                label: const Text('Add Staff Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCard(cardBg, borderColor, [
            employeesAsync.when(
              data: (employees) {
                if (employees.isEmpty) {
                  return const Center(child: Text('No staff members registered.'));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: employees.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    final isCurrent = emp.id == currentEmp?.id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        child: Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Current User', style: TextStyle(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('Role: ${emp.role.name.toUpperCase()} • Status: ${emp.status.name.toUpperCase()}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (emp.role != EmployeeRole.owner)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () => _confirmDeleteEmployee(context, emp.id!),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ]),
        ],
      ),
    );
  }

  void _openAddEmployeeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    EmployeeRole role = EmployeeRole.staff;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Add Staff Member'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SinglishTextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Staff Name', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: '4-Digit Login PIN', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<EmployeeRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: EmployeeRole.staff, child: Text('Cashier / Staff (POS Sales & Receipts)')),
                    DropdownMenuItem(value: EmployeeRole.owner, child: Text('Store Owner / Administrator (Full Access)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSt(() => role = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.isEmpty || pin.length != 4) return;

                final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                final newEmp = Employee(
                  branchId: branchId,
                  name: name,
                  pin: Employee.hashPin(pin),
                  role: role,
                  status: EmployeeStatus.active,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ref.read(employeeListProvider.notifier).addEmployee(newEmp);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              child: const Text('Create Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEmployee(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Staff Member'),
        content: const Text('Are you sure you want to remove this staff member?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(employeeListProvider.notifier).deleteEmployee(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Color cardBg, Color borderColor, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Future<void> _previewReceipt(AppSettings settings) async {
    final sampleSale = Sale(
      billNumber: 'INV000001',
      total: 1450.0,
      discount: 50.0,
      itemsCount: 4,
      paymentMethod: 'cash',
      cashierName: 'Harshana',
      customerName: 'Kusal Mendis',
      customerPhone: '077 123 4567',
      createdAt: DateTime.now(),
      notes: 'Cash: 1500.00\nChange: 50.00',
    );

    final sampleItems = [
      SaleItem(
        saleId: 0,
        productId: 1,
        productName: 'ප්රීමා වෙජිටබල් ඔයිල් මිලි ලීටර් 100',
        quantity: 1,
        unitPrice: 420.0,
        costPrice: 380.0,
        discount: 20.0,
        total: 400.0,
      ),
      SaleItem(
        saleId: 0,
        productId: 2,
        productName: 'Egg Yellow food colour 28ml',
        quantity: 2,
        unitPrice: 125.0,
        costPrice: 90.0,
        discount: 0.0,
        total: 250.0,
      ),
      SaleItem(
        saleId: 0,
        productId: 3,
        productName: 'කිරිපිටි',
        quantity: 1,
        unitPrice: 480.0,
        costPrice: 420.0,
        discount: 30.0,
        total: 450.0,
      ),
      SaleItem(
        saleId: 0,
        productId: 4,
        productName: 'Rice 5kg',
        quantity: 1,
        unitPrice: 350.0,
        costPrice: 300.0,
        discount: 0.0,
        total: 350.0,
      ),
    ];

    await ReceiptPreviewDialog.show(
      context,
      sale: sampleSale,
      items: sampleItems,
      settings: settings,
      cashReceived: 1500.0,
      change: 50.0,
    );
  }

  Widget _buildDesktopTemplateCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppTheme.primaryGreen : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 6: SYSTEM & AUTOMATIC UPDATES
  // ==========================================
  Widget _buildSystemUpdateTab(Color cardBg, Color borderColor, bool isDark) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '1.0.7';
        final buildNumber = snapshot.data?.buildNumber ?? '11';
        final updateLogPath = WindowsUpdateService.instance.getUpdateLogPath();

        return ListView(
          children: [
            Text(
              'System & Automatic Updates',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage application versioning, check for Windows updates, and view system logs.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Card 1: Application Version & Updates
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.system_update_rounded, color: AppTheme.primaryGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QuickBill POS — Windows Edition',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Installed Version: v$version (Build $buildNumber)',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isCheckingUpdate
                            ? null
                            : () async {
                                setState(() => _isCheckingUpdate = true);
                                try {
                                  final info = await WindowsUpdateService.instance.checkForUpdate();
                                  if (!context.mounted) return;
                                  setState(() => _isCheckingUpdate = false);
                                  if (info.hasUpdate) {
                                    UpdateDialog.show(context, info);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('QuickBill is up to date! (v${info.currentVersion})'),
                                        backgroundColor: AppTheme.primaryGreen,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setState(() => _isCheckingUpdate = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Update check failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        icon: _isCheckingUpdate
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(_isCheckingUpdate ? 'Checking...' : 'Check for Updates'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Zero-Data-Loss Guarantee: Updates only overwrite application binaries in C:\\Program Files\\QuickBill POS. Your SQLite database, invoices, products, and user settings stored in %APPDATA% are strictly preserved.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card 2: System Directories & Diagnostics
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Paths & Diagnostics', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, color: Colors.blueAccent),
                    title: const Text('Update Log File', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: SelectableText(updateLogPath, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.storage_rounded, color: Colors.amber),
                    title: Text('Local SQLite Database Directory', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: SelectableText('%APPDATA%\\quickbill\\databases\\quickbill.db', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
