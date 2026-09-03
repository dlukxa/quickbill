import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/discount_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../widgets/cached_product_image.dart';
import '../../utils/category_icon_util.dart';
import '../../config/theme.dart';
import 'add_discount_screen.dart';
import '../../utils/region_utils.dart';
import '../../models/discount.dart';

class DiscountListScreen extends ConsumerWidget {
  const DiscountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountsAsync = ref.watch(discountsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.discounts),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDiscountScreen()),
            ),
          ),
        ],
      ),
      body: discountsAsync.when(
        data: (discounts) => discounts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noProductsFound,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: discounts.length,
                itemBuilder: (context, index) {
                  final discount = discounts[index];
                  return AnimateIn(
                    key: ValueKey('discount_item_${discount.id}'),
                    delay: Duration(milliseconds: 50 * index),
                    child: _DiscountListItem(discount: discount),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDiscountScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DiscountListItem extends ConsumerWidget {
  final Discount discount;
  const _DiscountListItem({required this.discount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(discount.productId ?? 0));
    final l10n = AppLocalizations.of(context)!;
    final isActive = discount.isCurrentlyActive;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryGreen.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              if (discount.isClearance)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.clearance,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warningOrange),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          productAsync.when(
            data: (product) => Row(
              children: [
                if (product != null)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 48,
                    height: 48,
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
                              width: 48,
                              height: 48,
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
                Expanded(
                  child: Text(
                    product?.name ?? 'Unknown Product',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            loading: () => const Text('Loading...'),
            error: (_, __) => const Text('Error loading product'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${discount.discountType == 'percentage' ? '' : '${globalAppRegion.currencySymbol} '}${discount.discountValue}${discount.discountType == 'percentage' ? '%' : ''} OFF',
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                '${Formatters.date(discount.startDate)} - ${Formatters.date(discount.endDate)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discount?'),
        content: const Text('Are you sure you want to remove this scheduled discount?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(discountsProvider.notifier).deleteDiscount(discount.id!);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }
}
