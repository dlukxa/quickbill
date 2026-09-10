import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/preference_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/sinhala_search_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/add_stock_dialog.dart';
import '../../widgets/cached_product_image.dart';
import '../stock/add_product_screen.dart';
import '../stock/batch_list_screen.dart';
import '../stock/product_price_manager_screen.dart';
import '../stock/archived_products_screen.dart';
import '../inventory/stock_history_screen.dart';

class DesktopInventoryView extends ConsumerStatefulWidget {
  const DesktopInventoryView({super.key});

  @override
  ConsumerState<DesktopInventoryView> createState() => _DesktopInventoryViewState();
}

class _DesktopInventoryViewState extends ConsumerState<DesktopInventoryView> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'low', 'out'
  String? _selectedCategory;

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

  void _openRestock(Product product) async {
    final res = await AddStockDialog.show(
      context,
      product: product,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    if (res == true) {
      ref.invalidate(productsProvider);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text('Are you sure you want to archive "${product.name}"? It will be moved to archived items.'),
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = settings.isDarkMode;
    final productsAsync = ref.watch(productsProvider);

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      color: bg,
      child: productsAsync.when(
        data: (allProducts) {
          final activeProducts = allProducts.where((p) => p.deleted != true).toList();

          // Calculate statistics
          final totalCount = activeProducts.length;
          final lowStockList = activeProducts.where((p) => p.stock > 0 && p.stock <= p.minStock).toList();
          final outOfStockList = activeProducts.where((p) => p.stock <= 0).toList();
          final totalValuation = activeProducts.fold(0.0, (sum, p) => sum + (p.stock * (p.costPrice ?? p.price)));

          // Extract unique categories
          final categories = <String>{};
          for (final p in activeProducts) {
            if (p.category != null && p.category!.trim().isNotEmpty) {
              categories.add(p.category!.trim());
            }
          }
          final sortedCategories = categories.toList()..sort();

          // Apply filters
          List<Product> displayed = activeProducts;
          if (_statusFilter == 'low') {
            displayed = lowStockList;
          } else if (_statusFilter == 'out') {
            displayed = outOfStockList;
          }

          if (_selectedCategory != null) {
            displayed = displayed.where((p) => p.category == _selectedCategory).toList();
          }

          if (_searchQuery.trim().isNotEmpty) {
            displayed = SinhalaSearchService.filterAndRank(displayed, _searchQuery.trim());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Header & Actions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory & Product Catalog',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage products, stock levels, multi-selling modes, and batches',
                          style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.price_change_rounded, size: 16),
                          label: const Text('Price Manager'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProductPriceManagerScreen()),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.archive_outlined, size: 16),
                          label: const Text('Archived'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ArchivedProductsScreen()),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('+ Add Product (F3)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openAddProduct(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── KPI Summary Cards ──
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'TOTAL PRODUCTS',
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
                        title: 'LOW STOCK ITEMS',
                        value: lowStockList.length.toString(),
                        subtitle: 'Below threshold',
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
                        title: 'OUT OF STOCK',
                        value: outOfStockList.length.toString(),
                        subtitle: 'Requires immediate restock',
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
                        title: 'TOTAL VALUATION',
                        value: Formatters.currency(totalValuation),
                        subtitle: 'Inventory at cost',
                        color: AppTheme.primaryGreen,
                        cardBg: cardBg,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Search & Filter Controls ──
                Container(
                  padding: const EdgeInsets.all(16),
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
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search by name, Sinhala, barcode, or alias...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Category Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String?>(
                          value: _selectedCategory,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ...sortedCategories.map((c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Status Segmented Filter
                      SegmentedButton<String>(
                        segments: [
                          const ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(
                            value: 'low',
                            label: Text('Low (${lowStockList.length})'),
                          ),
                          ButtonSegment(
                            value: 'out',
                            label: Text('Out (${outOfStockList.length})'),
                          ),
                        ],
                        selected: {_statusFilter},
                        onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Data Table ──
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: displayed.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty ? 'No products match "$_searchQuery"' : 'No products in this view',
                                  style: GoogleFonts.inter(fontSize: 15, color: textSecondary, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Add New Product'),
                                  onPressed: () => _openAddProduct(),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                            ),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 64,
                            columnSpacing: 18,
                            columns: const [
                              DataColumn(label: Text('PRODUCT')),
                              DataColumn(label: Text('BARCODE')),
                              DataColumn(label: Text('CATEGORY')),
                              DataColumn(label: Text('COST (RS.)'), numeric: true),
                              DataColumn(label: Text('PRICE (RS.)'), numeric: true),
                              DataColumn(label: Text('MODES')),
                              DataColumn(label: Text('STOCK'), numeric: true),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('ACTIONS')),
                            ],
                            rows: displayed.map((p) {
                              final isOut = p.stock <= 0;
                              final isLow = p.stock > 0 && p.stock <= p.minStock;

                              Color badgeBg = AppTheme.primaryGreen.withValues(alpha: 0.12);
                              Color badgeFg = AppTheme.primaryGreen;
                              String badgeLabel = 'In Stock';

                              if (isOut) {
                                badgeBg = AppTheme.errorRed.withValues(alpha: 0.12);
                                badgeFg = AppTheme.errorRed;
                                badgeLabel = 'Out of Stock';
                              } else if (isLow) {
                                badgeBg = Colors.amber.withValues(alpha: 0.15);
                                badgeFg = Colors.amber.shade800;
                                badgeLabel = 'Low Stock';
                              }

                              return DataRow(
                                cells: [
                                  // Product details with image & Sinhala/English subtitle
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CachedProductImage(
                                              imageUrl: p.imageUrl ?? '',
                                              fit: BoxFit.cover,
                                              placeholder: Container(
                                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                                child: const Icon(Icons.inventory_2_outlined, size: 20),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 220),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                style: GoogleFonts.notoSansSinhala(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (p.nameSinhala != null && p.nameSinhala!.isNotEmpty && p.nameSinhala != p.name)
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
                                      ],
                                    ),
                                  ),

                                  // Barcode
                                  DataCell(
                                    Text(
                                      p.baseBarcode?.isNotEmpty == true ? p.baseBarcode! : '—',
                                      style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                                    ),
                                  ),

                                  // Category
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.category?.isNotEmpty == true ? p.category! : 'General',
                                        style: GoogleFonts.inter(fontSize: 11, color: textSecondary),
                                      ),
                                    ),
                                  ),

                                  // Cost
                                  DataCell(
                                    Text(
                                      p.costPrice != null ? Formatters.number(p.costPrice!, decimalPlaces: 2) : '—',
                                      style: GoogleFonts.inter(fontSize: 12.5),
                                    ),
                                  ),

                                  // Selling Price
                                  DataCell(
                                    Text(
                                      Formatters.number(p.price, decimalPlaces: 2),
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary),
                                    ),
                                  ),

                                  // Multi-Mode indicator
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (p.allowLoose)
                                          Tooltip(
                                            message: 'Loose / Decimal sale enabled',
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 4),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.cyan.withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.scale_rounded, size: 12, color: Colors.cyan),
                                            ),
                                          ),
                                        if (p.allowPack)
                                          Tooltip(
                                            message: 'Pack sale enabled: ${p.packSize}${p.packSizeUnit}',
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.indigo.withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.inventory_2_rounded, size: 12, color: Colors.indigo),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Stock Quantity
                                  DataCell(
                                    Text(
                                      '${p.stock == p.stock.roundToDouble() ? p.stock.toInt() : p.stock} ${p.unit}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isOut ? AppTheme.errorRed : textPrimary,
                                      ),
                                    ),
                                  ),

                                  // Status Badge
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        badgeLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Actions
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.add_box_outlined, size: 18),
                                          color: AppTheme.primaryGreen,
                                          tooltip: 'Restock / Add Stock',
                                          onPressed: () => _openRestock(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          color: AppTheme.primaryBlue,
                                          tooltip: 'Edit Product',
                                          onPressed: () => _openAddProduct(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.layers_outlined, size: 18),
                                          color: Colors.purple,
                                          tooltip: 'Batches',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => BatchListScreen(product: p)),
                                          ),
                                        ),
                                        if (p.id != null)
                                          IconButton(
                                            icon: const Icon(Icons.history_rounded, size: 18),
                                            color: Colors.teal,
                                            tooltip: 'Stock History',
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => StockHistoryScreen(productId: p.id!, productName: p.name)),
                                            ),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.archive_outlined, size: 18),
                                          color: AppTheme.errorRed,
                                          tooltip: 'Archive Product',
                                          onPressed: () => _deleteProduct(p),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
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
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }
}
