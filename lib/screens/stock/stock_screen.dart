import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';
import 'add_product_screen.dart';
import 'add_batch_screen.dart';
import 'batch_list_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../services/pdf_service.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/l10n_extensions.dart';
import '../../providers/preference_provider.dart';
import '../../providers/employee_provider.dart';
import '../inventory/stock_history_screen.dart';
import '../../providers/forecasting_provider.dart';
import 'archived_products_screen.dart';
import 'product_analysis_screen.dart';
import 'product_price_manager_screen.dart';
import '../../utils/category_icon_util.dart';
import '../../utils/category_constants.dart';
import '../../widgets/cached_product_image.dart';
import '../../services/sinhala_search_service.dart';
import '../../widgets/add_stock_dialog.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _filter = 'all'; // all, low, out
  String? _selectedMainCategory; // null = show all
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterButton() {
    final hasActiveFilters = _filter != 'all' || _selectedMainCategory != null;
    return Container(
      decoration: BoxDecoration(
        color: hasActiveFilters 
            ? AppTheme.primaryGreen.withValues(alpha: 0.12)
            : context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveFilters 
              ? AppTheme.primaryGreen
              : context.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          Icons.filter_list_rounded,
          color: hasActiveFilters ? AppTheme.primaryGreen : context.onSurface,
        ),
        tooltip: 'Filter Products',
        onPressed: () => _showFilterBottomSheet(context),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String tempFilter = _filter;
        String? tempCategory = _selectedMainCategory;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: context.borderColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Products',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempFilter = 'all';
                            tempCategory = null;
                          });
                        },
                        child: Text(
                          'Reset All',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.errorRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stock Status',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.subText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: AppLocalizations.of(context)!.all,
                          isSelected: tempFilter == 'all',
                          onTap: () => setSheetState(() => tempFilter = 'all'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: AppLocalizations.of(context)!.lowStock,
                          isSelected: tempFilter == 'low',
                          onTap: () => setSheetState(() => tempFilter = 'low'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: AppLocalizations.of(context)!.outOfStock,
                          isSelected: tempFilter == 'out',
                          onTap: () => setSheetState(() => tempFilter = 'out'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Categories',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.subText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: CategoryConstants.mainCategories.length,
                      itemBuilder: (context, index) {
                        final main = CategoryConstants.mainCategories[index];
                        final isSelected = tempCategory == main;
                        final color = CategoryIconUtil.getColorForMainCategory(main);
                        final icon = CategoryIconUtil.getIconForMainCategory(main);

                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              tempCategory = isSelected ? null : main;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? color.withValues(alpha: 0.12)
                                  : context.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected 
                                    ? color 
                                    : context.borderColor.withValues(alpha: 0.5),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: isSelected ? color : context.subText,
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    context.getLocalizedCategory(main),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? color : context.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filter = tempFilter;
                          _selectedMainCategory = tempCategory;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.stockOverview,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.price_change_outlined),
            tooltip: 'Price & Unit Manager',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProductPriceManagerScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived Products',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ArchivedProductsScreen(),
                ),
              );
            },
          ),
          if (ref.watch(currentEmployeeProvider).value?.permissions.canManageInventory ?? false)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter button Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.borderColor.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: context.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.searchHint ?? 'Search products...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: context.subText.withValues(alpha: 0.7),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: context.subText,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterButton(),
              ],
            ),
          ),

          // Prominent Add Product Banner
          if (ref.watch(currentEmployeeProvider).value?.permissions.canManageInventory ?? false)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddProductScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Product',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Quickly register new stock items, track inventory, and set prices.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Product list
          Expanded(
            child: _filter == 'low'
                ? lowStockAsync.when(
                    data: (products) => _buildProductList(_applyFilters(products)),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(child: Text(AppLocalizations.of(context)!.errorLoadingProducts)),
                  )
                : productsAsync.when(
                    data: (products) {
                      List<Product> filteredProducts = products;
                      if (_filter == 'out') {
                        filteredProducts = products.where((p) => p.isOutOfStock).toList();
                      }
                      return _buildProductList(_applyFilters(filteredProducts));
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(child: Text(AppLocalizations.of(context)!.errorLoadingProducts)),
                  ),
          ),
        ],
      ),
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    List<Product> filtered = products;

    // Search query filter with Sinhala/Singlish intelligence
    final query = _searchQuery.trim();
    if (query.isNotEmpty) {
      filtered = SinhalaSearchService.filterAndRank(filtered, query);
    }

    // Category filter
    if (_selectedMainCategory != null) {
      filtered = filtered.where((p) {
        final main = CategoryConstants.getMainCategory(p.category);
        return main == _selectedMainCategory;
      }).toList();
    }

    return filtered;
  }

  Widget _buildProductList(List<Product> products) {
    if (products.isEmpty) {
      final canManage = ref.watch(currentEmployeeProvider).value?.permissions.canManageInventory ?? false;
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.borderColor.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 56,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Your First Product',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Get started by adding products to your inventory. This will enable billing, barcode scanning, stock tracking, and sales analytics.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: context.subText,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (canManage)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddProductScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      label: Text(
                        'Create Product',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppTheme.errorRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Inventory management is restricted. Please contact your manager or admin to add products.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.errorRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return AnimateIn(
          key: ValueKey('stock_item_${product.id}'),
          delay: Duration(milliseconds: index * 50),
          child: AppCard(
            padding: EdgeInsets.zero, // Use zero padding as ListTile has its own
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Hero(
                tag: 'product_icon_${product.id}',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: product.imageUrl == null
                      ? CategoryIconUtil.getColorForCategory(product.category).withValues(alpha: 0.15)
                      : AppTheme.stockStatusColor(product.stockStatus).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: product.imageUrl != null
                      ? ClipOval(
                          child: CachedProductImage(
                            imageUrl: product.imageUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: Icon(
                              CategoryIconUtil.getIconForCategory(product.category),
                              color: CategoryIconUtil.getColorForCategory(product.category),
                            ),
                          ),
                        )
                      : Icon(
                          CategoryIconUtil.getIconForCategory(product.category),
                          color: CategoryIconUtil.getColorForCategory(product.category),
                        ),
                ),
              ),
              title: Text(
                product.name,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.currency(product.price),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: context.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.stockStatusColor(product.stockStatus).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              product.isOutOfStock
                                  ? Icons.cancel
                                  : product.isLowStock
                                      ? Icons.warning
                                      : Icons.check_circle,
                              size: 14,
                              color: AppTheme.stockStatusColor(product.stockStatus),
                            ),
                            Text(
                              AppLocalizations.of(context)!.stockLabel(
                                (product.trackBatches ? product.calculatedStock : product.stock).toString(),
                                product.unit
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.stockStatusColor(product.stockStatus),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (product.trackBatches)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.batchTracked,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w700
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ForecastingBadge(productId: product.id!),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryGreen),
                    tooltip: AppLocalizations.of(context)!.restock,
                    onPressed: () {
                      if (ref.read(currentEmployeeProvider).value?.permissions.canManageInventory ?? false) {
                        _showRestockDialog(product);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
                        );
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'history') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StockHistoryScreen(
                              productId: product.id!,
                              productName: product.name,
                            ),
                          ),
                        );
                      } else if (value == 'insights') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductAnalysisScreen(product: product),
                          ),
                        );
                      } else if (value == 'write_off') {
                        final canManage = ref.read(currentEmployeeProvider).value?.permissions.canManageInventory ?? false;
                        if (!canManage) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
                          );
                          return;
                        }
                        if (product.trackBatches) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tap the product to write-off from specific batches.')),
                          );
                        } else {
                          _showWriteOffDialog(product);
                        }
                      } else if (value == 'archive') {
                        final canManage = ref.read(currentEmployeeProvider).value?.permissions.canManageInventory ?? false;
                        if (!canManage) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
                          );
                          return;
                        }
                        
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Archive Product'),
                            content: Text('Are you sure you want to archive "${product.name}"? It will not be visible in stock but past reports are preserved. You can restore it later.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(AppLocalizations.of(context)!.cancel),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                onPressed: () {
                                  ref.read(productActionsProvider).deleteProduct(product.id!);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${product.name} archived')),
                                  );
                                },
                                child: const Text('Archive'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'history',
                        child: Row(
                          children: [
                            const Icon(Icons.history, color: AppTheme.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.transactionHistory),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'write_off',
                        child: Row(
                          children: [
                            Icon(Icons.remove_shopping_cart, color: AppTheme.warningOrange, size: 20),
                            SizedBox(width: 8),
                            Text('Write-off / Damage'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'insights',
                        child: Row(
                          children: [
                            Icon(Icons.insights, color: Colors.purple, size: 20),
                            SizedBox(width: 8),
                            Text('Sales Analytics'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive, color: AppTheme.errorRed, size: 20),
                            SizedBox(width: 8),
                            Text('Archive', style: TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () {
                final canManage = ref.read(currentEmployeeProvider).value?.permissions.canManageInventory ?? false;
                if (!canManage) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
                  );
                  return;
                }

                if (product.trackBatches) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BatchListScreen(product: product),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddProductScreen(product: product),
                    ),
                  );
                }
              },
              onLongPress: () {
                 if (ref.read(currentEmployeeProvider).value?.permissions.canManageInventory ?? false) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddProductScreen(product: product),
                    ),
                  );
                 }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRestockDialog(Product product) async {
    // If product tracks batches, navigate to AddBatchScreen
    if (product.trackBatches) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddBatchScreen(product: product),
        ),
      );
      return;
    }

    await AddStockDialog.show(
      context,
      product: product,
      isDark: context.isDark,
    );
  }

  Future<void> _showWriteOffDialog(Product product) async {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String writeOffReason = 'Damaged';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Write-off ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.currentStock(product.stock.toString())),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Write-off',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: writeOffReason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['Damaged', 'Expired', 'Lost', 'Theft', 'Returned to Supplier', 'Other']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => writeOffReason = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () async {
                final qty = double.tryParse(quantityController.text);
                if (qty == null || qty <= 0 || qty > product.stock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid quantity')),
                  );
                  return;
                }

                final employeeId = ref.read(currentEmployeeProvider).value?.id;

                await ref.read(productActionsProvider).adjustStock(
                  productId: product.id!,
                  quantityChange: -qty, // Negative for write-off
                  notes: 'Write-off: $writeOffReason - ${notesController.text}',
                );

                if (context.mounted) {
                  Navigator.pop(dialogContext); // close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock written off successfully')),
                  );
                }
              },
              child: const Text('Write-off'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastingBadge extends ConsumerWidget {
  final int productId;
  const _ForecastingBadge({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(productForecastProvider(productId));

    if (forecast == null || forecast.dailyVelocity <= 0) return const SizedBox.shrink();
    
    final days = forecast.daysRemaining;
    final isCritical = forecast.isCritical;
    final badgeColor = isCritical ? AppTheme.errorRed : AppTheme.primaryGreen;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.2),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            isCritical ? Icons.speed : Icons.analytics_outlined,
            size: 14,
            color: badgeColor,
          ),
          Text(
            isCritical 
                ? AppLocalizations.of(context)!.predictedStockout(days.toStringAsFixed(1))
                : AppLocalizations.of(context)!.dailyVelocity(forecast.dailyVelocity.toStringAsFixed(2)),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : context.cardColor,
            gradient: isSelected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : context.borderColor.withValues(alpha: 0.5),
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? Colors.white : context.subText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
