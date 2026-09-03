import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';
import 'purchase_provider.dart';

final suppliersProvider = AsyncNotifierProvider<SupplierNotifier, List<Supplier>>(() {
  return SupplierNotifier();
});

class SupplierNotifier extends AsyncNotifier<List<Supplier>> {
  @override
  Future<List<Supplier>> build() async {
    final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
    return await DatabaseService.instance.getAllSuppliers(branchId);
  }

  void refresh() {
    state = const AsyncValue.loading();
    build().then((value) => state = AsyncValue.data(value));
  }
}

final supplierSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredSuppliersProvider = Provider.autoDispose<List<Supplier>>((ref) {
  final suppliers = ref.watch(suppliersProvider).value ?? [];
  final search = ref.watch(supplierSearchProvider).toLowerCase();

  if (search.isEmpty) return suppliers;

  return suppliers.where((s) {
    return s.name.toLowerCase().contains(search) ||
           (s.phone?.contains(search) ?? false) ||
           (s.providedItems?.toLowerCase().contains(search) ?? false);
  }).toList();
});

final supplierActionsProvider = Provider((ref) => SupplierActions(ref));

class SupplierActions {
  final Ref _ref;

  SupplierActions(this._ref);

  Future<int> addSupplier(Supplier supplier) async {
    final branchId = _ref.read(branchProvider).selectedBranch?.id ?? 1;
    final supplierWithBranch = supplier.copyWith(branchId: branchId);
    final id = await DatabaseService.instance.insertSupplier(supplierWithBranch);
    _ref.read(suppliersProvider.notifier).refresh();
    return id;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await DatabaseService.instance.updateSupplier(supplier);
    _ref.read(suppliersProvider.notifier).refresh();
  }

  Future<void> deleteSupplier(int id) async {
    await DatabaseService.instance.deleteSupplier(id);
    _ref.read(suppliersProvider.notifier).refresh();
  }

  Future<int> recordPurchase(Purchase purchase) async {
    final branchId = _ref.read(branchProvider).selectedBranch?.id ?? 1;
    final purchaseWithBranch = purchase.copyWith(branchId: branchId);
    final id = await DatabaseService.instance.insertPurchase(purchaseWithBranch);
    _ref.read(suppliersProvider.notifier).refresh();
    _ref.read(purchasesProvider.notifier).refresh(); // Add this
    return id;
  }

  Future<List<Purchase>> getSupplierPurchases(int supplierId) async {
    return await DatabaseService.instance.getPurchasesBySupplier(supplierId);
  }
}
