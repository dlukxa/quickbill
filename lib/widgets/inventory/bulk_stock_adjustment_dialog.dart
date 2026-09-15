import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';

enum BulkStockMode {
  add,
  deduct,
  setFixed,
  setMinStock,
}

class BulkStockAdjustmentDialog extends ConsumerStatefulWidget {
  final List<Product> selectedProducts;

  const BulkStockAdjustmentDialog({
    super.key,
    required this.selectedProducts,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<Product> selectedProducts,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => BulkStockAdjustmentDialog(
        selectedProducts: selectedProducts,
      ),
    );
  }

  @override
  ConsumerState<BulkStockAdjustmentDialog> createState() =>
      _BulkStockAdjustmentDialogState();
}

class _BulkStockAdjustmentDialogState
    extends ConsumerState<BulkStockAdjustmentDialog> {
  BulkStockMode _mode = BulkStockMode.add;
  final TextEditingController _quantityController =
      TextEditingController(text: '10');
  final TextEditingController _notesController =
      TextEditingController(text: 'Bulk stock adjustment');
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _parsedQuantity =>
      double.tryParse(_quantityController.text.trim()) ?? 0.0;

  double _calculateNewStock(Product p) {
    final qty = _parsedQuantity;
    switch (_mode) {
      case BulkStockMode.add:
        return p.stock + qty;
      case BulkStockMode.deduct:
        return (p.stock - qty) < 0 ? 0.0 : (p.stock - qty);
      case BulkStockMode.setFixed:
        return qty < 0 ? 0.0 : qty;
      case BulkStockMode.setMinStock:
        return p.stock;
    }
  }

  double _calculateNewMinStock(Product p) {
    if (_mode == BulkStockMode.setMinStock) {
      return _parsedQuantity < 0 ? 0.0 : _parsedQuantity;
    }
    return p.minStock;
  }

  Future<void> _applyAdjustments() async {
    final qty = _parsedQuantity;
    if (qty < 0 && _mode != BulkStockMode.deduct) {
      setState(() => _errorMessage = 'Quantity cannot be negative');
      return;
    }

    if (qty == 0 && _mode != BulkStockMode.setFixed && _mode != BulkStockMode.setMinStock) {
      setState(() => _errorMessage = 'Please enter a quantity greater than 0');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final notes = _notesController.text.trim().isEmpty
        ? 'Bulk stock adjustment'
        : _notesController.text.trim();

    try {
      final productActions = ref.read(productActionsProvider);

      for (final p in widget.selectedProducts) {
        if (p.id == null) continue;

        if (_mode == BulkStockMode.setMinStock) {
          final newMin = _calculateNewMinStock(p);
          await productActions.updateProduct(p.copyWith(minStock: newMin));
        } else {
          final newStock = _calculateNewStock(p);
          final diff = newStock - p.stock;
          if (diff != 0) {
            await productActions.adjustStock(
              productId: p.id!,
              quantityChange: diff,
              notes: notes,
            );
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to apply changes: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk Stock Adjustment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Updating ${widget.selectedProducts.length} selected products',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mode selector
              Text(
                'Adjustment Mode',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModeChip(
                    BulkStockMode.add,
                    'Add Stock (+)',
                    Icons.add_circle_outline_rounded,
                    AppTheme.primaryGreen,
                  ),
                  _buildModeChip(
                    BulkStockMode.deduct,
                    'Deduct Stock (-)',
                    Icons.remove_circle_outline_rounded,
                    AppTheme.errorRed,
                  ),
                  _buildModeChip(
                    BulkStockMode.setFixed,
                    'Set Exact Stock (=)',
                    Icons.equalizer_rounded,
                    AppTheme.primaryBlue,
                  ),
                  _buildModeChip(
                    BulkStockMode.setMinStock,
                    'Set Minimum Stock',
                    Icons.notifications_active_outlined,
                    Colors.amber.shade800,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Inputs: Quantity & Notes
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mode == BulkStockMode.setMinStock
                              ? 'New Minimum Stock'
                              : 'Quantity (${_mode == BulkStockMode.add ? '+' : _mode == BulkStockMode.deduct ? '-' : '='})',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audit Notes / Reason',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Weekly stock intake',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Preview Table Title
              Text(
                'Adjustment Preview (${widget.selectedProducts.length} items)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Preview Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: widget.selectedProducts.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: border),
                      itemBuilder: (context, index) {
                        final p = widget.selectedProducts[index];
                        final oldStock = p.stock;
                        final newStock = _calculateNewStock(p);
                        final oldMin = p.minStock;
                        final newMin = _calculateNewMinStock(p);

                        final isMinMode = _mode == BulkStockMode.setMinStock;
                        final beforeVal = isMinMode ? oldMin : oldStock;
                        final afterVal = isMinMode ? newMin : newStock;
                        final diff = afterVal - beforeVal;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (p.nameSinhala != null && p.nameSinhala!.isNotEmpty)
                                      Text(
                                        p.nameSinhala!,
                                        style: GoogleFonts.notoSansSinhala(
                                          fontSize: 11,
                                          color: textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${Formatters.number(beforeVal)} ${p.unit}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '${Formatters.number(afterVal)} ${p.unit}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: diff > 0
                                              ? AppTheme.primaryGreen
                                              : diff < 0
                                                  ? AppTheme.errorRed
                                                  : textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _applyAdjustments,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Applying...' : 'Apply to ${widget.selectedProducts.length} Items',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(
    BulkStockMode mode,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
