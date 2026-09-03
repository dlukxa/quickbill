import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/purchase.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/preference_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../services/pdf_service.dart';
import '../../services/share_service.dart';
import '../../services/printing_service.dart';
import 'add_purchase_screen.dart';

class PurchaseManagementScreen extends ConsumerStatefulWidget {
  const PurchaseManagementScreen({super.key});

  @override
  ConsumerState<PurchaseManagementScreen> createState() => _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState extends ConsumerState<PurchaseManagementScreen> {
  String _filter = 'All'; // All, Pending, Received

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.purchaseOrders),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const AddPurchaseScreen())
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const AddPurchaseScreen())
        ),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.newOrder),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip(AppLocalizations.of(context)!.all),
                const SizedBox(width: 8),
                _buildFilterChip(AppLocalizations.of(context)!.pending),
                const SizedBox(width: 8),
                _buildFilterChip(AppLocalizations.of(context)!.received),
              ],
            ),
          ),

          // Purchase List
          Expanded(
            child: purchasesAsync.when(
              data: (purchases) {
                final filtered = _filter == 'All' 
                    ? purchases 
                    : purchases.where((p) => p.status == _filter).toList();
                
                if (filtered.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context)!.noPurchaseOrdersFound));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _PurchaseOrderItem(purchase: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            border: Border.all(color: isSelected ? AppTheme.primaryBlue : AppTheme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderItem extends ConsumerWidget {
  final Purchase purchase;
  const _PurchaseOrderItem({required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(suppliersProvider);
    final suppliers = supplierAsync.value ?? [];
    final supplier = suppliers.isEmpty 
        ? null 
        : suppliers.where((s) => s.id == purchase.supplierId).firstOrNull;

    return AnimateIn(
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PO #${purchase.id ?? "Draft"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        Formatters.date(purchase.date),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, size: 20, color: AppTheme.primaryGreen),
                      onPressed: () async {
                        try {
                          final settings = ref.read(settingsProvider);
                          await PrintingService.instance.printPurchaseOrder(purchase, settings, supplier);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Purchase Order sent to printer')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to print: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 20, color: AppTheme.primaryBlue),
                      onPressed: () {
                        final settings = ref.read(settingsProvider);
                        PdfService.instance.generatePurchaseOrder(
                          purchase, 
                          settings: settings,
                          supplierName: supplier?.name
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddPurchaseScreen(purchase: purchase)),
                          );
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              const SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: AppTheme.errorRed),
                              const SizedBox(width: 12),
                              Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: purchase.status),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  supplier?.name ?? AppLocalizations.of(context)!.unknownSupplier,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${purchase.items.length} items',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                Text(
                  Formatters.currency(purchase.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                ),
              ],
            ),
            if (purchase.status == 'Pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmReceive(context, ref),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(AppLocalizations.of(context)!.receiveGoods),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmReceive(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.receiveOrderTitle),
        content: Text(AppLocalizations.of(context)!.receiveOrderContent(purchase.items.length.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () async {
              await ref.read(purchaseActionsProvider).receivePurchase(purchase.id!);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.inventoryUpdatedSuccessfully)),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deletePurchaseTitle),
        content: Text(AppLocalizations.of(context)!.deletePurchaseContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () async {
              await ref.read(purchaseActionsProvider).deletePurchase(purchase.id!);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.purchaseOrderDeleted)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Received':
        color = AppTheme.primaryGreen;
        break;
      case 'Pending':
        color = AppTheme.warningOrange;
        break;
      default:
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
