import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/report_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/export_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import 'package:fl_chart/fl_chart.dart';

class DamageReportScreen extends ConsumerWidget {
  const DamageReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final damageAsync = ref.watch(damageAndWasteProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
        title: Text(l10n.damageAndWasteReport),
        actions: [
          damageAsync.when(
            data: (items) => Row(
              children: [
                IconButton(
                  tooltip: l10n.exportCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: () {
                    if (items.isNotEmpty) {
                      ExportService.instance.exportDamageReportToCsv(items, dateRange.start, dateRange.end);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.noRefundsExport)), // Reuse
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: l10n.exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () {
                    if (items.isNotEmpty) {
                      PdfService.instance.generateDamageReportPdf(items, dateRange.start, dateRange.end);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.noRefundsExport)), // Reuse
                      );
                    }
                  },
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'History'),
            Tab(text: 'Analysis'),
          ],
        ),
      ),
      body: damageAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No damage or waste recorded in this period.'));
          }

          final totalValue = items.fold(0.0, (sum, i) => sum + (i['cost_value'] as num).toDouble());

          return Column(
            children: [
              // Summary Header
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.errorRed, Color(0xFF991B1B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.errorRed.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(l10n.totalValueLost, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text(
                      Formatters.currency(totalValue),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.totalItemsWrittenOff(items.length), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // History Tab
                    GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 450,
                        mainAxisExtent: 140,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final date = DateTime.parse(item['date']);
                        final isWriteOff = item['source'] == 'write_off';

                        return AnimateIn(
                          delay: Duration(milliseconds: index * 20),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.errorRed.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.errorRed,
                                    child: Icon(
                                      isWriteOff ? Icons.remove_shopping_cart : Icons.settings_backup_restore, 
                                      color: Colors.white, 
                                      size: 20
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['product_name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Formatters.currency(item['cost_value']),
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${Formatters.quantity(item['quantity'])} Units • ${DateFormat('dd MMM, HH:mm').format(date)}',
                                          style: TextStyle(fontSize: 13, color: Colors.blueGrey.withValues(alpha: 0.8)),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item['reason']?.toString() ?? 'No reason provided',
                                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ),
                        );
                      },
                    ),

                    // Analysis Tab
                    _DamageAnalysisView(items: items),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    ));
  }
}

class _DamageAnalysisView extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  
  const _DamageAnalysisView({required this.items});

  @override
  Widget build(BuildContext context) {
    // Aggregate by Reason
    final reasonTotals = <String, double>{};
    // Aggregate by Product
    final productTotals = <String, double>{};
    // Aggregate by Type (Write-off vs Return)
    double manualTotal = 0;
    double returnTotal = 0;

    for (final item in items) {
      final value = (item['cost_value'] as num).toDouble();
      
      // Reason
      var reason = item['reason']?.toString() ?? 'Other';
      if (reason.isEmpty) reason = 'Other';
      // simplify reason string if it has notes
      if (reason.contains('-')) {
        reason = reason.split('-').first.trim();
      }
      reasonTotals[reason] = (reasonTotals[reason] ?? 0) + value;

      // Product
      final product = item['product_name']?.toString() ?? 'Unknown';
      productTotals[product] = (productTotals[product] ?? 0) + value;

      // Type
      if (item['source'] == 'write_off') {
        manualTotal += value;
      } else {
        returnTotal += value;
      }
    }

    final sortedProducts = productTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = sortedProducts.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Source Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 16),
              _buildRow('Manual Write-offs', manualTotal, manualTotal + returnTotal),
              const SizedBox(height: 8),
              _buildRow('Damaged Returns', returnTotal, manualTotal + returnTotal),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        if (reasonTotals.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loss by Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 16),
                ...reasonTotals.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRow(e.key, e.value, manualTotal + returnTotal),
                )),
              ],
            ),
          ),
          
        const SizedBox(height: 16),
        
        if (topProducts.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Most Damaged Products (Value)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 16),
                ...topProducts.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(
                    Formatters.currency(e.value),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRow(String label, double value, double total) {
    if (total == 0) return const SizedBox.shrink();
    final pct = value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(Formatters.currency(value), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
          color: AppTheme.errorRed,
        ),
      ],
    );
  }
}

