import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';

class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportDateRangeProvider);
    final profitLossAsync = ref.watch(profitLossProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profitLossStatement)),
      body: profitLossAsync.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodBanner(context, dateRange),
            const SizedBox(height: 20),
            
            AnimateIn(
              child: _buildMainValue(
                label: l10n.netProfit.toUpperCase(),
                value: data['profit'],
                color: AppTheme.primaryGreen,
              ),
            ),
            
            const SizedBox(height: 24),
            
            AnimateIn(
              delay: const Duration(milliseconds: 100),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                      _ProfitDetailRow(
                        label: l10n.revenue,
                        value: data['gross_revenue'] ?? data['revenue'], // Use Gross if available
                        icon: Icons.add_circle_outline,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(height: 12),
                      _ProfitDetailRow(
                        label: l10n.discountsGiven,
                        value: data['discounts'] ?? 0.0,
                        icon: Icons.remove_circle_outline,
                        color: Colors.orange,
                        valuePrefix: '-',
                      ),
                      const SizedBox(height: 12),
                      _ProfitDetailRow(
                        label: l10n.refunds,
                        value: data['refunds'] ?? 0.0,
                        icon: Icons.assignment_return_outlined,
                        color: Colors.purple,
                        valuePrefix: '-',
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    _ProfitDetailRow(
                      label: l10n.cogs,
                      value: data['cogs'],
                      icon: Icons.remove_circle_outline,
                      color: AppTheme.errorRed,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(thickness: 2),
                    ),
                    _ProfitDetailRow(
                      label: l10n.grossProfit,
                      value: data['profit'],
                      icon: Icons.check_circle_outline,
                      color: AppTheme.primaryGreen,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            AppCard(
              padding: const EdgeInsets.all(16),
              color: Colors.blueGrey,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.profitCalculationNote,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPeriodBanner(BuildContext context, ReportDateRange range) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          l10n.forPeriod(Formatters.fullDate(range.start), Formatters.fullDate(range.end)),
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildMainValue({required String label, required num value, required Color color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(
          Formatters.currency(value),
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _ProfitDetailRow extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  final Color color;
  final bool isBold;

  const _ProfitDetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isBold = false,
    this.valuePrefix = '',
  });

  final String valuePrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '$valuePrefix${Formatters.currency(value)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
