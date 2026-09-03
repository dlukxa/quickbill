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

class SupplierReturnsReportScreen extends ConsumerWidget {
  const SupplierReturnsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(supplierReturnsProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supplierReturnsReport),
        actions: [
          returnsAsync.when(
            data: (items) => Row(
              children: [
                IconButton(
                  tooltip: l10n.exportCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: () {
                    if (items.isNotEmpty) {
                      ExportService.instance.exportSupplierReturnsReportToCsv(items, dateRange.start, dateRange.end);
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
                      PdfService.instance.generateSupplierReturnsReportPdf(items, dateRange.start, dateRange.end);
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
      ),
      body: returnsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No supplier returns recorded in this period.'));
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
                    colors: [AppTheme.primaryBlue, Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(l10n.totalReturnedValue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text(
                      Formatters.currency(totalValue),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.totalItemsReturned(items.length), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              Expanded(
                child: GridView.builder(
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

                    return AnimateIn(
                      delay: Duration(milliseconds: index * 20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppTheme.primaryBlue,
                                child: Icon(
                                  Icons.local_shipping, 
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
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
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
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
