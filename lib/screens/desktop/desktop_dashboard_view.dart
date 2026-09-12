import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/preference_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/sale_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/pos_l10n.dart';
import '../reports/analytics_dashboard_screen.dart';
import '../reports/profit_loss_screen.dart';
import '../reports/peak_hours_screen.dart';
import '../reports/reports_screen.dart';
import '../reports/employee_reports_screen.dart';

class DesktopDashboardView extends ConsumerWidget {
  final Function(int viewIndex)? onNavigateTo;

  const DesktopDashboardView({super.key, this.onNavigateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final isDark = settings.isDarkMode;
    final todayStatsAsync = ref.watch(todayStatsProvider);
    final topProductsAsync = ref.watch(topProductsProvider);
    final todaySalesAsync = ref.watch(todaySalesProvider);

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      color: bg,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayStatsProvider);
          ref.invalidate(topProductsProvider);
          ref.invalidate(profitLossProvider);
          ref.invalidate(todaySalesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        posL10n.storeDashboardTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        posL10n.dashboardSubtitle,
                        style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.bar_chart_rounded, size: 16),
                        label: Text(posL10n.allReports),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                        label: Text(posL10n.goToPos),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => onNavigateTo?.call(0),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 1. KPI Top Cards ──
              todayStatsAsync.when(
                data: (stats) {
                  final totalRevenue = (stats['totalSales'] as num?)?.toDouble() ?? 0.0;
                  final totalInvoices = (stats['totalOrders'] as num?)?.toInt() ?? 0;
                  final totalProfit = (stats['totalProfit'] as num?)?.toDouble() ?? 0.0;
                  final avgOrder = totalInvoices > 0 ? totalRevenue / totalInvoices : 0.0;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: posL10n.todaysRevenue,
                          value: Formatters.currency(totalRevenue),
                          icon: Icons.payments_rounded,
                          color: AppTheme.primaryGreen,
                          cardBg: cardBg,
                          border: border,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKpiCard(
                          title: posL10n.grossProfit,
                          value: Formatters.currency(totalProfit),
                          icon: Icons.trending_up_rounded,
                          color: AppTheme.primaryBlue,
                          cardBg: cardBg,
                          border: border,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKpiCard(
                          title: posL10n.billsInvoices,
                          value: totalInvoices.toString(),
                          icon: Icons.receipt_rounded,
                          color: Colors.amber.shade700,
                          cardBg: cardBg,
                          border: border,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKpiCard(
                          title: posL10n.averageTicket,
                          value: Formatters.currency(avgOrder),
                          icon: Icons.shopping_basket_rounded,
                          color: AppTheme.primaryPurple,
                          cardBg: cardBg,
                          border: border,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error loading stats: $e')),
              ),
              const SizedBox(height: 24),

              // ── 2. Middle Row: Sales Activity & Payment Distribution ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Hourly Sales Volume / Activity
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                posL10n.hourlySalesVelocity,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.analytics_rounded, size: 14),
                                label: const Text('Profitability Analytics'),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          todaySalesAsync.when(
                            data: (sales) {
                              if (sales.isEmpty) {
                                return SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text('No sales recorded yet today.', style: TextStyle(color: textSecondary)),
                                  ),
                                );
                              }

                              // Group sales by 2-hour slots: 8-10, 10-12, 12-14, 14-16, 16-18, 18-20, 20-22
                              final slots = List.generate(7, (_) => 0.0);
                              for (final s in sales) {
                                final hour = s.createdAt.hour;
                                if (hour >= 8 && hour < 10) slots[0] += s.total;
                                else if (hour >= 10 && hour < 12) slots[1] += s.total;
                                else if (hour >= 12 && hour < 14) slots[2] += s.total;
                                else if (hour >= 14 && hour < 16) slots[3] += s.total;
                                else if (hour >= 16 && hour < 18) slots[4] += s.total;
                                else if (hour >= 18 && hour < 20) slots[5] += s.total;
                                else if (hour >= 20) slots[6] += s.total;
                              }

                              final maxVal = slots.fold(100.0, (m, v) => v > m ? v : m);

                              return SizedBox(
                                height: 220,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxVal * 1.15,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          return BarTooltipItem(
                                            Formatters.currency(rod.toY),
                                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, meta) {
                                            const labels = ['8am', '10am', '12pm', '2pm', '4pm', '6pm', '8pm+'];
                                            final idx = val.toInt();
                                            if (idx >= 0 && idx < labels.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Text(labels[idx], style: TextStyle(fontSize: 11, color: textSecondary)),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barGroups: List.generate(slots.length, (i) {
                                      return BarChartGroupData(
                                        x: i,
                                        barRods: [
                                          BarChartRodData(
                                            toY: slots[i],
                                            color: AppTheme.primaryGreen,
                                            width: 28,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              );
                            },
                            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                            error: (_, __) => const SizedBox(height: 200, child: Center(child: Text('Chart unavailable'))),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right: Payment Methods Breakdown & Quick Launchers
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            posL10n.paymentMethodsBreakdown,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          todaySalesAsync.when(
                            data: (sales) {
                              double cashTotal = 0;
                              double cardTotal = 0;
                              double creditTotal = 0;
                              double otherTotal = 0;

                              for (final s in sales) {
                                switch (s.paymentMethod.toLowerCase()) {
                                  case 'cash':
                                    cashTotal += s.total;
                                    break;
                                  case 'card':
                                    cardTotal += s.total;
                                    break;
                                  case 'credit':
                                    creditTotal += s.total;
                                    break;
                                  default:
                                    otherTotal += s.total;
                                    break;
                                }
                              }

                              final grandTotal = cashTotal + cardTotal + creditTotal + otherTotal;

                              return Column(
                                children: [
                                  _buildPaymentRow(posL10n.cash, cashTotal, grandTotal, AppTheme.primaryGreen, textPrimary, textSecondary),
                                  const SizedBox(height: 8),
                                  _buildPaymentRow(posL10n.card, cardTotal, grandTotal, AppTheme.primaryBlue, textPrimary, textSecondary),
                                  const SizedBox(height: 8),
                                  _buildPaymentRow(posL10n.credit, creditTotal, grandTotal, Colors.orange.shade700, textPrimary, textSecondary),
                                  if (otherTotal > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildPaymentRow('Other / QR', otherTotal, grandTotal, AppTheme.primaryPurple, textPrimary, textSecondary),
                                  ],
                                ],
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const Text('Unable to load payment breakdown'),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Quick Navigation to Specialized Reports
                          Text('Quick Analysis', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickChip(context, 'P&L Statement', Icons.account_balance_wallet_rounded, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitLossScreen()));
                              }, isDark),
                              _buildQuickChip(context, 'Peak Hours', Icons.access_time_rounded, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const PeakHoursScreen()));
                              }, isDark),
                              _buildQuickChip(context, 'Staff Sales', Icons.badge_rounded, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeReportsScreen()));
                              }, isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 3. Bottom Row: Top Selling Products Leaderboard ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          posL10n.topSellingProducts,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.inventory_2_rounded, size: 14),
                          label: Text(posL10n.manageStock),
                          onPressed: () => onNavigateTo?.call(2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    topProductsAsync.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No product sales data available for this period.', style: TextStyle(color: textSecondary)),
                            ),
                          );
                        }

                        return Table(
                          columnWidths: const {
                            0: FixedColumnWidth(60),
                            1: FlexColumnWidth(4),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: border, width: 1.5)),
                              ),
                              children: [
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 12))),
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(posL10n.productCol, style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 12))),
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(posL10n.qtySoldCol, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 12))),
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(posL10n.totalRevenueCol, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 12))),
                              ],
                            ),
                            ...items.asMap().entries.map((entry) {
                              final idx = entry.key + 1;
                              final item = entry.value;
                              final name = item['product_name'] ?? item['name'] ?? 'Unknown Item';
                              final qty = (item['total_quantity'] as num?)?.toDouble() ?? 0.0;
                              final rev = (item['total_sales'] as num?)?.toDouble() ?? 0.0;

                              return TableRow(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: border.withValues(alpha: 0.5), width: 0.8)),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Text(idx.toString(), style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Text(name.toString(), style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Text(
                                      qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Text(
                                      Formatters.currency(rev),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                      error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Error loading top products: $e')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String method, double amount, double total, Color color, Color textPrimary, Color textSecondary) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(method, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
            Text(Formatters.currency(amount), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(BuildContext context, String label, IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
