import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../utils/l10n_extensions.dart';
import '../utils/category_icon_util.dart';

class CategoryPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const CategoryPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No category data available', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: data.asMap().entries.map((entry) {
                final item = entry.value;
                final categoryStr = item['category'] as String?;
                final color = CategoryIconUtil.getColorForCategory(categoryStr);
                
                return PieChartSectionData(
                  color: color,
                  value: (item['total_sales'] as num).toDouble(),
                  title: '', // Title shown in legend instead
                  radius: 50,
                  badgeWidget: _Badge(context.getLocalizedCategory(item['category'] ?? 'Other'), color),
                  badgePositionPercentageOffset: 1.3,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 40),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: data.map((item) {
            final categoryStr = item['category'] as String?;
            final color = CategoryIconUtil.getColorForCategory(categoryStr);
            return _LegendItem(
              color: color,
              text: context.getLocalizedCategory(categoryStr ?? 'Other'),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
