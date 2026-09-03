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

class RefundReportScreen extends ConsumerWidget {
  const RefundReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refundsAsync = ref.watch(refundsProvider);
    final dateRange = ref.watch(reportDateRangeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.refundReport),
        actions: [
          refundsAsync.when(
            data: (refunds) => Row(
              children: [
                IconButton(
                  tooltip: l10n.exportCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  onPressed: () {
                    if (refunds.isNotEmpty) {
                      ExportService.instance.exportRefundsToCsv(refunds, dateRange.start, dateRange.end);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.noRefundsExport)),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: l10n.exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () {
                    if (refunds.isNotEmpty) {
                      PdfService.instance.generateRefundReport(refunds, dateRange.start, dateRange.end);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.noRefundsExport)),
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
        body: refundsAsync.when(
        data: (refunds) {
          if (refunds.isEmpty) {
            return Center(child: Text(l10n.noRefundsPeriod));
          }

          final totalRefunded = refunds.fold(0.0, (sum, r) => sum + (r['refund_amount'] as num).toDouble());

          return Column(
            children: [
              // Summary Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Text(l10n.totalRefunded, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.errorRed)),
                    const SizedBox(height: 8),
                    Text(
                      Formatters.currency(totalRefunded),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                    ),
                    Text(l10n.transactionsCount(refunds.length), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: refunds.length,
                  itemBuilder: (context, index) {
                    final refund = refunds[index];
                    final date = DateTime.parse(refund['return_date']);
                    final items = refund['items'] as List;

                    return AnimateIn(
                      delay: Duration(milliseconds: index * 20),
                      child: AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.errorRed,
                            child: Icon(Icons.settings_backup_restore, color: Colors.white, size: 20),
                          ),
                          title: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(refund['bill_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                Formatters.currency(refund['refund_amount']), 
                                style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${DateFormat('dd MMM, HH:mm').format(date)} • ${refund['payment_method'].toString().toUpperCase()}'),
                              Text(
                                items.map((i) => i['product_name']).join(', '),
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey.withValues(alpha: 0.8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (refund['reason'] != null && refund['reason'].toString().isNotEmpty)
                                Text(l10n.reasonLabel(refund['reason'].toString()), style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.returnedItemsHeading, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  ...items.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${Formatters.quantity(item['quantity'])} x ${item['product_name']}',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                              Text(
                                                item['condition'] == 'restockable' ? l10n.returnedToStock : l10n.damagedWaste,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: item['condition'] == 'restockable' ? AppTheme.primaryGreen : AppTheme.errorRed,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          Formatters.currency(item['total']),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  )),
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
