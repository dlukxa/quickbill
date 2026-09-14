import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/employee_provider.dart';
import '../utils/formatters.dart';
import '../utils/region_utils.dart';

enum DiscountInputMode { percentage, fixedAmount }

/// Dedicated dialog for adding, modifying, or clearing a product's discount in the cart.
class CartItemDiscountDialog extends ConsumerStatefulWidget {
  final CartItem item;
  final int itemIndex;
  final bool isDark;

  const CartItemDiscountDialog({
    super.key,
    required this.item,
    required this.itemIndex,
    this.isDark = true,
  });

  static Future<void> show(
    BuildContext context, {
    required CartItem item,
    required int index,
    bool isDark = true,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CartItemDiscountDialog(
        item: item,
        itemIndex: index,
        isDark: isDark,
      ),
    );
  }

  @override
  ConsumerState<CartItemDiscountDialog> createState() => _CartItemDiscountDialogState();
}

class _CartItemDiscountDialogState extends ConsumerState<CartItemDiscountDialog> {
  late TextEditingController _controller;
  DiscountInputMode _mode = DiscountInputMode.percentage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final subtotal = item.subtotal;

    if (item.discount > 0 && subtotal > 0) {
      final pct = (item.discount / subtotal) * 100;
      // If the discount matches a clean round percentage, default to percentage mode
      if ((pct - pct.round()).abs() < 0.01) {
        _mode = DiscountInputMode.percentage;
        _controller = TextEditingController(text: pct.toInt().toString());
      } else {
        _mode = DiscountInputMode.fixedAmount;
        _controller = TextEditingController(
          text: item.discount == item.discount.roundToDouble()
              ? item.discount.toInt().toString()
              : item.discount.toStringAsFixed(2),
        );
      }
    } else {
      _mode = DiscountInputMode.percentage;
      _controller = TextEditingController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _enteredValue => double.tryParse(_controller.text.trim()) ?? 0.0;

  double get _calculatedDiscount {
    final subtotal = widget.item.subtotal;
    if (_mode == DiscountInputMode.percentage) {
      final pct = _enteredValue.clamp(0.0, 100.0);
      return ((subtotal * (pct / 100.0)) * 100).round() / 100;
    } else {
      return _enteredValue.clamp(0.0, subtotal);
    }
  }

  double get _calculatedPercent {
    final subtotal = widget.item.subtotal;
    if (subtotal <= 0) return 0.0;
    return ((_calculatedDiscount / subtotal) * 100).clamp(0.0, 100.0);
  }

  double get _netLineTotal {
    final subtotal = widget.item.subtotal;
    return (subtotal - _calculatedDiscount).clamp(0.0, double.infinity);
  }

  void _switchMode(DiscountInputMode newMode) {
    if (_mode == newMode) return;
    setState(() {
      final currentDisc = _calculatedDiscount;
      _mode = newMode;
      if (newMode == DiscountInputMode.percentage) {
        final pct = widget.item.subtotal > 0 ? (currentDisc / widget.item.subtotal) * 100 : 0.0;
        _controller.text = pct > 0
            ? (pct == pct.round() ? pct.toInt().toString() : pct.toStringAsFixed(1))
            : '';
      } else {
        _controller.text = currentDisc > 0
            ? (currentDisc == currentDisc.roundToDouble()
                ? currentDisc.toInt().toString()
                : currentDisc.toStringAsFixed(2))
            : '';
      }
      _errorMessage = null;
    });
  }

  void _applyPresetPercent(double pct) {
    setState(() {
      _mode = DiscountInputMode.percentage;
      _controller.text = pct == pct.round() ? pct.toInt().toString() : pct.toString();
      _errorMessage = null;
    });
  }

  void _clearDiscount() {
    setState(() {
      _controller.text = '';
      _errorMessage = null;
    });
    ref.read(cartProvider.notifier).updateItemDiscount(
          discount: 0.0,
          index: widget.itemIndex,
        );
    Navigator.pop(context);
  }

  void _confirm() {
    final subtotal = widget.item.subtotal;
    final discount = _calculatedDiscount;
    final permissions = ref.read(currentEmployeeProvider).value?.permissions;

    if (permissions != null && !permissions.canGiveDiscount && discount > 0) {
      setState(() => _errorMessage = 'Access denied: You do not have permission to give discounts.');
      return;
    }

    if (permissions != null && permissions.canGiveDiscount && discount > 0) {
      final maxPct = permissions.maxDiscountPercent;
      final actualPct = subtotal > 0 ? (discount / subtotal) * 100 : 0.0;
      if (actualPct > maxPct + 0.01) {
        setState(() => _errorMessage = 'Discount exceeds maximum allowed limit (${maxPct.toStringAsFixed(0)}%).');
        return;
      }
    }

    if (discount < 0 || discount > subtotal) {
      setState(() => _errorMessage = 'Discount cannot be greater than line subtotal.');
      return;
    }

    ref.read(cartProvider.notifier).updateItemDiscount(
          discount: discount,
          index: widget.itemIndex,
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final item = widget.item;
    final permissions = ref.watch(currentEmployeeProvider).value?.permissions;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: isDark ? 0.4 : 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: GoogleFonts.notoSansSinhala(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Subtotal: ${Formatters.currency(item.subtotal)} • ${item.formattedQuantity}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: subColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mode Selector: [% Percentage] or [Currency Amount]
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeTab(
                      label: 'Percentage (%)',
                      icon: Icons.percent_rounded,
                      isActive: _mode == DiscountInputMode.percentage,
                      onTap: () => _switchMode(DiscountInputMode.percentage),
                    ),
                  ),
                  Expanded(
                    child: _buildModeTab(
                      label: 'Amount (${globalAppRegion.currencySymbol})',
                      icon: Icons.payments_outlined,
                      isActive: _mode == DiscountInputMode.fixedAmount,
                      onTap: () => _switchMode(DiscountInputMode.fixedAmount),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Preset Percentage Chips
            Text(
              'Quick Presets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: subColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('5%', 5),
                _buildPresetChip('10%', 10),
                _buildPresetChip('15%', 15),
                _buildPresetChip('20%', 20),
                _buildPresetChip('25%', 25),
                _buildPresetChip('50%', 50),
                if (item.discount > 0 || _enteredValue > 0)
                  InkWell(
                    onTap: () => setState(() {
                      _controller.text = '';
                      _errorMessage = null;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.clear_rounded, size: 12, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Numeric Input Field
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              decoration: InputDecoration(
                labelText: _mode == DiscountInputMode.percentage ? 'Discount Percentage' : 'Discount Amount',
                hintText: _mode == DiscountInputMode.percentage ? 'e.g. 10' : '0.00',
                prefixIcon: Icon(
                  _mode == DiscountInputMode.percentage ? Icons.percent_rounded : Icons.local_offer_outlined,
                  size: 18,
                  color: Colors.amber,
                ),
                suffixText: _mode == DiscountInputMode.percentage ? '%' : globalAppRegion.currencySymbol,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onChanged: (_) => setState(() => _errorMessage = null),
              onFieldSubmitted: (_) => _confirm(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppTheme.errorRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.errorRed, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],

            if (permissions != null && permissions.canGiveDiscount && permissions.maxDiscountPercent < 100) ...[
              const SizedBox(height: 6),
              Text(
                'Max allowed cashier discount: ${permissions.maxDiscountPercent.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(fontSize: 11, color: subColor),
              ),
            ],

            const SizedBox(height: 18),

            // Live Calculation Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _calculatedDiscount > 0
                      ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Item Gross Subtotal:', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                      Text(
                        Formatters.currency(item.subtotal),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discount Applied:', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                      Text(
                        _calculatedDiscount > 0
                            ? '-${Formatters.currency(_calculatedDiscount)} (${_calculatedPercent.toStringAsFixed(_calculatedPercent == _calculatedPercent.round() ? 0 : 1)}%)'
                            : Formatters.currency(0.0),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _calculatedDiscount > 0 ? Colors.amber : subColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New Line Total:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        Formatters.currency(_netLineTotal),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                if (item.discount > 0)
                  TextButton.icon(
                    onPressed: _clearDiscount,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                    label: Text(
                      'Remove',
                      style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Apply Discount',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.amber : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double pct) {
    final currentPct = _calculatedPercent;
    final isSelected = (currentPct - pct).abs() < 0.1 && _calculatedDiscount > 0;
    return InkWell(
      onTap: () => _applyPresetPercent(pct),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber
              : (widget.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.amber : (widget.isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? Colors.black : (widget.isDark ? Colors.white : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
