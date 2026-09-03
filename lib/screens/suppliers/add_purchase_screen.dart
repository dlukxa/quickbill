import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/supplier.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../utils/region_utils.dart';
import '../../models/purchase.dart';
import '../../models/purchase_item.dart';
import '../../models/product.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/gradient_button.dart';
import '../../services/barcode_service.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../widgets/cached_product_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/category_icon_util.dart';

// import '../../widgets/animate_in.dart'; // Removed unused import

class AddPurchaseScreen extends ConsumerStatefulWidget {
  final Supplier? initialSupplier;
  final Purchase? purchase;

  const AddPurchaseScreen({super.key, this.initialSupplier, this.purchase});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  Supplier? _selectedSupplier;
  final List<PurchaseItem> _items = [];
  final _notesController = TextEditingController();
  bool _isSaving = false;
  bool _isReceived = false; // Default to Pending (not received)

  @override
  void initState() {
    super.initState();
    if (widget.purchase != null) {
      _items.addAll(widget.purchase!.items);
      _notesController.text = widget.purchase!.notes ?? '';
      _isReceived = widget.purchase!.status == 'Received';
      
      // Initialize supplier from the list
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final suppliers = ref.read(suppliersProvider).value ?? [];
        if (mounted) {
          setState(() {
            _selectedSupplier = suppliers.where((s) => s.id == widget.purchase!.supplierId).firstOrNull;
          });
        }
      });
    } else {
      _selectedSupplier = widget.initialSupplier;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + (item.quantity * item.costPrice));

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectSupplier)));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pleaseAddItem)));
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    final purchase = Purchase(
      id: widget.purchase?.id,
      supplierId: _selectedSupplier!.id!,
      totalAmount: _totalAmount,
      date: widget.purchase?.date ?? DateTime.now(),
      status: _isReceived ? 'Received' : 'Pending',
      notes: _notesController.text.trim(),
      items: _items,
    );

    try {
      if (widget.purchase != null) {
        await ref.read(purchaseActionsProvider).updatePurchase(purchase);
      } else {
        await ref.read(supplierActionsProvider).recordPurchase(purchase);
      }
      if (_isReceived) {
        ref.invalidate(productsProvider); // Refresh stock levels only if received
      }
      messenger.showSnackBar(SnackBar(
        content: Text(widget.purchase != null 
            ? AppLocalizations.of(context)!.purchaseOrderUpdated
            : (_isReceived ? AppLocalizations.of(context)!.purchaseRecordedStock : AppLocalizations.of(context)!.purchaseOrderSavedPending)),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.error}: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addItem() {
    _showProductSelector();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.newPurchaseTitle)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSupplierSection(),
                  const SizedBox(height: 20),
                  _buildItemsSection(),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.notesInvoiceLabel,
                        border: InputBorder.none,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppLocalizations.of(context)!.markAsReceivedLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(AppLocalizations.of(context)!.markAsReceivedSubtitle),
                      value: _isReceived,
                      onChanged: (val) => setState(() => _isReceived = val),
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomSummary(),
        ],
      ),
    );
  }

  Widget _buildSupplierSection() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.supplierSectionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          if (_selectedSupplier == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(AppLocalizations.of(context)!.selectSupplier),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSupplierSelector,
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(_selectedSupplier!.name[0], style: const TextStyle(color: AppTheme.primaryBlue)),
              ),
              title: Text(_selectedSupplier!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_selectedSupplier!.category ?? AppLocalizations.of(context)!.noCategory),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: _showSupplierSelector,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.purchaseItemsLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue),
                  tooltip: 'Scan Barcode',
                ),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: Text(AppLocalizations.of(context)!.addProduct),
                ),
              ],
            ),
          ],
        ),
        if (_items.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(AppLocalizations.of(context)!.addProductsToRestock, style: const TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Qty: ${item.quantity} • Cost: ${globalAppRegion.currencySymbol} ${item.costPrice}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${globalAppRegion.currencySymbol} ${(item.quantity * item.costPrice).toStringAsFixed(0)}', 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorRed, size: 20),
                        onPressed: () => setState(() => _items.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ', style: Theme.of(context).textTheme.titleLarge),
                Text('${globalAppRegion.currencySymbol} ${_totalAmount.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ],
            ),
            const SizedBox(height: 16),
            GradientButton(
              onPressed: _isSaving ? null : _savePurchase,
              colors: _isReceived 
                ? [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.8)]
                : [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.8)],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isReceived ? Icons.check_circle : Icons.save, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(_isReceived ? AppLocalizations.of(context)!.completeUpdateStock : AppLocalizations.of(context)!.saveAsPendingOrder),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplierSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context)!.selectSupplierTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Consumer(builder: (context, ref, child) {
                  final suppliers = ref.watch(suppliersProvider).value ?? [];
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: suppliers.length,
                    itemBuilder: (context, index) {
                      final s = suppliers[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(s.name[0])),
                        title: Text(s.name),
                        subtitle: Text(s.category ?? ''),
                        onTap: () {
                          setState(() => _selectedSupplier = s);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context)!.selectProductToRestock, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Consumer(builder: (context, ref, child) {
                  final products = ref.watch(productsProvider).value ?? [];
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: p.imageUrl == null
                                  ? CategoryIconUtil.getColorForCategory(p.category).withValues(alpha: 0.15)
                                  : AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: p.imageUrl != null
                                  ? ClipOval(
                                      child: CachedProductImage(
                                        imageUrl: p.imageUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        placeholder: Icon(
                                          CategoryIconUtil.getIconForCategory(p.category),
                                          color: CategoryIconUtil.getColorForCategory(p.category),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      CategoryIconUtil.getIconForCategory(p.category),
                                      color: CategoryIconUtil.getColorForCategory(p.category),
                                    ),
                            ),
                            title: Text(
                              p.name,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Formatters.currency(p.price),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
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
                                        color: AppTheme.stockStatusColor(p.stockStatus).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Wrap(
                                        spacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Icon(
                                            p.isOutOfStock
                                                ? Icons.cancel
                                                : p.isLowStock
                                                    ? Icons.warning
                                                    : Icons.check_circle,
                                            size: 14,
                                            color: AppTheme.stockStatusColor(p.stockStatus),
                                          ),
                                          Text(
                                            AppLocalizations.of(context)!.stockLabel(
                                              (p.trackBatches ? p.calculatedStock : p.stock).toString(),
                                              p.unit
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.stockStatusColor(p.stockStatus),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showItemDetailInput(p);
                            },
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetailInput(Product product) {
    final qtyController = TextEditingController();
    final costController = TextEditingController(text: product.costPrice?.toString() ?? '');
    final batchController = TextEditingController();
    DateTime? selectedExpiry;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.restockItem(product.name)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.quantityToAdd(product.unit)),
                ),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.costPricePerUnit),
                ),
                if (product.trackBatches) ...[
                  const Divider(height: 32),
                  Text(AppLocalizations.of(context)!.batchDetails, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  TextField(
                    controller: batchController,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)!.batchNumberField),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.expiryDateLabel, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(selectedExpiry != null 
                        ? DateFormat('MMM dd, yyyy').format(selectedExpiry!) 
                        : AppLocalizations.of(context)!.optionalHint),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date != null) setDialogState(() => selectedExpiry = date);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text);
                final cost = double.tryParse(costController.text);
                if (qty == null || qty <= 0 || cost == null) return;

                setState(() {
                  _items.add(PurchaseItem(
                    productId: product.id!,
                    productName: product.name,
                    quantity: qty,
                    costPrice: cost,
                    batchNumber: product.trackBatches ? batchController.text.trim().isEmpty ? 'B-${DateTime.now().millisecondsSinceEpoch}' : batchController.text.trim() : null,
                    expiryDate: selectedExpiry,
                  ));
                });
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.addToList),
            ),
          ],
        ),
      ),
    );
  }

  void _scanBarcode() async {
    // Show barcode scanner options (camera or manual entry)
    final barcode = await BarcodeScannerService.showScanOptions(context);
    
    if (barcode == null || barcode.isEmpty) return;

    // Search for product by barcode
    final products = ref.read(productsProvider).value ?? [];
    final product = products.where((p) => p.baseBarcode == barcode).firstOrNull;

    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.productNotFoundBarcode(barcode))),
        );
      }
      return;
    }

    // Product found, show quantity/cost dialog
    _showItemDetailInput(product);
  }
}
