import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/product.dart';
import '../models/product_selling_mode.dart';
import '../providers/preference_provider.dart';
import '../services/unit_conversion_service.dart';
import '../utils/formatters.dart';
import '../utils/pos_l10n.dart';
import '../utils/region_utils.dart';

/// Ultra-modern modal dialog for choosing weight, volume, pack, or count when billing products with one or multiple selling modes.
class VariableQuantityDialog extends ConsumerStatefulWidget {
  final Product product;
  final double? initialQuantity;
  final String? initialUnit;
  final String? initialMode;
  final bool isDark;
  final void Function(
    double quantity,
    String unit, {
    String? sellingMode,
    double? packSize,
    String? packSizeUnit,
    double? customPrice,
  }) onConfirmed;

  const VariableQuantityDialog({
    super.key,
    required this.product,
    this.initialQuantity,
    this.initialUnit,
    this.initialMode,
    this.isDark = false,
    required this.onConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required Product product,
    double? initialQuantity,
    String? initialUnit,
    String? initialMode,
    bool isDark = false,
    required void Function(
      double quantity,
      String unit, {
      String? sellingMode,
      double? packSize,
      String? packSizeUnit,
      double? customPrice,
    }) onConfirmed,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => VariableQuantityDialog(
        product: product,
        initialQuantity: initialQuantity,
        initialUnit: initialUnit,
        initialMode: initialMode,
        isDark: isDark,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  ConsumerState<VariableQuantityDialog> createState() => _VariableQuantityDialogState();
}

class _VariableQuantityDialogState extends ConsumerState<VariableQuantityDialog> {
  late TextEditingController _qtyController;
  late String _selectedUnit;
  late ProductSellingMode _activeMode;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final modes = p.sellingModes;

    if (widget.initialMode != null) {
      _activeMode = modes.firstWhere((m) => m.id == widget.initialMode, orElse: () => modes.first);
    } else {
      _activeMode = modes.first;
    }

    if (_activeMode.modeType == 'pack') {
      _selectedUnit = _activeMode.unit;
      final defaultQty = widget.initialQuantity ?? 1.0;
      _qtyController = TextEditingController(
        text: defaultQty == defaultQty.roundToDouble() ? defaultQty.toInt().toString() : defaultQty.toString(),
      );
    } else {
      final defaultUnit = widget.initialUnit ?? (p.unitCategory == 'weight' ? 'g' : (p.unitCategory == 'liquid' ? 'ml' : p.baseUnit));
      _selectedUnit = UnitConversionService.normalizeUnit(defaultUnit);
      final defaultQty = widget.initialQuantity ?? (p.unitCategory == 'weight' ? 500.0 : (p.unitCategory == 'liquid' ? 500.0 : 1.0));
      _qtyController = TextEditingController(
        text: defaultQty == defaultQty.roundToDouble() ? defaultQty.toInt().toString() : defaultQty.toString(),
      );
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _switchMode(ProductSellingMode mode) {
    setState(() {
      _activeMode = mode;
      if (mode.modeType == 'pack') {
        _selectedUnit = mode.unit;
        _qtyController.text = '1';
      } else {
        final cat = widget.product.unitCategory;
        _selectedUnit = cat == 'weight' ? 'g' : (cat == 'liquid' ? 'ml' : widget.product.baseUnit);
        _qtyController.text = (cat == 'weight' || cat == 'liquid') ? '500' : '1';
      }
    });
  }

  void _setPreset(double qty, String unit) {
    setState(() {
      _selectedUnit = unit;
      _qtyController.text = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    });
  }

  void _stepQuantity(double delta) {
    final cur = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final next = (cur + delta).clamp(0.01, 99999.0);
    setState(() {
      _qtyController.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1);
    });
  }

  double get _enteredQuantity => double.tryParse(_qtyController.text.trim()) ?? 0.0;

  double get _lineTotal {
    final qty = _enteredQuantity;
    if (qty <= 0) return 0.0;
    if (_activeMode.modeType == 'pack') {
      return qty * _activeMode.price;
    } else {
      return UnitConversionService.calculatePriceForQuantity(
        quantity: qty,
        selectedUnit: _selectedUnit,
        basePrice: widget.product.price,
        baseUnit: widget.product.baseUnit,
      );
    }
  }

  double get _baseQuantity {
    final qty = _enteredQuantity;
    if (qty <= 0) return 0.0;
    if (_activeMode.modeType == 'pack') {
      final packBaseSize = UnitConversionService.convertToBaseQuantity(
        _activeMode.packSize ?? 1.0,
        _activeMode.packSizeUnit ?? widget.product.baseUnit,
        widget.product.baseUnit,
      );
      return qty * packBaseSize;
    } else {
      return UnitConversionService.convertToBaseQuantity(
        qty,
        _selectedUnit,
        widget.product.baseUnit,
      );
    }
  }

  void _confirm() {
    final qty = _enteredQuantity;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than zero.')),
      );
      return;
    }

    Navigator.pop(context);
    widget.onConfirmed(
      qty,
      _selectedUnit,
      sellingMode: _activeMode.id,
      packSize: _activeMode.packSize,
      packSizeUnit: _activeMode.packSizeUnit,
      customPrice: _activeMode.modeType == 'pack' ? _activeMode.price : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final dialogBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final p = widget.product;
    final modes = p.sellingModes;

    final isPackMode = _activeMode.modeType == 'pack';
    final isWeight = p.unitCategory == 'weight' && !isPackMode;
    final isLiquid = p.unitCategory == 'liquid' && !isPackMode;
    final isCount = p.unitCategory == 'count' && !isPackMode;
    final isPackaging = p.unitCategory == 'packaging' && !isPackMode;

    final units = isPackMode ? [_activeMode.unit] : p.compatibleSellingUnits;

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with glowing gradient icon
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPackMode
                          ? Icons.inventory_2_rounded
                          : (isWeight
                              ? Icons.scale_rounded
                              : (isLiquid ? Icons.water_drop_rounded : Icons.shopping_bag_outlined)),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.sinhalaOrName,
                          style: GoogleFonts.notoSansSinhala(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (p.nameEnglish != null && p.nameEnglish!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              p.nameEnglish!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: subColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subColor),
                    splashRadius: 20,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Multi-mode tabs if product supports multiple selling modes
              if (modes.length > 1) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: modes.map((mode) {
                      final isSelected = _activeMode.id == mode.id;
                      return Expanded(
                        child: InkWell(
                          onTap: () => _switchMode(mode),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                        blurRadius: 8,
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
                                      size: 15,
                                      color: isSelected ? Colors.white : subColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      mode.name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isSelected ? Colors.white : subColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${globalAppRegion.currencySymbol} ${mode.price.toStringAsFixed(2)} / ${mode.unit}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF10B981),
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
                const SizedBox(height: 18),
              ],

              // Quick Presets
              Text(
                PosL10n.of(ref.watch(settingsProvider).languageCode).quickPresets,
                style: GoogleFonts.notoSansSinhala(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 18),

              // Large Quantity Stepper Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _stepQuantity(isWeight || isLiquid ? (_selectedUnit == 'g' || _selectedUnit == 'ml' ? -50.0 : -0.5) : -1.0),
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _stepQuantity(isWeight || isLiquid ? (_selectedUnit == 'g' || _selectedUnit == 'ml' ? 50.0 : 0.5) : 1.0),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 36,
                      width: 1,
                      color: borderColor,
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedUnit,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF10B981)),
                      items: units.map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(
                          u,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                      )).toList(),
                      onChanged: isPackMode ? null : (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Total Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF064E3B).withValues(alpha: 0.35), const Color(0xFF022C22).withValues(alpha: 0.45)]
                        : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
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
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.currency(_lineTotal),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${_baseQuantity.toStringAsFixed(_baseQuantity == _baseQuantity.roundToDouble() ? 0 : 3)} ${p.baseUnit}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: borderColor),
                      ),
                      child: Text(
                        PosL10n.of(ref.watch(settingsProvider).languageCode).cancel,
                        style: GoogleFonts.notoSansSinhala(fontWeight: FontWeight.w700, fontSize: 14, color: subColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_shopping_cart_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              PosL10n.of(ref.watch(settingsProvider).languageCode).addToBill,
                              style: GoogleFonts.notoSansSinhala(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildPresetChip(String label, double qty, String unit) {
    final isSelected = _enteredQuantity == qty && _selectedUnit == unit;
    return InkWell(
      onTap: () => _setPreset(qty, unit),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981)
              : (widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
