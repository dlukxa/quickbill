import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';
import '../../config/theme.dart';
import '../../widgets/app_card.dart';

class ProductAnalysisScreen extends ConsumerWidget {
  final Product product;

  const ProductAnalysisScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(productAnalyticsProvider(product.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('${product.name} Analytics'),
      ),
      body: analyticsAsync.when(
        data: (data) {
          final overall = data['overall'] as Map<String, dynamic>? ?? {};
          final monthly = data['monthly'] as List<dynamic>? ?? [];
          final recent = data['recent'] as List<dynamic>? ?? [];

          final totalQty = (overall['total_qty'] as num?)?.toDouble() ?? 0.0;
          final totalRevenue = (overall['total_revenue'] as num?)?.toDouble() ?? 0.0;
          final totalProfit = (overall['total_profit'] as num?)?.toDouble() ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCards(totalQty, totalRevenue, totalProfit),
                const SizedBox(height: 24),
                
                if (monthly.isNotEmpty) ...[
                  const Text('Revenue Trend (Last 6 Months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  AppCard(
                    child: SizedBox(
                      height: 250,
                      child: _buildMonthlyChart(monthly),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text('Recent Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (recent.isNotEmpty)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recent.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sale = recent[index] as Map<String, dynamic>;
                        final date = DateTime.tryParse(sale['sale_date'].toString());
                        final formattedDate = date != null ? Formatters.date(date) : 'Unknown Date';
                        
                        return ListTile(
                          title: Text(sale['customer_name']?.toString() ?? 'Walk-in Customer'),
                          subtitle: Text('$formattedDate • Qty: ${sale['quantity']}'),
                          trailing: Text(
                            Formatters.currency((sale['total'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No recent sales found.')),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading analytics: $err')),
      ),
    );
  }

  Widget _buildOverviewCards(double qty, double revenue, double profit) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard('Units Sold', Formatters.number(qty), Icons.shopping_bag_outlined, Colors.purple),
            _buildStatCard('Revenue', Formatters.currency(revenue), Icons.attach_money, AppTheme.primaryBlue),
            _buildStatCard('Profit Estimate', Formatters.currency(profit), Icons.trending_up, AppTheme.primaryGreen),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(List<dynamic> monthlyData) {
    final spots = <FlSpot>[];
    double maxY = 0;
    final titles = <String>[];

    for (int i = 0; i < monthlyData.length; i++) {
      final month = monthlyData[i] as Map<String, dynamic>;
      final revenue = (month['revenue'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), revenue));
      final monthStr = month['month'].toString();
      String formattedMonth = monthStr.split('-').last;
      try {
        final parts = monthStr.split('-');
        if (parts.length >= 2) {
          final m = int.tryParse(parts[1]);
          if (m != null && m >= 1 && m <= 12) {
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            formattedMonth = months[m - 1];
          }
        }
      } catch (_) {}
      titles.add(formattedMonth);

      if (revenue > maxY) {
        maxY = revenue;
      }
    }

    // Add a bit of padding to the top of chart
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value != value.toInt().toDouble()) return const SizedBox.shrink();
                final index = value.toInt();
                if (index < 0 || index >= titles.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(titles[index], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (monthlyData.length - 1).toDouble() > 0 ? (monthlyData.length - 1).toDouble() : 1,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryBlue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
