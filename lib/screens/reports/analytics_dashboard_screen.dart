import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../generated/l10n/app_localizations_en.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../utils/l10n_extensions.dart';
import '../../services/ai/tflite_predictor_service.dart';
import '../../providers/preference_provider.dart';
import 'package:intl/intl.dart';

final aiInsightsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  return await TFLitePredictorService.instance.generateBackgroundInsights(1); // Default Branch 1
});

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProfitabilityProvider);
    final categoryAsync = ref.watch(categoryProfitabilityProvider);
    final topProfitableAsync = ref.watch(topProfitableProductsProvider);
    final expensesAsync = ref.watch(operatingExpensesProvider);
    final trendsAsync = ref.watch(profitabilityTrendsProvider);
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profitabilityAnalytics),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(summaryProfitabilityProvider);
          ref.invalidate(categoryProfitabilityProvider);
          ref.invalidate(topProfitableProductsProvider);
          ref.invalidate(operatingExpensesProvider);
          ref.invalidate(profitabilityTrendsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Net Profit & Margins
            _buildSummaryCard(context, summaryAsync),
            const SizedBox(height: 24),
            
            if (isTablet)
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAIInsightsSection(l10n, ref),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWaterfallSection(l10n, summaryAsync, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfitTrendSection(l10n, trendsAsync),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCategoryProfitSection(l10n, categoryAsync, context),
                            const SizedBox(height: 24),
                            _buildTopProductsSection(l10n, topProfitableAsync, context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAIInsightsSection(l10n, ref),
                  const SizedBox(height: 24),
                  _buildWaterfallSection(l10n, summaryAsync, context),
                  const SizedBox(height: 24),
                  _buildProfitTrendSection(l10n, trendsAsync),
                  const SizedBox(height: 24),
                  _buildCategoryProfitSection(l10n, categoryAsync, context),
                  const SizedBox(height: 24),
                  _buildTopProductsSection(l10n, topProfitableAsync, context),
                ],
              ),


            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  Widget _buildSummaryCard(BuildContext context, AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
              data: (summary) => _buildSummarySection(context, summary),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            );
  }

  Widget _buildAIInsightsSection(AppLocalizations l10n, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.aiPredictiveInsights, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            ref.watch(aiInsightsProvider).when(
               data: (insights) => _buildAIInsights(insights),
               loading: () => const LinearProgressIndicator(),
               error: (e, _) => Text('Error loading insights: $e'),
            ),
      ],
    );
  }

  Widget _buildWaterfallSection(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> summaryAsync, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profitWaterfall, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            summaryAsync.when(
              data: (summary) => _buildProfitWaterfall(context, summary),
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
      ],
    );
  }

  Widget _buildProfitTrendSection(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> trendsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profitabilityTrend, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: trendsAsync.when(
                data: (trends) => _ProfitTrendChart(data: trends),
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
      ],
    );
  }

  Widget _buildCategoryProfitSection(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> categoryAsync, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.categoryProfitability, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            categoryAsync.when(
              data: (categories) => _buildCategoryProfitability(categories, context),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
      ],
    );
  }

  Widget _buildTopProductsSection(AppLocalizations l10n, AsyncValue<List<Map<String, dynamic>>> topProfitableAsync, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.topProfitContributors, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            topProfitableAsync.when(
              data: (products) => _buildTopProfitableProducts(context, products),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
      ],
    );
  }


  Widget _buildSummarySection(BuildContext context, Map<String, dynamic> summary) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        AnimateIn(
          child: AppCard(
            padding: const EdgeInsets.all(24),
            color: AppTheme.primaryGreen,
            child: Column(
              children: [
                Text(l10n.netProfit.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(
                  Formatters.currency(summary['net_profit']),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(label: l10n.grossMargin, value: '${summary['gross_margin'].toStringAsFixed(1)}%', color: Colors.white),
                    _MiniStat(label: l10n.netMargin, value: '${summary['net_margin'].toStringAsFixed(1)}%', color: Colors.white),
                    _MiniStat(label: l10n.expenseRatio, value: '${summary['expense_ratio'].toStringAsFixed(1)}%', color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIInsights(List<String> insights) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      children: insights.map((insight) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryPurple.withValues(alpha: 0.15),
                AppTheme.primaryBlue.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppTheme.primaryPurple, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Insight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                    const SizedBox(height: 6),
                    Text(insight, style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildProfitWaterfall(BuildContext context, Map<String, dynamic> summary) {
    final l10n = AppLocalizations.of(context)!;
    final revenue = (summary['gross_revenue'] as num? ?? 1.0).toDouble();
    if (revenue == 0) return const SizedBox.shrink();
 
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _WaterfallRow(
            label: l10n.revenue,
            amount: summary['gross_revenue'] ?? 0.0,
            color: AppTheme.primaryBlue,
            percentage: 1.0,
          ),
          _WaterfallRow(
            label: l10n.cogs,
            amount: -(summary['cogs'] ?? 0.0),
            color: AppTheme.errorRed,
            percentage: (summary['cogs'] ?? 0.0) / revenue,
            isNegative: true,
          ),
          _WaterfallRow(
            label: l10n.operatingExpenses,
            amount: -summary['operating_expenses'],
            color: AppTheme.warningOrange,
            percentage: summary['operating_expenses'] / revenue,
            isNegative: true,
          ),
          const Divider(height: 24),
          _WaterfallRow(
            label: l10n.netProfit,
            amount: summary['net_profit'],
            color: AppTheme.primaryGreen,
            percentage: summary['net_profit'] / revenue,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProfitability(List<Map<String, dynamic>> categories, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        children: categories.map((cat) {
          final revenue = (cat['revenue'] as num? ?? 0.0).toDouble();
          final profit = (cat['profit'] as num? ?? 0.0).toDouble();
          final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;
 
          return ListTile(
            title: Text(context.getLocalizedCategory(cat['category'] ?? 'Other'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(l10n.marginPercent(margin.toStringAsFixed(1))),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatters.currency(profit), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                Text(l10n.netProfit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopProfitableProducts(BuildContext context, List<Map<String, dynamic>> products) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        children: products.map((p) {
          return ListTile(
            title: Text(p['product_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(l10n.soldUnits(p['quantity'] ?? 0)),
            trailing: Text(
              Formatters.currency(p['profit'] ?? 0.0),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
      ],
    );
  }
}

class _WaterfallRow extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;
  final double percentage;
  final bool isNegative;
  final bool isBold;

  const _WaterfallRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.percentage,
    this.isNegative = false,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
              Text(
                Formatters.currency(amount),
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: percentage.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfitTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _ProfitTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: 200, child: Center(child: Text(AppLocalizations.of(context)!.noTrendData)));

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: data.length > 1 ? (data.length - 1).toDouble() : 1.0,
          minY: 0, // Ensure Y axis starts at 0 for proper scaling
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.toInt().toDouble()) return const SizedBox();
                  if (value.toInt() >= data.length || value.toInt() < 0) return const SizedBox();
                  final dateStr = data[value.toInt()]['date'] as String;
                  final date = DateTime.parse(dateStr);
                  // Only show roughly 5 titles to avoid crowding
                  if (data.length > 5 && value.toInt() % (data.length ~/ 5) != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Revenue Line
            LineChartBarData(
              spots: data.asMap().entries.map((e) {
                final revenue = (e.value['revenue'] as num? ?? 0.0).toDouble();
                return FlSpot(e.key.toDouble(), revenue);
              }).toList(),
              color: AppTheme.warningOrange,
              barWidth: 3,
              isCurved: true,
              dotData: const FlDotData(show: true),
            ),
            // Net Profit Line
            LineChartBarData(
              spots: data.asMap().entries.map((e) {
                final revenue = (e.value['revenue'] as num? ?? 0.0).toDouble();
                final cogs = (e.value['cogs'] as num? ?? 0.0).toDouble();
                final expenses = (e.value['expenses'] as num? ?? 0.0).toDouble();
                return FlSpot(e.key.toDouble(), revenue - cogs - expenses);
              }).toList(),
              color: AppTheme.primaryGreen,
              barWidth: 3,
              isCurved: true,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
