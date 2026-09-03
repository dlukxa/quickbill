import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/custom_order.dart';
import '../models/custom_order_item.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';

final customOrdersProvider = AsyncNotifierProvider<CustomOrderNotifier, List<CustomOrder>>(() {
  return CustomOrderNotifier();
});

class CustomOrderNotifier extends AsyncNotifier<List<CustomOrder>> {
  @override
  Future<List<CustomOrder>> build() async {
    final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
    return await DatabaseService.instance.getCustomOrders(branchId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
    state = await AsyncValue.guard(() => DatabaseService.instance.getCustomOrders(branchId));
  }
}

final customOrderActionsProvider = Provider((ref) => CustomOrderActions(ref));

class CustomOrderActions {
  final Ref _ref;

  CustomOrderActions(this._ref);

  Future<int> createOrder(CustomOrder order, List<CustomOrderItem> items) async {
    final id = await DatabaseService.instance.insertCustomOrder(order, items);
    _ref.read(customOrdersProvider.notifier).refresh();
    return id;
  }

  Future<List<CustomOrderItem>> getOrderItems(int orderId) async {
    return await DatabaseService.instance.getCustomOrderItems(orderId);
  }

  Future<void> updateStatus(int orderId, String status) async {
    await DatabaseService.instance.updateCustomOrderStatus(orderId, status);
    _ref.read(customOrdersProvider.notifier).refresh();
  }

  Future<void> updateDepositPaid(int orderId, int depositPaid) async {
    await DatabaseService.instance.updateCustomOrderDepositPaid(orderId, depositPaid);
    _ref.read(customOrdersProvider.notifier).refresh();
  }

  Future<void> deleteOrder(int orderId) async {
    await DatabaseService.instance.deleteCustomOrder(orderId);
    _ref.read(customOrdersProvider.notifier).refresh();
  }
}

final ordersByStatusProvider = Provider.family<List<CustomOrder>, String>((ref, status) {
  final orders = ref.watch(customOrdersProvider).valueOrNull ?? [];
  return orders.where((o) => o.status == status).toList();
});
