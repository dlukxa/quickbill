import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import 'branch_provider.dart';

/// Provider for the list of all customers
final customersProvider = AsyncNotifierProvider<CustomerNotifier, List<Customer>>(() {
  return CustomerNotifier();
});

class CustomerNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async {
    final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
    return await DatabaseService.instance.getAllCustomers(branchId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
    state = await AsyncValue.guard(() => DatabaseService.instance.getAllCustomers(branchId));
  }
}

/// Provider for customer-related actions
final customerActionsProvider = Provider((ref) => CustomerActions(ref));

class CustomerActions {
  final Ref _ref;

  CustomerActions(this._ref);

  Future<int> addCustomer(Customer customer) async {
    final branchId = _ref.read(branchProvider).selectedBranch?.id ?? 1;
    final customerWithBranch = customer.copyWith(branchId: branchId);
    final id = await DatabaseService.instance.insertCustomer(customerWithBranch);
    _ref.read(customersProvider.notifier).refresh();
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    await DatabaseService.instance.updateCustomer(customer);
    _ref.read(customersProvider.notifier).refresh();
  }

  Future<void> deleteCustomer(int id) async {
    await DatabaseService.instance.deleteCustomer(id);
    _ref.read(customersProvider.notifier).refresh();
  }

  Future<void> recordPayment(CustomerPayment payment) async {
    await DatabaseService.instance.insertCustomerPayment(payment);
    _ref.read(customersProvider.notifier).refresh();
  }

  Future<List<CustomerPayment>> getPayments(int customerId) async {
    return await DatabaseService.instance.getCustomerPayments(customerId);
  }

  Future<List<Sale>> getCustomerSales(int customerId) async {
    return await DatabaseService.instance.getCustomerSales(customerId);
  }
}

/// Provider for searching customers
final customerSearchProvider = StateProvider<String>((ref) => '');

final filteredCustomersProvider = Provider<List<Customer>>((ref) {
  final query = ref.watch(customerSearchProvider).toLowerCase();
  final customers = ref.watch(customersProvider).value ?? [];

  if (query.isEmpty) return customers;

  return customers.where((c) {
    return c.name.toLowerCase().contains(query) || 
           (c.phone != null && c.phone!.contains(query));
  }).toList();
});

/// Provider for selected customer during billing
final selectedCustomerProvider = StateProvider<Customer?>((ref) => null);
