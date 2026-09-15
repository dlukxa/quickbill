import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../providers/preference_provider.dart';
import '../../services/printing_service.dart';
import '../../widgets/receipt/receipt_widget.dart';

/// Complete, professional Receipt Print Settings screen with interactive
/// real-time thermal roll preview and instant test-printing capabilities.
class ReceiptPrintSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptPrintSettingsScreen({super.key});

  @override
  ConsumerState<ReceiptPrintSettingsScreen> createState() =>
      _ReceiptPrintSettingsScreenState();
}

class _ReceiptPrintSettingsScreenState
    extends ConsumerState<ReceiptPrintSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _previewScale = 1.0;
  bool _isPrinting = false;

  late Sale _sampleSale;
  late List<SaleItem> _sampleItems;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSampleData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initSampleData() {
    _sampleItems = [
      SaleItem(
        id: 1,
        saleId: 99999,
        productId: 101,
        productName: 'Highland Fresh Milk 1L / නැවුම් කිරි',
        quantity: 2.0,
        unitPrice: 520.0,
        total: 980.0,
        discount: 60.0,
        costPrice: 420.0,
        soldUnit: 'bottle',
        sellingMode: 'pack',
      ),
      SaleItem(
        id: 2,
        saleId: 99999,
        productId: 102,
        productName: 'Keells Keeri Samba Rice 5kg / සම්බා සහල්',
        quantity: 1.0,
        unitPrice: 1350.0,
        total: 1250.0,
        discount: 100.0,
        costPrice: 1100.0,
        soldUnit: 'kg',
        sellingMode: 'weight',
      ),
      SaleItem(
        id: 3,
        saleId: 99999,
        productId: 103,
        productName: 'Munchee Super Cream Cracker 500g',
        quantity: 2.0,
        unitPrice: 380.0,
        total: 660.0,
        discount: 100.0,
        costPrice: 310.0,
        soldUnit: 'pack',
        sellingMode: 'pack',
      ),
      SaleItem(
        id: 4,
        saleId: 99999,
        productId: 104,
        productName: 'Dilmah Ceylon Tea 100 Tea Bags / තේ',
        quantity: 1.0,
        unitPrice: 300.0,
        total: 250.0,
        discount: 50.0,
        costPrice: 210.0,
        soldUnit: 'box',
        sellingMode: 'pack',
      ),
    ];

    _sampleSale = Sale(
      id: 99999,
      billNumber: 'INV-2026-0889',
      total: 3140.00,
      discount: 310.00,
      tax: 0.0,
      serviceCharge: 0.0,
      itemsCount: _sampleItems.length,
      paymentMethod: 'cash',
      cashierName: 'Kasun Bandara',
      customerName: 'Nimal Perera',
      customerPhone: '077 123 4567',
      notes: 'Cash: 5000.00, Change: 1860.00',
      createdAt: DateTime.now(),
      items: _sampleItems,
    );
  }

  Future<void> _handleTestPrint(AppSettings settings) async {
    setState(() {
      _isPrinting = true;
    });

    try {
      await PrintingService.instance.printReceiptUnified(
        _sampleSale,
        _sampleItems,
        settings,
        cashReceived: 5000.0,
        change: 1860.0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Test receipt sent to printer successfully!'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Print error: $e')),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  void _showSavePresetDialog(BuildContext context, AppSettings settings) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_rounded, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('Save Custom Preset'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a descriptive name for your custom receipt print preset:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'e.g. 76mm Dense Kitchen Slip',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(settingsProvider.notifier)
                    .saveCustomReceiptPreset(name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preset "$name" saved successfully!'),
                    backgroundColor: AppTheme.primaryGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save Preset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = settings.isDarkMode;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12181F) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          'Receipt Print Settings',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E2630) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        actions: [
          IconButton(
            tooltip: 'Reset to Standard (80mm)',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () async {
              await notifier.applyReceiptPreset('standard');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reset to Standard POS Receipt settings'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: !isDesktop
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryGreen,
                labelColor: AppTheme.primaryGreen,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.tune_rounded), text: 'Settings'),
                  Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Live Preview'),
                ],
              )
            : null,
      ),
      body: isDesktop
          ? _buildDesktopLayout(settings, notifier, isDark)
          : _buildMobileLayout(settings, notifier, isDark),
    );
  }

  // ─── Desktop 2-Column Side-by-Side Layout ───
  Widget _buildDesktopLayout(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Scrollable Settings Controls
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPresetsBar(settings, notifier, isDark),
                const SizedBox(height: 20),
                _buildPaperSettingsCard(settings, notifier, isDark),
                const SizedBox(height: 20),
                _buildMarginsCard(settings, notifier, isDark),
                const SizedBox(height: 20),
                _buildTypographyCard(settings, notifier, isDark),
                const SizedBox(height: 20),
                _buildLayoutCard(settings, notifier, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Right Column: Live Thermal Paper Roll Preview & Test Print Panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161E27) : const Color(0xFFEEF2F6),
              border: Border(
                left: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                _buildPreviewHeader(settings, isDark),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: _buildThermalPaperSlip(settings, isDark),
                    ),
                  ),
                ),
                _buildPreviewFooterActions(settings, isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile Tabbed Layout ───
  Widget _buildMobileLayout(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Settings
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPresetsBar(settings, notifier, isDark),
              const SizedBox(height: 16),
              _buildPaperSettingsCard(settings, notifier, isDark),
              const SizedBox(height: 16),
              _buildMarginsCard(settings, notifier, isDark),
              const SizedBox(height: 16),
              _buildTypographyCard(settings, notifier, isDark),
              const SizedBox(height: 16),
              _buildLayoutCard(settings, notifier, isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),

        // Tab 2: Live Preview
        Container(
          color: isDark ? const Color(0xFF161E27) : const Color(0xFFEEF2F6),
          child: Column(
            children: [
              _buildPreviewHeader(settings, isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(child: _buildThermalPaperSlip(settings, isDark)),
                ),
              ),
              _buildPreviewFooterActions(settings, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 0. Presets Bar ───
  Widget _buildPresetsBar(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    Map<String, dynamic> customMap = {};
    try {
      customMap = Map<String, dynamic>.from(
          jsonDecode(settings.receiptCustomPresetsJson));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_outline_rounded,
                      size: 20, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Presets',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Save As Preset', style: TextStyle(fontSize: 12)),
                onPressed: () => _showSavePresetDialog(context, settings),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip(
                label: 'Standard POS (80mm)',
                presetKey: 'standard',
                isActive: settings.receiptActivePreset == 'standard',
                onSelect: () => notifier.applyReceiptPreset('standard'),
                isDark: isDark,
              ),
              _buildPresetChip(
                label: 'Large Readable Text',
                presetKey: 'large',
                isActive: settings.receiptActivePreset == 'large',
                onSelect: () => notifier.applyReceiptPreset('large'),
                isDark: isDark,
              ),
              _buildPresetChip(
                label: 'Compact (58mm)',
                presetKey: 'compact',
                isActive: settings.receiptActivePreset == 'compact',
                onSelect: () => notifier.applyReceiptPreset('compact'),
                isDark: isDark,
              ),
              ...customMap.keys.map((customName) {
                final isSelected = settings.receiptActivePreset == customName;
                return InputChip(
                  label: Text(customName),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryGreen,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryGreen : null,
                    fontSize: 12,
                  ),
                  onSelected: (_) => notifier.applyReceiptPreset(customName),
                  onDeleted: () => notifier.deleteCustomReceiptPreset(customName),
                  deleteIconColor: Colors.redAccent,
                  deleteButtonTooltipMessage: 'Delete custom preset',
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String presetKey,
    required bool isActive,
    required VoidCallback onSelect,
    required bool isDark,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        color: isActive
            ? AppTheme.primaryGreen
            : (isDark ? Colors.white70 : Colors.black87),
        fontSize: 12,
      ),
      onSelected: (_) => onSelect(),
    );
  }

  // ─── 1. Paper Roll Settings Card ───
  Widget _buildPaperSettingsCard(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return _buildCardWrapper(
      title: '1. Printer & Paper Roll Settings',
      icon: Icons.receipt_long_rounded,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thermal Roll Paper Width',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: '80mm',
                label: Text('80mm Standard'),
                icon: Icon(Icons.straighten_rounded),
              ),
              ButtonSegment(
                value: '58mm',
                label: Text('58mm Standard'),
                icon: Icon(Icons.crop_portrait_rounded),
              ),
              ButtonSegment(
                value: 'custom',
                label: Text('Custom (mm)'),
                icon: Icon(Icons.tune_rounded),
              ),
            ],
            selected: {
              settings.isCustomPaperWidth
                  ? 'custom'
                  : (settings.printerPaperSize == '58mm' ? '58mm' : '80mm')
            },
            onSelectionChanged: (set) {
              final selected = set.first;
              if (selected == 'custom') {
                notifier.updateReceiptPaper(
                  widthMm: settings.printerPaperWidthMm,
                  isCustom: true,
                );
              } else if (selected == '58mm') {
                notifier.updateReceiptPaper(
                  widthMm: 58.0,
                  isCustom: false,
                  standardSize: '58mm',
                );
              } else {
                notifier.updateReceiptPaper(
                  widthMm: 80.0,
                  isCustom: false,
                  standardSize: '80mm',
                );
              }
            },
          ),
          if (settings.isCustomPaperWidth) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: settings.printerPaperWidthMm.clamp(40.0, 110.0),
                    min: 40.0,
                    max: 110.0,
                    divisions: 70,
                    label: '${settings.printerPaperWidthMm.toStringAsFixed(1)} mm',
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (val) {
                      notifier.updateReceiptPaper(
                        widthMm: double.parse(val.toStringAsFixed(1)),
                        isCustom: true,
                      );
                    },
                  ),
                ),
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${settings.printerPaperWidthMm.toStringAsFixed(1)} mm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QuickBill receipts are optimized for continuous thermal rolls (58mm / 80mm). Receipts will never be forced into A4 format, preventing paper waste.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Margins Settings Card ───
  Widget _buildMarginsCard(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return _buildCardWrapper(
      title: '2. Adjustable Margins (in mm)',
      icon: Icons.border_outer_rounded,
      isDark: isDark,
      trailing: TextButton.icon(
        icon: const Icon(Icons.restore_rounded, size: 16),
        label: const Text('Default Margins', style: TextStyle(fontSize: 12)),
        onPressed: () {
          notifier.updateReceiptMargins(
            left: 3.0,
            right: 3.0,
            top: 4.0,
            bottom: 6.0,
          );
        },
      ),
      child: Column(
        children: [
          _buildSliderRow(
            label: 'Left Margin',
            value: settings.receiptMarginLeftMm,
            min: 0.0,
            max: 15.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptMargins(left: val),
          ),
          _buildSliderRow(
            label: 'Right Margin',
            value: settings.receiptMarginRightMm,
            min: 0.0,
            max: 15.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptMargins(right: val),
          ),
          _buildSliderRow(
            label: 'Top Margin',
            value: settings.receiptMarginTopMm,
            min: 0.0,
            max: 25.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptMargins(top: val),
          ),
          _buildSliderRow(
            label: 'Bottom Margin',
            value: settings.receiptMarginBottomMm,
            min: 0.0,
            max: 30.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptMargins(bottom: val),
          ),
        ],
      ),
    );
  }

  // ─── 3. Typography & Font Sizing Card ───
  Widget _buildTypographyCard(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return _buildCardWrapper(
      title: '3. Typography & Font Settings',
      icon: Icons.format_size_rounded,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('High-Contrast Bold Text',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: const Text('Enhances readability on faded or older thermal heads',
                style: TextStyle(fontSize: 12)),
            value: settings.receiptBoldText,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (val) => notifier.updateReceiptFontSizes(boldText: val),
          ),
          const Divider(height: 16),
          _buildSliderRow(
            label: 'Store Name Size',
            value: settings.receiptStoreNameFontSize,
            min: 14.0,
            max: 32.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(storeName: val),
          ),
          _buildSliderRow(
            label: 'Product Name Size',
            value: settings.receiptProductNameFontSize,
            min: 9.0,
            max: 20.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(productName: val),
          ),
          _buildSliderRow(
            label: 'Quantity & Price Size',
            value: settings.receiptQtyPriceFontSize,
            min: 8.0,
            max: 18.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(qtyPrice: val),
          ),
          _buildSliderRow(
            label: 'Subtotal / Line Item Size',
            value: settings.receiptSubtotalFontSize,
            min: 9.0,
            max: 20.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(subtotal: val),
          ),
          _buildSliderRow(
            label: 'Discount / Savings Size',
            value: settings.receiptDiscountFontSize,
            min: 10.0,
            max: 22.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(discount: val),
          ),
          _buildSliderRow(
            label: 'Grand Total Size',
            value: settings.receiptGrandTotalFontSize,
            min: 12.0,
            max: 30.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(grandTotal: val),
          ),
          _buildSliderRow(
            label: 'Footer Note Size',
            value: settings.receiptFooterFontSize,
            min: 8.0,
            max: 18.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(footer: val),
          ),
          _buildSliderRow(
            label: 'Main Body Size',
            value: settings.receiptMainFontSize,
            min: 8.0,
            max: 18.0,
            unit: 'pt',
            onChanged: (val) => notifier.updateReceiptFontSizes(main: val),
          ),
          _buildSliderRow(
            label: 'Line Spacing',
            value: settings.receiptLineSpacing,
            min: 1.0,
            max: 1.8,
            divisions: 16,
            unit: 'x',
            onChanged: (val) => notifier.updateReceiptFontSizes(lineSpacing: val),
          ),
        ],
      ),
    );
  }

  // ─── 4. Layout & Content Toggles Card ───
  Widget _buildLayoutCard(
    AppSettings settings,
    AppSettingsNotifier notifier,
    bool isDark,
  ) {
    return _buildCardWrapper(
      title: '4. Receipt Layout & Content Options',
      icon: Icons.dashboard_customize_rounded,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alignment Controls
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Header Alignment',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left_rounded)),
                        ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center_rounded)),
                        ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right_rounded)),
                      ],
                      selected: {settings.receiptHeaderAlignment},
                      onSelectionChanged: (set) =>
                          notifier.updateReceiptLayout(headerAlignment: set.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Footer Alignment',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left_rounded)),
                        ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center_rounded)),
                        ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right_rounded)),
                      ],
                      selected: {settings.receiptFooterAlignment},
                      onSelectionChanged: (set) =>
                          notifier.updateReceiptLayout(footerAlignment: set.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Product Name Wrapping
          Text('Product Name Wrapping',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Multi-line Wrap'),
                icon: Icon(Icons.wrap_text_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text('Single Line (Ellipsis)'),
                icon: Icon(Icons.short_text_rounded),
              ),
            ],
            selected: {settings.receiptWrapProductName},
            onSelectionChanged: (set) =>
                notifier.updateReceiptLayout(wrapProductName: set.first),
          ),
          const SizedBox(height: 16),

          // Spacing Sliders
          _buildSliderRow(
            label: 'Item Row Spacing',
            value: settings.receiptItemSpacing,
            min: 1.0,
            max: 12.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptLayout(itemSpacing: val),
          ),
          _buildSliderRow(
            label: 'Header Bottom Spacing',
            value: settings.receiptHeaderSpacing,
            min: 2.0,
            max: 20.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptLayout(headerSpacing: val),
          ),
          _buildSliderRow(
            label: 'Footer Top Spacing',
            value: settings.receiptFooterSpacing,
            min: 2.0,
            max: 20.0,
            unit: 'mm',
            onChanged: (val) => notifier.updateReceiptLayout(footerSpacing: val),
          ),
          const Divider(height: 24),

          // Content Visibility Toggles
          Text(
            'Receipt Elements Show / Hide',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildToggleTile(
            title: 'Print Barcode (Bill Number)',
            value: settings.showReceiptBarcode,
            onChanged: (val) => notifier.updateReceiptLayout(showBarcode: val),
          ),
          _buildToggleTile(
            title: 'Print Store Address',
            value: settings.showReceiptAddress,
            onChanged: (val) => notifier.updateReceiptLayout(showAddress: val),
          ),
          _buildToggleTile(
            title: 'Print Store Phone Number',
            value: settings.showReceiptPhone,
            onChanged: (val) => notifier.updateReceiptLayout(showPhone: val),
          ),
          _buildToggleTile(
            title: 'Print Cashier Name',
            value: settings.showReceiptCashier,
            onChanged: (val) => notifier.updateReceiptLayout(showCashier: val),
          ),
          _buildToggleTile(
            title: 'Print Date & Time',
            value: settings.showReceiptDateTime,
            onChanged: (val) => notifier.updateReceiptLayout(showDateTime: val),
          ),
          _buildToggleTile(
            title: 'Print Standard MRP & Our Price Columns',
            value: settings.showReceiptStandardPrice,
            onChanged: (val) => notifier.updateReceiptToggles(
              showStandardPrice: val,
              showOurPrice: val,
            ),
          ),
          _buildToggleTile(
            title: 'Print Customer Total Savings Banner',
            value: settings.showReceiptDiscount,
            onChanged: (val) => notifier.updateReceiptToggles(showDiscount: val),
          ),
        ],
      ),
    );
  }

  // ─── Live Thermal Paper Roll Preview & Tear-off Edge ───
  Widget _buildPreviewHeader(AppSettings settings, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_rounded,
                  size: 20, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Live Thermal Slip Preview',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded, size: 18),
                tooltip: 'Zoom Out',
                onPressed: () {
                  setState(() {
                    _previewScale = (_previewScale - 0.1).clamp(0.6, 1.4);
                  });
                },
              ),
              Text(
                '${(_previewScale * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded, size: 18),
                tooltip: 'Zoom In',
                onPressed: () {
                  setState(() {
                    _previewScale = (_previewScale + 0.1).clamp(0.6, 1.4);
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen_rounded, size: 18),
                tooltip: 'Reset Zoom (100%)',
                onPressed: () => setState(() => _previewScale = 1.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThermalPaperSlip(AppSettings settings, bool isDark) {
    final rollWidthMm = settings.effectivePaperWidthMm;

    return Transform.scale(
      scale: _previewScale,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Roll width tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Continuous Thermal Roll: ${rollWidthMm.toStringAsFixed(1)} mm (${settings.effectiveReceiptWidthPx.toInt()} px)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),

          // Authentic Thermal Paper Roll with Tear Edges and Drop Shadow
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Serrated Tear Edge
                CustomPaint(
                  size: Size(settings.effectiveReceiptWidthPx, 8),
                  painter: const _TearEdgePainter(isTop: true),
                ),

                // Actual ReceiptWidget matching 100% of Print Output
                ReceiptWidget(
                  sale: _sampleSale,
                  items: _sampleItems,
                  settings: settings,
                  cashReceived: 5000.0,
                  change: 1860.0,
                ),

                // Bottom Serrated Tear Edge
                CustomPaint(
                  size: Size(settings.effectiveReceiptWidthPx, 8),
                  painter: const _TearEdgePainter(isTop: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewFooterActions(AppSettings settings, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: _isPrinting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_rounded),
              label: Text(
                _isPrinting ? 'Printing Test Receipt...' : 'Test Print to POS Printer',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isPrinting ? null : () => _handleTestPrint(settings),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper Widgets ───
  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Widget child,
    required bool isDark,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions ?? ((max - min) * 2).toInt(),
              label: '${value.toStringAsFixed(1)} $unit',
              activeColor: AppTheme.primaryGreen,
              onChanged: (v) => onChanged(double.parse(v.toStringAsFixed(2))),
            ),
          ),
          Container(
            width: 64,
            alignment: Alignment.centerRight,
            child: Text(
              '${value.toStringAsFixed(1)} $unit',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 13)),
      value: value,
      activeThumbColor: AppTheme.primaryGreen,
      onChanged: onChanged,
    );
  }
}

/// Custom painter that creates authentic serrated zig-zag tear-off edge on thermal slips
class _TearEdgePainter extends CustomPainter {
  final bool isTop;

  const _TearEdgePainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 6.0;
    const toothHeight = 4.0;
    final teethCount = (size.width / toothWidth).ceil();

    if (isTop) {
      path.moveTo(0, size.height);
      for (int i = 0; i < teethCount; i++) {
        final x = i * toothWidth;
        path.lineTo(x + toothWidth / 2, size.height - toothHeight);
        path.lineTo(x + toothWidth, size.height);
      }
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, 0);
      for (int i = 0; i < teethCount; i++) {
        final x = i * toothWidth;
        path.lineTo(x + toothWidth / 2, toothHeight);
        path.lineTo(x + toothWidth, 0);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
