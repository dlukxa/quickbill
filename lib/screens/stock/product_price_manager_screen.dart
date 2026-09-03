import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/price_history.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../services/sinhala_search_service.dart';
import '../../services/unit_conversion_service.dart';
import '../../utils/region_utils.dart';
import '../../widgets/app_card.dart';
import '../../widgets/add_stock_dialog.dart';
import 'add_product_screen.dart';

/// Central Product, Price, Unit & Stock Management Screen.
/// Optimized for fast desktop and tablet shop operations with inline edits and price history.
class ProductPriceManagerScreen extends ConsumerStatefulWidget {
  const ProductPriceManagerScreen({super.key});

  @override
  ConsumerState<ProductPriceManagerScreen> createState() => _ProductPriceManagerScreenState();
}

class _ProductPriceManagerScreenState extends ConsumerState<ProductPriceManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _stockFilter = 'all'; // 'all', 'low', 'out'
  String _sortBy = 'name'; // 'name', 'price_desc', 'margin_desc', 'stock_asc'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showQuickEditModal(Product product) {
    final priceController = TextEditingController(text: product.price.toStringAsFixed(2));
    final costController = TextEditingController(text: product.costPrice?.toStringAsFixed(2) ?? '');
    final stockController = TextEditingController(text: product.stock.toString());
    String selectedUnit = product.unit;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final pPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
          final pCost = double.tryParse(costController.text.trim());
          final profit = pCost != null ? pPrice - pCost : pPrice;
          final margin = pPrice > 0 && pCost != null ? ((profit / pPrice) * 100) : 100.0;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.sinhalaOrName,
                        style: GoogleFonts.notoSansSinhala(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (product.nameEnglish != null)
                        Text(
                          product.nameEnglish!,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Unit Selection
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: UnitConversionService.normalizeUnit(selectedUnit),
                          decoration: InputDecoration(
                            labelText: 'Base Unit',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('kg (Weight)')),
                            DropdownMenuItem(value: 'g', child: Text('g (Grams)')),
                            DropdownMenuItem(value: 'L', child: Text('L (Liquid)')),
                            DropdownMenuItem(value: 'ml', child: Text('ml (Milliliters)')),
                            DropdownMenuItem(value: 'pcs', child: Text('pcs (Pieces)')),
                            DropdownMenuItem(value: 'pack', child: Text('pack (Packets)')),
                            DropdownMenuItem(value: 'box', child: Text('box (Boxes)')),
                            DropdownMenuItem(value: 'm', child: Text('m (Meters)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Selling Price & Cost Price
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Selling Price',
                            prefixText: 'Rs. ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Cost Price',
                            prefixText: 'Rs. ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stock Quantity
                  TextFormField(
                    controller: stockController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Current Stock',
                      suffixText: selectedUnit,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Margin Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profit: Rs. ${profit.toStringAsFixed(2)} / $selectedUnit',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                        ),
                        Text(
                          'Margin: ${margin.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                onPressed: () async {
                  final newPrice = double.tryParse(priceController.text.trim()) ?? product.price;
                  final newCost = costController.text.trim().isEmpty ? null : double.tryParse(costController.text.trim());
                  final newStock = double.tryParse(stockController.text.trim()) ?? product.stock;

                  final updated = product.copyWith(
                    price: newPrice,
                    costPrice: newCost,
                    stock: newStock,
                    unit: selectedUnit,
                  );

                  await ref.read(productActionsProvider).updateProduct(updated);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated ${product.name} (Price: Rs. $newPrice / $selectedUnit)'),
                        backgroundColor: AppTheme.primaryGreen,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPriceHistorySheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Change History',
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      product.sinhalaOrName,
                      style: GoogleFonts.notoSansSinhala(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<PriceHistory>>(
                future: DatabaseService.instance.getPriceHistory(product.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final history = snapshot.data ?? [];
                  if (history.isEmpty) {
                    return Center(
                      child: Text(
                        'No price changes recorded yet.\nCurrent price: Rs. ${product.price.toStringAsFixed(2)} / ${product.unit}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final isUp = item.isIncrease;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUp ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          child: Icon(
                            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: isUp ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'Rs. ${item.oldPrice.toStringAsFixed(2)} → Rs. ${item.newPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/ ${item.newUnit ?? product.unit}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt)} • ${item.reason ?? 'Adjustment'}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product & Price Management',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add New Product',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddProductScreen()),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (allProducts) {
          // Filter products
          var filtered = SinhalaSearchService.filterAndRank(allProducts, _searchQuery);

          if (_selectedCategory != 'All') {
            filtered = filtered.where((p) => p.category == _selectedCategory).toList();
          }

          if (_stockFilter == 'low') {
            filtered = filtered.where((p) => p.isLowStock).toList();
          } else if (_stockFilter == 'out') {
            filtered = filtered.where((p) => p.isOutOfStock).toList();
          }

          // Sort
          if (_sortBy == 'price_desc') {
            filtered.sort((a, b) => b.price.compareTo(a.price));
          } else if (_sortBy == 'margin_desc') {
            filtered.sort((a, b) => b.profitMarginPercent.compareTo(a.profitMarginPercent));
          } else if (_sortBy == 'stock_asc') {
            filtered.sort((a, b) => a.calculatedStock.compareTo(b.calculatedStock));
          }

          final categories = {'All', ...allProducts.map((p) => p.category ?? 'Uncategorized')}.toList();

          return Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search (Singlish: "sini", Sinhala: "සීනි", Barcode, English)...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedCategory,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                        DropdownMenuItem(value: 'price_desc', child: Text('Sort: Price (High)')),
                        DropdownMenuItem(value: 'margin_desc', child: Text('Sort: Margin %')),
                        DropdownMenuItem(value: 'stock_asc', child: Text('Sort: Low Stock')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ],
                ),
              ),

              // Table Content
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('No matching products found.', style: GoogleFonts.inter(color: subColor)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final margin = product.profitMarginPercent;

                          return AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Product details
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.sinhalaOrName,
                                        style: GoogleFonts.notoSansSinhala(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                      ),
                                      if (product.nameEnglish != null && product.nameEnglish!.isNotEmpty)
                                        Text(
                                          product.nameEnglish!,
                                          style: GoogleFonts.inter(fontSize: 12, color: subColor),
                                        ),
                                    ],
                                  ),
                                ),

                                // Base Unit Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.unit,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Cost & Selling Price
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Rs. ${product.price.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                      if (product.costPrice != null)
                                        Text(
                                          'Cost: Rs. ${product.costPrice!.toStringAsFixed(2)}',
                                          style: GoogleFonts.inter(fontSize: 11, color: subColor),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Margin Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (margin >= 15 ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${margin.toStringAsFixed(0)}% Margin',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: margin >= 15 ? Colors.green[700] : Colors.orange[800],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Stock Quantity
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        product.formattedStock,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: product.isOutOfStock ? Colors.red : (product.isLowStock ? Colors.orange : textColor),
                                        ),
                                      ),
                                      if (product.isLowStock)
                                        Text('Low Stock', style: GoogleFonts.inter(fontSize: 10, color: Colors.orange)),
                                    ],
                                  ),
                                ),

                                // Actions (Add Stock, Edit Price & History)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_box_rounded, size: 22, color: AppTheme.primaryGreen),
                                      tooltip: 'Add Stock / Receive Delivery',
                                      onPressed: () => AddStockDialog.show(context, product: product, isDark: isDark),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.history_rounded, size: 20),
                                      tooltip: 'Price History',
                                      onPressed: () => _showPriceHistorySheet(product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.blueGrey),
                                      tooltip: 'Quick Edit Price & Stock',
                                      onPressed: () => _showQuickEditModal(product),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
