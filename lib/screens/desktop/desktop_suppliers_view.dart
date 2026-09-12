import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/purchase_item.dart';
import '../../models/supplier.dart';
import '../../providers/preference_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../utils/pos_l10n.dart';
import '../../utils/region_utils.dart';
import '../../widgets/sinhala_transliteration_input.dart';
import '../suppliers/add_supplier_screen.dart';

/// Desktop Suppliers & Inward Stock (GRN) Management view
class DesktopSuppliersView extends ConsumerStatefulWidget {
  const DesktopSuppliersView({super.key});

  @override
  ConsumerState<DesktopSuppliersView> createState() => _DesktopSuppliersViewState();
}

class _DesktopSuppliersViewState extends ConsumerState<DesktopSuppliersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _poFilter = 'All'; // All, Pending, Received
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final posL10n = PosL10n.of(settings.languageCode);
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(cardBg, borderColor, isDark, posL10n),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSuppliersTab(cardBg, borderColor, isDark),
                _buildPurchasesTab(cardBg, borderColor, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color cardBg, Color borderColor, bool isDark, PosL10n posL10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryBlue, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                posL10n.suppliersAndGrn,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                posL10n.suppliersSubtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Tabs
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: '  ${posL10n.supplierDirectory}  '),
                Tab(text: '  ${posL10n.purchaseOrdersGrn}  '),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_tabController.index == 0) {
                _openAddSupplierDialog(context);
              } else {
                _openNewPurchaseOrderDialog(context);
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: Text(
              _tabController.index == 0 ? posL10n.newSupplier : posL10n.inwardStockGrn,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: SUPPLIERS DIRECTORY
  // ==========================================
  Widget _buildSuppliersTab(Color cardBg, Color borderColor, bool isDark) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final filteredSuppliers = ref.watch(filteredSuppliersProvider);

    return Column(
      children: [
        // Sub-bar with search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: SinglishTextField(
                    controller: _searchCtrl,
                    showSuggestionBanner: false,
                    onChanged: (v) => ref.read(supplierSearchProvider.notifier).state = v,
                    onConverted: () => ref.read(supplierSearchProvider.notifier).state = _searchCtrl.text,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search suppliers by name, phone, or provided items...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Total Vendors: ${filteredSuppliers.length}',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
        ),

        // Suppliers Table
        Expanded(
          child: suppliersAsync.when(
            data: (_) {
              if (filteredSuppliers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_mall_directory_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 16),
                      Text('No suppliers found', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filteredSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = filteredSuppliers[index];
                  final hasDebt = supplier.totalPending > 0;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: borderColor),
                    ),
                    color: cardBg,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                            child: Text(
                              supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'V',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Name & Category
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.name,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                if (supplier.category != null && supplier.category!.isNotEmpty)
                                  Text(
                                    supplier.category!,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.primaryBlue),
                                  ),
                              ],
                            ),
                          ),

                          // Provided Items
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Supplies:',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                                ),
                                Text(
                                  supplier.providedItems ?? 'Various items',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Contact info
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (supplier.phone != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(supplier.phone!, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                                    ],
                                  ),
                                if (supplier.address != null)
                                  Text(
                                    supplier.address!,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          // Pending Payable
                          SizedBox(
                            width: 160,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Payable Balance',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                                ),
                                Text(
                                  hasDebt
                                      ? '${globalAppRegion.currencySymbol} ${supplier.totalPending.toStringAsFixed(2)}'
                                      : 'All Settled',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: hasDebt ? AppTheme.errorRed : AppTheme.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Actions
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openAddSupplierDialog(context, supplier: supplier);
                              } else if (val == 'po') {
                                _openNewPurchaseOrderDialog(context, initialSupplier: supplier);
                              } else if (val == 'call' && supplier.phone != null) {
                                launchUrl(Uri.parse('tel:${supplier.phone}'));
                              } else if (val == 'delete' && supplier.id != null) {
                                _confirmDeleteSupplier(context, supplier.id!);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'po', child: Row(children: [Icon(Icons.post_add_rounded, size: 18), SizedBox(width: 8), Text('Create PO / GRN')])),
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit Supplier')])),
                              if (supplier.phone != null)
                                const PopupMenuItem(value: 'call', child: Row(children: [Icon(Icons.phone_rounded, size: 18), SizedBox(width: 8), Text('Call Vendor')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: PURCHASE ORDERS / GRN
  // ==========================================
  Widget _buildPurchasesTab(Color cardBg, Color borderColor, bool isDark) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final suppliers = ref.watch(suppliersProvider).value ?? [];
    final supplierMap = {for (var s in suppliers) s.id: s.name};

    return Column(
      children: [
        // Sub-bar with status filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              _buildStatusFilterChip('All', _poFilter == 'All'),
              const SizedBox(width: 8),
              _buildStatusFilterChip('Pending', _poFilter == 'Pending'),
              const SizedBox(width: 8),
              _buildStatusFilterChip('Received', _poFilter == 'Received'),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openNewPurchaseOrderDialog(context),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                label: const Text('Record Stock Inward (GRN)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              ),
            ],
          ),
        ),

        // Purchases Table
        Expanded(
          child: purchasesAsync.when(
            data: (purchases) {
              final filtered = _poFilter == 'All'
                  ? purchases
                  : purchases.where((p) => p.status == _poFilter).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 16),
                      Text('No purchase orders found', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final po = filtered[index];
                  final supplierName = supplierMap[po.supplierId] ?? 'Supplier #${po.supplierId}';
                  final isPending = po.status.toLowerCase() == 'pending';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: borderColor),
                    ),
                    color: cardBg,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.amber.withValues(alpha: 0.15) : AppTheme.primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isPending ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                              color: isPending ? Colors.amber.shade700 : AppTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // PO ID & Date
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PO #${po.id ?? index + 1}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a').format(po.date),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                          // Supplier
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vendor', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                                Text(supplierName, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),

                          // Total Items & Notes
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${po.items.length} Items included', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500)),
                                if (po.notes != null)
                                  Text(
                                    po.notes!,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          // Total Cost
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Total Valuation', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                                Text(
                                  '${globalAppRegion.currencySymbol} ${po.totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.amber.withValues(alpha: 0.15) : AppTheme.primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              po.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPending ? Colors.amber.shade800 : AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Receive button if pending
                          if (isPending && po.id != null)
                            ElevatedButton.icon(
                              onPressed: () => _confirmReceivePurchase(context, po.id!),
                              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              label: const Text('Receive Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                            ),

                          // Options
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (action) {
                              if (action == 'delete' && po.id != null) {
                                ref.read(purchaseActionsProvider).deletePurchase(po.id!);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete PO', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChip(String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => setState(() => _poFilter = label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  void _openAddSupplierDialog(BuildContext context, {Supplier? supplier}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 500,
          child: AddSupplierScreen(supplier: supplier),
        ),
      ),
    ).then((_) {
      ref.read(suppliersProvider.notifier).refresh();
    });
  }

  void _openNewPurchaseOrderDialog(BuildContext context, {Supplier? initialSupplier}) {
    final suppliers = ref.read(suppliersProvider).value ?? [];
    final products = ref.read(productsProvider).value ?? [];

    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one supplier first.')),
      );
      return;
    }

    Supplier selectedSupplier = initialSupplier ?? suppliers.first;
    final items = <PurchaseItem>[];
    final notesController = TextEditingController();
    String status = 'Received'; // default desktop GRN is instant inward stock

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double total = items.fold(0.0, (sum, it) => sum + (it.costPrice * it.quantity));

          return AlertDialog(
            title: Text('Record Stock Inward / GRN', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Selector
                    DropdownButtonFormField<Supplier>(
                      value: selectedSupplier,
                      decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder()),
                      items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSupplier = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Add items header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Purchase Items (${items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () {
                            _showAddItemModal(context, products, (newItem) {
                              setModalState(() => items.add(newItem));
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('No items added yet. Click "+ Add Item" above.')),
                      )
                    else
                      ...items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final prod = products.firstWhere((p) => p.id == item.productId, orElse: () => Product(name: 'Product #${item.productId}', price: 0, costPrice: 0, stock: 0, category: ''));
                        return ListTile(
                          dense: true,
                          title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Qty: ${item.quantity}  x  ${globalAppRegion.currencySymbol} ${item.costPrice.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${globalAppRegion.currencySymbol} ${(item.quantity * item.costPrice).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                onPressed: () => setModalState(() => items.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),

                    // Status: Received or Pending
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Order Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Received', child: Text('Received (Add items immediately to stock)')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending (Awaiting delivery)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    SinglishTextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'PO Notes / Reference', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    // Total
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Valuation:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${globalAppRegion.currencySymbol} ${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: items.isEmpty
                    ? null
                    : () async {
                        final po = Purchase(
                          supplierId: selectedSupplier.id!,
                          totalAmount: total,
                          date: DateTime.now(),
                          status: status,
                          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          items: items,
                        );

                        final poId = await ref.read(purchaseActionsProvider).createPurchase(po);
                        if (status == 'Received') {
                          await ref.read(purchaseActionsProvider).receivePurchase(poId);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.read(purchasesProvider.notifier).refresh();
                        ref.invalidate(productsProvider);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                child: const Text('Save Purchase Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddItemModal(BuildContext context, List<Product> products, Function(PurchaseItem) onAdd) {
    if (products.isEmpty) return;
    Product selectedProduct = products.first;
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(text: (selectedProduct.costPrice ?? 0).toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Add Item to Inward Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: selectedProduct,
                decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSt(() {
                      selectedProduct = val;
                      costController.text = (val.costPrice ?? 0).toStringAsFixed(2);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Inward Quantity', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Unit Cost Price (${globalAppRegion.currencySymbol})',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text.trim()) ?? 0;
                final cost = double.tryParse(costController.text.trim()) ?? 0;
                if (qty <= 0 || cost < 0) return;

                onAdd(PurchaseItem(
                  purchaseId: 0,
                  productId: selectedProduct.id!,
                  productName: selectedProduct.name,
                  quantity: qty,
                  costPrice: cost,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReceivePurchase(BuildContext context, int purchaseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Stock Inward'),
        content: const Text(
          'Receiving this purchase order will automatically increment product stock counts in inventory. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(purchaseActionsProvider).receivePurchase(purchaseId);
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(productsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Confirm & Receive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSupplier(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: const Text('Are you sure you want to remove this supplier?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(supplierActionsProvider).deleteSupplier(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
