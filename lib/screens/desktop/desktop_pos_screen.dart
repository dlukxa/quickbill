import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../models/cart_item.dart';
import '../../models/employee.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../models/sale_item.dart';
import '../../providers/sale_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/printing_service.dart';
import '../../services/share_service.dart';
import '../../providers/preference_provider.dart';
import '../../providers/business_modules_provider.dart';
import '../../models/business_modules.dart';
import '../../providers/cart_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/sale.dart';
import '../../providers/customer_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/cached_product_image.dart';
import '../billing/quick_item_sheet.dart';
import '../customers/customer_list_screen.dart';
import '../reports/analytics_dashboard_screen.dart';
import '../reports/reports_screen.dart';
import '../reports/sales_report_screen.dart';
import '../reports/expense_management_screen.dart';
import '../settings/add_employee_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/sinhala_search_service.dart';
import '../../services/sinhala_transliteration_service.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import '../settings/employee_list_screen.dart';
import '../stock/add_batch_screen.dart';
import '../stock/add_product_screen.dart';
import '../stock/stock_screen.dart';
import '../stock/product_price_manager_screen.dart';
import '../../widgets/add_stock_dialog.dart';
import '../../widgets/variable_quantity_dialog.dart';
import '../../widgets/cart_quantity_edit_dialog.dart';
import '../suppliers/supplier_list_screen.dart';
import '../suppliers/purchase_management_screen.dart';
import '../returns/sales_history_screen.dart';
import '../../models/product_batch.dart';
import '../../services/database_service.dart';
import '../discount/discount_list_screen.dart';
import '../../utils/pos_l10n.dart';
import '../ai/ai_assistant_screen.dart';
import '../appointments/appointments_calendar_screen.dart';
import '../orders/orders_board_screen.dart';
import '../services/services_list_screen.dart';

/// Full-screen Windows POS with:
/// - USB/Bluetooth barcode scanner via keyboard capture
/// - 5-column product grid
/// - Live cart + checkout panel
/// - Cashier management sidebar (owner only)
class DesktopPosScreen extends ConsumerStatefulWidget {
  final String shopUid;

  const DesktopPosScreen({super.key, required this.shopUid});

  @override
  ConsumerState<DesktopPosScreen> createState() => _DesktopPosScreenState();
}

class _DesktopPosScreenState extends ConsumerState<DesktopPosScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showCashierPanel = false;

  // ─── Barcode Scanner (Keyboard Capture) ───────────────────────────────────
  // USB/BT scanners send keystrokes very fast then press Enter or Tab.
  // We buffer characters and detect scanner input vs. human typing.
  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime? _lastKeystroke;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openAddStockPicker() {
    final products = ref.read(productsProvider).valueOrNull ?? [];

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchCtrl.text.trim();
            final filtered = query.isEmpty
                ? products.where((p) => p.deleted != true).toList()
                : SinhalaSearchService.filterAndRank(products.where((p) => p.deleted != true).toList(), query);

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 520,
                height: 560,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_box_rounded, color: AppTheme.primaryGreen, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Stock / Receive Inventory',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Select a product to restock in bulk, bags, or packs',
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search product name (Sinhala/Singlish), barcode...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchCtrl.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    query.isEmpty ? 'No products registered yet.' : 'No product matching "$query"',
                                    style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _openAddProduct(
                                        product: query.isNotEmpty
                                            ? Product(
                                                name: query,
                                                price: 0.0,
                                                stock: 0.0,
                                                minStock: 10.0,
                                                unit: 'pcs',
                                                type: 'product',
                                                trackBatches: false,
                                              )
                                            : null,
                                      );
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(query.isNotEmpty ? '+ Create "$query"' : '+ Add New Product'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final p = filtered[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  title: Text(
                                    p.sinhalaOrName,
                                    style: GoogleFonts.notoSansSinhala(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${p.nameEnglish ?? p.name} • Rs. ${p.price.toStringAsFixed(2)} / ${p.unit}',
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.formattedStock,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.stockStatusColor(p.stockStatus),
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    AddStockDialog.show(context, product: p, isDark: isDark);
                                  },
                                );
                              },
                            ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openAddProduct();
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.primaryGreen),
                          label: Text(
                            '+ Register New Product',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAddProduct({String? initialBarcode, Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          product: product,
          initialBarcode: initialBarcode,
        ),
      ),
    );
  }

  void _openQuickCustomItem() {
    showDialog(
      context: context,
      builder: (_) => _QuickCustomItemDialog(
        isDark: ref.watch(settingsProvider).isDarkMode,
        onAdd: (name, price, qty) {
          final dummyProduct = Product(
            id: -DateTime.now().millisecondsSinceEpoch,
            name: name,
            price: price,
            stock: 9999,
            minStock: 0,
            unit: 'item',
            type: 'product',
            trackBatches: false,
          );
          ref.read(cartProvider.notifier).addProduct(dummyProduct, quantity: qty);
          _showBarcodeSnack('✓ Added "$name" (${qty.toInt()}x Rs. ${price.toStringAsFixed(2)}) to cart');
        },
      ),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    // F2 = Focus Search Bar
    if (key == LogicalKeyboardKey.f2) {
      _searchFocusNode.requestFocus();
      return true;
    }

    // Escape = Clear search or unfocus
    if (key == LogicalKeyboardKey.escape) {
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
        setState(() => _searchQuery = '');
        return true;
      }
      _searchFocusNode.unfocus();
    }

    // F12 or Ctrl+Enter / Cmd+Enter = Quick Checkout
    if (key == LogicalKeyboardKey.f12 ||
        ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) &&
            (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed))) {
      final cart = ref.read(cartProvider);
      if (cart.isNotEmpty) {
        final subtotal = cart.fold(0.0, (s, item) => s + item.total);
        _showCheckout(subtotal);
        return true;
      }
    }

    // F3 or Ctrl+N / Cmd+N = Add New Product on PC
    if (key == LogicalKeyboardKey.f3 ||
        (key == LogicalKeyboardKey.keyN &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed))) {
      _openAddProduct();
      return true;
    }

    // F4 or Ctrl+I / Cmd+I = Quick Custom Item on PC
    if (key == LogicalKeyboardKey.f4 ||
        (key == LogicalKeyboardKey.keyI &&
            (HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed))) {
      _openQuickCustomItem();
      return true;
    }

    // F5 = Add Stock / Restock on PC
    if (key == LogicalKeyboardKey.f5) {
      _openAddStockPicker();
      return true;
    }

    // Enter or Tab = End of wired/USB barcode scan (scanners send Enter, NumpadEnter, or Tab)
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      String barcode = _barcodeBuffer.toString().trim();
      _barcodeBuffer.clear();
      _lastKeystroke = null;

      // Fallback: If user had search field focused, the scanner typed into the search controller
      if (barcode.isEmpty && _searchController.text.trim().isNotEmpty) {
        final searchText = _searchController.text.trim();
        // If it's pure numbers or alphanumeric barcode format (length >= 3)
        if (searchText.length >= 3 && RegExp(r'^[0-9A-Za-z\-_./+*#@]+$').hasMatch(searchText)) {
          barcode = searchText;
        }
      }

      if (barcode.isNotEmpty && barcode.length >= 3) {
        // If the search controller was populated with the scanned barcode, clear it so the product grid isn't restricted
        if (_searchController.text.trim() == barcode || _searchController.text.contains(barcode)) {
          _searchController.clear();
          setState(() => _searchQuery = '');
        }
        _processBarcode(barcode);
        return true; // consume event
      }
      return false;
    }

    final now = DateTime.now();
    final timeSinceLast = _lastKeystroke != null
        ? now.difference(_lastKeystroke!).inMilliseconds
        : 0;

    final char = _keyToChar(key);
    if (char != null) {
      // Long pause (>350ms) = human typing manually, reset scanner buffer
      if (_barcodeBuffer.isNotEmpty && timeSinceLast > 350) {
        _barcodeBuffer.clear();
      }
      _barcodeBuffer.write(char);
      _lastKeystroke = now;
    }

    return false;
  }

  String? _keyToChar(LogicalKeyboardKey key) {
    const validChars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_./+*#@';
    final label = key.keyLabel;
    if (label.length == 1 && validChars.contains(label)) {
      return label;
    }
    return null;
  }

  Future<void> _processBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return;

    // 1. Try finding via database findByBarcode (handles batch barcodes & base barcodes)
    final lookup = await DatabaseService.instance.findByBarcode(clean);
    if (lookup != null && lookup['product'] != null) {
      final Product p = lookup['product'] as Product;
      final ProductBatch? batch = lookup['batch'] as ProductBatch?;

      if (p.hasMultipleSellingModes || p.isVariableQuantity) {
        if (!mounted) return;
        VariableQuantityDialog.show(
          context,
          product: p,
          isDark: ref.read(settingsProvider).isDarkMode,
          onConfirmed: (qty, unit, {sellingMode, packSize, packSizeUnit, customPrice}) {
            ref.read(cartProvider.notifier).addProduct(
              p,
              quantity: qty,
              unit: unit,
              sellingMode: sellingMode,
              packSize: packSize,
              packSizeUnit: packSizeUnit,
              customPrice: customPrice,
              batch: batch,
            );
          },
        );
        _showBarcodeSnack('🔍 ${p.sinhalaOrName} scanned. Select selling mode/quantity.');
        return;
      }

      ref.read(cartProvider.notifier).addProduct(p, batch: batch);
      _showBarcodeSnack('✓ ${p.sinhalaOrName} added (${Formatters.currency(p.price)})');
      return;
    }

    // 2. Try in-memory products list
    final products = ref.read(productsProvider).valueOrNull ?? [];
    Product? found;

    // Search by barcode field first
    for (final p in products) {
      if (p.baseBarcode == clean) {
        found = p;
        break;
      }
    }

    // Search by ID if purely numeric
    if (found == null) {
      final id = int.tryParse(clean);
      if (id != null) {
        for (final p in products) {
          if (p.id == id) {
            found = p;
            break;
          }
        }
      }
    }

    if (found != null) {
      if (found.hasMultipleSellingModes || found.isVariableQuantity) {
        if (!mounted) return;
        VariableQuantityDialog.show(
          context,
          product: found,
          isDark: ref.read(settingsProvider).isDarkMode,
          onConfirmed: (qty, unit, {sellingMode, packSize, packSizeUnit, customPrice}) {
            ref.read(cartProvider.notifier).addProduct(
              found!,
              quantity: qty,
              unit: unit,
              sellingMode: sellingMode,
              packSize: packSize,
              packSizeUnit: packSizeUnit,
              customPrice: customPrice,
            );
          },
        );
        _showBarcodeSnack('🔍 ${found.sinhalaOrName} scanned. Select selling mode/quantity.');
      } else {
        ref.read(cartProvider.notifier).addProduct(found);
        _showBarcodeSnack('✓ ${found.sinhalaOrName} added (${Formatters.currency(found.price)})');
      }
    } else {
      _showBarcodeSnack(
        '⚠ No product found for barcode: $clean',
        isError: true,
        actionLabel: '+ Register Product',
        onAction: () => _openAddProduct(initialBarcode: clean),
      );
    }
  }

  void _showScannerTestModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final testController = TextEditingController();
        String lastDecoded = '';
        DateTime? scanStartTime;
        int? scanLatencyMs;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subColor = isDark ? Colors.white60 : const Color(0xFF64748B);

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USB Barcode Scanner',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Windows & macOS Plug-and-Play (HID Keyboard Mode)',
                              style: GoogleFonts.inter(fontSize: 11, color: subColor),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Hardware Status: Ready for Scanning',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Any wired USB or wireless 2.4GHz handheld barcode scanner works automatically on Windows and macOS. Simply point and scan products.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: subColor, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Live Barcode Test Box:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: testController,
                      autofocus: true,
                      style: GoogleFonts.sourceCodePro(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                      onChanged: (val) {
                        scanStartTime ??= DateTime.now();
                      },
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          final duration = scanStartTime != null
                              ? DateTime.now().difference(scanStartTime!).inMilliseconds
                              : 0;
                          setModalState(() {
                            lastDecoded = val.trim();
                            scanLatencyMs = duration;
                            testController.clear();
                            scanStartTime = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Scan any barcode with your wired reader...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: subColor),
                        prefixIcon: const Icon(Icons.barcode_reader, size: 20, color: Color(0xFF10B981)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    if (lastDecoded.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.task_alt_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Decoded: $lastDecoded (${scanLatencyMs ?? 0}ms)',
                                style: GoogleFonts.sourceCodePro(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBarcodeSnack(
    String msg, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: isError ? Colors.red.shade700 : AppTheme.primaryGreen,
      duration: Duration(seconds: actionLabel != null ? 5 : 2),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              onPressed: onAction,
            )
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currentEmployee = ref.watch(currentEmployeeProvider).valueOrNull;
    final isOwner = currentEmployee?.isAdmin ?? false;
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildTopBar(currentEmployee, isOwner, isDark),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 7, child: _buildProductPanel(isDark)),
                SizedBox(width: 340, child: _buildCartPanel(isDark)),
                if (_showCashierPanel && isOwner)
                  SizedBox(width: 320, child: _buildCashierPanel(isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(Employee? employee, bool isOwner, bool isDark) {
    final perms = employee?.rawPermissions;
    final canViewReports = isOwner || (perms?.canViewReports ?? false);
    final canManageStock = isOwner || (perms?.canManageInventory ?? false);
    final canManageEmployees = isOwner || (perms?.canManageEmployees ?? false);
    final canDeleteBill = isOwner || (perms?.canDeleteBill ?? false);
    final modules = ref.watch(businessModulesProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = PosL10n.of(settings.languageCode);
    final shopName = settings.shopName.trim().isNotEmpty ? settings.shopName.trim() : 'QuickBill Store';

    final topBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: topBarBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Store Branding & Logo Container with Shop Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xFF10B981),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shopName,
                        style: GoogleFonts.notoSansSinhala(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.posActive,
                              style: GoogleFonts.notoSansSinhala(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.quickBillPos,
                        style: GoogleFonts.notoSansSinhala(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                      ),
                      InkWell(
                        onTap: () => _showScannerTestModal(context, isDark),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.scannerReady,
                                style: GoogleFonts.notoSansSinhala(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.info_outline_rounded, size: 12, color: const Color(0xFF10B981).withValues(alpha: 0.8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 14),
          Container(
            height: 28,
            width: 1,
            color: borderColor,
          ),
          const SizedBox(width: 10),

          // Scrollable middle/right navigation actions
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  _TopBarButton(
                    icon: Icons.receipt_long_rounded,
                    label: l10n.billHistory,
                    isDark: isDark,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SalesReportScreen())),
                  ),
                  const SizedBox(width: 4),

                  if (canViewReports) ...[
                    _TopBarButton(
                      icon: Icons.dashboard_rounded,
                      label: l10n.dashboard,
                      isDark: isDark,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen())),
                    ),
                    const SizedBox(width: 4),
                    _TopBarButton(
                      icon: Icons.bar_chart_rounded,
                      label: l10n.reports,
                      isDark: isDark,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ReportsScreen())),
                    ),
                    const SizedBox(width: 4),
                  ],

                  if (canManageStock) ...[
                    _TopBarButton(
                      icon: Icons.add_box_rounded,
                      label: l10n.addStockF5,
                      isDark: isDark,
                      onTap: () => _openAddStockPicker(),
                    ),
                    const SizedBox(width: 4),
                    _TopBarButton(
                      icon: Icons.add_circle_outline_rounded,
                      label: l10n.addProductF3,
                      isDark: isDark,
                      onTap: () => _openAddProduct(),
                    ),
                    const SizedBox(width: 4),
                    _TopBarButton(
                      icon: Icons.flash_on_rounded,
                      label: l10n.customItemF4,
                      isDark: isDark,
                      onTap: () => _openQuickCustomItem(),
                    ),
                    const SizedBox(width: 4),
                    _TopBarButton(
                      icon: Icons.inventory_2_rounded,
                      label: l10n.stock,
                      isDark: isDark,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StockScreen())),
                    ),
                    const SizedBox(width: 4),
                    _TopBarButton(
                      icon: Icons.price_change_rounded,
                      label: l10n.pricesAndUnits,
                      isDark: isDark,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProductPriceManagerScreen())),
                    ),
                    const SizedBox(width: 4),
                  ],

                  _TopBarButton(
                    icon: Icons.people_alt_rounded,
                    label: l10n.customers,
                    isDark: isDark,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const CustomerListScreen())),
                  ),
                  const SizedBox(width: 4),

                  _MoreMenuButton(
                    employee: employee,
                    isOwner: isOwner,
                    canViewReports: canViewReports,
                    canManageStock: canManageStock,
                    canManageEmployees: canManageEmployees,
                    canDeleteBill: canDeleteBill,
                    modules: modules,
                    isDark: isDark,
                  ),

                  const SizedBox(width: 12),

                  if (employee != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOwner ? Icons.shield_rounded : Icons.person_rounded,
                            color: isOwner ? Colors.amber : AppTheme.primaryGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(employee.name,
                              style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],

                  _TopBarButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: l10n.quickItem,
                    isDark: isDark,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const QuickItemSheet(),
                    ),
                  ),

                  if (canManageEmployees) ...[
                    const SizedBox(width: 4),
                    _TopBarButton(
                      icon: _showCashierPanel ? Icons.group_off_rounded : Icons.group_rounded,
                      label: l10n.cashiers,
                      isActive: _showCashierPanel,
                      isDark: isDark,
                      onTap: () => setState(() => _showCashierPanel = !_showCashierPanel),
                    ),
                  ],

                  const SizedBox(width: 4),
                  _TopBarButton(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    label: isDark ? l10n.lightMode : l10n.darkMode,
                    isDark: isDark,
                    onTap: () => ref.read(settingsProvider.notifier).updateDarkMode(!isDark),
                  ),

                  const SizedBox(width: 4),
                  _TopBarButton(
                    icon: Icons.swap_horiz_rounded,
                    label: l10n.switchUser,
                    isDark: isDark,
                    onTap: () => ref.read(currentEmployeeProvider.notifier).logout(),
                  ),

                  const SizedBox(width: 4),
                  _TopBarButton(
                    icon: Icons.logout_rounded,
                    label: 'Exit Shop',
                    isDark: isDark,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Disconnect POS Terminal'),
                          content: const Text(
                            'Are you sure you want to disconnect this terminal from the shop? '
                            'You will return to the shop pairing screen.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('desktop_shop_uid');
                        await prefs.remove('active_shop_uid');
                        await prefs.remove('current_employee_id');
                        await ref.read(currentEmployeeProvider.notifier).logout();
                        await AuthService.instance.signOut();
                        if (context.mounted) {
                          RestartWidget.restartApp(context);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Product Panel ─────────────────────────────────────────────────────────

  Widget _buildProductPanel(bool isDark) {
    final productsAsync = ref.watch(productsProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = PosL10n.of(settings.languageCode);
    final panelBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return Container(
      color: panelBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: GoogleFonts.notoSansSinhala(color: textColor, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  hintStyle: GoogleFonts.notoSansSinhala(color: hintColor, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color: hintColor,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  'F2',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: hintColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final nonDeleted = products.where((p) => p.deleted != true).toList();
                final filtered = _searchQuery.isEmpty
                    ? nonDeleted
                    : SinhalaSearchService.filterAndRank(nonDeleted, _searchQuery);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: hintColor),
                        const SizedBox(height: 10),
                        Text(l10n.noProductsFound, style: GoogleFonts.notoSansSinhala(color: hintColor, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final product = filtered[i];
                    return _ProductTile(
                      product: product,
                      isDark: isDark,
                      onTap: () {
                        final parsed = SinhalaSearchService.parseSearchQuery(_searchController.text);
                        if (product.hasMultipleSellingModes || product.isVariableQuantity) {
                          if (parsed.hasQuantitySpec && parsed.quantity != null) {
                            ref.read(cartProvider.notifier).addProduct(
                              product,
                              quantity: parsed.quantity!,
                              unit: parsed.unit,
                              sellingMode: parsed.sellingMode,
                            );
                          } else {
                            VariableQuantityDialog.show(
                              context,
                              product: product,
                              isDark: isDark,
                              onConfirmed: (qty, unit, {sellingMode, packSize, packSizeUnit, customPrice}) {
                                ref.read(cartProvider.notifier).addProduct(
                                  product,
                                  quantity: qty,
                                  unit: unit,
                                  sellingMode: sellingMode,
                                  packSize: packSize,
                                  packSizeUnit: packSizeUnit,
                                  customPrice: customPrice,
                                );
                              },
                            );
                          }
                        } else {
                          ref.read(cartProvider.notifier).addProduct(product);
                        }
                      },
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error loading products',
                      style: GoogleFonts.inter(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cart Panel ────────────────────────────────────────────────────────────

  Widget _buildCartPanel(bool isDark) {
    final cart = ref.watch(cartProvider);
    final settings = ref.watch(settingsProvider);
    final l10n = PosL10n.of(settings.languageCode);
    final subtotal = cart.fold(0.0, (s, item) => s + item.total);
    final total = subtotal;

    final cartBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: cartBg,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.currentBill,
                  style: GoogleFonts.notoSansSinhala(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                if (cart.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cart.length}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (cart.isNotEmpty)
                  InkWell(
                    onTap: () => ref.read(cartProvider.notifier).clear(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text(
                            l10n.clear,
                            style: GoogleFonts.notoSansSinhala(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Customer selection strip
          Consumer(
            builder: (context, ref, _) {
              final selectedCustomer = ref.watch(selectedCustomerProvider);
              final stripBg = selectedCustomer != null
                  ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9));
              final stripBorder = selectedCustomer != null
                  ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0));
              final iconColor = selectedCustomer != null ? AppTheme.primaryBlue : (isDark ? Colors.white54 : const Color(0xFF64748B));
              final textColor = selectedCustomer != null ? (isDark ? Colors.white : AppTheme.primaryBlue) : (isDark ? Colors.white54 : const Color(0xFF64748B));

              return Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: InkWell(
                  onTap: () async {
                    final cust = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerListScreen(isSelectionMode: true),
                      ),
                    );
                    if (cust != null) {
                      ref.read(selectedCustomerProvider.notifier).state = cust;
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: stripBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: stripBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedCustomer != null ? Icons.person_rounded : Icons.person_add_alt_1_rounded,
                          size: 16,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedCustomer?.name ?? l10n.attachCustomer,
                            style: GoogleFonts.notoSansSinhala(
                              fontSize: 13,
                              fontWeight: selectedCustomer != null ? FontWeight.w600 : FontWeight.w400,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedCustomer != null)
                          GestureDetector(
                            onTap: () {
                              ref.read(selectedCustomerProvider.notifier).state = null;
                            },
                            child: Icon(Icons.close_rounded, size: 16, color: iconColor),
                          )
                        else
                          Icon(Icons.chevron_right_rounded, size: 16, color: iconColor),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(l10n.cartIsEmpty,
                            style: GoogleFonts.notoSansSinhala(color: isDark ? Colors.white24 : const Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        Text(l10n.scanOrTapProduct,
                            style: GoogleFonts.notoSansSinhala(
                                fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: borderColor),
                    itemBuilder: (_, i) => _CartItemTile(
                      item: cart[i],
                      index: i,
                      isDark: isDark,
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor))),
            child: Column(
              children: [
                _TotalRow(
                    label: l10n.subtotal,
                    value: Formatters.currency(subtotal),
                    isDark: isDark),
                const SizedBox(height: 8),
                Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                _TotalRow(
                    label: l10n.total,
                    value: Formatters.currency(total),
                    isTotal: true,
                    isDark: isDark),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        cart.isEmpty ? null : () => _showCheckout(total),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      elevation: 4,
                      shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.checkout,
                          style: GoogleFonts.notoSansSinhala(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckout(double total) {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final currentEmployee = ref.read(currentEmployeeProvider).valueOrNull;
    final selectedCustomer = ref.read(selectedCustomerProvider);

    showDialog(
      context: context,
      builder: (ctx) => _DesktopCheckoutDialog(
        total: total,
        cartItems: List.from(cart),
        customer: selectedCustomer,
        employee: currentEmployee,
      ),
    );
  }

  // ─── Cashier Management Panel ──────────────────────────────────────────────

  Widget _buildCashierPanel(bool isDark) {
    final employeesAsync = ref.watch(employeeListProvider);
    final panelBg = isDark ? const Color(0xFF0F1929) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.group_rounded,
                    color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text('Cashier Management',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white38, size: 18),
                  onPressed: () =>
                      setState(() => _showCashierPanel = false),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddEmployeeScreen()),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text('Add New Cashier',
                  style: GoogleFonts.inter(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: employeesAsync.when(
              data: (employees) => ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: employees.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _CashierTile(employee: employees[i], isDark: isDark),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error',
                      style: GoogleFonts.inter(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDark;
  final Color? accentColor;

  const _TopBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDark = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? (isActive ? const Color(0xFF3B82F6) : const Color(0xFF10B981));
    final bg = isActive
        ? effectiveAccent.withValues(alpha: 0.18)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9));
    final fg = isActive
        ? effectiveAccent
        : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155));
    final border = isActive
        ? effectiveAccent.withValues(alpha: 0.6)
        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "More" Overflow Menu for Desktop Top Bar ─────────────────────────────────
// Shows all features the mobile app exposes, gated by permissions.

class _MoreMenuButton extends ConsumerWidget {
  final Employee? employee;
  final bool isOwner;
  final bool canViewReports;
  final bool canManageStock;
  final bool canManageEmployees;
  final bool canDeleteBill;
  final BusinessModules modules;
  final bool isDark;

  const _MoreMenuButton({
    required this.employee,
    required this.isOwner,
    required this.canViewReports,
    required this.canManageStock,
    required this.canManageEmployees,
    required this.canDeleteBill,
    required this.modules,
    this.isDark = true,
  });

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build the list of menu items based on permissions & enabled modules
    final List<PopupMenuEntry<String>> items = [];

    void addItem(String value, IconData icon, String label, Color color) {
      items.add(PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ));
    }

    void addDivider() {
      if (items.isNotEmpty && items.last is! PopupMenuDivider) {
        items.add(const PopupMenuDivider());
      }
    }

    // ── SALES & BILLING ──
    addItem('bill_history', Icons.receipt_long_rounded, 'Bill History', AppTheme.primaryBlue);
    if (canDeleteBill) {
      addItem('returns', Icons.assignment_return_rounded, 'Returns / Refunds', AppTheme.errorRed);
    }

    // ── INVENTORY ──
    if (canManageStock && modules.enableProducts) {
      addItem('new_product', Icons.add_circle_outline_rounded, 'Add New Product (F3)', AppTheme.primaryGreen);
      addItem('discounts', Icons.local_offer_rounded, 'Discounts', AppTheme.primaryBlue);
      addItem('purchases', Icons.shopping_bag_rounded, 'Purchases', AppTheme.primaryGreen);
      addItem('suppliers', Icons.business_rounded, 'Suppliers', const Color(0xFF64748B));
    }

    // ── REPORTS & FINANCE ──
    if (canViewReports) {
      addItem('expenses', Icons.money_off_rounded, 'Expenses', AppTheme.errorRed);
    }

    // ── SERVICES & APPOINTMENTS ──
    if (modules.enableServices && canManageStock) {
      addDivider();
      addItem('services', Icons.spa_rounded, 'Services', AppTheme.primaryGreen);
    }
    if (modules.enableAppointments) {
      if (items.isNotEmpty && items.last is! PopupMenuDivider) addDivider();
      addItem('appointments', Icons.calendar_month_rounded, 'Appointments', AppTheme.primaryPurple);
    }

    // ── CUSTOM ORDERS ──
    if (modules.enableCustomOrders) {
      if (items.isNotEmpty && items.last is! PopupMenuDivider) addDivider();
      addItem('orders', Icons.assignment_rounded, 'Custom Orders', AppTheme.errorRed);
    }

    // ── MANAGEMENT ──
    addDivider();
    if (canManageEmployees) {
      addItem('employees', Icons.people_outline_rounded, 'Manage Employees', AppTheme.primaryPurple);
    }
    addItem('ai', Icons.auto_awesome_rounded, 'AI Assistant', AppTheme.primaryGreen);
    addItem('theme', isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, isDark ? 'Light Mode' : 'Dark Mode', isDark ? Colors.amber : Colors.indigo);
    addItem('settings', Icons.settings_rounded, 'Settings', Colors.grey);

    if (items.isEmpty) return const SizedBox.shrink();

    final menuBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final btnBg = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
    final btnFg = isDark ? Colors.white54 : const Color(0xFF475569);
    final border = isDark ? Colors.transparent : const Color(0xFFCBD5E1);

    return PopupMenuButton<String>(
      tooltip: 'More Features',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: menuBg,
      shadowColor: Colors.black54,
      elevation: 8,
      itemBuilder: (_) => items,
      onSelected: (value) {
        switch (value) {
          case 'bill_history':
            _push(context, const SalesReportScreen());
            break;
          case 'new_product':
            _push(context, const AddProductScreen());
            break;
          case 'returns':
            _push(context, const SalesHistoryScreen());
            break;
          case 'discounts':
            _push(context, const DiscountListScreen());
            break;
          case 'purchases':
            _push(context, const PurchaseManagementScreen());
            break;
          case 'suppliers':
            _push(context, const SupplierListScreen());
            break;
          case 'expenses':
            _push(context, const ExpenseManagementScreen());
            break;
          case 'services':
            _push(context, const ServicesListScreen());
            break;
          case 'appointments':
            _push(context, const AppointmentsCalendarScreen());
            break;
          case 'orders':
            _push(context, const OrdersBoardScreen());
            break;
          case 'employees':
            _push(context, const EmployeeListScreen());
            break;
          case 'ai':
            _push(context, const AIAssistantScreen());
            break;
          case 'theme':
            ref.read(settingsProvider.notifier).updateDarkMode(!isDark);
            break;
          case 'settings':
            _push(context, const SettingsScreen());
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 16, color: btnFg),
            const SizedBox(width: 5),
            Text('More', style: GoogleFonts.inter(fontSize: 13, color: btnFg)),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: btnFg),
          ],
        ),
      ),
    );
  }
}



class _ProductTile extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;
  final bool isDark;

  const _ProductTile({
    required this.product,
    required this.onTap,
    this.isDark = true,
  });

  void _showActionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_box_rounded, color: Color(0xFF10B981), size: 20),
              ),
              title: Text('Add Stock / Receive Delivery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              subtitle: Text('Receive wholesale bags (50kg), direct units, or packaged shipments', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
              onTap: () {
                Navigator.pop(context);
                AddStockDialog.show(context, product: product, isDark: isDark);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
              ),
              title: Text('Quick Price & Stock Update', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              subtitle: Text('Instantly update price, cost price, and stock levels', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => _QuickStockPriceDialog(product: product, isDark: isDark),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 20),
              ),
              title: Text('Full Edit Product Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              subtitle: Text('Edit Sinhala name, barcodes, categories & supplier', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddProductScreen(product: product)));
              },
            ),
            if (product.trackBatches)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Colors.orange, size: 20),
                ),
                title: Text('Add / Manage Batches', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                subtitle: Text('Add expiry dates and batch lot tracking', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddBatchScreen(product: product)));
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              ),
              title: Text('Delete Product', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Delete ${product.name}?'),
                    content: const Text('Are you sure you want to delete this product?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && product.id != null) {
                  ref.read(productActionsProvider).deleteProduct(product.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = product.imageUrl != null && product.imageUrl!.trim().isNotEmpty;
    final tileBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final placeholderBg = isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC);
    final iconColor = isDark ? Colors.white24 : const Color(0xFF94A3B8);

    final secondaryName = product.nameSinhala?.isNotEmpty == true && product.nameSinhala != product.name
        ? product.nameSinhala!
        : (product.nameEnglish?.isNotEmpty == true && product.nameEnglish != product.name
            ? product.nameEnglish!
            : null);

    final isMulti = product.hasMultipleSellingModes;

    return InkWell(
      onTap: onTap,
      onSecondaryTap: () {
        showDialog(
          context: context,
          builder: (_) => _QuickStockPriceDialog(product: product, isDark: isDark),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image container with stock badge & quick edit overlay
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: hasImage
                        ? CachedProductImage(
                            imageUrl: product.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: placeholderBg,
                              child: Center(
                                child: Icon(Icons.shopping_bag_outlined, color: iconColor, size: 28),
                              ),
                            ),
                          )
                        : Container(
                            color: placeholderBg,
                            child: Center(
                              child: Icon(Icons.shopping_bag_outlined, color: iconColor, size: 28),
                            ),
                          ),
                  ),
                  // Clickable stock badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: InkWell(
                      onTap: () => AddStockDialog.show(context, product: product, isDark: isDark),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.stockStatusColor(product.stockStatus).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.stockStatusColor(product.stockStatus),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.formattedStock,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.add_rounded, color: AppTheme.stockStatusColor(product.stockStatus), size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Multi mode pill
                  if (isMulti)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          PosL10n.of(ref.watch(settingsProvider).languageCode).multiModeBadge,
                          style: GoogleFonts.notoSansSinhala(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  // More action button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showActionSheet(context, ref),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.sinhalaOrName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSansSinhala(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  if (secondaryName != null)
                    Text(
                      secondaryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.currency(product.price),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        '/ ${product.unit}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
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

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final int index;
  final bool isDark;

  const _CartItemTile({
    required this.item,
    required this.index,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final qtyColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final imageUrl = item.product?.imageUrl;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    final imgBg = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9);
    final iconColor = isDark ? Colors.white24 : const Color(0xFF94A3B8);

    return Row(
      children: [
        // Product Thumbnail Image
        Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: imgBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasImage
                ? CachedProductImage(
                    imageUrl: imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: imgBg,
                      child: Icon(
                        item.itemType == 'service' ? Icons.build_rounded : Icons.shopping_bag_outlined,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    color: imgBg,
                    child: Icon(
                      item.itemType == 'service'
                          ? Icons.build_rounded
                          : (item.isQuickItem ? Icons.flash_on_rounded : Icons.shopping_bag_outlined),
                      color: iconColor,
                      size: 20,
                    ),
                  ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: titleColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    Formatters.currency(item.total),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '(${Formatters.currency(item.itemPrice)}/${item.productBaseUnit})',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QtyButton(
              icon: Icons.remove,
              isDark: isDark,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .decrementQuantity(index: index),
            ),
            InkWell(
              onTap: () => CartQuantityEditDialog.show(
                context,
                item: item,
                index: index,
                isDark: isDark,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  item.formattedQuantity,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: qtyColor),
                ),
              ),
            ),
            _QtyButton(
              icon: Icons.add,
              isDark: isDark,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .incrementQuantity(index: index),
            ),
          ],
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _QtyButton({
    required this.icon,
    required this.onTap,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
    final fg = isDark ? Colors.white70 : const Color(0xFF475569);
    final border = isDark ? Colors.transparent : const Color(0xFFCBD5E1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 14, color: fg),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool isDark;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isTotal
        ? (isDark ? Colors.white : const Color(0xFF0F172A))
        : (isDark ? Colors.white60 : const Color(0xFF64748B));
    final valueColor = isTotal
        ? AppTheme.primaryGreen
        : (isDark ? Colors.white70 : const Color(0xFF334155));

    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
            color: labelColor,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _CashierTile extends StatelessWidget {
  final Employee employee;
  final bool isDark;

  const _CashierTile({
    required this.employee,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = employee.rawRole == EmployeeRole.owner;
    final tileBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final nameColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isOwner
                  ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                  : AppTheme.primaryPurple.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOwner
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: isOwner
                  ? AppTheme.primaryBlue
                  : AppTheme.primaryPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.name,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: nameColor)),
                Text(isOwner ? 'Owner' : 'Cashier',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: subColor)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  employee.status == EmployeeStatus.active
                      ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              employee.status == EmployeeStatus.active ? 'Active' : 'Off',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: employee.status == EmployeeStatus.active
                      ? AppTheme.primaryGreen
                      : Colors.red,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checkout Dialog & Post-Sale Actions ─────────────────────────────────────

class _DesktopCheckoutDialog extends ConsumerStatefulWidget {
  final double total;
  final List<CartItem> cartItems;
  final Customer? customer;
  final Employee? employee;

  const _DesktopCheckoutDialog({
    super.key,
    required this.total,
    required this.cartItems,
    required this.customer,
    required this.employee,
  });

  @override
  ConsumerState<_DesktopCheckoutDialog> createState() => _DesktopCheckoutDialogState();
}

class _DesktopCheckoutDialogState extends ConsumerState<_DesktopCheckoutDialog> {
  String _paymentMethod = 'cash'; // 'cash', 'card', 'credit', 'other'
  final _cashController = TextEditingController();
  final _discountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cashController.text = widget.total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _discount => double.tryParse(_discountController.text.replaceAll(',', '')) ?? 0;
  double get _netTotal => (widget.total - _discount).clamp(0, double.infinity);
  double get _cashPaid => double.tryParse(_cashController.text.replaceAll(',', '')) ?? 0;
  double get _change => _cashPaid - _netTotal;

  void _setAmount(double amount) {
    setState(() {
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _processSale() async {
    final isCredit = _paymentMethod == 'credit';
    if (isCredit && widget.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach a customer to issue store credit.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_paymentMethod == 'cash' && _cashPaid < _netTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cash received is less than total due.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final rootNavContext = Navigator.of(context, rootNavigator: true).context;
    setState(() => _isProcessing = true);

    try {
      final saleActions = ref.read(saleActionsProvider);
      final createdSale = await saleActions.createSale(
        cartItems: widget.cartItems,
        total: _netTotal,
        discount: _discount,
        paymentMethod: _paymentMethod,
        customerId: widget.customer?.id,
        customerName: widget.customer?.name,
        customerPhone: widget.customer?.phone,
      );

      // Clear cart & customer
      ref.read(cartProvider.notifier).clear();
      ref.read(selectedCustomerProvider.notifier).state = null;

      if (mounted) {
        Navigator.pop(context); // Close checkout dialog
        _showPostSaleDialog(rootNavContext, ref, createdSale, widget.cartItems, widget.customer, _netTotal, _change);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing sale: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final inputTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inputHintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);
    final inputBorder = isDark ? BorderSide.none : const BorderSide(color: Color(0xFFCBD5E1));
    final isCredit = _paymentMethod == 'credit';

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    PosL10n.of(ref.watch(settingsProvider).languageCode).checkout,
                    style: GoogleFonts.notoSansSinhala(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const Spacer(),
                  if (widget.customer != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 14, color: AppTheme.primaryBlue),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.customer!.name,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Total display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      PosL10n.of(ref.watch(settingsProvider).languageCode).amountDue,
                      style: GoogleFonts.notoSansSinhala(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.currency(_netTotal),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Discount Input
              TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(color: inputTextColor, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Discount Amount (Optional)',
                  labelStyle: GoogleFonts.inter(color: inputHintColor, fontSize: 13),
                  prefixIcon: const Icon(Icons.discount_outlined, color: Colors.amber, size: 20),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: inputBorder),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: inputBorder),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                PosL10n.of(ref.watch(settingsProvider).languageCode).paymentMethod,
                style: GoogleFonts.notoSansSinhala(fontSize: 12, fontWeight: FontWeight.w700, color: subTextColor, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              // Payment Method Chips (Cash, Card, Credit, Other)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MethodChip(
                    label: PosL10n.of(ref.watch(settingsProvider).languageCode).cashPayment,
                    isSelected: _paymentMethod == 'cash',
                    onTap: () => setState(() => _paymentMethod = 'cash'),
                    isDark: isDark,
                  ),
                  _MethodChip(
                    label: PosL10n.of(ref.watch(settingsProvider).languageCode).cardPayment,
                    isSelected: _paymentMethod == 'card',
                    onTap: () => setState(() => _paymentMethod = 'card'),
                    isDark: isDark,
                  ),
                  _MethodChip(
                    label: PosL10n.of(ref.watch(settingsProvider).languageCode).creditPayment,
                    isSelected: _paymentMethod == 'credit',
                    onTap: () => setState(() => _paymentMethod = 'credit'),
                    isDark: isDark,
                  ),
                  _MethodChip(
                    label: PosL10n.of(ref.watch(settingsProvider).languageCode).otherPayment,
                    isSelected: _paymentMethod == 'other',
                    onTap: () => setState(() => _paymentMethod = 'other'),
                    isDark: isDark,
                  ),
                ],
              ),

              // ── CREDIT WARNING / INFO ──
              if (isCredit) ...[
                const SizedBox(height: 14),
                if (widget.customer != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Debt of ${Formatters.currency(_netTotal)} will be recorded for ${widget.customer!.name}.',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ ${PosL10n.of(ref.watch(settingsProvider).languageCode).customerCreditWarning}',
                            style: GoogleFonts.notoSansSinhala(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.errorRed),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              // ── CASH RECEIVED & QUICK AMOUNTS ──
              if (_paymentMethod == 'cash') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(color: inputTextColor, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: PosL10n.of(ref.watch(settingsProvider).languageCode).cashPaid,
                    labelStyle: GoogleFonts.notoSansSinhala(color: inputHintColor),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: inputBorder),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: inputBorder),
                  ),
                ),
                const SizedBox(height: 10),
                Text('QUICK AMOUNTS',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: subTextColor, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _QuickAmtChip(
                      label: 'Exact',
                      isSelected: _cashPaid == _netTotal,
                      onTap: () => _setAmount(_netTotal),
                      isDark: isDark,
                    ),
                    for (final amt in [500.0, 1000.0, 2000.0, 5000.0, 10000.0])
                      _QuickAmtChip(
                        label: Formatters.currencySimple(amt),
                        isSelected: _cashPaid == amt,
                        onTap: () => _setAmount(amt),
                        isDark: isDark,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_cashPaid >= _netTotal && _cashPaid > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${PosL10n.of(ref.watch(settingsProvider).languageCode).changeToReturn}:',
                          style: GoogleFonts.notoSansSinhala(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.currency(_change),
                          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  )
                else if (_cashPaid < _netTotal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Insufficient Cash Paid',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      PosL10n.of(ref.watch(settingsProvider).languageCode).cancel,
                      style: GoogleFonts.notoSansSinhala(color: inputHintColor),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processSale,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              PosL10n.of(ref.watch(settingsProvider).languageCode).completePayment,
                              style: GoogleFonts.notoSansSinhala(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
}

class _MethodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _MethodChip({required this.label, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryGreen : (isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
      ),
      labelStyle: GoogleFonts.inter(
        color: isSelected ? AppTheme.primaryGreen : (isDark ? Colors.white70 : const Color(0xFF475569)),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _QuickAmtChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickAmtChip({required this.label, required this.isSelected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppTheme.primaryBlue.withValues(alpha: 0.2)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9));
    final fg = isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white70 : const Color(0xFF475569));
    final border = isSelected ? AppTheme.primaryBlue : (isDark ? Colors.transparent : const Color(0xFFCBD5E1));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}

// ─── Post Sale Success Dialog ──────────────────────────────────────────────────

void _showPostSaleDialog(
  BuildContext context,
  WidgetRef ref,
  Sale sale,
  List<CartItem> cartItems,
  Customer? customer,
  double total,
  double change,
) {
  final settings = ref.read(settingsProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
  final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

  List<SaleItem> buildSaleItems() => cartItems
      .map((c) => SaleItem(
            saleId: sale.id ?? 0,
            productId: c.itemType == 'product' && !c.isQuickItem ? (c.product?.id ?? 0) : 0,
            itemType: c.itemType,
            serviceId: c.serviceId,
            productName: c.itemName,
            quantity: c.quantity,
            unitPrice: c.itemPrice,
            total: c.total,
            costPrice: (c.itemType == 'product' && !c.isQuickItem) ? (c.product?.costPrice ?? 0.0) : 0.0,
            batchId: c.batchId,
            batchNumber: c.batchNumber,
            discount: c.discount,
          ))
      .toList();

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actionsAlignment: MainAxisAlignment.center,
      title: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.grey),
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sale Completed!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bill #${sale.billNumber}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total: ${Formatters.currency(total)}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
          ),
          if (change > 0 && sale.paymentMethod == 'cash') ...[
            const SizedBox(height: 6),
            Text(
              'Change: ${Formatters.currency(change)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ],
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: Text(settings.is58mm ? 'Print Receipt (58mm)' : 'Print Receipt (80mm)'),
              onPressed: () async {
                try {
                  await PrintingService.instance.printReceiptUnified(sale, buildSaleItems(), settings);
                } catch (e) {
                  debugPrint('Error printing receipt: $e');
                }
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Print Invoice (A4)'),
              onPressed: () async {
                try {
                  await PdfService.instance.generateProfessionalInvoice(sale, buildSaleItems(), settings: settings);
                } catch (e) {
                  debugPrint('Error printing invoice: $e');
                }
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('WhatsApp'),
              onPressed: () => _handleWhatsAppShare(ctx, sale, buildSaleItems(), settings),
            ),
            if (sale.customerPhone != null && sale.customerPhone!.trim().isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.message_rounded, size: 18),
                label: const Text('SMS'),
                onPressed: () => ShareService.instance.shareViaSMS(sale, buildSaleItems(), settings),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Done (New Sale)'),
            ),
          ],
        ),
      ],
    ),
  );
}

void _handleWhatsAppShare(BuildContext context, Sale sale, List<SaleItem> items, AppSettings settings) {
  if (sale.customerPhone != null && sale.customerPhone!.trim().isNotEmpty) {
    ShareService.instance.shareViaWhatsApp(sale, items, settings, phone: sale.customerPhone);
  } else {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (promptCtx) {
        final isDark = Theme.of(promptCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.chat_rounded, color: Colors.green.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Send via WhatsApp',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter WhatsApp phone number:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: GoogleFonts.inter(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g. 0771234567 or +94771234567',
                  hintStyle: GoogleFonts.inter(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(promptCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final phone = phoneController.text.trim();
                Navigator.pop(promptCtx);
                ShareService.instance.shareViaWhatsApp(sale, items, settings, phone: phone);
              },
              child: Text('Send WhatsApp', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _QuickCustomItemDialog extends StatefulWidget {
  final bool isDark;
  final void Function(String name, double price, double qty) onAdd;

  const _QuickCustomItemDialog({required this.isDark, required this.onAdd});

  @override
  State<_QuickCustomItemDialog> createState() => _QuickCustomItemDialogState();
}

class _QuickCustomItemDialogState extends State<_QuickCustomItemDialog> {
  final _nameController = TextEditingController(text: 'Custom Item');
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: AppTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Quick Custom Item (F4)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.inter(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Item Name / Description',
                  hintText: 'e.g. Service / Loose Item',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: SinhalaConvertSuffix(
                    controller: _nameController,
                    isDark: isDark,
                    onConverted: () => setState(() {}),
                  ),
                ),
                validator: (v) => v?.trim().isEmpty == true ? 'Enter item name' : null,
              ),
              SinhalaSuggestionBanner(
                controller: _nameController,
                isDark: isDark,
                onApplied: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Price (LKR)',
                        hintText: '0.00',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Valid price required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        hintText: '1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Valid qty';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(color: isDark ? Colors.white60 : Colors.black54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text('Add to Cart', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    onPressed: () {
                      if (_formKey.currentState?.validate() == true) {
                        final name = _nameController.text.trim();
                        final price = double.parse(_priceController.text.trim());
                        final qty = double.parse(_qtyController.text.trim());
                        widget.onAdd(name, price, qty);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStockPriceDialog extends ConsumerStatefulWidget {
  final Product product;
  final bool isDark;

  const _QuickStockPriceDialog({required this.product, required this.isDark});

  @override
  ConsumerState<_QuickStockPriceDialog> createState() => _QuickStockPriceDialogState();
}

class _QuickStockPriceDialogState extends ConsumerState<_QuickStockPriceDialog> {
  late TextEditingController _nameController;
  late TextEditingController _nameSinhalaController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _barcodeController;
  late TextEditingController _stockAddController;
  late TextEditingController _exactStockController;
  bool _isSettingExactStock = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _nameSinhalaController = TextEditingController(text: widget.product.nameSinhala ?? '');
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(2));
    _costPriceController = TextEditingController(
      text: widget.product.costPrice != null ? widget.product.costPrice!.toStringAsFixed(2) : '',
    );
    _barcodeController = TextEditingController(text: widget.product.baseBarcode ?? '');
    _stockAddController = TextEditingController(text: '0');
    _exactStockController = TextEditingController(text: widget.product.calculatedStock.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameSinhalaController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _barcodeController.dispose();
    _stockAddController.dispose();
    _exactStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final nameSinhala = _nameSinhalaController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final costPrice = double.tryParse(_costPriceController.text.trim());
      final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();

      double newStock = widget.product.stock;
      if (_isSettingExactStock) {
        newStock = double.tryParse(_exactStockController.text.trim()) ?? widget.product.stock;
      } else {
        final addQty = double.tryParse(_stockAddController.text.trim()) ?? 0.0;
        newStock += addQty;
      }

      final updatedProduct = widget.product.copyWith(
        name: name,
        nameSinhala: nameSinhala.isNotEmpty ? nameSinhala : null,
        price: price,
        costPrice: costPrice,
        baseBarcode: barcode,
        stock: newStock,
      );

      await ref.read(productActionsProvider).updateProduct(updatedProduct);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Updated ${widget.product.name} successfully!', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating product: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final sectionBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.primaryGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Product Update',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          widget.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: hintColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: hintColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name (English & Sinhala)
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.inter(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Product Name (English / Base)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: SinhalaConvertSuffix(
                            controller: _nameController,
                            isDark: isDark,
                            onConverted: () {
                              final sinhala = SinhalaTransliterationService.transliterate(_nameController.text);
                              if (_nameSinhalaController.text.trim().isEmpty) {
                                _nameSinhalaController.text = sinhala;
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      SinhalaSuggestionBanner(
                        controller: _nameController,
                        isDark: isDark,
                        onApplied: () {
                          if (_nameSinhalaController.text.trim().isEmpty) {
                            _nameSinhalaController.text = _nameController.text;
                          }
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameSinhalaController,
                        style: GoogleFonts.notoSansSinhala(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Sinhala Name (සිංහල නම)',
                          hintText: 'e.g. කිරි තේ / සුදු සීනි',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: SinhalaConvertSuffix(
                            controller: _nameSinhalaController,
                            isDark: isDark,
                            onConverted: () => setState(() {}),
                          ),
                        ),
                      ),
                      SinhalaSuggestionBanner(
                        controller: _nameSinhalaController,
                        isDark: isDark,
                        onApplied: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Pricing Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Selling Price (LKR)',
                                prefixText: 'Rs. ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) {
                                final val = double.tryParse(v ?? '');
                                if (val == null || val < 0) return 'Valid price';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _costPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Cost Price (LKR)',
                                prefixText: 'Rs. ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Barcode
                      TextFormField(
                        controller: _barcodeController,
                        style: GoogleFonts.inter(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Barcode',
                          hintText: 'Scan or enter barcode',
                          suffixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stock Management Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sectionBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.primaryGreen),
                                    const SizedBox(width: 6),
                                    Text('Current Stock:', style: GoogleFonts.inter(fontSize: 13, color: hintColor)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${widget.product.calculatedStock.toInt()} ${widget.product.unit}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: Text('+/- Adjust Stock', style: GoogleFonts.inter(fontSize: 12)),
                                  selected: !_isSettingExactStock,
                                  onSelected: (val) => setState(() => _isSettingExactStock = !val),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text('Set Exact Count', style: GoogleFonts.inter(fontSize: 12)),
                                  selected: _isSettingExactStock,
                                  onSelected: (val) => setState(() => _isSettingExactStock = val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (!_isSettingExactStock) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _stockAddController,
                                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                      style: GoogleFonts.inter(color: textColor, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Add / Deduct Quantity',
                                        hintText: 'e.g. 10 or -5',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: [
                                  for (final q in [5, 10, 25, 50, 100])
                                    ActionChip(
                                      label: Text('+$q', style: GoogleFonts.inter(fontSize: 11)),
                                      onPressed: () {
                                        final cur = double.tryParse(_stockAddController.text) ?? 0;
                                        _stockAddController.text = (cur + q).toInt().toString();
                                      },
                                    ),
                                ],
                              ),
                            ] else ...[
                              TextFormField(
                                controller: _exactStockController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.inter(color: textColor, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'New Exact Stock Level',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Footer Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('Full Edit Form', style: GoogleFonts.inter(fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddProductScreen(product: widget.product)),
                      );
                    },
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter(color: hintColor)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text('Save Update', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        onPressed: _isSaving ? null : _save,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


