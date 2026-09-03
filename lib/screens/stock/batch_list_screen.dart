import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/batch_provider.dart';
import 'add_batch_screen.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../providers/employee_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/database_service.dart';
import '../../models/product_batch.dart';
import '../../utils/category_icon_util.dart';

class BatchListScreen extends ConsumerWidget {
  final Product product;

  const BatchListScreen({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(productBatchesProvider(product.id!));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
             Hero(
               tag: 'product_icon_${product.id}',
               child: Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: product.imageUrl == null
                      ? CategoryIconUtil.getColorForCategory(product.category).withValues(alpha: 0.15)
                      : AppTheme.stockStatusColor(product.stockStatus).withValues(alpha: 0.1),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(
                   CategoryIconUtil.getIconForCategory(product.category),
                   color: CategoryIconUtil.getColorForCategory(product.category),
                   size: 20,
                 ),
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.batchesTitle, 
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    product.name, 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddBatchScreen(product: product),
            ),
          );
          
          if (result == true) {
            // Refresh data handled by provider invalidation in AddBatch logic
          }
        },
        label: Text(AppLocalizations.of(context)!.addBatchFab),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: batchesAsync.when(
        data: (batches) {
          if (batches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.noBatchesFound, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddBatchScreen(product: product),
                        ),
                      );
                    },
                    child: Text(AppLocalizations.of(context)!.createFirstBatch),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: batches.length,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final batch = batches[index];
              return AnimateIn(
                key: ValueKey('batch_item_${batch.id}'),
                delay: Duration(milliseconds: index * 50),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          batch.batchNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (batch.isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.expired,
                              style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          )
                        else if (batch.expiresSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.expiresSoon,
                              style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(AppLocalizations.of(context)!.batchStockLabel(batch.stock.toString(), product.unit)),
                        if (batch.expiryDate != null)
                          Text(
                            AppLocalizations.of(context)!.expiresLabel(DateFormat('MMM dd, yyyy').format(batch.expiryDate!)),
                            style: TextStyle(
                              color: batch.isExpired ? Colors.red : Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                      trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddBatchScreen(
                                product: product,
                                batch: batch,
                              ),
                            ),
                          );
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(AppLocalizations.of(context)!.deleteBatchTitle),
                              content: Text(AppLocalizations.of(context)!.deleteBatchContent(batch.batchNumber)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(AppLocalizations.of(context)!.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: Text(AppLocalizations.of(context)!.delete),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref.read(batchActionsProvider).deleteBatch(batch.id!, product.id!);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.of(context)!.batchDeleted)),
                              );
                            }
                          }
                        } else if (value == 'write_off') {
                           // Handle wastage
                           _showWastageDialog(context, ref, batch);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 20),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.editDetails),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'write_off',
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle_outline, size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Mark as Waste', style: TextStyle(color: Colors.orange)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, size: 20, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.deleteBatch, style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddBatchScreen(
                            product: product,
                            batch: batch,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _showWastageDialog(BuildContext context, WidgetRef ref, ProductBatch batch) async {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String writeOffReason = 'expired';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mark as Waste: ${batch.batchNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available Stock: ${batch.stock} ${product.unit}'),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity to write off',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: writeOffReason,
                items: const [
                  DropdownMenuItem(value: 'expired', child: Text('Expired')),
                  DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                  DropdownMenuItem(value: 'spoiled', child: Text('Spoiled')),
                  DropdownMenuItem(value: 'returned to supplier', child: Text('Returned to Supplier')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) writeOffReason = val;
                },
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Optional Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              final qty = double.tryParse(quantityController.text);
              if (qty == null || qty <= 0 || qty > batch.stock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid quantity')),
                );
                return;
              }

              // Proceed with write-off
              final canManage = ref.read(currentEmployeeProvider).value?.permissions.canManageInventory ?? false;
              if (!canManage) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.accessDenied)),
                 );
                 return;
              }

              final employeeId = ref.read(currentEmployeeProvider).value?.id;

              await DatabaseService.instance.writeOffBatchStock(
                productId: product.id!,
                batchId: batch.id!,
                branchId: batch.branchId,
                quantity: qty,
                reason: writeOffReason,
                notes: notesController.text,
                employeeId: employeeId,
              );

              if (context.mounted) {
                Navigator.pop(dialogContext); // close dialog
                // Invalidate providers
                ref.invalidate(productsProvider);
                ref.invalidate(productBatchesProvider(product.id!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Marked $qty ${product.unit} as waste.')),
                );
              }
            },
            child: const Text('Confirm Write-off'),
          ),
        ],
      ),
    );
  }
}
