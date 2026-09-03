import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../generated/l10n/app_localizations_en.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../providers/branch_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/sales_chart.dart';
import '../../widgets/category_pie_chart.dart';
import 'sales_report_screen.dart';
import 'profit_loss_screen.dart';
import 'inventory_report_screen.dart';
import 'refund_report_screen.dart';
import 'damage_report_screen.dart';
import 'supplier_returns_report_screen.dart';
import 'employee_reports_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'peak_hours_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportDateRangeProvider);
    final salesChartAsync = ref.watch(salesChartProvider);
    final profitLossAsync = ref.watch(profitLossProvider);
    final inventoryAsync = ref.watch(inventoryAuditProvider);
    final topProductsAsync = ref.watch(topProductsProvider);
    final topCustomersAsync = ref.watch(topCustomersProvider);
    final categorySalesAsync = ref.watch(categorySalesProvider);
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsDashboard),
        actions: [
          // Global View Toggle (Only show if multiple branches exist)
          if (ref.watch(branchProvider).branches.length > 1)
            Row(
              children: [
                Text(l10n.globalView, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Switch(
                  value: ref.watch(isConsolidatedProvider),
                  onChanged: (val) => ref.read(isConsolidatedProvider.notifier).state = val,
                  activeColor: AppTheme.primaryBlue,
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _showDateRangePicker(context, ref, dateRange),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesChartProvider);
          ref.invalidate(profitLossProvider);
          ref.invalidate(inventoryAuditProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period Indicator
            _buildPeriodHeader(context, dateRange, ref),
            const SizedBox(height: 12),
            // Preset Filters
            _buildPresetFilters(context, ref, dateRange),
            const SizedBox(height: 16),
            
            // P&L Overview Cards
            _buildPLCards(l10n, profitLossAsync),
            const SizedBox(height: 20),

            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSalesTrendCard(l10n, salesChartAsync),
                        const SizedBox(height: 20),
                        _buildInventoryCard(l10n, inventoryAsync),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildCategorySalesCard(l10n, categorySalesAsync),
                        const SizedBox(height: 20),
                        _buildTopProductsCard(l10n, topProductsAsync),
                        const SizedBox(height: 20),
                        _buildTopCustomersCard(l10n, topCustomersAsync),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildSalesTrendCard(l10n, salesChartAsync),
                  const SizedBox(height: 20),
                  _buildCategorySalesCard(l10n, categorySalesAsync),
                  const SizedBox(height: 20),
                  _buildInventoryCard(l10n, inventoryAsync),
                  const SizedBox(height: 20),
                  _buildTopProductsCard(l10n, topProductsAsync),
                  const SizedBox(height: 20),
                  _buildTopCustomersCard(l10n, topCustomersAsync),
                ],
              ),
            
            const SizedBox(height: 20),
            Text(l10n.detailedReports.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            
            if (isTablet)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _buildDetailedReportTiles(context, l10n).map((tile) {
                  return SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 32 - 12) / 2, // 2 columns
                    child: tile,
                  );
                }).toList(),
              )
            else
              Column(
                children: _buildDetailedReportTiles(context, l10n),
              ),


            const SizedBox(height: 40), // Space at bottom
          ],
        ),
      ),
    );
  }
  Widget _buildPLCards(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> profitLossAsync) {
    return profitLossAsync.when(
              data: (pl) => Row(
                children: [
                  Expanded(child: _SummaryCard(
                    label: l10n.revenue,
                    value: Formatters.currency(pl['revenue']),
                    color: AppTheme.primaryBlue,
                    icon: Icons.trending_up,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(
                    label: l10n.netProfit,
                    value: Formatters.currency(pl['profit']),
                    color: AppTheme.primaryGreen,
                    icon: Icons.account_balance_wallet,
                  )),
                ],
              ),
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            );
  }

  Widget _buildSalesTrendCard(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> salesChartAsync) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.salesTrend.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          salesChartAsync.when(
            data: (data) => SalesChart(data: data),
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySalesCard(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> categorySalesAsync) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.salesByCategory.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 24),
          categorySalesAsync.when(
            data: (data) => CategoryPieChart(data: data),
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> inventoryAsync) {
    return inventoryAsync.when(
              data: (inv) => AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.inventorySnapshot.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 16),
                    _ReportRow(
                      label: l10n.totalStockValueRetail,
                      value: Formatters.currency(inv['retail_value']),
                      color: AppTheme.primaryBlue,
                    ),
                    const Divider(),
                    _ReportRow(
                      label: l10n.totalStockValueCost,
                      value: Formatters.currency(inv['cost_value']),
                      color: Colors.blueGrey,
                    ),
                    const Divider(),
                    _ReportRow(
                      label: l10n.potentialProfit,
                      value: Formatters.currency((inv['retail_value'] ?? 0) - (inv['cost_value'] ?? 0)),
                      color: AppTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Error loading inventory data'),
            );
  }

  Widget _buildTopProductsCard(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> topProductsAsync) {
    return AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.topSellingProducts.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 16),
                  topProductsAsync.when(
                    data: (products) => Column(
                      children: products.map((p) => _InsightRow(
                        label: p['product_name'] ?? 'Unknown',
                        value: '${p['total_qty']} units',
                        amount: Formatters.currency(p['total_sales']),
                      )).toList(),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Error loading top products'),
                  ),
                ],
              ),
            );
  }

  Widget _buildTopCustomersCard(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> topCustomersAsync) {
    return AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.highValueCustomers.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 16),
                  topCustomersAsync.when(
                    data: (customers) => Column(
                      children: customers.map((c) => _InsightRow(
                        label: c['customer_name'] ?? 'Guest',
                        value: '${c['visit_count']} visits',
                        amount: Formatters.currency(c['total_spent']),
                      )).toList(),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Error loading top customers'),
                  ),
                ],
              ),
            );
  }

  List<Widget> _buildDetailedReportTiles(BuildContext context, AppLocalizations l10n) {
    return [

                _PremiumReportTile(
                  icon: Icons.analytics, color: AppTheme.primaryGreen,
                  title: l10n.profitabilityAnalytics, subtitle: l10n.profitabilityAnalyticsDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.receipt_long, color: AppTheme.primaryBlue,
                  title: l10n.salesReport, subtitle: l10n.salesReportDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.pie_chart, color: AppTheme.warningOrange,
                  title: l10n.profitLoss, subtitle: l10n.profitLossDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitLossScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.remove_shopping_cart, color: AppTheme.errorRed,
                  title: l10n.damageAndWasteReport, subtitle: l10n.damageAndWasteReportDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageReportScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.local_shipping, color: AppTheme.primaryBlue,
                  title: l10n.supplierReturnsReport, subtitle: l10n.supplierReturnsReportDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierReturnsReportScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.inventory, color: AppTheme.primaryPurple,
                  title: l10n.inventoryAudit, subtitle: l10n.inventoryAuditDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryReportScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.settings_backup_restore, color: AppTheme.errorRed,
                  title: l10n.refundReport, subtitle: l10n.refundReportDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundReportScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.people, color: Colors.teal,
                  title: l10n.employeePerformance, subtitle: l10n.employeePerformanceDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeReportsScreen())),
                ),
                _PremiumReportTile(
                  icon: Icons.grid_on, color: AppTheme.primaryPurple,
                  title: l10n.peakHours, subtitle: l10n.peakHoursDesc,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeakHoursScreen())),
                ),
              
    ];
  }


  Widget _buildPresetFilters(BuildContext context, WidgetRef ref, ReportDateRange current) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PresetChip(
            label: l10n.today,
            preset: ReportPreset.day,
            selected: current.preset == ReportPreset.day,
            onTap: () => ref.read(reportDateRangeProvider.notifier).state = ReportDateRange.fromPreset(ReportPreset.day),
          ),
          _PresetChip(
            label: l10n.thisWeek,
            preset: ReportPreset.week,
            selected: current.preset == ReportPreset.week,
            onTap: () => ref.read(reportDateRangeProvider.notifier).state = ReportDateRange.fromPreset(ReportPreset.week),
          ),
          _PresetChip(
            label: l10n.thisMonth,
            preset: ReportPreset.month,
            selected: current.preset == ReportPreset.month,
            onTap: () => ref.read(reportDateRangeProvider.notifier).state = ReportDateRange.fromPreset(ReportPreset.month),
          ),
          _PresetChip(
            label: l10n.threeMonths,
            preset: ReportPreset.threeMonths,
            selected: current.preset == ReportPreset.threeMonths,
            onTap: () => ref.read(reportDateRangeProvider.notifier).state = ReportDateRange.fromPreset(ReportPreset.threeMonths),
          ),
          _PresetChip(
            label: l10n.thisYear,
            preset: ReportPreset.year,
            selected: current.preset == ReportPreset.year,
            onTap: () => ref.read(reportDateRangeProvider.notifier).state = ReportDateRange.fromPreset(ReportPreset.year),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodHeader(BuildContext context, ReportDateRange range, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final start = DateFormat('MMM dd').format(range.start);
    final end = DateFormat('MMM dd, yyyy').format(range.end);
    final isConsolidated = ref.watch(isConsolidatedProvider);
    final accentColor = isConsolidated ? AppTheme.primaryGreen : AppTheme.primaryBlue;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConsolidated ? Icons.business : Icons.date_range, 
              size: 14, 
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isConsolidated 
                  ? l10n.globalPeriod(start, end)
                  : l10n.showingPeriod(start, end),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, 
                fontSize: 13,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context, WidgetRef ref, ReportDateRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = current.copyWith(
        start: picked.start,
        end: picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReportRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final ReportPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryGreen : context.cardColor,
              gradient: selected ? AppTheme.primaryGradient : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? Colors.transparent : context.borderColor.withValues(alpha: 0.5),
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_circle, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                ],
                Text(
                  label, 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, 
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : context.subText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String label;
  final String value;
  final String amount;

  const _InsightRow({required this.label, required this.value, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
        ],
      ),
    );
  }
}

class _PremiumReportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PremiumReportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1);
    final subText = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: subText, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: subText.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
