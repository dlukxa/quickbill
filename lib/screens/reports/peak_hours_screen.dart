import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class PeakHoursScreen extends ConsumerStatefulWidget {
  const PeakHoursScreen({super.key});

  @override
  ConsumerState<PeakHoursScreen> createState() => _PeakHoursScreenState();
}

class _PeakHoursScreenState extends ConsumerState<PeakHoursScreen> {
  bool _showRevenue = true; // toggle between revenue and count

  String _getDayLabel(BuildContext context, int dayIndex) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.E(locale).format(DateTime(2026, 6, 14 + dayIndex));
  }

  @override
  Widget build(BuildContext context) {
    final peakAsync = ref.watch(peakHoursProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.peakHours),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppTheme.primaryGreen,
                selectedForegroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 11),
              ),
              segments: [
                ButtonSegment(value: true, label: Text(l10n.revenue)),
                ButtonSegment(value: false, label: Text(l10n.countLabel)),
              ],
              selected: {_showRevenue},
              onSelectionChanged: (s) => setState(() => _showRevenue = s.first),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(peakHoursProvider),
        child: peakAsync.when(
          data: (data) {
            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(l10n.noSalesDataPeriod, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            // Build lookup: (day, hour) → value
            final Map<String, double> lookup = {};
            for (final row in data) {
              final day = (row['day_of_week'] as int? ?? 0);
              final hour = (row['hour'] as int? ?? 0);
              final value = _showRevenue
                  ? (row['total_sales'] as num? ?? 0).toDouble()
                  : (row['bill_count'] as num? ?? 0).toDouble();
              lookup['${day}_$hour'] = value;
            }

            final maxValue = lookup.values.isEmpty ? 1.0 : lookup.values.reduce((a, b) => a > b ? a : b);

            // Summary stats
            double bestVal = 0;
            int bestDay = 0, bestHour = 0;
            double worstVal = double.infinity;
            int worstDay = 0, worstHour = 0;

            for (final row in data) {
              final d = row['day_of_week'] as int? ?? 0;
              final h = row['hour'] as int? ?? 0;
              final v = _showRevenue
                  ? (row['total_sales'] as num? ?? 0).toDouble()
                  : (row['bill_count'] as num? ?? 0).toDouble();
              if (v > bestVal) { bestVal = v; bestDay = d; bestHour = h; }
              if (v < worstVal) { worstVal = v; worstDay = d; worstHour = h; }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period line
                Text(
                  '${Formatters.date(dateRange.start)} – ${Formatters.date(dateRange.end)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: l10n.busiest,
                        title: '${_getDayLabel(context, bestDay)} ${_fmtHour(bestHour)}',
                        subtitle: _showRevenue
                            ? Formatters.currency(bestVal)
                            : l10n.transactionsCount(bestVal.toInt()),
                        color: AppTheme.primaryGreen,
                        icon: Icons.bolt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: l10n.quietest,
                        title: '${_getDayLabel(context, worstDay)} ${_fmtHour(worstHour)}',
                        subtitle: _showRevenue
                            ? Formatters.currency(worstVal)
                            : l10n.transactionsCount(worstVal.toInt()),
                        color: AppTheme.warningOrange,
                        icon: Icons.access_time,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Heatmap
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.activityHeatmap,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.1)),
                          Row(children: [
                            _LegendDot(color: Colors.grey.shade100, label: l10n.low),
                            const SizedBox(width: 6),
                            _LegendDot(color: AppTheme.primaryGreen.withValues(alpha: 0.5), label: ''),
                            const SizedBox(width: 6),
                            _LegendDot(color: AppTheme.primaryGreen, label: l10n.high),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Hour labels row
                      Row(
                        children: [
                          const SizedBox(width: 28), // space for day label
                          ...List.generate(24, (h) {
                            final showLabel = h % 4 == 0;
                            return Expanded(
                              child: Center(
                                child: Text(
                                  showLabel ? '${h}h' : '',
                                  style: const TextStyle(fontSize: 7, color: Colors.grey),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Day rows
                      ...List.generate(7, (dayIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  _getDayLabel(context, dayIndex),
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              ),
                              ...List.generate(24, (hour) {
                                final val = lookup['${dayIndex}_$hour'] ?? 0.0;
                                final intensity = maxValue > 0 ? (val / maxValue) : 0.0;
                                return Expanded(
                                  child: Tooltip(
                                    message: '${_getDayLabel(context, dayIndex)} ${_fmtHour(hour)}\n'
                                        '${_showRevenue ? Formatters.currency(val) : l10n.transactionsCount(val.toInt())}',
                                    child: Container(
                                      height: 18,
                                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                      decoration: BoxDecoration(
                                        color: intensity == 0
                                            ? Colors.grey.shade100
                                            : AppTheme.primaryGreen.withValues(alpha: intensity.clamp(0.1, 1.0)),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Top 5 hours table
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.top5PeakSlots,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1.1)),
                      const SizedBox(height: 12),
                      ..._buildTopSlots(context, data, lookup),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  List<Widget> _buildTopSlots(
      BuildContext context, List<Map<String, dynamic>> data, Map<String, double> lookup) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = List<MapEntry<String, double>>.from(lookup.entries)
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();
    return top5.asMap().entries.map((e) {
      final rank = e.key + 1;
      final parts = e.value.key.split('_');
      final day = int.parse(parts[0]);
      final hour = int.parse(parts[1]);
      final val = e.value.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: rank == 1
                    ? AppTheme.primaryGreen
                    : AppTheme.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rank == 1 ? Colors.white : AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_getDayLabel(context, day)}  ${_fmtHour(hour)} – ${_fmtHour(hour + 1)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              _showRevenue ? Formatters.currency(val) : l10n.transactionsCount(val.toInt()),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _fmtHour(int h) {
    final hour = h % 24;
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    ]);
  }
}
