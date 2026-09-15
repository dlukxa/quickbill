import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_expiry_item.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';
import 'employee_provider.dart';
import 'product_provider.dart';

/// Configurable alert threshold in days: default 30 days.
/// User can switch between 7, 15, 30, 60, or 90 days.
final expiryAlertThresholdProvider = StateProvider<int>((ref) => 30);

/// Active tab on the Expiry Management screen.
enum ExpiryTab {
  expired,
  expiringSoon,
  valid,
  all,
}

/// Sort options for expiry items.
enum ExpirySort {
  expiryAsc,   // Oldest expiry / nearest first
  expiryDesc,  // Furthest expiry first
  qtyDesc,     // Highest stock first
  qtyAsc,      // Lowest stock first
  nameAsc,     // Product name A-Z
}

/// Filter state for Expiry Management.
class ExpiryFilterState {
  final ExpiryTab tab;
  final String searchQuery;
  final String? selectedCategory;
  final DateTime? startDate;
  final DateTime? endDate;
  final ExpirySort sortBy;

  const ExpiryFilterState({
    this.tab = ExpiryTab.expired,
    this.searchQuery = '',
    this.selectedCategory,
    this.startDate,
    this.endDate,
    this.sortBy = ExpirySort.expiryAsc,
  });

  ExpiryFilterState copyWith({
    ExpiryTab? tab,
    String? searchQuery,
    String? selectedCategory,
    bool clearCategory = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDateRange = false,
    ExpirySort? sortBy,
  }) {
    return ExpiryFilterState(
      tab: tab ?? this.tab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class ExpiryFilterNotifier extends StateNotifier<ExpiryFilterState> {
  ExpiryFilterNotifier() : super(const ExpiryFilterState());

  void setTab(ExpiryTab tab) => state = state.copyWith(tab: tab);
  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);
  void setCategory(String? cat) => state = state.copyWith(selectedCategory: cat, clearCategory: cat == null);
  void setDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      state = state.copyWith(startDate: start, endDate: end);
    }
  }
  void setSortBy(ExpirySort sort) => state = state.copyWith(sortBy: sort);
  void reset() => state = const ExpiryFilterState();
}

final expiryFilterProvider =
    StateNotifierProvider<ExpiryFilterNotifier, ExpiryFilterState>((ref) {
  return ExpiryFilterNotifier();
});

/// Fetches all stock items with an expiry date from SQLite database.
final stockExpiryItemsProvider =
    FutureProvider<List<StockExpiryItem>>((ref) async {
  final branchId = ref.watch(currentBranchIdProvider);
  return await DatabaseService.instance.getAllStockExpiryItems(branchId: branchId);
});

/// Summary KPIs for dashboard cards and screen headers.
class ExpirySummary {
  final int totalExpiredProducts;
  final double totalExpiredStockQty;
  final int expiringSoonProducts;
  final double expiringSoonStockQty;
  final int validProducts;
  final double validStockQty;
  final int totalTrackedProducts;
  final double totalTrackedStockQty;

  const ExpirySummary({
    this.totalExpiredProducts = 0,
    this.totalExpiredStockQty = 0.0,
    this.expiringSoonProducts = 0,
    this.expiringSoonStockQty = 0.0,
    this.validProducts = 0,
    this.validStockQty = 0.0,
    this.totalTrackedProducts = 0,
    this.totalTrackedStockQty = 0.0,
  });
}

/// Provider computing real-time expiry summary metrics based on the active threshold.
final expirySummaryProvider = Provider<ExpirySummary>((ref) {
  final itemsAsync = ref.watch(stockExpiryItemsProvider);
  final threshold = ref.watch(expiryAlertThresholdProvider);

  return itemsAsync.when(
    data: (items) {
      final expiredProductIds = <int>{};
      double expiredQty = 0.0;

      final expiringProductIds = <int>{};
      double expiringQty = 0.0;

      final validProductIds = <int>{};
      double validQty = 0.0;

      final allProductIds = <int>{};
      double totalQty = 0.0;

      for (final item in items) {
        allProductIds.add(item.productId);
        totalQty += item.stock;

        if (item.isExpired) {
          expiredProductIds.add(item.productId);
          expiredQty += item.stock;
        } else if (item.isExpiringSoon(threshold)) {
          expiringProductIds.add(item.productId);
          expiringQty += item.stock;
        } else {
          validProductIds.add(item.productId);
          validQty += item.stock;
        }
      }

      return ExpirySummary(
        totalExpiredProducts: expiredProductIds.length,
        totalExpiredStockQty: expiredQty,
        expiringSoonProducts: expiringProductIds.length,
        expiringSoonStockQty: expiringQty,
        validProducts: validProductIds.length,
        validStockQty: validQty,
        totalTrackedProducts: allProductIds.length,
        totalTrackedStockQty: totalQty,
      );
    },
    loading: () => const ExpirySummary(),
    error: (_, __) => const ExpirySummary(),
  );
});

/// Filtered, searched, and sorted list of expiry items ready for display.
final filteredExpiryItemsProvider = Provider<List<StockExpiryItem>>((ref) {
  final itemsAsync = ref.watch(stockExpiryItemsProvider);
  final filter = ref.watch(expiryFilterProvider);
  final threshold = ref.watch(expiryAlertThresholdProvider);

  return itemsAsync.when(
    data: (allItems) {
      List<StockExpiryItem> list = List.of(allItems);

      // 1. Tab / Status filtering
      switch (filter.tab) {
        case ExpiryTab.expired:
          list = list.where((i) => i.isExpired).toList();
          break;
        case ExpiryTab.expiringSoon:
          list = list.where((i) => i.isExpiringSoon(threshold)).toList();
          break;
        case ExpiryTab.valid:
          list = list.where((i) => !i.isExpired && !i.isExpiringSoon(threshold)).toList();
          break;
        case ExpiryTab.all:
          break;
      }

      // 2. Category filtering
      if (filter.selectedCategory != null && filter.selectedCategory!.isNotEmpty) {
        list = list.where((i) =>
            i.category?.toLowerCase() == filter.selectedCategory!.toLowerCase()).toList();
      }

      // 3. Expiry date range filtering
      if (filter.startDate != null) {
        final start = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
        list = list.where((i) => !i.expiryDate.isBefore(start)).toList();
      }
      if (filter.endDate != null) {
        final end = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day, 23, 59, 59);
        list = list.where((i) => !i.expiryDate.isAfter(end)).toList();
      }

      // 4. Search query (supports name, Sinhala, English, barcode)
      final query = filter.searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        list = list.where((i) {
          final name = i.productName.toLowerCase();
          final sinhala = i.nameSinhala?.toLowerCase() ?? '';
          final english = i.nameEnglish?.toLowerCase() ?? '';
          final barcode = i.barcode?.toLowerCase() ?? '';
          final batchNo = i.batchNumber?.toLowerCase() ?? '';

          return name.contains(query) ||
              sinhala.contains(query) ||
              english.contains(query) ||
              barcode.contains(query) ||
              batchNo.contains(query);
        }).toList();
      }

      // 5. Sorting
      list.sort((a, b) {
        switch (filter.sortBy) {
          case ExpirySort.expiryAsc:
            return a.expiryDate.compareTo(b.expiryDate);
          case ExpirySort.expiryDesc:
            return b.expiryDate.compareTo(a.expiryDate);
          case ExpirySort.qtyDesc:
            return b.stock.compareTo(a.stock);
          case ExpirySort.qtyAsc:
            return a.stock.compareTo(b.stock);
          case ExpirySort.nameAsc:
            return a.displayName.compareTo(b.displayName);
        }
      });

      return list;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Actions provider for stock write-offs and inventory updates.
class ExpiryActions {
  final Ref ref;

  ExpiryActions(this.ref);

  /// Mark stock as removed / damaged / expired using the existing inventory adjustment system.
  /// Does not delete the product record.
  Future<void> writeOffStock({
    required StockExpiryItem item,
    required double quantity,
    required String reason, // 'expired', 'damaged', 'spoiled', 'returned to supplier'
    String? notes,
  }) async {
    final branchId = ref.read(currentBranchIdProvider);
    final employeeId = ref.read(currentEmployeeProvider).value?.id;

    if (item.batchId != null) {
      // Deduct from batch and product scope
      await DatabaseService.instance.writeOffBatchStock(
        productId: item.productId,
        batchId: item.batchId!,
        branchId: branchId,
        quantity: quantity,
        reason: reason,
        notes: notes,
        employeeId: employeeId,
      );
    } else {
      // Non-batch product: adjust product stock directly
      await DatabaseService.instance.adjustStock(
        productId: item.productId,
        branchId: branchId,
        quantityChange: -quantity,
        notes: 'Wastage ($reason): ${notes ?? "Inventory expiry adjustment"}',
        employeeId: employeeId,
      );
    }

    // Refresh relevant providers
    ref.invalidate(stockExpiryItemsProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(lowStockProductsProvider);
  }

  /// Manually refresh expiry items from DB.
  void refresh() {
    ref.invalidate(stockExpiryItemsProvider);
  }
}

final expiryActionsProvider = Provider<ExpiryActions>((ref) {
  return ExpiryActions(ref);
});
