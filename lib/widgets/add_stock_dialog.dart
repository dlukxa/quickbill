import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/preference_provider.dart';
import '../providers/supplier_provider.dart';
import '../services/unit_conversion_service.dart';
import '../utils/formatters.dart';
import '../utils/pos_l10n.dart';
import '../utils/region_utils.dart';

/// Ultra-modern, premium stock receiving and inventory adjustment modal.
class AddStockDialog extends ConsumerStatefulWidget {
  final Product product;
  final bool isDark;

  const AddStockDialog({
    super.key,
    required this.product,
    this.isDark = true,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Product product,
    bool isDark = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => AddStockDialog(
        product: product,
        isDark: isDark,
      ),
    );
  }

  @override
  ConsumerState<AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends ConsumerState<AddStockDialog> {
  // Mode: 'direct' vs 'package'
  String _restockMode = 'direct';

  // Direct Input Controllers
  final _qtyController = TextEditingController(text: '10');
  late String _selectedUnit;

  // Package Input Controllers
  final _packCountController = TextEditingController(text: '10');
  final _packSizeController = TextEditingController(text: '1.0');
  late String _packSizeUnit;
  late String _packUnit;

  // Cost & Supplier Info
  final _costController = TextEditingController();
  final _notesController = TextEditingController();
  int? _selectedSupplierId;
  bool _showCostDetails = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _selectedUnit = p.baseUnit;
    _packSizeUnit = p.packSizeUnit;
    _packUnit = p.packUnit;
    _packSizeController.text = (p.packSize ?? 1.0).toString();
    _selectedSupplierId = p.supplierId;
    if (p.costPrice != null) {
      _costController.text = p.costPrice!.toStringAsFixed(2);
    }

    if (p.unitCategory == 'weight') {
      _qtyController.text = '25';
    } else if (p.unitCategory == 'liquid') {
      _qtyController.text = '10';
    } else {
      _qtyController.text = '10';
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _packCountController.dispose();
    _packSizeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _addedBaseQuantity {
    final p = widget.product;
    if (_restockMode == 'package') {
      final packCount = double.tryParse(_packCountController.text.trim()) ?? 0.0;
      final packSize = double.tryParse(_packSizeController.text.trim()) ?? 1.0;
      final sizeInBase = UnitConversionService.convertToBaseQuantity(packSize, _packSizeUnit, p.baseUnit);
      return packCount * sizeInBase;
    } else {
      final enteredQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
      return UnitConversionService.convertToBaseQuantity(enteredQty, _selectedUnit, p.baseUnit);
    }
  }

  double get _newCalculatedStock => widget.product.stock + _addedBaseQuantity;

  void _stepQuantity(double delta) {
    if (_restockMode == 'package') {
      final cur = double.tryParse(_packCountController.text.trim()) ?? 0.0;
      final next = (cur + delta).clamp(1.0, 99999.0);
      setState(() {
        _packCountController.text = next == next.roundToDouble() ? next.toInt().toString() : next.toString();
      });
    } else {
      final cur = double.tryParse(_qtyController.text.trim()) ?? 0.0;
      final next = (cur + delta).clamp(0.1, 99999.0);
      setState(() {
        _qtyController.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1);
      });
    }
  }

  void _setDirectPreset(double qty, String unit) {
    setState(() {
      _selectedUnit = unit;
      _qtyController.text = qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    });
  }

  void _setPackagePreset(double count) {
    setState(() {
      _packCountController.text = count == count.roundToDouble() ? count.toInt().toString() : count.toString();
    });
  }

  Future<void> _submit() async {
    final addedQty = _addedBaseQuantity;
    if (addedQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid stock quantity greater than zero.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final p = widget.product;
      String noteText = _notesController.text.trim();
      if (noteText.isEmpty) {
        if (_restockMode == 'package') {
          noteText = 'Restocked ${_packCountController.text} × ${_packSizeController.text}$_packSizeUnit $_packUnit (+${_addedBaseQuantity.toStringAsFixed(2)} ${p.baseUnit})';
        } else {
          noteText = 'Restocked ${_qtyController.text} $_selectedUnit (+${_addedBaseQuantity.toStringAsFixed(2)} ${p.baseUnit})';
        }
      }

      await ref.read(productActionsProvider).adjustStock(
        productId: p.id!,
        quantityChange: addedQty,
        notes: noteText,
      );

      final newCost = double.tryParse(_costController.text.trim());
      if ((newCost != null && newCost > 0 && newCost != p.costPrice) ||
          (_selectedSupplierId != null && _selectedSupplierId != p.supplierId)) {
        final updatedProduct = p.copyWith(
          costPrice: newCost ?? p.costPrice,
          supplierId: _selectedSupplierId ?? p.supplierId,
        );
        await ref.read(productActionsProvider).updateProduct(updatedProduct);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Added +${UnitConversionService.formatHumanReadableQuantity(addedQty, p.baseUnit)} to ${p.sinhalaOrName}. New stock: ${UnitConversionService.formatHumanReadableQuantity(_newCalculatedStock, p.baseUnit)}',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update stock: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    final suppliersAsync = ref.watch(suppliersProvider);

    final cat = p.unitCategory;
    final isWeight = cat == 'weight';
    final isLiquid = cat == 'liquid';
    final isCount = cat == 'count';
    final isPackaging = cat == 'packaging';

    final units = p.compatibleSellingUnits;

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with glowing icon and badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.sinhalaOrName,
                                style: GoogleFonts.notoSansSinhala(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'Current: ${p.formattedStock}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.stockStatusColor(p.stockStatus),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (p.nameEnglish != null && p.nameEnglish!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              p.nameEnglish!,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
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
              const SizedBox(height: 22),

              // Segmented Tab: Direct Bulk vs Package Delivery
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _restockMode = 'direct'),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: _restockMode == 'direct'
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _restockMode == 'direct'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.scale_rounded,
                                size: 16,
                                color: _restockMode == 'direct' ? Colors.white : subColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                PosL10n.of(ref.watch(settingsProvider).languageCode).directQuantityMode,
                                style: GoogleFonts.notoSansSinhala(
                                  fontSize: 13,
                                  fontWeight: _restockMode == 'direct' ? FontWeight.w700 : FontWeight.w600,
                                  color: _restockMode == 'direct' ? Colors.white : subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _restockMode = 'package'),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: _restockMode == 'package'
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _restockMode == 'package'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_rounded,
                                size: 16,
                                color: _restockMode == 'package' ? Colors.white : subColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                PosL10n.of(ref.watch(settingsProvider).languageCode).wholesaleDeliveryMode,
                                style: GoogleFonts.notoSansSinhala(
                                  fontSize: 13,
                                  fontWeight: _restockMode == 'package' ? FontWeight.w700 : FontWeight.w600,
                                  color: _restockMode == 'package' ? Colors.white : subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // DIRECT RESTOCK SECTION
              if (_restockMode == 'direct') ...[
                Text(
                  'Quick Wholesale Presets',
                  style: GoogleFonts.plusJakartaSans(
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
                    if (isWeight) ...[
                      _buildPresetChip('+5 kg', 5, 'kg'),
                      _buildPresetChip('+10 kg', 10, 'kg'),
                      _buildPresetChip('+25 kg Sack', 25, 'kg'),
                      _buildPresetChip('+50 kg Wholesale Bag', 50, 'kg'),
                      _buildPresetChip('+100 kg', 100, 'kg'),
                    ] else if (isLiquid) ...[
                      _buildPresetChip('+5 L', 5, 'L'),
                      _buildPresetChip('+10 L', 10, 'L'),
                      _buildPresetChip('+20 L Can', 20, 'L'),
                      _buildPresetChip('+50 L Drum', 50, 'L'),
                    ] else if (isCount) ...[
                      _buildPresetChip('+10 pcs', 10, 'pcs'),
                      _buildPresetChip('+25 pcs', 25, 'pcs'),
                      _buildPresetChip('+50 pcs', 50, 'pcs'),
                      _buildPresetChip('+100 pcs', 100, 'pcs'),
                      _buildPresetChip('+1 Dozen (12)', 1, 'dozen'),
                      _buildPresetChip('+5 Dozen (60)', 5, 'dozen'),
                    ] else if (isPackaging) ...[
                      _buildPresetChip('+10 $_selectedUnit', 10, _selectedUnit),
                      _buildPresetChip('+20 $_selectedUnit', 20, _selectedUnit),
                      _buildPresetChip('+50 $_selectedUnit', 50, _selectedUnit),
                      _buildPresetChip('+100 $_selectedUnit', 100, _selectedUnit),
                    ],
                  ],
                ),
                const SizedBox(height: 18),

                // Large Stepper Input Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      // Minus Button
                      IconButton(
                        onPressed: () => _stepQuantity(-5.0),
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _qtyController,
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
                      // Plus Button
                      IconButton(
                        onPressed: () => _stepQuantity(5.0),
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
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedUnit = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // PACKAGE MULTIPLIER SECTION
              if (_restockMode == 'package') ...[
                Text(
                  'Quick Pack Presets',
                  style: GoogleFonts.plusJakartaSans(
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
                    _buildPackPresetChip('+5 packs', 5),
                    _buildPackPresetChip('+10 packs', 10),
                    _buildPackPresetChip('+20 packs', 20),
                    _buildPackPresetChip('+50 packs', 50),
                    _buildPackPresetChip('+100 packs', 100),
                  ],
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Packs Received', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: subColor)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _packCountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                              decoration: InputDecoration(
                                hintText: '10',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                        child: Text('×', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Size', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: subColor)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _packSizeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                              decoration: InputDecoration(
                                hintText: '1.0',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unit', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: subColor)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _packSizeUnit,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'kg', child: Text('kg')),
                                DropdownMenuItem(value: 'g', child: Text('g')),
                                DropdownMenuItem(value: 'L', child: Text('L')),
                                DropdownMenuItem(value: 'ml', child: Text('ml')),
                                DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _packSizeUnit = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Stock Impact Flow Card
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
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Stock to Receive',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+${UnitConversionService.formatHumanReadableQuantity(_addedBaseQuantity, p.baseUnit)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'New Total Stock',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          UnitConversionService.formatHumanReadableQuantity(_newCalculatedStock, p.baseUnit),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Expandable Optional Cost & Supplier Info
              InkWell(
                onTap: () => setState(() => _showCostDetails = !_showCostDetails),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showCostDetails ? Icons.remove_circle_outline : Icons.add_circle_outline,
                        size: 18,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showCostDetails ? 'Hide Cost & Supplier Information' : 'Attach Purchase Cost, Supplier & Invoice Note (Optional)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showCostDetails) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Purchase Cost Price',
                          prefixText: '${globalAppRegion.currencySymbol} ',
                          suffixText: '/ ${p.baseUnit}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: suppliersAsync.when(
                        data: (suppliers) => DropdownButtonFormField<int?>(
                          value: _selectedSupplierId,
                          decoration: InputDecoration(
                            labelText: 'Supplier',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Supplier')),
                            ...suppliers.map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name, overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (val) => setState(() => _selectedSupplierId = val),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Receipt Note / Invoice No.',
                    hintText: 'e.g. Invoice #1024 from Pettah Wholesale',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],

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
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_shopping_cart_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    PosL10n.of(ref.watch(settingsProvider).languageCode).confirmAndAddStock,
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
    final isSelected = (double.tryParse(_qtyController.text.trim()) ?? 0.0) == qty && _selectedUnit == unit;
    return InkWell(
      onTap: () => _setDirectPreset(qty, unit),
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

  Widget _buildPackPresetChip(String label, double count) {
    final isSelected = (double.tryParse(_packCountController.text.trim()) ?? 0.0) == count;
    return InkWell(
      onTap: () => _setPackagePreset(count),
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
