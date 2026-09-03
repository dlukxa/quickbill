import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class EmployeeReportsScreen extends ConsumerWidget {
  const EmployeeReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(employeePerformanceProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeePerformance),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(employeePerformanceProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
             Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: AppTheme.primaryPurple),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.performanceReport, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${Formatters.date(dateRange.start)} - ${Formatters.date(dateRange.end)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            performanceAsync.when(
              data: (data) {
                if (data.isEmpty) {
                  return Center(child: Text(l10n.noPerformanceData));
                }
                return Column(
                  children: data.map((employeeData) {
                    final name = employeeData['employee_name'] as String;
                    final bills = employeeData['bills_count'] as int;
                    final sales = (employeeData['total_sales'] as num).toDouble();
                    final hours = (employeeData['hours_worked'] as num).toDouble();

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(Formatters.currency(sales), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _MetricItem(l10n.billsLabel, bills.toString(), Icons.receipt_long),
                              _MetricItem(l10n.hoursLabel, hours.toStringAsFixed(1), Icons.access_time),
                              _MetricItem(l10n.avgBillLabel, bills > 0 ? Formatters.currency(sales / bills) : '-', Icons.show_chart), // Using show_chart
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricItem(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
