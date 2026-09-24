import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/preference_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/sinhala_search_service.dart';
import '../../utils/formatters.dart';
import '../../utils/pos_l10n.dart';
import '../../widgets/inventory/bulk_stock_adjustment_dialog.dart';
import '../../widgets/inventory/excel_inventory_table.dart';
import '../stock/add_product_screen.dart';
import '../stock/product_price_manager_screen.dart';
import '../stock/archived_products_screen.dart';
import '../../providers/expiry_provider.dart';
import '../inventory/expiry_management_screen.dart';
import '../stock/csv_import_wizard_sheet.dart';
import '../../utils/l10n_extensions.dart';

class DesktopInventoryView extends ConsumerStatefulWidget {
  const DesktopInventoryView({super.key});

  @override
  ConsumerState<DesktopInventoryView> createState() =>
      _DesktopInventoryViewState();
}

class _DesktopInventoryViewState extends ConsumerState<DesktopInventoryView> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'low', 'out'
  String? _selectedCategory;

  // Selection state for bulk operations
  final Set<int> _selectedProductIds = {};

  // Sorting state
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 50; // 25, 50, 100, or -1 for All

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddProduct([Product? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(product: product),
      ),
    ).then((_) {
      ref.invalidate(productsProvider);
    });
  }

  void _openBulkAdjust(List<Product> allProducts) async {
    final selected = allProducts
        .where((p) => p.id != null && _selectedProductIds.contains(p.id))
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product first')),
      );
      return;
    }

    final res = await BulkStockAdjustmentDialog.show(
      context,
      selectedProducts: selected,
    );

    if (res == true) {
      ref.invalidate(productsProvider);
      setState(() => _selectedProductIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully updated ${selected.length} products'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    }
  }

  Future<void> _bulkArchive(List<Product> allProducts) async {
    final selected = allProducts
        .where((p) => p.id != null && _selectedProductIds.contains(p.id))
        .toList();

    if (selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Selected Products'),
        content: Text(
          'Are you sure you want to archive ${selected.length} selected products? They will be hidden from billing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final productActions = ref.read(productActionsProvider);
      for (final p in selected) {
        if (p.id != null) {
          await productActions.deleteProduct(p.id!);
        }
      }
      setState(() => _selectedProductIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archived ${selected.length} products')),
        );
      }
    }
  }

  List<Product> _sortProducts(List<Product> list) {
    final sorted = List<Product>.from(list);
    sorted.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'nameSinhala':
          final sA = a.nameSinhala ?? '';
          final sB = b.nameSinhala ?? '';
          cmp = sA.compareTo(sB);
          break;
        case 'barcode':
          final bA = a.baseBarcode ?? '';
          final bB = b.baseBarcode ?? '';
          cmp = bA.compareTo(bB);
          break;
        case 'category':
          final cA = a.category ?? '';
          final cB = b.category ?? '';
          cmp = cA.compareTo(cB);
          break;
        case 'stock':
          cmp = a.stock.compareTo(b.stock);
          break;
        case 'minStock':
          cmp = a.minStock.compareTo(b.minStock);
          break;
        case 'costPrice':
          final cA = a.costPrice ?? 0.0;
          final cB = b.costPrice ?? 0.0;
          cmp = cA.compareTo(cB);
          break;
        case 'price':
          cmp = a.price.compareTo(b.price);
          break;
        default:
          cmp = a.name.compareTo(b.name);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final isDark = settings.isDarkMode;
    final productsAsync = ref.watch(productsProvider);
    final expirySummary = ref.watch(expirySummaryProvider);
    final alertCount = expirySummary.totalExpiredProducts + expirySummary.expiringSoonProducts;

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      color: bg,
      child: productsAsync.when(
        data: (allProducts) {
          final activeProducts =
              allProducts.where((p) => p.deleted != true).toList();

          // Statistics
          final totalCount = activeProducts.length;
          final lowStockList = activeProducts
              .where((p) => p.stock > 0 && p.stock <= p.minStock)
              .toList();
          final outOfStockList =
              activeProducts.where((p) => p.stock <= 0).toList();
          final totalValuation = activeProducts.fold(
            0.0,
            (sum, p) => sum + (p.stock * (p.costPrice ?? p.price)),
          );

          // Unique Categories
          final categories = <String>{};
          for (final p in activeProducts) {
            if (p.category != null && p.category!.trim().isNotEmpty) {
              categories.add(p.category!.trim());
            }
          }
          final sortedCategories = categories.toList()..sort();

          // Filtering
          List<Product> displayed = activeProducts;
          if (_statusFilter == 'low') {
            displayed = lowStockList;
          } else if (_statusFilter == 'out') {
            displayed = outOfStockList;
          }

          if (_selectedCategory != null) {
            displayed = displayed
                .where((p) => p.category == _selectedCategory)
                .toList();
          }

          if (_searchQuery.trim().isNotEmpty) {
            displayed =
                SinhalaSearchService.filterAndRank(displayed, _searchQuery.trim());
          }

          // Sorting
          displayed = _sortProducts(displayed);

          // Pagination
          final totalFiltered = displayed.length;
          final effectivePageSize =
              _pageSize == -1 ? totalFiltered : _pageSize;
          final totalPages = effectivePageSize > 0
              ? (totalFiltered / effectivePageSize).ceil().clamp(1, 9999)
              : 1;
          final clampedPage = _currentPage.clamp(1, totalPages);

          final startIndex = (clampedPage - 1) * effectivePageSize;
          final endIndex = (startIndex + effectivePageSize) > totalFiltered
              ? totalFiltered
              : (startIndex + effectivePageSize);

          final pageItems = (startIndex < totalFiltered)
              ? displayed.sublist(startIndex, endIndex)
              : <Product>[];

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header & Actions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Text(
                                posL10n.inventoryCatalog,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.table_chart_rounded,
                                        size: 14,
                                        color: AppTheme.primaryGreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Excel Edit Mode',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click any cell to edit inline. Press Enter to save and move down, Tab to move across.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_selectedProductIds.isNotEmpty)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: Text('Bulk Adjust (${_selectedProductIds.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _openBulkAdjust(activeProducts),
                          ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.price_change_rounded, size: 16),
                          label: Text(posL10n.pricesAndUnits),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductPriceManagerScreen(),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.archive_outlined, size: 16),
                          label: Text(posL10n.archived),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ArchivedProductsScreen(),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: Badge(
                            isLabelVisible: alertCount > 0,
                            backgroundColor: expirySummary.totalExpiredProducts > 0
                                ? AppTheme.errorRed
                                : const Color(0xFFF59E0B),
                            label: Text(
                              '$alertCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            child: Icon(
                              Icons.event_busy_rounded,
                              size: 16,
                              color: alertCount > 0
                                  ? (expirySummary.totalExpiredProducts > 0
                                      ? AppTheme.errorRed
                                      : const Color(0xFFF59E0B))
                                  : null,
                            ),
                          ),
                          label: const Text('Expiry Alerts'),
                          style: alertCount > 0
                              ? OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: (expirySummary.totalExpiredProducts > 0
                                            ? AppTheme.errorRed
                                            : const Color(0xFFF59E0B))
                                        .withValues(alpha: 0.5),
                                  ),
                                  foregroundColor: expirySummary.totalExpiredProducts > 0
                                      ? AppTheme.errorRed
                                      : const Color(0xFFF59E0B),
                                )
                              : null,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ExpiryManagementScreen(),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('Import CSV'),
                          onPressed: () => CsvImportWizardSheet.show(context),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(posL10n.newProduct),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _openAddProduct(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── KPI Summary Cards ──
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: posL10n.totalItems,
                        value: totalCount.toString(),
                        subtitle: 'Active SKUs',
                        color: AppTheme.primaryBlue,
                        cardBg: cardBg,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        title: posL10n.lowStockAlert,
                        value: lowStockList.length.toString(),
                        subtitle: 'Below reorder threshold',
                        color: Colors.amber.shade700,
                        cardBg: cardBg,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        title: posL10n.outOfStockBadge,
                        value: outOfStockList.length.toString(),
                        subtitle: 'Needs immediate restock',
                        color: AppTheme.errorRed,
                        cardBg: cardBg,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        title: posL10n.totalValuation,
                        value: Formatters.currency(totalValuation),
                        subtitle: 'Inventory valuation at cost',
                        color: AppTheme.primaryGreen,
                        cardBg: cardBg,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Search & Filter Controls ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      // Search Input
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() {
                            _searchQuery = val;
                            _currentPage = 1;
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search by Name, Sinhala Name, or Barcode...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 1;
                                      });
                                    },
                                  )
                                : null,
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
                      ),
                      const SizedBox(width: 12),

                      // Category Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String?>(
                          value: _selectedCategory,
                          isDense: true,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: posL10n.categoryCol,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(posL10n.allItems),
                            ),
                            ...sortedCategories.map((c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(
                                    context.getLocalizedCategory(c),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedCategory = val;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status Segmented Filter
                      Expanded(
                        flex: 3,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'all',
                              label: Text(
                                posL10n.allItems,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ButtonSegment(
                              value: 'low',
                              label: Text(
                                '${posL10n.lowStock} (${lowStockList.length})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ButtonSegment(
                              value: 'out',
                              label: Text(
                                '${posL10n.outOfStock} (${outOfStockList.length})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          selected: {_statusFilter},
                          onSelectionChanged: (set) => setState(() {
                            _statusFilter = set.first;
                            _currentPage = 1;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bulk Actions Floating Bar ──
                if (_selectedProductIds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_selectedProductIds.length} products selected',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Adjust Stock (+/-)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => _openBulkAdjust(activeProducts),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.archive_outlined, size: 16),
                          label: const Text('Archive Selected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorRed,
                            side: const BorderSide(color: AppTheme.errorRed),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => _bulkArchive(activeProducts),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedProductIds.clear()),
                          child: const Text('Deselect All'),
                        ),
                      ],
                    ),
                  ),

                // ── Excel Data Table Viewport ──
                Expanded(
                  child: displayed.isEmpty
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No products match "$_searchQuery"'
                                      : posL10n.noProductsFound,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: Text(posL10n.newProduct),
                                  onPressed: () => _openAddProduct(),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ExcelInventoryTable(
                          products: pageItems,
                          selectedProductIds: _selectedProductIds,
                          onSelectionChanged: (set) =>
                              setState(() => _selectedProductIds..clear()..addAll(set)),
                          sortColumn: _sortColumn,
                          sortAscending: _sortAscending,
                          onSort: (col, asc) => setState(() {
                            _sortColumn = col;
                            _sortAscending = asc;
                          }),
                          onRefresh: () => ref.invalidate(productsProvider),
                        ),
                ),

                // ── Pagination & Summary Footer ──
                if (displayed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Showing ${startIndex + 1}–$endIndex of $totalFiltered products',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),

                        // Page size selector
                        Text(
                          'Rows per page:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _pageSize,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                            DropdownMenuItem(value: -1, child: Text('All')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _pageSize = val;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 20),

                        // Page Navigation buttons
                        IconButton(
                          icon: const Icon(Icons.first_page_rounded, size: 18),
                          onPressed: clampedPage > 1
                              ? () => setState(() => _currentPage = 1)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          onPressed: clampedPage > 1
                              ? () => setState(() => _currentPage = clampedPage - 1)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Page $clampedPage of $totalPages',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          onPressed: clampedPage < totalPages
                              ? () => setState(() => _currentPage = clampedPage + 1)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.last_page_rounded, size: 18),
                          onPressed: clampedPage < totalPages
                              ? () => setState(() => _currentPage = totalPages)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading inventory: $e')),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color cardBg,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
        ],
      ),
    );
  }
}
