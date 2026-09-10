import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../../services/pdf_service.dart';
import '../../services/printing_service.dart';
import '../../services/sync_service.dart';
import '../../models/sale.dart';

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

  // Controllers for Printer
  late TextEditingController _printerIpCtrl;
  late TextEditingController _printerPortCtrl;

  bool _isSyncing = false;
  String? _syncMessage;

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
    _printerIpCtrl.dispose();
    _printerPortCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        'Settings',
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
                      _buildNavItem(0, 'Store Profile', Icons.storefront_rounded),
                      _buildNavItem(1, 'Printers & Hardware', Icons.print_rounded),
                      _buildNavItem(2, 'Tax & Service Charges', Icons.percent_rounded),
                      _buildNavItem(3, 'Business Modules', Icons.dashboard_customize_rounded),
                      _buildNavItem(4, 'Cloud Sync & Data', Icons.cloud_sync_rounded),
                      _buildNavItem(5, 'Staff & Permissions', Icons.badge_rounded),
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
      default: return const SizedBox.shrink();
    }
  }

  // ==========================================
  // TAB 0: STORE PROFILE
  // ==========================================
  Widget _buildStoreProfileTab(Color cardBg, Color borderColor, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabHeader('Store Profile & Receipt Branding', 'Business name, address and custom receipt footer message'),
          const SizedBox(height: 24),
          _buildCard(cardBg, borderColor, [
            TextField(
              controller: _shopNameCtrl,
              decoration: const InputDecoration(labelText: 'Store / Company Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shopPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Store Phone Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shopAddressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Business Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _receiptFooterCtrl,
              decoration: const InputDecoration(labelText: 'Receipt Footer Thank-You Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final notifier = ref.read(settingsProvider.notifier);
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
              label: const Text('Save Store Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ]),
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
            Text('Thermal Paper Width', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPaperSizeOption('80mm (Standard POS)', '80mm', settings.printerPaperSize == '80mm', () {
                  notifier.updatePrinterPaperSize('80mm');
                }),
                const SizedBox(width: 16),
                _buildPaperSizeOption('58mm (Compact Mobile)', '58mm', settings.printerPaperSize == '58mm', () {
                  notifier.updatePrinterPaperSize('58mm');
                }),
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
                          billNumber: 'TEST-001',
                          total: 1000.0,
                          discount: 0.0,
                          itemsCount: 1,
                          paymentMethod: 'cash',
                          createdAt: DateTime.now(),
                        );
                        final doc = await PdfService.instance.buildReceiptDocument(testSale, [], settings: settings);
                        await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'Test-Receipt');
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
          _buildTabHeader('Tax, Service Charges & Inventory Limits', 'Default VAT/tax percentages, service charges and low stock triggers'),
          const SizedBox(height: 24),
          _buildCard(cardBg, borderColor, [
            TextField(
              controller: _taxRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Default Tax / VAT Rate (%)',
                hintText: 'e.g. 15.0 (Enter 0 if prices are tax-inclusive or tax exempt)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serviceChargeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Default Service Charge Rate (%)',
                hintText: 'e.g. 10.0 (Commonly used for dine-in / salon services)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lowStockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Low Stock Alert Threshold',
                hintText: 'e.g. 10 units',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final notifier = ref.read(settingsProvider.notifier);
                final tax = double.tryParse(_taxRateCtrl.text.trim()) ?? 0.0;
                final sc = double.tryParse(_serviceChargeCtrl.text.trim()) ?? 0.0;
                final threshold = int.tryParse(_lowStockCtrl.text.trim()) ?? 10;

                await notifier.updateTaxRate(tax);
                await notifier.updateServiceChargeRate(sc);
                await notifier.updateLowStockThreshold(threshold);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tax and inventory settings updated!')),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: const Text('Save Tax Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Staff Name', border: OutlineInputBorder())),
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
}
