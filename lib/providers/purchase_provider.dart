import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';
import 'employee_provider.dart';
import 'supplier_provider.dart';

final purchasesProvider = AsyncNotifierProvider<PurchaseNotifier, List<Purchase>>(() {
  return PurchaseNotifier();
});

class PurchaseNotifier extends AsyncNotifier<List<Purchase>> {
  @override
  Future<List<Purchase>> build() async {
    final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
    return await DatabaseService.instance.getAllPurchases(branchId: branchId);
  }

  void refresh() {
    state = const AsyncValue.loading();
    build().then((value) => state = AsyncValue.data(value));
  }
}

final pendingPurchasesProvider = Provider<List<Purchase>>((ref) {
  final purchases = ref.watch(purchasesProvider).value ?? [];
  return purchases.where((p) => p.status == "Pending").toList();
});

final purchaseActionsProvider = Provider((ref) => PurchaseActions(ref));

class PurchaseActions {
  final Ref _ref;

  PurchaseActions(this._ref);

  Future<int> createPurchase(Purchase purchase) async {
    final branchId = _ref.read(branchProvider).selectedBranch?.id ?? 1;
    final employeeId = _ref.read(currentEmployeeProvider).value?.id;
    
    final purchaseWithMeta = purchase.copyWith(
      branchId: branchId,
      employeeId: employeeId,
      date: DateTime.now(),
    );

    final id = await DatabaseService.instance.insertPurchase(purchaseWithMeta);
    _ref.read(purchasesProvider.notifier).refresh();
    _ref.read(suppliersProvider.notifier).refresh();
    return id;
  }

  Future<void> receivePurchase(int purchaseId) async {
    await DatabaseService.instance.receivePurchase(purchaseId);
    _ref.read(purchasesProvider.notifier).refresh();
    _ref.read(suppliersProvider.notifier).refresh();
  }

  Future<void> updatePurchase(Purchase purchase) async {
    await DatabaseService.instance.updatePurchase(purchase);
    _ref.read(purchasesProvider.notifier).refresh();
    _ref.read(suppliersProvider.notifier).refresh();
  }

  Future<void> deletePurchase(int id) async {
    await DatabaseService.instance.deletePurchase(id);
    _ref.read(purchasesProvider.notifier).refresh();
    _ref.read(suppliersProvider.notifier).refresh();
  }
}
