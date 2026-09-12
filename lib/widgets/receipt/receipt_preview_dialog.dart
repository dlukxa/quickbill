import 'package:flutter/material.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../providers/preference_provider.dart';
import '../../services/printing_service.dart';
import '../../config/theme.dart';
import '../../utils/receipt_theme.dart';
import 'receipt_widget.dart';

/// Modal dialog for visual receipt preview with 1-tap thermal printing.
/// Visually matches the exact thermal printed output using [ReceiptWidget].
class ReceiptPreviewDialog extends StatefulWidget {
  final Sale sale;
  final List<SaleItem> items;
  final AppSettings settings;
  final double? cashReceived;
  final double? change;

  const ReceiptPreviewDialog({
    super.key,
    required this.sale,
    required this.items,
    required this.settings,
    this.cashReceived,
    this.change,
  });

  static Future<void> show(
    BuildContext context, {
    required Sale sale,
    required List<SaleItem> items,
    required AppSettings settings,
    double? cashReceived,
    double? change,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiptPreviewDialog(
        sale: sale,
        items: items,
        settings: settings,
        cashReceived: cashReceived,
        change: change,
      ),
    );
  }

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  late String _paperSize;
  late String _language;
  late String _template;
  bool _isPrinting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _paperSize = widget.settings.printerPaperSize;
    _language = widget.settings.receiptLanguage;
    _template = widget.settings.receiptTemplate;
  }

  Future<void> _handlePrint() async {
    setState(() {
      _isPrinting = true;
      _statusMessage = null;
    });

    try {
      final customSettings = widget.settings.copyWith(
        printerPaperSize: _paperSize,
        receiptLanguage: _language,
        receiptTemplate: _template,
      );

      await PrintingService.instance.printReceiptUnified(
        widget.sale,
        widget.items,
        customSettings,
        cashReceived: widget.cashReceived,
        change: widget.change,
      );

      if (mounted) {
        setState(() {
          _statusMessage = '✓ Receipt sent to printer successfully';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '⚠ Print failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AppTheme.primaryGreen, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Receipt Preview (${widget.sale.billNumber})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Controls toolbar (Paper size, language, template)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Paper Size Toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Width: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ChoiceChip(
                        label: const Text('80mm', style: TextStyle(fontSize: 11)),
                        selected: _paperSize == '80mm',
                        onSelected: (val) {
                          if (val) setState(() => _paperSize = '80mm');
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('58mm', style: TextStyle(fontSize: 11)),
                        selected: _paperSize == '58mm',
                        onSelected: (val) {
                          if (val) setState(() => _paperSize = '58mm');
                        },
                      ),
                    ],
                  ),

                  // Language selector
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Lang: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      DropdownButton<String>(
                        value: _language,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'si', child: Text('Sinhala (සිංහල)')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'bilingual', child: Text('Bilingual (ද්විභාෂා)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _language = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Preview Scrollable Container
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ReceiptWidget(
                      sale: widget.sale,
                      items: widget.items,
                      settings: widget.settings,
                      cashReceived: widget.cashReceived,
                      change: widget.change,
                      overridePaperSize: _paperSize,
                      overrideLanguage: _language,
                      overrideTemplate: _template,
                    ),
                  ),
                ),
              ),
            ),

            // Status message
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: _statusMessage!.startsWith('✓')
                    ? Colors.green.shade800
                    : Colors.red.shade800,
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isPrinting ? null : _handlePrint,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print_rounded, size: 20),
                      label: Text(
                        _isPrinting
                            ? 'Printing...'
                            : 'Print Receipt ($_paperSize)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
