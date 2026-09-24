import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/discount.dart';
import '../../models/product.dart';
import '../../providers/discount_provider.dart';
import '../../providers/preference_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/category_constants.dart';
import '../../utils/formatters.dart';
import '../../utils/pos_l10n.dart';
import '../../utils/l10n_extensions.dart';
import '../add_stock_dialog.dart';
import '../cached_product_image.dart';
import '../../screens/stock/add_product_screen.dart';
import '../../screens/stock/batch_list_screen.dart';
import '../../screens/inventory/stock_history_screen.dart';

/// Position of a cell within the table (0-indexed).
class CellPosition {
  final int row;
  final int col;

  const CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'CellPosition($row, $col)';
}

/// Column indices for the Excel Inventory Table:
/// 0: Select Checkbox
/// 1: Product Name
/// 2: Sinhala Name
/// 3: Barcode
/// 4: Category
/// 5: Current Stock
/// 6: Minimum Stock
/// 7: Purchase Price (Cost)
/// 8: Selling Price
/// 9: Discount
/// 10: Unit
/// 11: Tax / VAT
/// 12: Actions
class ExcelColumns {
  static const int select = 0;
  static const int name = 1;
  static const int nameSinhala = 2;
  static const int barcode = 3;
  static const int category = 4;
  static const int stock = 5;
  static const int minStock = 6;
  static const int costPrice = 7;
  static const int price = 8;
  static const int discount = 9;
  static const int unit = 10;
  static const int tax = 11;
  static const int actions = 12;

  static const int firstEditable = 1;
  static const int lastEditable = 10;
}

class ExcelInventoryTable extends ConsumerStatefulWidget {
  final List<Product> products;
  final Set<int> selectedProductIds;
  final ValueChanged<Set<int>> onSelectionChanged;
  final String sortColumn;
  final bool sortAscending;
  final Function(String column, bool ascending) onSort;
  final VoidCallback? onRefresh;

  const ExcelInventoryTable({
    super.key,
    required this.products,
    required this.selectedProductIds,
    required this.onSelectionChanged,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    this.onRefresh,
  });

  @override
  ConsumerState<ExcelInventoryTable> createState() => _ExcelInventoryTableState();
}

class _ExcelInventoryTableState extends ConsumerState<ExcelInventoryTable> {
  CellPosition? _activeCell;
  CellPosition? _editingCell;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _cellFocusNode = FocusNode();
  final ScrollController _headerScrollCtrl = ScrollController();
  final ScrollController _bodyHScrollCtrl = ScrollController();
  final ScrollController _bodyVScrollCtrl = ScrollController();

  final Set<int> _savingProductIds = {};
  CellPosition? _recentlySavedCell;
  Timer? _savedFeedbackTimer;
  String? _cellErrorMessage;

  static const List<String> _availableUnits = [
    'pcs',
    'kg',
    'g',
    'L',
    'ml',
    'pack',
    'box',
    'bottle',
    'can',
    'm',
    'bundle',
  ];

  @override
  void initState() {
    super.initState();
    // Synchronize horizontal scrolling between header and body
    _bodyHScrollCtrl.addListener(() {
      if (_headerScrollCtrl.hasClients &&
          _headerScrollCtrl.offset != _bodyHScrollCtrl.offset) {
        _headerScrollCtrl.jumpTo(_bodyHScrollCtrl.offset);
      }
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _cellFocusNode.dispose();
    _headerScrollCtrl.dispose();
    _bodyHScrollCtrl.dispose();
    _bodyVScrollCtrl.dispose();
    _savedFeedbackTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Cell Navigation & Editing Engine
  // ──────────────────────────────────────────────────────────────────────────

  void _activateCell(int row, int col) {
    if (row < 0 || row >= widget.products.length) return;
    if (col < ExcelColumns.firstEditable || col > ExcelColumns.lastEditable) return;

    if (_editingCell != null && _editingCell != CellPosition(row, col)) {
      _commitEdit();
    }

    setState(() {
      _activeCell = CellPosition(row, col);
    });
  }

  void _startEditing(int row, int col) {
    if (row < 0 || row >= widget.products.length) return;
    if (col < ExcelColumns.firstEditable || col > ExcelColumns.lastEditable) return;

    final product = widget.products[row];
    String initialText = '';

    switch (col) {
      case ExcelColumns.name:
        initialText = product.name;
        break;
      case ExcelColumns.nameSinhala:
        initialText = product.nameSinhala ?? '';
        break;
      case ExcelColumns.barcode:
        initialText = product.baseBarcode ?? '';
        break;
      case ExcelColumns.stock:
        initialText = product.stock == product.stock.roundToDouble()
            ? product.stock.toInt().toString()
            : product.stock.toString();
        break;
      case ExcelColumns.minStock:
        initialText = product.minStock == product.minStock.roundToDouble()
            ? product.minStock.toInt().toString()
            : product.minStock.toString();
        break;
      case ExcelColumns.costPrice:
        initialText = product.costPrice != null
            ? (product.costPrice == product.costPrice!.roundToDouble()
                ? product.costPrice!.toInt().toString()
                : product.costPrice!.toString())
            : '';
        break;
      case ExcelColumns.price:
        initialText = product.price == product.price.roundToDouble()
            ? product.price.toInt().toString()
            : product.price.toString();
        break;
      case ExcelColumns.discount:
        final activeDiscount = ref.read(discountsProvider.notifier).getActiveDiscountSync(product.id ?? 0);
        initialText = activeDiscount != null
            ? activeDiscount.discountValue.toString()
            : '0';
        break;
      default:
        initialText = '';
    }

    setState(() {
      _activeCell = CellPosition(row, col);
      _editingCell = CellPosition(row, col);
      _cellErrorMessage = null;
      _editController.text = initialText;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    });

    // Request focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cellFocusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCell = null;
      _cellErrorMessage = null;
    });
  }

  Future<bool> _commitEdit() async {
    if (_editingCell == null) return true;
    final row = _editingCell!.row;
    final col = _editingCell!.col;

    if (row >= widget.products.length) {
      _cancelEdit();
      return true;
    }

    final product = widget.products[row];
    final text = _editController.text.trim();

    // Validation & Update
    try {
      final productActions = ref.read(productActionsProvider);
      bool changed = false;

      switch (col) {
        case ExcelColumns.name:
          if (text.isEmpty) {
            _showError('Product name cannot be empty');
            return false;
          }
          if (text != product.name) {
            await _runSave(product.id, () async {
              await productActions.updateProduct(product.copyWith(name: text));
            });
            changed = true;
          }
          break;

        case ExcelColumns.nameSinhala:
          final newNameSinhala = text.isEmpty ? null : text;
          if (newNameSinhala != product.nameSinhala) {
            await _runSave(product.id, () async {
              await productActions.updateProduct(product.copyWith(nameSinhala: newNameSinhala));
            });
            changed = true;
          }
          break;

        case ExcelColumns.barcode:
          final newBarcode = text.isEmpty ? null : text;
          if (newBarcode != product.baseBarcode) {
            await _runSave(product.id, () async {
              await productActions.updateProduct(product.copyWith(baseBarcode: newBarcode));
            });
            changed = true;
          }
          break;

        case ExcelColumns.stock:
          final newStock = double.tryParse(text);
          if (newStock == null || newStock < 0) {
            _showError('Stock must be a non-negative number');
            return false;
          }
          if (newStock != product.stock) {
            final diff = newStock - product.stock;
            await _runSave(product.id, () async {
              await productActions.adjustStock(
                productId: product.id!,
                quantityChange: diff,
                notes: 'Inline Excel stock update ($text)',
              );
            });
            changed = true;
          }
          break;

        case ExcelColumns.minStock:
          final newMin = double.tryParse(text);
          if (newMin == null || newMin < 0) {
            _showError('Min stock must be non-negative');
            return false;
          }
          if (newMin != product.minStock) {
            await _runSave(product.id, () async {
              await productActions.updateProduct(product.copyWith(minStock: newMin));
            });
            changed = true;
          }
          break;

        case ExcelColumns.costPrice:
          final newCost = text.isEmpty ? null : double.tryParse(text);
          if (newCost != null && newCost < 0) {
            _showError('Cost price cannot be negative');
            return false;
          }
          if (newCost != product.costPrice) {
            await _runSave(product.id, () async {
              await productActions.updateProduct(product.copyWith(costPrice: newCost));
            });
            changed = true;
          }
          break;

        case ExcelColumns.price:
          final newPrice = double.tryParse(text);
          if (newPrice == null || newPrice < 0) {
            _showError('Selling price must be non-negative');
            return false;
          }
          if (newPrice != product.price) {
            await _runSave(product.id, () async {
              await productActions.updateProduct(product.copyWith(price: newPrice));
            });
            changed = true;
          }
          break;

        case ExcelColumns.discount:
          final discountVal = double.tryParse(text) ?? 0.0;
          if (discountVal < 0) {
            _showError('Discount cannot be negative');
            return false;
          }
          if (product.id != null) {
            final discountNotifier = ref.read(discountsProvider.notifier);
            final existing = discountNotifier.getActiveDiscountSync(product.id!);
            await _runSave(product.id, () async {
              if (discountVal <= 0) {
                if (existing != null && existing.id != null) {
                  await discountNotifier.deleteDiscount(existing.id!);
                }
              } else {
                final isPercentage = discountVal <= 100;
                final newDiscount = Discount(
                  id: existing?.id,
                  productId: product.id,
                  discountValue: discountVal,
                  discountType: isPercentage ? 'percentage' : 'fixed',
                  startDate: DateTime.now().subtract(const Duration(hours: 1)),
                  endDate: DateTime.now().add(const Duration(days: 365)),
                  isActive: true,
                );
                if (existing != null) {
                  await discountNotifier.updateDiscount(newDiscount);
                } else {
                  await discountNotifier.addDiscount(newDiscount);
                }
              }
            });
            changed = true;
          }
          break;
      }

      if (changed) {
        _triggerSavedFeedback(CellPosition(row, col));
      }

      setState(() {
        _editingCell = null;
        _cellErrorMessage = null;
      });
      return true;
    } catch (e) {
      _showError('Save failed: $e');
      return false;
    }
  }

  Future<void> _runSave(int? productId, Future<void> Function() action) async {
    if (productId == null) return;
    setState(() => _savingProductIds.add(productId));
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _savingProductIds.remove(productId));
      }
    }
  }

  void _showError(String message) {
    setState(() => _cellErrorMessage = message);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerSavedFeedback(CellPosition pos) {
    _savedFeedbackTimer?.cancel();
    setState(() => _recentlySavedCell = pos);
    _savedFeedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _recentlySavedCell = null);
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Keyboard Shortcuts (Enter, Tab, Shift-Tab, Esc)
  // ──────────────────────────────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelEdit();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_editingCell != null) {
        final currentRow = _editingCell!.row;
        final currentCol = _editingCell!.col;
        _commitEdit().then((ok) {
          if (ok && currentRow < widget.products.length - 1) {
            _activateCell(currentRow + 1, currentCol);
            _startEditing(currentRow + 1, currentCol);
          }
        });
        return KeyEventResult.handled;
      } else if (_activeCell != null) {
        _startEditing(_activeCell!.row, _activeCell!.col);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final curRow = _editingCell?.row ?? _activeCell?.row ?? 0;
      final curCol = _editingCell?.col ?? _activeCell?.col ?? ExcelColumns.name;

      _commitEdit().then((ok) {
        if (!ok) return;
        if (!isShift) {
          // Tab forward
          if (curCol < ExcelColumns.lastEditable) {
            _activateCell(curRow, curCol + 1);
            _startEditing(curRow, curCol + 1);
          } else if (curRow < widget.products.length - 1) {
            _activateCell(curRow + 1, ExcelColumns.firstEditable);
            _startEditing(curRow + 1, ExcelColumns.firstEditable);
          }
        } else {
          // Shift+Tab backward
          if (curCol > ExcelColumns.firstEditable) {
            _activateCell(curRow, curCol - 1);
            _startEditing(curRow, curCol - 1);
          } else if (curRow > 0) {
            _activateCell(curRow - 1, ExcelColumns.lastEditable);
            _startEditing(curRow - 1, ExcelColumns.lastEditable);
          }
        }
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Quick Dropdown Updates (Category & Unit)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _updateCategory(Product product, String? newCategory) async {
    if (product.id == null || newCategory == product.category) return;
    await _runSave(product.id, () async {
      await ref.read(productActionsProvider).updateProduct(
            product.copyWith(category: newCategory),
          );
    });
    final row = widget.products.indexWhere((p) => p.id == product.id);
    if (row != -1) {
      _triggerSavedFeedback(CellPosition(row, ExcelColumns.category));
    }
  }

  Future<void> _updateUnit(Product product, String newUnit) async {
    if (product.id == null || newUnit == product.unit) return;
    await _runSave(product.id, () async {
      await ref.read(productActionsProvider).updateProduct(
            product.copyWith(unit: newUnit),
          );
    });
    final row = widget.products.indexWhere((p) => p.id == product.id);
    if (row != -1) {
      _triggerSavedFeedback(CellPosition(row, ExcelColumns.unit));
    }
  }

  Future<void> _updateTaxStatus(Product product, String newStatus) async {
    if (product.id == null || newStatus == product.taxStatus) return;
    await _runSave(product.id, () async {
      await ref.read(productActionsProvider).updateProduct(
            product.copyWith(taxStatus: newStatus),
          );
    });
    final row = widget.products.indexWhere((p) => p.id == product.id);
    if (row != -1) {
      _triggerSavedFeedback(CellPosition(row, ExcelColumns.tax));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Actions Menu Callbacks
  // ──────────────────────────────────────────────────────────────────────────

  void _openRestock(Product product) async {
    final res = await AddStockDialog.show(
      context,
      product: product,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    if (res == true) {
      widget.onRefresh?.call();
    }
  }

  void _openEditModal(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(product: product),
      ),
    ).then((_) {
      ref.invalidate(productsProvider);
      widget.onRefresh?.call();
    });
  }

  Future<void> _archiveProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text('Are you sure you want to archive "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true && product.id != null) {
      await ref.read(productActionsProvider).deleteProduct(product.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archived "${product.name}"')),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build Method
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final isDark = settings.isDarkMode;

    final tableBg = isDark ? const Color(0xFF131E31) : Colors.white;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    const activeBorderColor = AppTheme.primaryGreen;

    // Column widths definition
    const double colSelectWidth = 46;
    const double colNameWidth = 220;
    const double colNameSinhalaWidth = 160;
    const double colBarcodeWidth = 140;
    const double colCategoryWidth = 150;
    const double colStockWidth = 135;
    const double colMinStockWidth = 120;
    const double colCostWidth = 110;
    const double colPriceWidth = 120;
    const double colDiscountWidth = 110;
    const double colUnitWidth = 105;
    const double colTaxWidth = 130;
    const double colActionsWidth = 220;

    const double totalTableWidth = colSelectWidth +
        colNameWidth +
        colNameSinhalaWidth +
        colBarcodeWidth +
        colCategoryWidth +
        colStockWidth +
        colMinStockWidth +
        colCostWidth +
        colPriceWidth +
        colDiscountWidth +
        colUnitWidth +
        colTaxWidth +
        colActionsWidth;

    return Focus(
      focusNode: _cellFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: BoxDecoration(
          color: tableBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sticky Header ──
              SingleChildScrollView(
                controller: _headerScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Container(
                  width: totalTableWidth,
                  height: 48,
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      // Selection Header
                      _buildHeaderCell(
                        width: colSelectWidth,
                        child: Center(
                          child: Checkbox(
                            value: widget.products.isNotEmpty &&
                                widget.selectedProductIds.length == widget.products.length,
                            tristate: widget.selectedProductIds.isNotEmpty &&
                                widget.selectedProductIds.length < widget.products.length,
                            onChanged: (val) {
                              if (val == true) {
                                widget.onSelectionChanged(
                                  widget.products.where((p) => p.id != null).map((p) => p.id!).toSet(),
                                );
                              } else {
                                widget.onSelectionChanged({});
                              }
                            },
                          ),
                        ),
                      ),
                      _buildSortableHeader(
                        title: posL10n.productCol,
                        columnKey: 'name',
                        width: colNameWidth,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: 'Sinhala Name',
                        columnKey: 'nameSinhala',
                        width: colNameSinhalaWidth,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: posL10n.barcodeCol,
                        columnKey: 'barcode',
                        width: colBarcodeWidth,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: posL10n.categoryCol,
                        columnKey: 'category',
                        width: colCategoryWidth,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: posL10n.stockLevelCol,
                        columnKey: 'stock',
                        width: colStockWidth,
                        alignRight: true,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: 'Min Stock',
                        columnKey: 'minStock',
                        width: colMinStockWidth,
                        alignRight: true,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: '${posL10n.costCol} (Rs.)',
                        columnKey: 'costPrice',
                        width: colCostWidth,
                        alignRight: true,
                        textPrimary: textPrimary,
                      ),
                      _buildSortableHeader(
                        title: '${posL10n.sellingPriceCol} (Rs.)',
                        columnKey: 'price',
                        width: colPriceWidth,
                        alignRight: true,
                        textPrimary: textPrimary,
                      ),
                      _buildHeaderCell(
                        width: colDiscountWidth,
                        child: Center(
                          child: Text(
                            posL10n.discount,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                      _buildHeaderCell(
                        width: colUnitWidth,
                        child: Center(
                          child: Text(
                            'Unit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                      _buildHeaderCell(
                        width: colTaxWidth,
                        child: Center(
                          child: Text(
                            'Tax / VAT',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                      _buildHeaderCell(
                        width: colActionsWidth,
                        child: Center(
                          child: Text(
                            posL10n.actionsCol,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Data Rows Viewport ──
              Expanded(
                child: SingleChildScrollView(
                  controller: _bodyHScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalTableWidth,
                    child: ListView.builder(
                      controller: _bodyVScrollCtrl,
                      itemCount: widget.products.length,
                      itemBuilder: (context, rowIndex) {
                        final product = widget.products[rowIndex];
                        final isSelected = widget.selectedProductIds.contains(product.id);
                        final isSaving = _savingProductIds.contains(product.id);

                        final isRowDark = isDark
                            ? (rowIndex.isEven ? const Color(0xFF131E31) : const Color(0xFF17243A))
                            : (rowIndex.isEven ? Colors.white : const Color(0xFFF9FAFB));

                        return Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                                : isRowDark,
                            border: Border(
                              bottom: BorderSide(color: borderColor, width: 0.8),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Selection Checkbox
                              _buildDataCell(
                                width: colSelectWidth,
                                child: Center(
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      final newSet = Set<int>.from(widget.selectedProductIds);
                                      if (val == true && product.id != null) {
                                        newSet.add(product.id!);
                                      } else if (product.id != null) {
                                        newSet.remove(product.id!);
                                      }
                                      widget.onSelectionChanged(newSet);
                                    },
                                  ),
                                ),
                              ),

                              // Product Name (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.name,
                                width: colNameWidth,
                                isSaving: isSaving,
                                activeBorderColor: activeBorderColor,
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CachedProductImage(
                                          imageUrl: product.imageUrl ?? '',
                                          fit: BoxFit.cover,
                                          category: product.category,
                                          productName: product.name,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Sinhala Name (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.nameSinhala,
                                width: colNameSinhalaWidth,
                                isSaving: isSaving,
                                activeBorderColor: activeBorderColor,
                                child: Text(
                                  product.nameSinhala?.isNotEmpty == true
                                      ? product.nameSinhala!
                                      : '—',
                                  style: GoogleFonts.notoSansSinhala(
                                    fontSize: 12.5,
                                    color: product.nameSinhala?.isNotEmpty == true
                                        ? textPrimary
                                        : textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Barcode (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.barcode,
                                width: colBarcodeWidth,
                                isSaving: isSaving,
                                activeBorderColor: activeBorderColor,
                                child: Text(
                                  product.baseBarcode?.isNotEmpty == true
                                      ? product.baseBarcode!
                                      : '—',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Category (Dropdown picker)
                              _buildCategoryCell(
                                product: product,
                                width: colCategoryWidth,
                                isSaving: isSaving,
                                isDark: isDark,
                                textSecondary: textSecondary,
                              ),

                              // Current Stock (Editable with status pill)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.stock,
                                width: colStockWidth,
                                isSaving: isSaving,
                                alignRight: true,
                                activeBorderColor: activeBorderColor,
                                child: _buildStockDisplay(product),
                              ),

                              // Minimum Stock (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.minStock,
                                width: colMinStockWidth,
                                isSaving: isSaving,
                                alignRight: true,
                                activeBorderColor: activeBorderColor,
                                child: Text(
                                  '${Formatters.number(product.minStock)} ${product.unit}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: textSecondary,
                                  ),
                                ),
                              ),

                              // Purchase Cost (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.costPrice,
                                width: colCostWidth,
                                isSaving: isSaving,
                                alignRight: true,
                                activeBorderColor: activeBorderColor,
                                child: Text(
                                  product.costPrice != null
                                      ? Formatters.number(product.costPrice!, decimalPlaces: 2)
                                      : '—',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: textSecondary,
                                  ),
                                ),
                              ),

                              // Selling Price (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.price,
                                width: colPriceWidth,
                                isSaving: isSaving,
                                alignRight: true,
                                activeBorderColor: activeBorderColor,
                                child: Text(
                                  Formatters.number(product.price, decimalPlaces: 2),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),

                              // Discount (Editable)
                              _buildInteractiveCell(
                                rowIndex: rowIndex,
                                colIndex: ExcelColumns.discount,
                                width: colDiscountWidth,
                                isSaving: isSaving,
                                activeBorderColor: activeBorderColor,
                                child: _buildDiscountDisplay(product),
                              ),

                              // Unit (Dropdown picker)
                              _buildUnitCell(
                                product: product,
                                width: colUnitWidth,
                                isSaving: isSaving,
                                isDark: isDark,
                                textPrimary: textPrimary,
                              ),

                              // Tax / VAT (Dropdown picker)
                              _buildTaxCell(
                                product: product,
                                width: colTaxWidth,
                                defaultRate: (settings.defaultVatRate as double?) ?? 18.0,
                                isDark: isDark,
                                textPrimary: textPrimary,
                              ),

                              // Actions Row
                              _buildDataCell(
                                width: colActionsWidth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_box_outlined, size: 16),
                                      color: AppTheme.primaryGreen,
                                      tooltip: posL10n.restock,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _openRestock(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      color: AppTheme.primaryBlue,
                                      tooltip: posL10n.edit,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => _openEditModal(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.layers_outlined, size: 16),
                                      color: Colors.purple,
                                      tooltip: posL10n.batches,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BatchListScreen(product: product),
                                        ),
                                      ),
                                    ),
                                    if (product.id != null)
                                      IconButton(
                                        icon: const Icon(Icons.history_rounded, size: 17),
                                        color: Colors.teal,
                                        tooltip: 'Stock History',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StockHistoryScreen(
                                              productId: product.id!,
                                              productName: product.name,
                                            ),
                                          ),
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.archive_outlined, size: 17),
                                      color: AppTheme.errorRed,
                                      tooltip: 'Archive',
                                      onPressed: () => _archiveProduct(product),
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
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Cell Renderers & Editors
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildInteractiveCell({
    required int rowIndex,
    required int colIndex,
    required double width,
    required bool isSaving,
    required Color activeBorderColor,
    required Widget child,
    bool alignRight = false,
  }) {
    final pos = CellPosition(rowIndex, colIndex);
    final isActive = _activeCell == pos;
    final isEditing = _editingCell == pos;
    final isRecentlySaved = _recentlySavedCell == pos;

    return InkWell(
      onTap: () {
        if (!isEditing) {
          _activateCell(rowIndex, colIndex);
          _startEditing(rowIndex, colIndex);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isRecentlySaved
              ? AppTheme.primaryGreen.withValues(alpha: 0.2)
              : null,
          border: isActive
              ? Border.all(
                  color: _cellErrorMessage != null
                      ? AppTheme.errorRed
                      : activeBorderColor,
                  width: 2,
                )
              : null,
        ),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: isEditing
            ? _buildCellEditor(colIndex, alignRight)
            : Row(
                mainAxisAlignment:
                    alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Expanded(child: child),
                  if (isSaving)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    )
                  else if (isRecentlySaved)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildCellEditor(int colIndex, bool alignRight) {
    final isNumeric = colIndex == ExcelColumns.stock ||
        colIndex == ExcelColumns.minStock ||
        colIndex == ExcelColumns.costPrice ||
        colIndex == ExcelColumns.price ||
        colIndex == ExcelColumns.discount;

    return TextField(
      controller: _editController,
      autofocus: true,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildCategoryCell({
    required Product product,
    required double width,
    required bool isSaving,
    required bool isDark,
    required Color textSecondary,
  }) {
    final categories = <String>{
      ...CategoryConstants.mainCategories,
      if (product.category?.isNotEmpty == true) product.category!,
    }.toList()
      ..sort();

    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: product.category?.isNotEmpty == true ? product.category : null,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, size: 16),
            hint: Text(context.getLocalizedCategory('General'), style: TextStyle(fontSize: 11.5, color: textSecondary)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(context.getLocalizedCategory('General'), style: const TextStyle(fontSize: 11.5)),
              ),
              ...categories.map((c) => DropdownMenuItem<String?>(
                    value: c,
                    child: Text(
                      context.getLocalizedCategory(c),
                      style: const TextStyle(fontSize: 11.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (newCat) => _updateCategory(product, newCat),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitCell({
    required Product product,
    required double width,
    required bool isSaving,
    required bool isDark,
    required Color textPrimary,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _availableUnits.contains(product.unit) ? product.unit : _availableUnits.first,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, size: 16),
            items: _availableUnits
                .map((u) => DropdownMenuItem<String>(
                      value: u,
                      child: Text(u, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ))
                .toList(),
            onChanged: (newUnit) {
              if (newUnit != null) _updateUnit(product, newUnit);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTaxCell({
    required Product product,
    required double width,
    required double? defaultRate,
    required bool isDark,
    required Color textPrimary,
  }) {
    Color badgeBg;
    Color badgeText;
    String label;

    switch (product.taxStatus) {
      case 'zero_rated':
        badgeBg = Colors.blue.withValues(alpha: 0.15);
        badgeText = Colors.blue.shade700;
        label = '0% ZERO';
        break;
      case 'taxable':
        badgeBg = const Color(0xFF6366F1).withValues(alpha: 0.15);
        badgeText = const Color(0xFF6366F1);
        final rate = product.customTaxRate ?? defaultRate ?? 18.0;
        label = '${rate.toStringAsFixed(0)}% VAT';
        break;
      case 'exempt':
      default: // null or unknown = not opted-in to VAT = exempt
        badgeBg = Colors.amber.withValues(alpha: 0.15);
        badgeText = Colors.amber.shade800;
        label = 'EXEMPT';
        break;
    }

    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: ['taxable', 'zero_rated', 'exempt'].contains(product.taxStatus)
                ? product.taxStatus
                : 'exempt', // null or unknown = not opted-in = exempt
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, size: 16),
            selectedItemBuilder: (ctx) => [
              'taxable',
              'zero_rated',
              'exempt',
            ].map((st) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeText,
                    ),
                  ),
                ),
              );
            }).toList(),
            items: const [
              DropdownMenuItem<String>(
                value: 'taxable',
                child: Text('Taxable (VAT)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              DropdownMenuItem<String>(
                value: 'zero_rated',
                child: Text('Zero-Rated (0%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              DropdownMenuItem<String>(
                value: 'exempt',
                child: Text('Exempt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
            onChanged: (newStatus) {
              if (newStatus != null) _updateTaxStatus(product, newStatus);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStockDisplay(Product product) {
    final isOut = product.stock <= 0;
    final isLow = product.stock > 0 && product.stock <= product.minStock;

    Color badgeColor = AppTheme.primaryGreen;
    if (isOut) {
      badgeColor = AppTheme.errorRed;
    } else if (isLow) {
      badgeColor = Colors.amber.shade700;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
          ),
        ),
        Flexible(
          child: Text(
            '${Formatters.number(product.stock)} ${product.unit}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountDisplay(Product product) {
    try {
      final activeDiscount = ref.watch(discountsProvider.notifier).getActiveDiscountSync(product.id ?? 0);
      if (activeDiscount == null || activeDiscount.discountValue <= 0) {
        return Center(
          child: Text('—', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        );
      }

      final isPct = activeDiscount.discountType == 'percentage';
      final label = isPct
          ? '${activeDiscount.discountValue.toInt()}%'
          : 'Rs. ${activeDiscount.discountValue.toInt()}';

      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ),
      );
    } catch (_) {
      return Center(
        child: Text('—', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      );
    }
  }

  Widget _buildHeaderCell({required double width, required Widget child}) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: child,
    );
  }

  Widget _buildDataCell({required double width, required Widget child}) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: child,
    );
  }

  Widget _buildSortableHeader({
    required String title,
    required String columnKey,
    required double width,
    required Color textPrimary,
    bool alignRight = false,
  }) {
    final isSorted = widget.sortColumn == columnKey;

    return InkWell(
      onTap: () {
        final newAsc = isSorted ? !widget.sortAscending : true;
        widget.onSort(columnKey, newAsc);
      },
      child: Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment:
              alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSorted ? AppTheme.primaryGreen : textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (widget.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted ? AppTheme.primaryGreen : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}
