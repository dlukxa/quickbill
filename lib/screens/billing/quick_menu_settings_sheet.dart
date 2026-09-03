import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/business_modules_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/quick_menu_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/category_icon_util.dart';
import '../../widgets/cached_product_image.dart';

class QuickMenuSettingsSheet extends ConsumerStatefulWidget {
  const QuickMenuSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickMenuSettingsSheet(),
    );
  }

  @override
  ConsumerState<QuickMenuSettingsSheet> createState() => _QuickMenuSettingsSheetState();
}

class _QuickMenuSettingsSheetState extends ConsumerState<QuickMenuSettingsSheet> {
  String _selectedTab = 'products'; // 'products' or 'services'
  
  Widget _buildIcon(String? category, double size, double iconSize) {
    final color = CategoryIconUtil.getColorForCategory(category);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(CategoryIconUtil.getIconForCategory(category), color: color, size: iconSize),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(businessModulesProvider);
    final qmAsync = ref.watch(quickMenuProvider);
    final productsAsync = ref.watch(productsProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final border = theme.dividerColor;
    final cardColor = theme.colorScheme.surface;
    
    // Auto-adjust tab if only one is enabled
    if (!modules.enableProducts && modules.enableServices && _selectedTab == 'products') {
      _selectedTab = 'services';
    } else if (modules.enableProducts && !modules.enableServices && _selectedTab == 'services') {
      _selectedTab = 'products';
    }
    
    final bool showTabs = modules.enableProducts && modules.enableServices;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quick Menu Settings',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold, fontSize: 17, color: textColor)),
                          Text('Pin items for fast billing',
                            style: TextStyle(fontSize: 12, color: subColor)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Enable toggle + header
              qmAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (qm) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Show Quick Menu on Billing Screen',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                                Text('Item strip at bottom of New Bill screen',
                                  style: TextStyle(fontSize: 12, color: subColor)),
                              ],
                            ),
                          ),
                          Switch(
                            value: qm.enabled,
                            activeColor: AppTheme.primaryGreen,
                            onChanged: (val) =>
                                ref.read(quickMenuProvider.notifier).setEnabled(val),
                          ),
                        ],
                      ),
                    ),
                    if (qm.enabled) ...[
                      const Divider(height: 1),
                      if (showTabs)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: border.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedTab = 'products'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 'products' ? cardColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: _selectedTab == 'products' ? [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                                        ] : [],
                                      ),
                                      margin: const EdgeInsets.all(2),
                                      alignment: Alignment.center,
                                      child: Text('Products', style: TextStyle(
                                        fontWeight: _selectedTab == 'products' ? FontWeight.w700 : FontWeight.w500,
                                        color: _selectedTab == 'products' ? textColor : subColor,
                                        fontSize: 13,
                                      )),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedTab = 'services'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 'services' ? cardColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: _selectedTab == 'services' ? [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                                        ] : [],
                                      ),
                                      margin: const EdgeInsets.all(2),
                                      alignment: Alignment.center,
                                      child: Text('Services', style: TextStyle(
                                        fontWeight: _selectedTab == 'services' ? FontWeight.w700 : FontWeight.w500,
                                        color: _selectedTab == 'services' ? textColor : subColor,
                                        fontSize: 13,
                                      )),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_selectedTab == 'products' ? 'Select Products to Pin' : 'Select Services to Pin',
                                    style: TextStyle(fontWeight: FontWeight.w700,
                                      color: textColor, fontSize: 15)),
                                  Text(
                                    _selectedTab == 'products' 
                                      ? (qm.pinnedProductIds.isEmpty
                                          ? 'No products pinned — showing all (auto)'
                                          : '${qm.pinnedProductIds.length} product${qm.pinnedProductIds.length == 1 ? '' : 's'} pinned')
                                      : (qm.pinnedServiceIds.isEmpty
                                          ? 'No services pinned'
                                          : '${qm.pinnedServiceIds.length} service${qm.pinnedServiceIds.length == 1 ? '' : 's'} pinned'),
                                    style: TextStyle(fontSize: 12, color: subColor),
                                  ),
                                ],
                              ),
                            ),
                            if ((_selectedTab == 'products' && qm.pinnedProductIds.isNotEmpty) ||
                                (_selectedTab == 'services' && qm.pinnedServiceIds.isNotEmpty))
                              TextButton.icon(
                                onPressed: () {
                                  if (_selectedTab == 'products') {
                                    ref.read(quickMenuProvider.notifier).setPinnedProducts([]);
                                  } else {
                                    ref.read(quickMenuProvider.notifier).setPinnedServices([]);
                                  }
                                },
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: const Text('Clear All'),
                                style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Item list
              Expanded(
                child: qmAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (qm) {
                    if (!qm.enabled) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_off, size: 56, color: subColor),
                            const SizedBox(height: 14),
                            Text('Enable Quick Menu to pin items',
                              style: TextStyle(color: subColor, fontSize: 14)),
                          ],
                        ),
                      );
                    }
                    
                    if (_selectedTab == 'products') {
                      return productsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Center(child: Text('Error loading products')),
                        data: (products) => ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final isPinned = qm.pinnedProductIds.contains(product.id);
                            final stock = product.trackBatches
                                ? product.calculatedStock
                                : product.stock;
                            return GestureDetector(
                              onTap: () => ref
                                  .read(quickMenuProvider.notifier)
                                  .toggleProduct(product.id!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isPinned
                                      ? AppTheme.primaryGreen.withValues(alpha: 0.07)
                                      : cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isPinned
                                        ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                                        : border,
                                    width: isPinned ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: product.imageUrl != null
                                          ? CachedProductImage(
                                              imageUrl: product.imageUrl!,
                                              width: 48, height: 48,
                                              fit: BoxFit.cover,
                                              placeholder: _buildIcon(product.category, 48, 22),
                                            )
                                          : _buildIcon(product.category, 48, 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name,
                                            style: TextStyle(fontWeight: FontWeight.w700,
                                              color: textColor, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${Formatters.currency(product.price)} · ${Formatters.quantity(stock)} ${product.unit}',
                                            style: TextStyle(fontSize: 12, color: subColor)),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: isPinned
                                            ? AppTheme.primaryGreen
                                            : border.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPinned ? Icons.check : Icons.add,
                                        color: isPinned ? Colors.white : subColor,
                                        size: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    } else {
                      return servicesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Center(child: Text('Error loading services')),
                        data: (services) => ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          itemCount: services.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final isPinned = qm.pinnedServiceIds.contains(service.id);
                            return GestureDetector(
                              onTap: () => ref
                                  .read(quickMenuProvider.notifier)
                                  .toggleService(service.id!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isPinned
                                      ? AppTheme.primaryGreen.withValues(alpha: 0.07)
                                      : cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isPinned
                                        ? AppTheme.primaryGreen.withValues(alpha: 0.5)
                                        : border,
                                    width: isPinned ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildIcon(service.category, 48, 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(service.name,
                                            style: TextStyle(fontWeight: FontWeight.w700,
                                              color: textColor, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            Formatters.currency(service.price),
                                            style: TextStyle(fontSize: 12, color: subColor)),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: isPinned
                                            ? AppTheme.primaryGreen
                                            : border.withValues(alpha: 0.4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPinned ? Icons.check : Icons.add,
                                        color: isPinned ? Colors.white : subColor,
                                        size: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
