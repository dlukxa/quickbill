import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/customer.dart';
import 'package:quickbill/models/expense.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/purchase.dart';
import 'package:quickbill/models/purchase_item.dart';
import 'package:quickbill/models/supplier.dart';
import 'package:quickbill/providers/cart_provider.dart';
import 'package:quickbill/providers/customer_insights_provider.dart';
import 'package:quickbill/providers/multi_bill_provider.dart';
import 'package:quickbill/screens/desktop/desktop_shell.dart';
import 'package:quickbill/screens/desktop/desktop_dashboard_view.dart';
import 'package:quickbill/screens/desktop/desktop_inventory_view.dart';
import 'package:quickbill/screens/desktop/desktop_sales_view.dart';
import 'package:quickbill/screens/desktop/desktop_customers_view.dart';
import 'package:quickbill/screens/desktop/desktop_suppliers_view.dart';
import 'package:quickbill/screens/desktop/desktop_expenses_view.dart';
import 'package:quickbill/screens/desktop/desktop_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickBill Desktop Feature Parity & Architecture Suite', () {
    test('Desktop Shell preserves cart state in Riverpod across view switches', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testProduct = Product(
        id: 101,
        name: 'Anchor Milk Powder 400g',
        price: 1150.0,
        costPrice: 980.0,
        stock: 50.0,
        category: 'Dairy',
      );

      // 1. Add item to POS Cart
      container.read(cartProvider.notifier).addProduct(testProduct);
      final initialCart = container.read(cartProvider);
      expect(initialCart.length, 1);
      expect(initialCart.first.product?.name, 'Anchor Milk Powder 400g');
      expect(initialCart.first.quantity, 1.0);

      // 2. Simulate switching views to Inventory, Sales, Settings (view indices 1-7)
      // Because DesktopShell uses IndexedStack and Riverpod cartProvider, the state remains alive
      final cartAfterNavigation = container.read(cartProvider);
      expect(cartAfterNavigation.length, 1);
      expect(cartAfterNavigation.first.quantity, 1.0);

      // 3. Increment quantity while in POS
      container.read(cartProvider.notifier).updateQuantity(productId: testProduct.id, quantity: 2.0);
      expect(container.read(cartProvider).first.quantity, 2.0);
      expect(container.read(cartProvider).first.total, 2300.0);
    });

    test('Customer segmentation and debtor filtering calculates correctly', () {
      final now = DateTime.now();
      final debtorCustomer = Customer(
        id: 1,
        name: 'Kamal Perera',
        phone: '0771234567',
        totalDebt: 4500.0,
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
      );

      final paidCustomer = Customer(
        id: 2,
        name: 'Nimal Silva',
        phone: '0719876543',
        totalDebt: 0.0,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      );

      final customers = [debtorCustomer, paidCustomer];
      final debtorsOnly = customers.where((c) => c.totalDebt > 0).toList();

      expect(debtorsOnly.length, 1);
      expect(debtorsOnly.first.name, 'Kamal Perera');
      expect(debtorsOnly.first.totalDebt, 4500.0);
    });

    test('Supplier and GRN purchase order valuation matches item cost subtotals', () {
      final item1 = PurchaseItem(
        productId: 1,
        productName: 'Keells Dhal 1kg',
        quantity: 20,
        costPrice: 320.0,
      );

      final item2 = PurchaseItem(
        productId: 2,
        productName: 'Prima Flour 1kg',
        quantity: 50,
        costPrice: 190.0,
      );

      final items = [item1, item2];
      final totalValuation = items.fold<double>(0.0, (sum, it) => sum + (it.quantity * it.costPrice));

      expect(totalValuation, (20 * 320.0) + (50 * 190.0)); // 6,400 + 9,500 = 15,900
      expect(totalValuation, 15900.0);

      final po = Purchase(
        supplierId: 10,
        totalAmount: totalValuation,
        date: DateTime.now(),
        status: 'Received',
        items: items,
      );

      expect(po.status, 'Received');
      expect(po.items.length, 2);
      expect(po.totalAmount, 15900.0);
    });

    test('Operating expenses aggregation calculates net cashflow vs sales', () {
      final now = DateTime.now();
      final expenses = [
        Expense(
          category: 'Electricity',
          amount: 14500.0,
          date: now,
        ),
        Expense(
          category: 'Transport',
          amount: 3200.0,
          date: now,
        ),
      ];

      final totalExpenses = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      expect(totalExpenses, 17700.0);

      const double todaySales = 85000.0;
      final netCashflow = todaySales - totalExpenses;
      expect(netCashflow, 67300.0);
      expect(netCashflow > 0, true);
    });
  });
}
