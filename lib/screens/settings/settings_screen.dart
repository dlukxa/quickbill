import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/printing_service.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../../services/backup_service.dart';
import '../../services/sync_service.dart';
import '../auth/auth_wrapper.dart';
import '../../providers/product_provider.dart';
import '../../providers/preference_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/branch_provider.dart';
import '../../models/employee.dart';
import '../../config/theme.dart';
import '../../services/storage_service.dart';
import '../../services/local_media_storage_service.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:printing/printing.dart';
import '../../services/cash_drawer_service.dart';
import '../../services/pdf_service.dart';
import '../../models/sale.dart';
import '../../widgets/receipt/receipt_preview_dialog.dart';
import '../../models/sale_item.dart';
import '../../generated/l10n/app_localizations.dart';
import 'bluetooth_scanner_settings_screen.dart' as bluetooth_scanner_settings_screen;
import 'employee_list_screen.dart';
import 'business_modules_screen.dart';
import 'branch_management_screen.dart';
import '../../utils/region_utils.dart';
import '../../utils/category_constants.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/cloud_backups_sheet.dart';
import '../desktop/link_to_pc_screen.dart';
import 'subscription_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final currentEmployee = employeeAsync.value;
    final selectedBranch = ref.watch(branchProvider).selectedBranch;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Store Header Card
          AnimateIn(
            delay: const Duration(milliseconds: 50),
            child: _buildShopHeaderCard(context, settings, currentEmployee, selectedBranch),
          ),
          const SizedBox(height: 24),
          
          // Category Cards
          if (currentEmployee?.role == EmployeeRole.owner) ...[
            AnimateIn(
              delay: const Duration(milliseconds: 75),
              child: _CategoryCard(
                title: 'Subscription & Billing',
                subtitle: 'Manage Google Play subscription, trial & renewal',
                icon: Icons.workspace_premium_rounded,
                iconColor: Colors.amber.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionSettingsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AnimateIn(
              delay: const Duration(milliseconds: 100),
              child: _CategoryCard(
                title: l10n.shopTeamSettings,
                subtitle: l10n.shopTeamSettingsDesc,
                icon: Icons.storefront_rounded,
                iconColor: AppTheme.primaryPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const _ShopSettingsPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          AnimateIn(
            delay: const Duration(milliseconds: 150),
            child: _CategoryCard(
              title: l10n.devicePrinting,
              subtitle: l10n.devicePrintingDesc,
              icon: Icons.print_rounded,
              iconColor: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const _DeviceSettingsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AnimateIn(
            delay: const Duration(milliseconds: 175),
            child: _CategoryCard(
              title: 'Receipt Settings & Templates',
              subtitle: 'Sri Lankan Retail POS, Sinhala/Tamil/English & field toggles',
              icon: Icons.receipt_long_rounded,
              iconColor: Colors.deepOrange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const _ReceiptSettingsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AnimateIn(
            delay: const Duration(milliseconds: 200),
            child: _CategoryCard(
              title: l10n.preferencesAlerts,
              subtitle: l10n.preferencesAlertsDesc,
              icon: Icons.tune_rounded,
              iconColor: AppTheme.primaryGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const _PreferenceSettingsPage()),
                );
              },
            ),
          ),
          if (currentEmployee?.role == EmployeeRole.owner) ...[
            const SizedBox(height: 12),
            AnimateIn(
              delay: const Duration(milliseconds: 250),
              child: _CategoryCard(
                title: l10n.dataBackups,
                subtitle: l10n.dataBackupsDesc,
                icon: Icons.cloud_sync_rounded,
                iconColor: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const _DataSettingsPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            AnimateIn(
              delay: const Duration(milliseconds: 265),
              child: _CategoryCard(
                title: 'Open on PC',
                subtitle: 'Link this shop to a Windows PC terminal',
                icon: Icons.computer_rounded,
                iconColor: AppTheme.primaryBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LinkToPcScreen()),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AnimateIn(
            delay: const Duration(milliseconds: 280),
            child: _CategoryCard(
              title: 'Help & Support',
              subtitle: 'Contact customer care via WhatsApp',
              icon: Icons.support_agent_rounded,
              iconColor: Colors.teal,
              onTap: () async {
                final url = Uri.parse('https://wa.me/94740136429');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Account Management section
          AnimateIn(
            delay: const Duration(milliseconds: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: AppLocalizations.of(context)!.account),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      AppLocalizations.of(context)!.signOut, 
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                    ),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.signOut),
                          content: Text(
                            AppLocalizations.of(context)!.localeName == 'si' ? 'ඔබට විශ්වාසද ඉවත් වීමට අවශ්‍ය බව?' :
                            AppLocalizations.of(context)!.localeName == 'ta' ? 'நீங்கள் வெளியேற விரும்புகிறீர்களா?' :
                            AppLocalizations.of(context)!.localeName == 'hi' ? 'क्या आप साइन आउट करना चाहते हैं?' :
                            AppLocalizations.of(context)!.localeName == 'bn' ? 'আপনি কি সাইন আউট করতে চান?' :
                            AppLocalizations.of(context)!.localeName == 'dv' ? 'ސައިން އައުޓް ކުރަންވީތޯ؟' :
                            'Are you sure you want to sign out?'
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text(AppLocalizations.of(context)!.signOut),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      ref.invalidate(dismissedAlertsProvider);
                      ref.invalidate(isStaffDeviceProvider);
                      await AuthService.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthWrapper()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildShopHeaderCard(BuildContext context, AppSettings settings, Employee? employee, dynamic selectedBranch) {
    final l10n = AppLocalizations.of(context)!;
    final roleName = employee?.role == EmployeeRole.owner ? l10n.owner : l10n.cashier;
    final branchName = selectedBranch?.name ?? l10n.mainBranch;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
            context.isDark ? const Color(0xFF0F172A) : const Color(0xFFDBEAFE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF334155) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryGreen, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              image: settings.shopLogoUrl != null
                ? DecorationImage(
                    image: NetworkImage(settings.shopLogoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            ),
            child: settings.shopLogoUrl == null
              ? const Icon(Icons.storefront, size: 36, color: AppTheme.primaryGreen)
              : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.shopName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: context.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        roleName,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        branchName,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: context.subText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.subText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-Pages for Lazy Loading
// ─────────────────────────────────────────────────────────────────────────────

class _ShopSettingsPage extends ConsumerWidget {
  const _ShopSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final currentEmployee = employeeAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.shopTeamSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: currentEmployee?.role == EmployeeRole.owner ? () => _pickAndUploadLogo(context, ref) : null,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      image: settings.shopLogoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(settings.shopLogoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: settings.shopLogoUrl == null
                        ? const Icon(Icons.add_a_photo_rounded, size: 48, color: AppTheme.primaryGreen)
                        : null,
                  ),
                ),
                if (settings.shopLogoUrl != null && currentEmployee?.role == EmployeeRole.owner) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      notifier.updateShopLogo(null);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    label: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: AppLocalizations.of(context)!.shopDetails),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(AppLocalizations.of(context)!.shopName),
                  subtitle: Text(settings.shopName),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner 
                    ? () => _showEditDialog(
                        context,
                        AppLocalizations.of(context)!.editShopName,
                        settings.shopName,
                        (val) => notifier.updateShopName(val),
                      )
                    : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Business Type'),
                  subtitle: Text(settings.businessType),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner
                    ? () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Theme.of(context).cardColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) {
                            final types = CategoryConstants.businessTypes;
                            return SafeArea(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('Select Business Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                                    ),
                                    ...types.map((type) => ListTile(
                                      title: Text(type, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                      trailing: settings.businessType == type ? const Icon(Icons.check, color: AppTheme.primaryGreen) : null,
                                      onTap: () {
                                        notifier.updateBusinessType(type);
                                        Navigator.pop(context);
                                      },
                                    )),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                    : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(AppLocalizations.of(context)!.phoneNumber),
                  subtitle: Text(settings.shopPhone.isEmpty ? AppLocalizations.of(context)!.notSet : settings.shopPhone),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner
                    ? () => _showEditDialog(
                        context,
                        AppLocalizations.of(context)!.editPhoneNumber,
                        settings.shopPhone,
                        (val) => notifier.updateShopPhone(val),
                        keyboardType: TextInputType.phone,
                      )
                    : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(AppLocalizations.of(context)!.address),
                  subtitle: Text(settings.shopAddress.isEmpty ? AppLocalizations.of(context)!.notSet : settings.shopAddress),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner
                    ? () => _showEditDialog(
                        context,
                        AppLocalizations.of(context)!.editAddress,
                        settings.shopAddress,
                        (val) => notifier.updateShopAddress(val),
                        maxLines: 2,
                      )
                    : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text(AppLocalizations.of(context)!.entityCode),
                  subtitle: Text(settings.entityCode),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner
                    ? () => _showEditDialog(
                        context,
                        AppLocalizations.of(context)!.editEntityCode,
                        settings.entityCode,
                        (val) {
                          final clean = val.trim().replaceAll(' ', '');
                          if (clean.isNotEmpty && clean.length <= 15) {
                            notifier.updateEntityCode(clean);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context)!.entityCodeError)),
                            );
                          }
                        },
                      )
                    : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Tax Rate (%)'),
                  subtitle: Text('${settings.taxRate}%'),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner
                    ? () => _showEditDialog(
                        context,
                        'Edit Tax Rate',
                        settings.taxRate.toString(),
                        (val) {
                          final rate = double.tryParse(val) ?? 0.0;
                          notifier.updateTaxRate(rate);
                        },
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      )
                    : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.room_service_outlined),
                  title: const Text('Service Charge Rate (%)'),
                  subtitle: Text('${settings.serviceChargeRate}%'),
                  trailing: currentEmployee?.role == EmployeeRole.owner ? const Icon(Icons.edit, size: 20) : null,
                  onTap: currentEmployee?.role == EmployeeRole.owner
                    ? () => _showEditDialog(
                        context,
                        'Edit Service Charge Rate',
                        settings.serviceChargeRate.toString(),
                        (val) {
                          final rate = double.tryParse(val) ?? 0.0;
                          notifier.updateServiceChargeRate(rate);
                        },
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      )
                    : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (currentEmployee?.role == EmployeeRole.owner) ...[
            _SectionHeader(title: 'Business Modules'),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.extension),
                title: const Text('Configure Modules'),
                subtitle: const Text('Enable or disable Retail, Services, Appointments, Custom Orders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BusinessModulesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (currentEmployee?.permissions.canManageEmployees ?? false) ...[
            _SectionHeader(title: AppLocalizations.of(context)!.teamManagement),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.badge),
                title: Text(AppLocalizations.of(context)!.staffMembers),
                subtitle: Text(AppLocalizations.of(context)!.manageEmployeesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (currentEmployee?.role == EmployeeRole.owner) ...[
            _SectionHeader(title: AppLocalizations.of(context)!.multiBranchManagement),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.account_tree),
                title: Text(AppLocalizations.of(context)!.branches),
                subtitle: Text(AppLocalizations.of(context)!.manageBranchesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BranchManagementScreen()),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceSettingsPage extends ConsumerWidget {
  const _DeviceSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.devicePrinting),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: AppLocalizations.of(context)!.printerSection),
          const AppCard(
            padding: EdgeInsets.zero,
            child: _PrinterSection(),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: AppLocalizations.of(context)!.barcodeScanner),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.barcode_reader),
              title: Text(AppLocalizations.of(context)!.barcodeScanner),
              subtitle: Text(AppLocalizations.of(context)!.connectBarcodeSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const bluetooth_scanner_settings_screen.BluetoothScannerSettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSettingsPage extends ConsumerWidget {
  const _PreferenceSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final currentEmployee = employeeAsync.value;
    final isOwner = currentEmployee?.role == EmployeeRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.preferencesAlerts),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: AppLocalizations.of(context)!.localization),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(AppLocalizations.of(context)!.language),
                  subtitle: Text(
                    settings.languageCode == 'en' ? 'English' : 
                    settings.languageCode == 'si' ? 'සිංහල' : 
                    settings.languageCode == 'ta' ? 'தமிழ்' :
                    settings.languageCode == 'hi' ? 'हिन्दी' :
                    settings.languageCode == 'bn' ? 'বাংলা' :
                    'ދިވެހި'
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.languageCode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'si', child: Text('සිංහල')),
                      DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                      DropdownMenuItem(value: 'dv', child: Text('ދިވެހި')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.updateLanguage(val);
                    },
                  ),
                ),
                if (isOwner) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: Text(AppLocalizations.of(context)!.countryRegion),
                    subtitle: Text(RegionUtils.fromCode(settings.regionCode).displayName),
                    trailing: DropdownButton<String>(
                      value: settings.regionCode,
                      underline: const SizedBox(),
                      items: AppRegion.values.map((region) => DropdownMenuItem(
                        value: region.code,
                        child: Text(region.displayName),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.updateRegion(val);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: AppLocalizations.of(context)!.appearance),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: Icon(
                settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: AppTheme.primaryGreen,
              ),
              title: Text(AppLocalizations.of(context)!.darkMode),
              subtitle: Text(settings.isDarkMode 
                ? AppLocalizations.of(context)!.darkThemeEnabled 
                : AppLocalizations.of(context)!.lightThemeEnabled),
              value: settings.isDarkMode,
              activeThumbColor: AppTheme.primaryGreen,
              onChanged: (value) => notifier.updateDarkMode(value),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: AppLocalizations.of(context)!.stockAlerts),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(AppLocalizations.of(context)!.lowStockThreshold),
                subtitle: Text(AppLocalizations.of(context)!.lowStockAlertSubtitle(settings.lowStockThreshold)),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () => _showEditDialog(
                  context,
                  AppLocalizations.of(context)!.lowStockThreshold,
                  settings.lowStockThreshold.toString(),
                  (val) {
                    final threshold = int.tryParse(val) ?? 10;
                    notifier.updateLowStockThreshold(threshold);
                  },
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: AppLocalizations.of(context)!.receiptSettings),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long_rounded, color: Colors.deepOrange),
                    title: const Text('Receipt Template & Language', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(settings.receiptTemplate == 'sri_lankan_retail'
                        ? 'Sri Lankan Retail POS (${settings.receiptLanguage.toUpperCase()})'
                        : 'QuickBill Classic (${settings.receiptLanguage.toUpperCase()})'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _ReceiptSettingsPage()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: Text(AppLocalizations.of(context)!.receiptFooter),
                    subtitle: Text(settings.receiptFooter),
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () => _showEditDialog(
                      context,
                      AppLocalizations.of(context)!.editReceiptFooter,
                      settings.receiptFooter,
                      (val) => notifier.updateReceiptFooter(val),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _DataSettingsPage extends ConsumerWidget {
  const _DataSettingsPage();

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryGreen),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final currentEmployee = employeeAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dataBackups),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: AppLocalizations.of(context)!.backupSync),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync),
                  title: Text(AppLocalizations.of(context)!.autoSync),
                  subtitle: Text(AppLocalizations.of(context)!.autoSyncSubtitle),
                  value: settings.autoSync,
                  onChanged: (value) {
                    notifier.updateAutoSync(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Cloud Backup Frequency'),
                  subtitle: const Text('How often to backup database to cloud'),
                  trailing: DropdownButton<String>(
                    value: settings.cloudBackupFrequency,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: '3h', child: Text('Every 3 hours')),
                      DropdownMenuItem(value: '6h', child: Text('Every 6 hours')),
                      DropdownMenuItem(value: '12h', child: Text('Every 12 hours')),
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        notifier.updateCloudBackupFrequency(val);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: Text(AppLocalizations.of(context)!.backupData),
                  subtitle: Text(AppLocalizations.of(context)!.exportDatabase),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await BackupService.instance.createBackup(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(AppLocalizations.of(context)!.restoreData),
                  subtitle: Text(AppLocalizations.of(context)!.importDatabaseFile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await BackupService.instance.restoreBackup(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download, color: AppTheme.primaryBlue),
                  title: const Text('Cloud Backups'),
                  subtitle: const Text('Restore database from cloud backups'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) => const CloudBackupsSheet(),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined, color: AppTheme.primaryGreen),
                  title: const Text('Sync All Historical Data'),
                  subtitle: const Text('Re-download all records from cloud (sales, inventory, etc.)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sync All Historical Data'),
                        content: const Text(
                          'This will re-download all your data from the cloud. '
                          'This may take a few minutes depending on how many records you have. '
                          'Your existing data will not be deleted.\n\nContinue?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Sync Now'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔄 Downloading all historical data... This may take a few minutes.'),
                        duration: Duration(seconds: 5),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    await ref.read(syncServiceProvider).pullRemoteChanges(
                      isManual: true,
                      forceFullRestore: true,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ All historical data synced successfully!'),
                          backgroundColor: AppTheme.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Offline Media & Device Storage'),
          const _OfflineMediaStorageCard(),
          const SizedBox(height: 24),
          _SectionHeader(title: AppLocalizations.of(context)!.csvManagement),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: Text(AppLocalizations.of(context)!.exportSales),
                  subtitle: Text(AppLocalizations.of(context)!.exportSalesSubtitle),
                  onTap: () async {
                    _showLoadingDialog(context, '${AppLocalizations.of(context)!.exportSales}...');
                    try {
                      final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                      await ExportService.instance.exportSales(branchId);
                    } finally {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.inventory),
                  title: Text(AppLocalizations.of(context)!.exportInventory),
                  subtitle: Text(AppLocalizations.of(context)!.exportInventorySubtitle),
                  onTap: () async {
                    _showLoadingDialog(context, '${AppLocalizations.of(context)!.exportInventory}...');
                    try {
                      final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                      await ExportService.instance.exportProducts(branchId);
                    } finally {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(AppLocalizations.of(context)!.exportCustomers),
                  subtitle: Text(AppLocalizations.of(context)!.exportCustomersSubtitle),
                  onTap: () async {
                    _showLoadingDialog(context, '${AppLocalizations.of(context)!.exportCustomers}...');
                    try {
                      final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                      await ExportService.instance.exportCustomers(branchId);
                    } finally {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.publish),
                  title: Text(AppLocalizations.of(context)!.importProducts),
                  subtitle: Text(AppLocalizations.of(context)!.importProductsSubtitle),
                  trailing: const Icon(Icons.add, color: AppTheme.primaryGreen),
                  onTap: () async {
                    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
                    
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['csv'],
                    );

                    if (result == null || result.files.single.path == null) return;

                    if (context.mounted) {
                      _showLoadingDialog(context, '${AppLocalizations.of(context)!.importProducts}...');
                    }

                    int count = 0;
                    try {
                      count = await ImportService.instance.importProductsFromPath(
                        branchId,
                        result.files.single.path!,
                      );
                    } finally {
                      if (context.mounted) Navigator.pop(context);
                    }

                    if (count > 0) {
                      ref.invalidate(productsProvider);
                      ref.invalidate(lowStockProductsProvider);
                      // Trigger a local push sync in background to upload imported products to server
                      SyncService.instance.pushLocalChanges();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.importSuccess(count.toString())),
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Danger Zone
          if (currentEmployee?.role == EmployeeRole.owner) ...[
            _SectionHeader(title: AppLocalizations.of(context)!.dangerZone),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppTheme.errorRed),
                    title: Text(AppLocalizations.of(context)!.clearAllData, style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                    subtitle: Text(AppLocalizations.of(context)!.clearDataSubtitle),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.wipeAllDataTitle),
                          content: Text(AppLocalizations.of(context)!.wipeAllDataContent),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                              onPressed: () async {
                                await DatabaseService.instance.clearAllData();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context)!.databaseCleared), backgroundColor: AppTheme.errorRed),
                                  );
                                }
                              },
                              child: Text(AppLocalizations.of(context)!.wipeEverything),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_remove, color: AppTheme.errorRed),
                    title: Text(AppLocalizations.of(context)!.deleteAccount, style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                    subtitle: Text(AppLocalizations.of(context)!.deleteAccountSubtitle),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.deleteAccountTitle),
                          content: Text(AppLocalizations.of(context)!.deleteAccountWarning),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                              onPressed: () async {
                                try {
                                  ref.invalidate(dismissedAlertsProvider);
                                  await ref.read(authServiceProvider).deleteAccount();
                                  if (context.mounted) {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed),
                                    );
                                  }
                                }
                              },
                              child: Text(AppLocalizations.of(context)!.deleteAccountConfirm),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers and Dialogs
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _pickAndUploadLogo(BuildContext context, WidgetRef ref) async {
  final picker = ImagePicker();
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(AppLocalizations.of(context)!.photoLibrary),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(AppLocalizations.of(context)!.camera),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );

  if (source == null) return;

  final pickedFile = await picker.pickImage(
    source: source,
    maxWidth: 400,
    maxHeight: 400,
    imageQuality: 80,
  );
  if (pickedFile == null) return;

  final l10n = AppLocalizations.of(context)!;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.uploadingLogo)),
    );
  }

  try {
    final shopUid = ref.read(activeShopUidProvider);
    if (shopUid == null) throw Exception('Not logged in');

    final storage = ref.read(storageServiceProvider);
    final url = await storage.uploadImage(
      path: 'shops/$shopUid/logo.jpg',
      imageFile: File(pickedFile.path),
      maxWidth: 400,
    );

    if (url != null) {
      await ref.read(settingsProvider.notifier).updateShopLogo(url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.logoUpdated)),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.uploadFailed(e.toString()))),
      );
    }
  }
}

void _showEditDialog(
  BuildContext context,
  String title,
  String initialValue,
  Function(String) onSave, {
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initialValue);
  final isNumeric = keyboardType == TextInputType.number ||
      keyboardType == TextInputType.phone;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: isNumeric
          ? TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            )
          : SinglishTextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: Text(AppLocalizations.of(context)!.cancel)
        ),
        ElevatedButton(
          onPressed: () {
            onSave(controller.text);
            Navigator.pop(context);
          },
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    ),
  );
}

class _PrinterSection extends ConsumerStatefulWidget {
  const _PrinterSection();

  @override
  ConsumerState<_PrinterSection> createState() => _PrinterSectionState();
}

class _PrinterSectionState extends ConsumerState<_PrinterSection> {
  List<BluetoothDevice> _bluetoothDevices = [];
  List<Printer> _systemPrinters = [];
  bool _isBluetoothConnected = false;
  bool _isTestingNetwork = false;
  bool _isTestingCashDrawer = false;
  
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _comPortController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _ipController = TextEditingController(text: settings.printerIpAddress);
    _portController = TextEditingController(text: settings.printerPort.toString());
    _comPortController = TextEditingController(text: settings.cashDrawerComPort);
    _checkStatus();
    _loadSystemPrinters();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _comPortController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final connected = await PrintingService.instance.isConnected();
      if (mounted) setState(() => _isBluetoothConnected = connected);
    } catch (e) {
      if (mounted) setState(() => _isBluetoothConnected = false);
    }
  }

  Future<void> _scanBluetooth() async {
    final devices = await PrintingService.instance.getDevices();
    if (mounted) setState(() => _bluetoothDevices = devices);
  }

  Future<void> _loadSystemPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      if (mounted) setState(() => _systemPrinters = printers);
    } catch (e) {
      debugPrint('Error listing system printers: $e');
    }
  }

  Future<void> _testNetworkPrint(AppSettings settings) async {
    setState(() => _isTestingNetwork = true);
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    final result = await PrintingService.instance.testNetworkPrinter(
      ip: ip,
      port: port,
      paperSize: settings.printerPaperSize,
    );

    if (mounted) {
      setState(() => _isTestingNetwork = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _testCashDrawer(AppSettings settings) async {
    setState(() => _isTestingCashDrawer = true);
    final result = await CashDrawerService.instance.openCashDrawer(settings, isManual: true);
    if (mounted) {
      setState(() => _isTestingCashDrawer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Connection Type Selector
          Text(
            'Printer Connection Type',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'bluetooth',
                label: Text('Bluetooth'),
                icon: Icon(Icons.bluetooth),
              ),
              ButtonSegment<String>(
                value: 'network',
                label: Text('Wi-Fi / LAN'),
                icon: Icon(Icons.wifi),
              ),
              ButtonSegment<String>(
                value: 'system',
                label: Text('Desktop / OS'),
                icon: Icon(Icons.desktop_windows),
              ),
            ],
            selected: {settings.printerConnectionType},
            onSelectionChanged: (Set<String> newSelection) {
              notifier.updatePrinterConnectionType(newSelection.first);
            },
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // 2. Paper Size Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paper Roll Width',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '80mm (Standard POS) or 58mm (Portable)',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: '80mm', label: Text('80mm')),
                  ButtonSegment<String>(value: '58mm', label: Text('58mm')),
                ],
                selected: {settings.printerPaperSize},
                onSelectionChanged: (Set<String> newSelection) {
                  notifier.updatePrinterPaperSize(newSelection.first);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // 3. Dynamic Configuration Section by Connection Type
          if (settings.printerConnectionType == 'bluetooth') ...[
            // Bluetooth Thermal Section
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.bluetooth_connected,
                color: _isBluetoothConnected ? Colors.green : Colors.grey,
                size: 28,
              ),
              title: const Text('Bluetooth Thermal Printer', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _isBluetoothConnected ? 'Status: Connected' : 'Status: Not Connected',
                style: TextStyle(color: _isBluetoothConnected ? Colors.green : Colors.red),
              ),
              trailing: ElevatedButton.icon(
                onPressed: _scanBluetooth,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Scan Devices'),
              ),
            ),
            if (_bluetoothDevices.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Paired Bluetooth Devices:',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: _bluetoothDevices.map((device) => ListTile(
                    leading: const Icon(Icons.print),
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.address ?? ''),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        final success = await PrintingService.instance.connect(device);
                        if (success) {
                          _checkStatus();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Connected to ${device.name ?? "Printer"}!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Connect'),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ] else if (settings.printerConnectionType == 'network') ...[
            // Wi-Fi / LAN Network Section
            Text(
              'Wi-Fi / Ethernet Network Printer (Raw TCP Port 9100)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the local IP address of your thermal receipt printer on the store Wi-Fi network.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Printer IP Address',
                      hintText: '192.168.1.100',
                      prefixIcon: Icon(Icons.lan),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '9100',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final ip = _ipController.text.trim();
                      final port = int.tryParse(_portController.text.trim()) ?? 9100;
                      notifier.updatePrinterNetworkConfig(ip: ip, port: port);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Network printer IP saved!'), backgroundColor: Colors.green),
                      );
                    },
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save IP'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingNetwork ? null : () => _testNetworkPrint(settings),
                    icon: _isTestingNetwork 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print, size: 16),
                    label: Text(_isTestingNetwork ? 'Testing...' : 'Test Print'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Windows / Desktop System Section
            Text(
              'Windows / System Installed Printer',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select an installed Windows/macOS printer driver for silent direct printing.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_systemPrinters.isEmpty)
              Row(
                children: [
                  const Text('No installed OS printers detected.'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _loadSystemPrinters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              )
            else
              DropdownButtonFormField<String>(
                value: _systemPrinters.any((p) => p.name == settings.selectedPrinterName)
                    ? settings.selectedPrinterName
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Default Thermal Printer',
                  prefixIcon: Icon(Icons.print),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('System Print Dialog (Default)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Always Show System Print Dialog'),
                  ),
                  ..._systemPrinters.map((p) => DropdownMenuItem<String>(
                    value: p.name,
                    child: Text(p.name),
                  )),
                ],
                onChanged: (val) {
                  notifier.updateSelectedPrinterName(val);
                },
              ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // 4. Auto-Print Toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-Print Receipt on Checkout', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Automatically print receipt when payment is marked complete'),
            value: settings.autoPrintReceipt,
            onChanged: (enabled) {
              notifier.updateAutoPrintReceipt(enabled);
            },
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // 5. Cash Drawer Configuration Section
          Row(
            children: [
              const Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryGreen, size: 22),
              const SizedBox(width: 8),
              Text(
                'Cash Drawer (මුදල් ලාච්චුව)',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Automatically kicks the cash drawer on Windows desktop when entering cash payment or completing cash sales. Supports ESC/POS RJ11/RJ12 printer kick and USB serial triggers.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Auto-Open on Cash Start
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-Eject Drawer when Starting Cash Payment', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Instantly opens drawer when Cash checkout starts or is chosen in POS'),
            value: settings.autoOpenCashDrawerOnCashStart,
            onChanged: (enabled) {
              notifier.updateAutoOpenCashDrawerOnCashStart(enabled);
            },
          ),

          // Auto-Open on Sale Complete
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-Eject Drawer on Completing Cash Sale', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Opens drawer when cash transaction payment is completed'),
            value: settings.autoOpenCashDrawerOnSaleComplete,
            onChanged: (enabled) {
              notifier.updateAutoOpenCashDrawerOnSaleComplete(enabled);
            },
          ),

          const SizedBox(height: 12),
          Text(
            'Drawer Trigger Hardware',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'printer',
                label: Text('Receipt Printer (RJ11/RJ12)'),
                icon: Icon(Icons.print),
              ),
              ButtonSegment<String>(
                value: 'com_port',
                label: Text('USB Serial Trigger (COM)'),
                icon: Icon(Icons.usb),
              ),
            ],
            selected: {settings.cashDrawerTriggerType},
            onSelectionChanged: (Set<String> newSelection) {
              notifier.updateCashDrawerTriggerType(newSelection.first);
            },
          ),

          if (settings.cashDrawerTriggerType == 'com_port') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _comPortController,
                    decoration: const InputDecoration(
                      labelText: 'Serial COM Port (e.g. COM1, COM2, COM3)',
                      hintText: 'COM1',
                      prefixIcon: Icon(Icons.settings_ethernet),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (val) {
                      notifier.updateCashDrawerComPort(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    notifier.updateCashDrawerComPort(_comPortController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('COM port saved!'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: const Text('Save Port'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isTestingCashDrawer ? null : () => _testCashDrawer(settings),
            icon: _isTestingCashDrawer
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryGreen),
            label: const Text('Test Eject Cash Drawer Now', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: AppTheme.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _OfflineMediaStorageCard extends ConsumerStatefulWidget {
  const _OfflineMediaStorageCard();

  @override
  ConsumerState<_OfflineMediaStorageCard> createState() => _OfflineMediaStorageCardState();
}

class _OfflineMediaStorageCardState extends ConsumerState<_OfflineMediaStorageCard> {
  bool _isDownloading = false;
  String? _downloadStatus;
  int _cachedCount = 0;
  String _cachedSize = '0 MB';

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final stats = await LocalMediaStorageService.instance.getStorageStats();
    if (mounted) {
      setState(() {
        _cachedCount = stats['count'] as int? ?? 0;
        _cachedSize = stats['formattedSize'] as String? ?? '0 MB';
      });
    }
  }

  Future<void> _downloadAllImages() async {
    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Fetching products...';
    });

    try {
      final products = await ref.read(productsProvider.future);
      await LocalMediaStorageService.instance.prefetchAllProductImages(
        products,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _downloadStatus = 'Downloading image $current of $total...';
            });
          }
        },
      );
      await _refreshStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ All product images downloaded to device storage!'),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading images: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryBlue),
            title: const Text('Offline Images & Media'),
            subtitle: Text('$_cachedCount images saved offline ($_cachedSize)'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshStats,
              tooltip: 'Refresh storage info',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.download_for_offline_rounded, color: AppTheme.primaryGreen),
            title: const Text('Download All Images to Device'),
            subtitle: Text(_downloadStatus ?? 'Store all product photos locally for 100% offline POS use'),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Download'),
              onPressed: _isDownloading ? null : _downloadAllImages,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
            title: const Text('Clear Local Image Cache'),
            subtitle: const Text('Free up disk space on this device'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Image Cache?'),
                  content: const Text('This will remove cached images from this device. They will be re-downloaded when viewed or synced.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear Cache', style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await LocalMediaStorageService.instance.clearImageCache();
                await _refreshStats();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Image cache cleared'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ReceiptSettingsPage extends ConsumerWidget {
  const _ReceiptSettingsPage();

  Future<void> _previewReceipt(BuildContext context, AppSettings settings) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Settings & Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_rounded),
            tooltip: 'Preview Receipt',
            onPressed: () => _previewReceipt(context, settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 1. Template Selection ───
          const _SectionHeader(title: 'Receipt Design Template'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose the visual layout for thermal printing and PDF receipts.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildTemplateTile(
                  title: 'Template 2 — Sri Lankan Retail POS (Recommended)',
                  subtitle: 'Itemized superstore receipt with standard price, our price, customer savings & Sinhala labels.',
                  isSelected: settings.receiptTemplate == 'sri_lankan_retail',
                  badgeText: 'POPULAR',
                  badgeColor: AppTheme.primaryGreen,
                  onTap: () => notifier.updateReceiptTemplate('sri_lankan_retail'),
                ),
                const SizedBox(height: 12),
                _buildTemplateTile(
                  title: 'Template 1 — QuickBill Classic',
                  subtitle: 'Compact 4-column POS slip (ITEM, QTY, PRICE, TOTAL) with prominent total box.',
                  isSelected: settings.receiptTemplate == 'classic',
                  badgeText: 'CLASSIC',
                  badgeColor: Colors.blueGrey,
                  onTap: () => notifier.updateReceiptTemplate('classic'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 2. Language Selection ───
          const _SectionHeader(title: 'Receipt Language'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: Colors.deepPurple),
                  title: const Text('Language Output', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_languageLabel(settings.receiptLanguage)),
                  trailing: DropdownButton<String>(
                    value: settings.receiptLanguage,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'si', child: Text('සිංහල (Sinhala)')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                      DropdownMenuItem(value: 'bilingual', child: Text('ද්විභාෂා (Bilingual)')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.updateReceiptLanguage(val);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.straighten_rounded, color: Colors.blue),
                  title: const Text('Paper Size', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(settings.printerPaperSize == '58mm' ? '58mm (Compact Mobile)' : '80mm (Standard POS)'),
                  trailing: DropdownButton<String>(
                    value: settings.printerPaperSize,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: '80mm', child: Text('80mm (Standard)')),
                      DropdownMenuItem(value: '58mm', child: Text('58mm (Compact)')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.updatePrinterPaperSize(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 3. Field Visibility Controls ───
          const _SectionHeader(title: 'Visible Receipt Fields'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Store Logo'),
                  subtitle: const Text('Print store logo at the top of receipt'),
                  value: settings.showReceiptLogo,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showLogo: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('1D Barcode'),
                  subtitle: const Text('Print scannable Code128 barcode at the bottom'),
                  value: settings.showReceiptBarcode,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showBarcode: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Standard Price (සදාන් මිල)'),
                  subtitle: const Text('Show gross / original product selling price'),
                  value: settings.showReceiptStandardPrice,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showStandardPrice: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Our Price (අපේ මිල)'),
                  subtitle: const Text('Show actual selling price used for the transaction'),
                  value: settings.showReceiptOurPrice,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showOurPrice: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Discount & Customer Savings (ලාභය)'),
                  subtitle: const Text('Display customer profit / total savings breakdown'),
                  value: settings.showReceiptDiscount,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showDiscount: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Tax (VAT)'),
                  subtitle: const Text('Show tax breakdown when tax is greater than zero'),
                  value: settings.showReceiptTax,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showTax: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Payment Details (ගෙවීම් / හුවමාරුව)'),
                  subtitle: const Text('Show cash received, change, and remaining balance'),
                  value: settings.showReceiptPaymentDetails,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showPaymentDetails: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Cashier Name'),
                  subtitle: const Text('Show cashier / operator name on slip'),
                  value: settings.showReceiptCashier,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showCashier: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Customer Details'),
                  subtitle: const Text('Show customer name and telephone when attached'),
                  value: settings.showReceiptCustomer,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) => notifier.updateReceiptToggles(showCustomer: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 4. Sensitive Internal Profit / Cost Section ───
          const _SectionHeader(title: 'Sensitive Merchant Data (Internal Controls)'),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sensitive internal data. Keep disabled on customer receipts unless used for internal audit slips.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Show Cost Price (ගැනුම් මිල)'),
                  subtitle: const Text('Print product cost price per item'),
                  value: settings.showReceiptCostPrice,
                  activeThumbColor: Colors.amber.shade800,
                  onChanged: (val) => notifier.updateReceiptToggles(showCostPrice: val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Show Business Profit (ව්‍යාපාරික ලාභය)'),
                  subtitle: const Text('Print store revenue minus cost on receipt'),
                  value: settings.showReceiptProfit,
                  activeThumbColor: Colors.amber.shade800,
                  onChanged: (val) => notifier.updateReceiptToggles(showProfit: val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── 5. Test Print Action ───
          ElevatedButton.icon(
            onPressed: () => _previewReceipt(context, settings),
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            label: const Text('Preview & Test Print Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTemplateTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'si':
        return 'සිංහල (Sinhala)';
      case 'en':
        return 'English';
      case 'ta':
        return 'தமிழ் (Tamil)';
      case 'bilingual':
        return 'ද්විභාෂා (Bilingual)';
      default:
        return code.toUpperCase();
    }
  }
}

