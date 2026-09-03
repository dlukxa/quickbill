import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/cart_item.dart';
import '../models/product_selling_mode.dart';
import '../providers/cart_provider.dart';
import '../services/unit_conversion_service.dart';
import '../utils/formatters.dart';
import '../utils/region_utils.dart';

/// Modal dialog for editing the quantity, unit, or selling mode of an existing cart item.
class CartQuantityEditDialog extends ConsumerStatefulWidget {
  final CartItem item;
  final int itemIndex;
  final bool isDark;

  const CartQuantityEditDialog({
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
      builder: (context) => CartQuantityEditDialog(
        item: item,
        itemIndex: index,
        isDark: isDark,
      ),
    );
  }

  @override
  ConsumerState<CartQuantityEditDialog> createState() => _CartQuantityEditDialogState();
}

class _CartQuantityEditDialogState extends ConsumerState<CartQuantityEditDialog> {
  late TextEditingController _qtyController;
  late String _selectedUnit;
  late ProductSellingMode _activeMode;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final p = item.product;
    final modes = p?.sellingModes ?? [
      ProductSellingMode(
        id: 'standard',
        name: 'Standard',
        modeType: 'piece',
        unit: item.itemUnit,
        price: item.itemPrice,
      )
    ];

    if (item.sellingMode == 'pack') {
      _activeMode = modes.firstWhere((m) => m.modeType == 'pack', orElse: () => modes.first);
    } else {
      _activeMode = modes.firstWhere((m) => m.modeType != 'pack', orElse: () => modes.first);
    }

    _selectedUnit = item.itemUnit;
    final qty = item.quantity;
    _qtyController = TextEditingController(
      text: qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString(),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double get _enteredQuantity => double.tryParse(_qtyController.text.trim()) ?? 0.0;

  double get _lineTotal {
    final item = widget.item;
    if (_activeMode.modeType == 'pack') {
      final subtotal = _activeMode.price * _enteredQuantity;
      return (subtotal - item.discount).clamp(0.0, double.infinity);
    }
    return UnitConversionService.calculateLinePrice(
      _activeMode.price,
      _enteredQuantity,
      _selectedUnit,
      item.productBaseUnit,
      discount: item.discount,
    );
  }

  double get _baseQuantity {
    final item = widget.item;
    if (_activeMode.modeType == 'pack') {
      final packBaseSize = UnitConversionService.convertToBaseQuantity(
        _activeMode.packSize,
        _activeMode.packSizeUnit,
        item.productBaseUnit,
      );
      return _enteredQuantity * packBaseSize;
    }
    return UnitConversionService.convertToBaseQuantity(
      _enteredQuantity,
      _selectedUnit,
      item.productBaseUnit,
    );
  }

  void _switchMode(ProductSellingMode mode) {
    setState(() {
      _activeMode = mode;
      if (mode.modeType == 'pack') {
        _selectedUnit = mode.unit;
        _qtyController.text = '1';
      } else {
        final p = widget.item.product;
        _selectedUnit = p?.unitCategory == 'weight' ? 'g' : (p?.unitCategory == 'liquid' ? 'ml' : widget.item.productBaseUnit);
        _qtyController.text = p?.unitCategory == 'weight' ? '500' : '1';
      }
    });
  }

  void _setPreset(double qty, String unit) {
    setState(() {
      _selectedUnit = unit;
      _qtyController.text = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    });
  }

  void _confirm() {
    final qty = _enteredQuantity;
    if (qty <= 0) return;

    ref.read(cartProvider.notifier).updateItemQuantityAndUnit(
      index: widget.itemIndex,
      quantity: qty,
      unit: _selectedUnit,
      sellingMode: _activeMode.modeType,
      packSize: _activeMode.modeType == 'pack' ? _activeMode.packSize : null,
      packSizeUnit: _activeMode.modeType == 'pack' ? _activeMode.packSizeUnit : null,
      customPrice: _activeMode.modeType == 'pack' ? _activeMode.price : null,
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
    final p = item.product;
    final modes = p?.sellingModes ?? [];

    final isPackMode = _activeMode.modeType == 'pack';
    final cat = UnitConversionService.getUnitCategory(item.productBaseUnit);
    final isWeight = !isPackMode && cat == 'weight';
    final isLiquid = !isPackMode && cat == 'liquid';
    final isCount = !isPackMode && cat == 'count';
    final isPackaging = !isPackMode && cat == 'packaging';

    final units = isPackMode ? [_activeMode.unit] : (p?.compatibleSellingUnits ?? UnitConversionService.getCompatibleUnits(item.itemUnit));

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
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
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPackMode
                        ? Icons.inventory_2_rounded
                        : (isWeight
                            ? Icons.scale_rounded
                            : (isLiquid ? Icons.water_drop_rounded : Icons.shopping_bag_outlined)),
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
                        item.itemName,
                        style: GoogleFonts.notoSansSinhala(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Edit Cart Item Quantity & Selling Mode',
                        style: GoogleFonts.inter(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: subColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selling Mode Selector Tabs (if product supports multiple modes)
            if (modes.length > 1) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: modes.map((mode) {
                    final isSelected = _activeMode.id == mode.id;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _switchMode(mode),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF334155) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    mode.modeType == 'pack' ? Icons.inventory_2_rounded : Icons.scale_rounded,
                                    size: 16,
                                    color: isSelected ? AppTheme.primaryGreen : subColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    mode.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? textColor : subColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${globalAppRegion.currencySymbol} ${mode.price.toStringAsFixed(2)} / ${mode.unit}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? AppTheme.primaryGreen : subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Price / Rate Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Rate: ', style: GoogleFonts.inter(fontSize: 12, color: subColor)),
                      Text(
                        '${globalAppRegion.currencySymbol} ${_activeMode.price.toStringAsFixed(2)} / ${_activeMode.unit}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  if (item.discount > 0)
                    Text(
                      'Discount: -${Formatters.currency(item.discount)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orangeAccent,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Preset Buttons
            Text(
              'Quick Presets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: subColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPackMode) ...[
                  _buildPresetChip('1 ${_activeMode.unit}', 1, _activeMode.unit),
                  _buildPresetChip('2 ${_activeMode.unit}s', 2, _activeMode.unit),
                  _buildPresetChip('3 ${_activeMode.unit}s', 3, _activeMode.unit),
                  _buildPresetChip('5 ${_activeMode.unit}s', 5, _activeMode.unit),
                  _buildPresetChip('10 ${_activeMode.unit}s', 10, _activeMode.unit),
                ] else if (isWeight) ...[
                  _buildPresetChip('100g', 100, 'g'),
                  _buildPresetChip('250g', 250, 'g'),
                  _buildPresetChip('500g', 500, 'g'),
                  _buildPresetChip('750g', 750, 'g'),
                  _buildPresetChip('1kg', 1, 'kg'),
                  _buildPresetChip('1.25kg', 1.25, 'kg'),
                  _buildPresetChip('1.5kg', 1.5, 'kg'),
                  _buildPresetChip('2kg', 2, 'kg'),
                ] else if (isLiquid) ...[
                  _buildPresetChip('100ml', 100, 'ml'),
                  _buildPresetChip('250ml', 250, 'ml'),
                  _buildPresetChip('500ml', 500, 'ml'),
                  _buildPresetChip('750ml', 750, 'ml'),
                  _buildPresetChip('1L', 1, 'L'),
                  _buildPresetChip('1.5L', 1.5, 'L'),
                ] else if (isCount) ...[
                  _buildPresetChip('1 pc', 1, 'pcs'),
                  _buildPresetChip('2 pcs', 2, 'pcs'),
                  _buildPresetChip('6 pcs', 6, 'pcs'),
                  _buildPresetChip('1 Dozen (12)', 1, 'dozen'),
                ] else if (isPackaging) ...[
                  _buildPresetChip('1 $_selectedUnit', 1, _selectedUnit),
                  _buildPresetChip('2 ${_selectedUnit}s', 2, _selectedUnit),
                  _buildPresetChip('3 ${_selectedUnit}s', 3, _selectedUnit),
                  _buildPresetChip('5 ${_selectedUnit}s', 5, _selectedUnit),
                  _buildPresetChip('10 ${_selectedUnit}s', 10, _selectedUnit),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Manual Input Row (Quantity + Unit Dropdown)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _qtyController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: units.map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(u, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                    )).toList(),
                    onChanged: isPackMode ? null : (val) {
                      if (val != null) {
                        setState(() => _selectedUnit = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Calculation Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Price',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        Formatters.currency(_lineTotal),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Deducts Stock',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                      Text(
                        '${_baseQuantity.toStringAsFixed(_baseQuantity == _baseQuantity.roundToDouble() ? 0 : 3)} ${item.productBaseUnit}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Update Cart Item',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double qty, String unit) {
    final isSelected = _enteredQuantity == qty && _selectedUnit == unit;
    return InkWell(
      onTap: () => _setPreset(qty, unit),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen
              : (widget.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : (widget.isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (widget.isDark ? Colors.white : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
