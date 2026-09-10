import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Barcode Scanner Flow - Cart Behavior', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final testProductA = Product(
      id: 101,
      name: 'Coca Cola 500ml',
      nameSinhala: 'කොකා කෝලා 500ml',
      price: 150.0,
      baseBarcode: 'ABC123COCA',
      stock: 50.0,
      unit: 'pcs',
    );

    final testProductB = Product(
      id: 102,
      name: 'Sunlight Soap 100g',
      nameSinhala: 'සන්ලයිට් සබන් 100g',
      price: 90.0,
      baseBarcode: 'XYZ789SOAP',
      stock: 100.0,
      unit: 'pcs',
    );

    test('First scan adds product to cart with quantity 1', () {
      final cartNotifier = container.read(cartProvider.notifier);

      // Scan 1: ABC123COCA
      cartNotifier.addProduct(testProductA, quantity: 1.0);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].product?.id, 101);
      expect(cart[0].quantity, 1.0);
      expect(cart[0].total, 150.0);
    });

    test('Consecutive scans of same product increment quantity (1 -> 2 -> 3)', () {
      final cartNotifier = container.read(cartProvider.notifier);

      // Scan 1
      cartNotifier.addProduct(testProductA, quantity: 1.0);
      var cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 1.0);
      expect(cart[0].total, 150.0);

      // Scan 2 (same product)
      cartNotifier.addProduct(testProductA, quantity: 1.0);
      cart = container.read(cartProvider);
      expect(cart.length, 1); // No duplicate rows created
      expect(cart[0].quantity, 2.0);
      expect(cart[0].total, 300.0);

      // Scan 3 (same product)
      cartNotifier.addProduct(testProductA, quantity: 1.0);
      cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 3.0);
      expect(cart[0].total, 450.0);
    });

    test('Scanning a second distinct barcode adds a second line item', () {
      final cartNotifier = container.read(cartProvider.notifier);

      // Scan Product A twice
      cartNotifier.addProduct(testProductA, quantity: 1.0);
      cartNotifier.addProduct(testProductA, quantity: 1.0);

      // Scan Product B once
      cartNotifier.addProduct(testProductB, quantity: 1.0);

      final cart = container.read(cartProvider);
      expect(cart.length, 2);
      expect(cart[0].product?.id, 101);
      expect(cart[0].quantity, 2.0);
      expect(cart[0].total, 300.0);

      expect(cart[1].product?.id, 102);
      expect(cart[1].quantity, 1.0);
      expect(cart[1].total, 90.0);

      // Total bill calculation
      final total = cart.fold(0.0, (sum, item) => sum + item.total);
      expect(total, 390.0);
    });

    test('Consecutive scans work even when calculatedStock is 0 or unmanaged', () {
      final cartNotifier = container.read(cartProvider.notifier);

      final zeroStockProduct = Product(
        id: 201,
        name: 'Fresh Bread',
        price: 180.0,
        baseBarcode: 'BREAD001',
        stock: 0.0, // Stock not yet counted or 0
        unit: 'pcs',
      );

      // Scan 1
      cartNotifier.addProduct(zeroStockProduct, quantity: 1.0);
      var cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 1.0);

      // Scan 2: Must increment to 2 even with 0 stock recorded
      cartNotifier.addProduct(zeroStockProduct, quantity: 1.0);
      cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 2.0);
      expect(cart[0].total, 360.0);
    });
  });
}
