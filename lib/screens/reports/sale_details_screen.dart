import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/sale.dart';
import '../../providers/preference_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/share_service.dart';
import '../../services/printing_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../returns/process_return_screen.dart';

class SaleDetailsScreen extends ConsumerWidget {
  final Sale sale;

  const SaleDetailsScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billNo(sale.billNumber)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Info Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(l10n.dateLabel, DateFormat('dd MMM yyyy').format(sale.createdAt)),
                  _buildDetailRow(l10n.timeLabel, DateFormat('hh:mm a').format(sale.createdAt)),
                  _buildDetailRow(l10n.paymentLabel, sale.paymentMethod.toUpperCase()),
                  if (sale.customerName != null) ...[
                    const Divider(),
                    _buildDetailRow(l10n.customer, sale.customerName!),
                    if (sale.customerPhone != null)
                      _buildDetailRow(l10n.phoneLabel, sale.customerPhone!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items List
            Text(l10n.itemsHeading, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sale.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = sale.items[index];
                  return ListTile(
                    title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${Formatters.quantity(item.quantity)} x ${Formatters.currency(item.unitPrice)}'),
                    trailing: Text(Formatters.currency(item.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // calculation Summary
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow(l10n.subtotal, Formatters.currency(sale.total + sale.discount)),
                  if (sale.discount > 0)
                    _buildDetailRow(l10n.discount, '-${Formatters.currency(sale.discount)}', valueColor: AppTheme.errorRed),
                  const Divider(),
                  _buildDetailRow(
                    l10n.total, 
                    Formatters.currency(sale.total), 
                    isBold: true, 
                    valueSize: 18, 
                    valueColor: AppTheme.primaryGreen
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await PdfService.instance.generateReceipt(sale, sale.items, settings: settings);
                      if (await PrintingService.instance.isConnected()) {
                        await PrintingService.instance.printReceipt(sale, sale.items, settings);
                      }
                    },
                    icon: const Icon(Icons.print),
                    label: Text(l10n.receipt80mm),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => PdfService.instance.generateProfessionalInvoice(sale, sale.items, settings: settings),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(l10n.invoiceA4),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ShareService.instance.shareViaWhatsApp(sale, sale.items, settings),
                      icon: const Icon(Icons.chat),
                      label: Text(l10n.shareViaWhatsApp),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ShareService.instance.shareViaSMS(sale, sale.items, settings),
                      icon: const Icon(Icons.message),
                      label: Text(l10n.shareViaSMS),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProcessReturnScreen(sale: sale),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_return_outlined),
                label: Text(l10n.returnRefundItems),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, double? valueSize, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: valueSize,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
