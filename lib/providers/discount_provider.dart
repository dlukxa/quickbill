import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';

final discountsProvider = StateNotifierProvider<DiscountNotifier, AsyncValue<List<Discount>>>((ref) {
  final branchId = ref.watch(currentBranchIdProvider);
  return DiscountNotifier(branchId);
});

class DiscountNotifier extends StateNotifier<AsyncValue<List<Discount>>> {
  final int branchId;
  final _db = DatabaseService.instance;

  DiscountNotifier(this.branchId) : super(const AsyncValue.loading()) {
    loadDiscounts();
  }

  Future<void> loadDiscounts() async {
    state = const AsyncValue.loading();
    try {
      final discounts = await _db.getAllDiscounts(branchId);
      if (mounted) state = AsyncValue.data(discounts);
    } catch (e, stack) {
      if (mounted) state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addDiscount(Discount discount) async {
    try {
      await _db.insertDiscount(discount.copyWith(branchId: branchId));
      await loadDiscounts();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> updateDiscount(Discount discount) async {
    try {
      await _db.updateDiscount(discount);
      await loadDiscounts();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteDiscount(int id) async {
    try {
      await _db.deleteDiscount(id);
      await loadDiscounts();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleDiscountStatus(Discount discount) async {
    try {
      final updated = discount.copyWith(isActive: !discount.isActive);
      await _db.updateDiscount(updated);
      await loadDiscounts();
    } catch (e) {
      // Handle error
    }
  }

  /// Synchronous lookup from memory
  Discount? getActiveDiscountSync(int productId) {
    if (state is! AsyncData) return null;
    final discounts = (state as AsyncData<List<Discount>>).value;
    final now = DateTime.now();

    // Find the best active discount for this product
    Discount? best;
    for (final d in discounts) {
      if (d.productId == productId && d.isActive && !d.deleted) {
        bool dateActive = d.isClearance || (now.isAfter(d.startDate) && now.isBefore(d.endDate.add(const Duration(days: 1))));
        if (dateActive) {
          if (best == null || d.discountValue > best.discountValue) {
            best = d;
          }
        }
      }
    }
    return best;
  }

  /// Synchronous lookup for best bill-level discount
  Discount? getActiveBillDiscountSync(double subtotal) {
    if (state is! AsyncData) return null;
    final discounts = (state as AsyncData<List<Discount>>).value;
    final now = DateTime.now();

    Discount? best;
    double bestAmount = 0;

    for (final d in discounts) {
      // Bill discount applies if productId and category are both null
      if (d.productId == null && d.category == null && d.isActive && !d.deleted) {
        bool dateActive = d.isClearance || (now.isAfter(d.startDate) && now.isBefore(d.endDate.add(const Duration(days: 1))));
        if (dateActive) {
          // Calculate discount amount based on subtotal
          double amount = d.discountType == 'percentage' 
              ? subtotal * (d.discountValue / 100) 
              : d.discountValue;
          
          if (best == null || amount > bestAmount) {
            best = d;
            bestAmount = amount;
          }
        }
      }
    }
    return best;
  }
}

final activeDiscountForProductProvider = FutureProvider.family<Discount?, int>((ref, productId) async {
  final branchId = ref.watch(currentBranchIdProvider);
  return await DatabaseService.instance.getActiveDiscountForProduct(productId, branchId);
});

final discountActionsProvider = Provider((ref) {
  final branchId = ref.watch(currentBranchIdProvider);
  return DiscountActions(ref, branchId);
});

class DiscountActions {
  final Ref ref;
  final int branchId;
  final _db = DatabaseService.instance;

  DiscountActions(this.ref, this.branchId);

  Future<Discount?> checkActiveDiscount(int productId) async {
    return await _db.getActiveDiscountForProduct(productId, branchId);
  }
}
