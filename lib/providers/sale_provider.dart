import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import '../models/cart_item.dart';
import 'product_provider.dart';
import 'customer_provider.dart';
import 'employee_provider.dart';
import 'branch_provider.dart';
import 'report_provider.dart';
import 'preference_provider.dart';

// All sales provider
final salesProvider = FutureProvider<List<Sale>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getAllSales(branchId);
});

// Today's sales provider
final todaySalesProvider = FutureProvider<List<Sale>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getSalesToday(branchId);
});

// Recent sales provider (for Returns screen)
final recentSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getAllSales(branchId);
});

// Today's stats provider
final todayStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final branchId = ref.watch(branchProvider).selectedBranch?.id ?? 1;
  return await db.getTodayStats(branchId);
});

// Sale by ID provider
final saleByIdProvider = FutureProvider.family<Sale?, int>((ref, id) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getSaleById(id);
});

// Sale actions
class SaleActions {
  final Ref ref;

  SaleActions(this.ref);

  Future<String> generateBillNumber() async {
    final db = ref.read(databaseServiceProvider);
    final entityCode = ref.read(settingsProvider).entityCode;
    return await db.generateBillNumber(entityCode);
  }

  Future<Sale> createSale({
    required List<CartItem> cartItems,
    required double total,
    double discount = 0,
    double tax = 0,
    double serviceCharge = 0,
    String paymentMethod = 'cash',
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? notes,
  }) async {
    final billNumber = await generateBillNumber();
    final db = ref.read(databaseServiceProvider);
    final employeeAsync = ref.read(currentEmployeeProvider);
    final employee = employeeAsync.value;

    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;

    final sale = Sale(
      billNumber: billNumber,
      branchId: branchId,
      total: total,
      discount: discount,
      tax: tax,
      serviceCharge: serviceCharge,
      itemsCount: cartItems.length,
      paymentMethod: paymentMethod,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
      employeeId: employee?.id,
      cashierName: employee?.name,
    );

    final saleId = await db.insertSale(sale, cartItems);
    
    // Invalidate related providers
    ref.invalidate(salesProvider);
    ref.invalidate(todaySalesProvider);
    ref.invalidate(todayStatsProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(lowStockProductsProvider);
    ref.invalidate(customersProvider);
    
    // Invalidate report and analytics providers
    ref.invalidate(salesChartProvider);
    ref.invalidate(categorySalesProvider);
    ref.invalidate(inventoryAlertsProvider);
    ref.invalidate(summaryProfitabilityProvider);

    return sale.copyWith(id: saleId);
  }

  Future<List<Sale>> getSalesByRange(DateTime start, DateTime end) async {
    final db = ref.read(databaseServiceProvider);
    final branchId = ref.read(branchProvider).selectedBranch?.id ?? 1;
    return await db.getSalesByRange(start, end, branchId);
  }
}

// Sale actions provider
final saleActionsProvider = Provider((ref) => SaleActions(ref));
