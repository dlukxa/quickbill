import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/category_icon_util.dart';
import '../../widgets/cached_product_image.dart';

class ArchivedProductsScreen extends ConsumerWidget {
  const ArchivedProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Products'),
      ),
      body: archivedAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('No archived products', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
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
                key: ValueKey('archived_item_${product.id}'),
                delay: Duration(milliseconds: index * 50),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: product.imageUrl == null
                          ? CategoryIconUtil.getColorForCategory(product.category).withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
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
                                  color: CategoryIconUtil.getColorForCategory(product.category).withValues(alpha: 0.6),
                                ),
                              ),
                            )
                          : Icon(
                              CategoryIconUtil.getIconForCategory(product.category),
                              color: CategoryIconUtil.getColorForCategory(product.category).withValues(alpha: 0.6),
                            ),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.lineThrough, // Show it's archived
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.currency(product.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        if (product.calculatedStock > 0) ...[
                          const SizedBox(height: 4),
                          Text('Left in stock: ${product.calculatedStock} ${product.unit}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ]
                      ],
                    ),
                    trailing: OutlinedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore'),
                      onPressed: () {
                        ref.read(productActionsProvider).restoreProduct(product.id!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${product.name} restored to stock')),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(AppLocalizations.of(context)!.errorLoadingProducts)),
      ),
    );
  }
}
