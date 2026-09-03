import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/stock_history.dart';
import '../../services/database_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animate_in.dart';
import '../../services/sync_service.dart';

final productStockHistoryProvider = StateNotifierProvider.family<ProductStockHistoryNotifier, AsyncValue<List<StockHistory>>, int>((ref, productId) {
  return ProductStockHistoryNotifier(productId);
});

class ProductStockHistoryNotifier extends StateNotifier<AsyncValue<List<StockHistory>>> {
  final int productId;
  ProductStockHistoryNotifier(this.productId) : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await DatabaseService.instance.getProductStockHistory(productId);
      state = AsyncValue.data(history);
      
      // Trigger background lazy fetch for older stock history from the cloud
      // This allows the initial fetch above to be fast (local SQLite) while fetching older data.
      _fetchHistoricalData();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _fetchHistoricalData() async {
    try {
      final container = ProviderContainer();
      final syncService = container.read(syncServiceProvider);
      await syncService.pullHistoricalData('stock_history');
      await syncService.pullHistoricalData('batch_stock_history');
      container.dispose();
      
      // After cloud fetch, reload from local SQLite
      final history = await DatabaseService.instance.getProductStockHistory(productId);
      if (mounted) {
        state = AsyncValue.data(history);
      }
    } catch (e) {
      debugPrint('Failed lazy load stock history: $e');
    }
  }
}

class StockHistoryScreen extends ConsumerWidget {
  final int productId;
  final String productName;

  const StockHistoryScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(productStockHistoryProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$productName History'),
      ),
      body: historyAsync.when(
        data: (history) => history.isEmpty
            ? const Center(child: Text('No history available for this product.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return AnimateIn(
                    key: ValueKey('stock_history_item_${item.id}'),
                    delay: Duration(milliseconds: 50 * index),
                    child: _StockHistoryItem(item: item),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StockHistoryItem extends StatelessWidget {
  final StockHistory item;
  const _StockHistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final isIncrease = item.quantityChange > 0;
    final color = isIncrease ? AppTheme.primaryGreen : AppTheme.errorRed;
    final icon = _getIconForType(item.type);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item.type.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              '${isIncrease ? "+" : ""}${item.quantityChange.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 18,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              Formatters.dateTime(item.createdAt),
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.notes!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'sale':
        return Icons.shopping_cart_outlined;
      case 'purchase':
        return Icons.add_business_outlined;
      case 'return':
        return Icons.assignment_return_outlined;
      case 'adjustment':
        return Icons.tune_outlined;
      default:
        return Icons.history;
    }
  }
}
