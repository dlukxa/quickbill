import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/preference_provider.dart';
import '../../models/inventory_alert.dart';
import '../../utils/formatters.dart';
import '../billing/billing_screen.dart';
import '../discount/discount_list_screen.dart';
import '../stock/stock_screen.dart';
import '../services/services_list_screen.dart';
import '../../providers/business_modules_provider.dart';
import '../reports/reports_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animate_in.dart';
import '../../widgets/cached_product_image.dart';
import '../settings/settings_screen.dart';
import '../customers/customer_list_screen.dart';
import '../suppliers/supplier_list_screen.dart';
import '../returns/sales_history_screen.dart';
import '../reports/expense_management_screen.dart';
import '../../providers/expense_provider.dart';
import 'smart_campaign_widget.dart';
import '../appointments/appointments_calendar_screen.dart';
import '../appointments/staff_schedule_screen.dart';
import '../orders/orders_board_screen.dart';

import '../../providers/forecasting_provider.dart';
import '../../providers/customer_insights_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../models/purchase.dart';
import '../../models/purchase_item.dart';
import '../suppliers/purchase_management_screen.dart';
import '../../providers/supplier_provider.dart';

import '../../providers/employee_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription.dart';
import '../../services/sync_service.dart';
import '../../models/employee.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../widgets/branch_switcher.dart';
import '../../providers/branch_provider.dart';
import '../auth/staff_login_handshake_dialog.dart';
import '../settings/employee_list_screen.dart';
import '../ai/ai_assistant_screen.dart';
import '../../services/backup_service.dart';
import '../../widgets/cloud_backups_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _dismissedBackupName;

  @override
  void initState() {
    super.initState();
    _loadBannerState();
    // Start background sync when home screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).startSync();
    });
  }

  Future<void> _loadBannerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('dismissed_backup_name');
      if (mounted) {
        setState(() {
          _dismissedBackupName = name;
        });
      }
    } catch (e) {
      debugPrint('Error loading banner state: $e');
    }
  }

  Future<void> _dismissBanner(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dismissed_backup_name', key);
      if (key == 'empty_db_setup_dismissed') {
        // If the user chooses to start fresh, initialize the pull timestamp to now
        // so that background sync doesn't indefinitely skip pulling new changes,
        // but only pulls changes that happen FROM NOW on.
        await prefs.setString('last_pull_timestamp', DateTime.now().toIso8601String());
      }
      if (mounted) {
        setState(() {
          _dismissedBackupName = key;
        });
      }
    } catch (e) {
      debugPrint('Error saving banner state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    final settings = ref.watch(settingsProvider);
    final todayStatsAsync = ref.watch(todayStatsProvider);
    final alertsAsync = ref.watch(inventoryAlertsProvider);
    final employeeAsync = ref.watch(currentEmployeeProvider);
    final currentEmployee = employeeAsync.value;

    final insightsAsync = ref.watch(customerInsightsProvider);
    final forecastsAsync = ref.watch(criticalForecastsProvider);
    
    final bool hasInsights = insightsAsync.valueOrNull?.any((i) => i.segment == CustomerSegment.atRisk || i.segment == CustomerSegment.bigSpender || i.segment == CustomerSegment.recent) ?? false;
    final bool hasForecasts = forecastsAsync.valueOrNull?.isNotEmpty ?? false;
    final bool hasAlerts = alertsAsync.valueOrNull?.isNotEmpty ?? false;
    
    final canViewReports = currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canViewReports ?? false);
    final canManageInventory = currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageInventory ?? false);
    
    final List<Widget> dashboardItems = [];
    final Widget? todaySalesWidget = canViewReports ? AnimateIn(
      child: todayStatsAsync.when(
        data: (stats) => _TodaySalesCard(stats: stats),
        loading: () => const _TodaySalesCard(stats: {
          'bill_count': 0,
          'total_sales': 0.0,
          'avg_bill': 0.0,
        }),
        error: (_, __) => const _TodaySalesCard(stats: {
          'bill_count': 0,
          'total_sales': 0.0,
          'avg_bill': 0.0,
        }),
      ),
    ) : null;
    if (hasInsights) {
      dashboardItems.add(
        const AnimateIn(
          delay: Duration(milliseconds: 150),
          child: SmartCampaignWidget(),
        )
      );
    }
    if (canManageInventory && hasForecasts) {
      dashboardItems.add(
        const AnimateIn(
          delay: Duration(milliseconds: 25),
          child: _SmartRestockWidget(),
        )
      );
    }
    if (hasAlerts) {
      dashboardItems.add(
        alertsAsync.when(
          data: (alerts) => AnimateIn(
            delay: const Duration(milliseconds: 50),
            child: _AlertsSection(alerts: alerts),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        )
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subTextColor = isDark ? Colors.white70 : const Color(0xFF475569);
            return AlertDialog(
              backgroundColor: context.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Exit App',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 18,
                ),
              ),
              content: Text(
                'Are you sure you want to exit QuickBill?',
                style: GoogleFonts.plusJakartaSans(
                  color: subTextColor,
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: TextStyle(color: subTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        );

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: BranchSwitcher(),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_account),
            tooltip: AppLocalizations.of(context)!.switchUser,
            onPressed: () => ref.read(currentEmployeeProvider.notifier).logout(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restoration Status
                if (ref.watch(syncStatusProvider) == SyncStatus.restoring)
                  AnimateIn(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.restoringData,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.restoringDataSubtitle,
                                  style: TextStyle(fontSize: 12, color: context.subText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Cloud Backup Available Banner (Shows if there are no local products or the user has an empty database)
                if ((ref.watch(productsProvider).value?.isEmpty ?? true) && _dismissedBackupName != 'empty_db_setup_dismissed')
                  AnimateIn(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cloud_download_rounded, color: AppTheme.primaryBlue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Set Up POS Terminal',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'No local product data detected. You can restore your data from a cloud backup or sync live data.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: context.subText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Action Buttons
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) {
                                      final isDark = Theme.of(ctx).brightness == Brightness.dark;
                                      final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
                                      final subTextColor = isDark ? Colors.white70 : const Color(0xFF475569);
                                      return AlertDialog(
                                        backgroundColor: context.cardColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Text(
                                          'Confirm Start Fresh',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            fontSize: 18,
                                          ),
                                        ),
                                        content: Text(
                                          'Are you sure you want to start with an empty database? Any existing cloud backups will be ignored.',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: subTextColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text('Cancel', style: TextStyle(color: subTextColor)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.errorRed,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (confirm == true) {
                                    _dismissBanner('empty_db_setup_dismissed');
                                  }
                                },
                                child: Text(
                                  'Start Fresh (Empty DB)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: context.subText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  final selectedBackup = await showModalBottomSheet<Map<String, dynamic>>(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    builder: (context) => const CloudBackupsSheet(isSelectionMode: true),
                                  );
                                  
                                  if (selectedBackup != null && context.mounted) {
                                    await BackupService.instance.restoreCloudBackup(context, selectedBackup['ref']);
                                  }
                                },
                                icon: const Icon(Icons.cloud_download_rounded, size: 14),
                                label: Text(
                                  'Restore Backup',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  await ref.read(syncServiceProvider).syncNow();
                                },
                                icon: const Icon(Icons.sync, size: 14),
                                label: Text(
                                  'Sync Live Data',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),


                if (todaySalesWidget != null) ...[
                  todaySalesWidget,
                  const SizedBox(height: 16),
                ],

                // Dashboards Layout (Responsive)
                if (dashboardItems.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double spacing = 16.0;
                      final double itemWidth = isTablet 
                          ? (constraints.maxWidth - spacing) / 2 
                          : constraints.maxWidth;
                          
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: dashboardItems.map((child) => ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: itemWidth),
                          child: child,
                        )).toList(),
                      );
                    },
                  ),
                
                if (dashboardItems.isNotEmpty)
                  const SizedBox(height: 16),

                // New Bill Button (HUGE)
                AnimateIn(
                  delay: const Duration(milliseconds: 100),
                  child: GradientButton(
                    height: 120, // More balanced height
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BillingScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          AppLocalizations.of(context)!.newBill,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24), // Increased spacing
                
                // Secondary Actions (Dynamic Grid based on permissions)
                Builder(
                  builder: (context) {
                    final List<Map<String, dynamic>> actions = [
                      if (ref.watch(businessModulesProvider).enableProducts && (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageInventory ?? false)))
                        {
                          'icon': Icons.inventory_2,
                          'label': AppLocalizations.of(context)!.stock,
                          'color': AppTheme.warningOrange,
                          'badgeCount': alertsAsync.value?.length,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen())),
                        },
                      if (ref.watch(businessModulesProvider).enableProducts && (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageInventory ?? false)))
                        {
                          'icon': Icons.local_offer,
                          'label': AppLocalizations.of(context)!.discounts,
                          'color': AppTheme.primaryBlue,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscountListScreen())),
                        },
                      if (ref.watch(businessModulesProvider).enableServices && (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageInventory ?? false)))
                        {
                          'icon': Icons.spa,
                          'label': AppLocalizations.of(context)!.services,
                          'color': AppTheme.primaryGreen,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesListScreen())),
                        },
                      if (ref.watch(businessModulesProvider).enableAppointments)
                        {
                          'icon': Icons.calendar_month,
                          'label': AppLocalizations.of(context)!.appointments,
                          'color': AppTheme.primaryPurple,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsCalendarScreen())),
                        },
                      if (ref.watch(businessModulesProvider).enableAppointments && (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageEmployees ?? false)))
                        {
                          'icon': Icons.schedule,
                          'label': AppLocalizations.of(context)!.staffSchedule,
                          'color': AppTheme.primaryBlue,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScheduleScreen())),
                        },
                      if (ref.watch(businessModulesProvider).enableCustomOrders)
                        {
                          'icon': Icons.assignment,
                          'label': AppLocalizations.of(context)!.customOrders,
                          'color': AppTheme.errorRed,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersBoardScreen())),
                        },
                      {
                        'icon': Icons.people,
                        'label': AppLocalizations.of(context)!.customers,
                        'color': AppTheme.primaryPurple,
                        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())),
                      },
                      if (ref.watch(businessModulesProvider).enableProducts && (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageInventory ?? false)))
                        {
                          'icon': Icons.business,
                          'label': AppLocalizations.of(context)!.suppliers,
                          'color': const Color(0xFF64748B),
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen())),
                        },
                      if (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canViewReports ?? false))
                        {
                          'icon': Icons.assessment,
                          'label': AppLocalizations.of(context)!.reports,
                          'color': AppTheme.primaryGreen,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                        },
                      if (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canViewReports ?? false))
                        {
                          'icon': Icons.money_off,
                          'label': AppLocalizations.of(context)!.expenses,
                          'color': AppTheme.errorRed,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseManagementScreen())),
                        },
                      if (ref.watch(businessModulesProvider).enableProducts && (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageInventory ?? false)))
                        {
                          'icon': Icons.shopping_bag,
                          'label': AppLocalizations.of(context)!.purchases,
                          'color': AppTheme.primaryGreen,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseManagementScreen())),
                        },
                      if (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canDeleteBill ?? false))
                        {
                          'icon': Icons.assignment_return,
                          'label': AppLocalizations.of(context)!.returns,
                          'color': AppTheme.errorRed,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
                        },
                      if (currentEmployee?.role == EmployeeRole.owner || (currentEmployee?.permissions.canManageEmployees ?? false))
                        {
                          'icon': Icons.people_outline,
                          'label': AppLocalizations.of(context)!.manageEmployees,
                          'color': AppTheme.primaryPurple,
                          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen())),
                        },
                      {
                        'icon': Icons.auto_awesome,
                        'label': 'Ask AI',
                        'color': AppTheme.primaryGreen,
                        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAssistantScreen())),
                      },
                    ];

                    return AnimateIn(
                      delay: const Duration(milliseconds: 200),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 4 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isTablet ? 1.5 : 1.35,
                        ),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final act = actions[index];
                          return _SecondaryActionCard(
                            icon: act['icon'] as IconData,
                            label: act['label'] as String,
                            color: act['color'] as Color,
                            badgeCount: act['badgeCount'] as int?,
                            onTap: act['onTap'] as VoidCallback,
                          );
                        },
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Sync Status
                AnimateIn(
                  delay: const Duration(milliseconds: 300),
                  child: Center(
                    child: _SyncStatusWidget(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

}

class _SmartRestockWidget extends ConsumerWidget {
  const _SmartRestockWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastsAsync = ref.watch(criticalForecastsProvider);

    return forecastsAsync.when(
      data: (forecasts) {
        if (forecasts.isEmpty) return const SizedBox.shrink();

        return Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              color: AppTheme.errorRed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.smartRestockUrgency,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () async {
                          // Quick PO Creation Logic
                          final suppliers = ref.read(suppliersProvider).value ?? [];
                          if (suppliers.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context)!.pleaseAddSupplierFirst)),
                            );
                            return;
                          }

                          // Use first supplier as default for quick PO
                          final defaultSupplier = suppliers.first;
                          
                          final List<PurchaseItem> items = [];
                          double total = 0;
                          for (final f in forecasts.take(5)) {
                            final product = ref.read(productByIdProvider(f.productId)).value;
                            if (product != null) {
                              items.add(PurchaseItem(
                                productId: product.id!,
                                productName: product.name,
                                quantity: f.recommendedReorder,
                                costPrice: product.costPrice ?? 0,
                              ));
                              total += (product.costPrice ?? 0) * f.recommendedReorder;
                            }
                          }

                          final purchase = Purchase(
                            supplierId: defaultSupplier.id!,
                            totalAmount: total,
                            date: DateTime.now(),
                            status: 'Pending',
                            items: items,
                            notes: 'Auto-generated from Smart Restock',
                          );

                          await ref.read(purchaseActionsProvider).createPurchase(purchase);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context)!.poCreatedFor(defaultSupplier.name))),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.createPo,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen())),
                        child: Text(
                          AppLocalizations.of(context)!.viewAll,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...forecasts.take(3).map((f) => _RestockItemRow(forecast: f)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RestockItemRow extends ConsumerWidget {
  final StockForecast forecast;
  const _RestockItemRow({required this.forecast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(forecast.productId));

    return productAsync.when(
      data: (product) {
        if (product == null) return const SizedBox.shrink();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: product.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedProductImage(
                          imageUrl: product.imageUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: const Icon(Icons.inventory_2, color: Colors.white, size: 20),
                        ),
                      )
                    : const Icon(Icons.inventory_2, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppLocalizations.of(context)!.outInDays(forecast.daysRemaining.toStringAsFixed(1)),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppLocalizations.of(context)!.reorder,
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${forecast.recommendedReorder.toStringAsFixed(0)} ${product.unit}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TodaySalesCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _TodaySalesCard({required this.stats});

  @override
  Widget build(BuildContext context) {

    // Safely convert to double
    final totalSales = (stats['total_sales'] as num?)?.toDouble() ?? 0.0;
    final billCount = (stats['bill_count'] as num?)?.toInt() ?? 0;
    
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.todaySales,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.subText,
                  letterSpacing: 1.5,
                ),
              ),
              Icon(
                Icons.today,
                color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            Formatters.currency(totalSales),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: context.onSurface,
              letterSpacing: -1.5,
            ),
          ),
          if (stats['refunds'] != null && (stats['refunds'] as num) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                AppLocalizations.of(context)!.refundedToday(Formatters.currency(stats['refunds'])),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.errorRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (stats['total_discounts'] != null && (stats['total_discounts'] as num) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings, size: 12, color: AppTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Total Savings: ${Formatters.currency(stats['total_discounts'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.subText.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 14,
                  color: context.subText,
                ),
                const SizedBox(width: 4),
                Text(
                  billCount == 1 
                    ? AppLocalizations.of(context)!.billGenerated(billCount.toString())
                    : AppLocalizations.of(context)!.billsGenerated(billCount.toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.subText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _SecondaryActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {

    return AppCard(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          if (badgeCount != null && badgeCount! > 0)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertsSection extends ConsumerWidget {
  final List<InventoryAlert> alerts;
  const _AlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final isCritical = alert.type == AlertType.expiring;
          final color = isCritical ? Colors.red : AppTheme.warningOrange;

          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () {
                    // Future: Navigate to detail
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCritical ? Icons.emergency : Icons.warning,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert.subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      final idToDismiss = alert.id;
                      Future.microtask(() {
                        ref.read(dismissedAlertsProvider.notifier).update((state) => {...state, idToDismiss});
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SyncStatusWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);

    Color color;
    IconData icon;
    String text;

    switch (status) {
      case SyncStatus.syncing:
        color = AppTheme.primaryBlue;
        icon = Icons.sync;
        text = AppLocalizations.of(context)!.syncing;
        break;
      case SyncStatus.error:
        color = Colors.red;
        icon = Icons.sync_problem;
        text = AppLocalizations.of(context)!.syncError;
        break;
      case SyncStatus.restoring:
        color = AppTheme.primaryBlue;
        icon = Icons.cloud_download;
        text = AppLocalizations.of(context)!.restoring;
        break;
      case SyncStatus.idle:
      default:
        color = AppTheme.primaryGreen;
        icon = Icons.cloud_done;
        text = lastSync == null ? AppLocalizations.of(context)!.syncActive : '${AppLocalizations.of(context)!.synced} ${_formatTimeAgo(context, lastSync)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == SyncStatus.syncing || status == SyncStatus.restoring)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            key: ValueKey(text), // Force rebuild on text change
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (status == SyncStatus.idle || status == SyncStatus.error) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () => ref.read(syncServiceProvider).syncNow(),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.refresh, size: 14, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(BuildContext context, DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    final l10n = AppLocalizations.of(context)!;
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes}${l10n.minShort} ${l10n.ago}';
    if (diff.inHours < 24) return '${diff.inHours}${l10n.hourShort} ${l10n.ago}';
    return '${diff.inDays}${l10n.dayShort} ${l10n.ago}';
  }
}
