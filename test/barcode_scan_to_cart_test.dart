import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/product_batch.dart';
import 'package:quickbill/providers/cart_provider.dart';
import 'package:quickbill/providers/product_provider.dart';
import 'package:quickbill/services/pos_barcode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PosBarcodeService - Scan to Cart Behavior', () {
    late ProviderContainer container;

    final testProductA = Product(
      id: 101,
      name: 'Highland Milk 1L',
      nameSinhala: 'හයිලන්ඩ් කිරි 1L',
      price: 450.0,
      baseBarcode: '479201900101',
      stock: 25.0,
      unit: 'pcs',
    );

    final testProductB = Product(
      id: 102,
      name: 'Munchee Super Cream Cracker 500g',
      nameSinhala: 'ක්‍රීම් ක්‍රැකර් 500g',
      price: 320.0,
      baseBarcode: '479201900102',
      stock: 40.0,
      unit: 'pcs',
    );

    final testProductPack = Product(
      id: 103,
      name: 'Anchor Butter 200g Pack',
      price: 850.0,
      baseBarcode: '479201900103',
      stock: 15.0,
      unit: 'pcs',
      allowPack: true,
      allowLoose: false,
      packPrice: 820.0,
      packUnit: 'pack',
    );

    final batch1 = ProductBatch(
      id: 501,
      productId: 104,
      batchNumber: 'BCH-2026-001',
      barcode: '479201900104-B1',
      stock: 20.0,
    );

    final testProductBatch = Product(
      id: 104,
      name: 'Panadol 12s Card',
      price: 180.0,
      baseBarcode: '479201900104',
      stock: 20.0,
      unit: 'pcs',
      batches: [batch1],
    );

    final mockProducts = [
      testProductA,
      testProductB,
      testProductPack,
      testProductBatch,
    ];

    setUp(() {
      container = ProviderContainer(
        overrides: [
          productsProvider.overrideWith((ref) async => mockProducts),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Single barcode scan automatically adds product to cart with quantity 1', () async {
      final result = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '479201900101',
        ref: _MockWidgetRef(container),
        playSound: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.product?.id, 101);
      expect(result.quantityAdded, 1.0);
      expect(result.totalQuantityInCart, 1.0);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].product?.id, 101);
      expect(cart[0].quantity, 1.0);
      expect(cart[0].total, 450.0);
    });

    test('2. Consecutively scanning the same barcode increments quantity (1 -> 2 -> 3) with no duplicate row', () async {
      final mockRef = _MockWidgetRef(container);

      // Scan 1
      final res1 = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '479201900101',
        ref: mockRef,
        playSound: false,
      );
      expect(res1.isSuccess, isTrue);
      expect(res1.totalQuantityInCart, 1.0);

      var cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 1.0);
      expect(cart[0].total, 450.0);

      // Scan 2 (same barcode)
      final res2 = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '479201900101',
        ref: mockRef,
        playSound: false,
      );
      expect(res2.isSuccess, isTrue);
      expect(res2.totalQuantityInCart, 2.0);

      cart = container.read(cartProvider);
      expect(cart.length, 1, reason: 'Must not create a duplicate row in cart');
      expect(cart[0].quantity, 2.0);
      expect(cart[0].total, 900.0);

      // Scan 3 (same barcode)
      final res3 = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '479201900101',
        ref: mockRef,
        playSound: false,
      );
      expect(res3.isSuccess, isTrue);
      expect(res3.totalQuantityInCart, 3.0);

      cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 3.0);
      expect(cart[0].total, 1350.0);
    });

    test('3. Multiple different barcodes scanned rapidly are all added in order with correct totals', () async {
      final mockRef = _MockWidgetRef(container);

      // Queue of rapid incoming barcodes
      final scanStream = [
        '479201900101', // Product A (450)
        '479201900102', // Product B (320)
        '479201900101', // Product A again -> qty 2 (450 * 2 = 900)
        '479201900102', // Product B again -> qty 2 (320 * 2 = 640)
      ];

      for (final barcode in scanStream) {
        final res = await PosBarcodeService.instance.processBarcodeScan(
          barcode: barcode,
          ref: mockRef,
          playSound: false,
        );
        expect(res.isSuccess, isTrue);
      }

      final cart = container.read(cartProvider);
      expect(cart.length, 2);

      final itemA = cart.firstWhere((i) => i.product?.id == 101);
      expect(itemA.quantity, 2.0);
      expect(itemA.total, 900.0);

      final itemB = cart.firstWhere((i) => i.product?.id == 102);
      expect(itemB.quantity, 2.0);
      expect(itemB.total, 640.0);

      final grandTotal = cart.fold(0.0, (sum, i) => sum + i.total);
      expect(grandTotal, 1540.0);
    });

    test('4. Unknown barcode returns isSuccess=false and cart remains unchanged', () async {
      final mockRef = _MockWidgetRef(container);

      final result = await PosBarcodeService.instance.processBarcodeScan(
        barcode: 'UNKNOWN-999999999',
        ref: mockRef,
        playSound: false,
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Product not found'));
      expect(result.barcode, 'UNKNOWN-999999999');

      final cart = container.read(cartProvider);
      expect(cart, isEmpty, reason: 'Cart should remain untouched on failed scan');
    });

    test('5. Pack product barcode applies custom pack price and pack unit correctly', () async {
      final mockRef = _MockWidgetRef(container);

      final result = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '479201900103',
        ref: mockRef,
        playSound: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.product?.id, 103);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].quantity, 1.0);
      expect(cart[0].selectedUnit, 'pack');
      expect(cart[0].customSellingPrice, 820.0);
      expect(cart[0].total, 820.0);
    });

    test('6. Batch specific barcode assigns batch to cart line item', () async {
      final mockRef = _MockWidgetRef(container);

      final result = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '479201900104-B1',
        ref: mockRef,
        playSound: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.product?.id, 104);
      expect(result.batch?.id, 501);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart[0].product?.id, 104);
      expect(cart[0].batchId, 501);
      expect(cart[0].quantity, 1.0);
    });

    test('7. Whitespace around barcode is cleaned and trimmed automatically', () async {
      final mockRef = _MockWidgetRef(container);

      final result = await PosBarcodeService.instance.processBarcodeScan(
        barcode: '  479201900101 \n',
        ref: mockRef,
        playSound: false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.barcode, '479201900101');
      expect(result.product?.id, 101);
    });
  });
}

/// Minimal mock implementation of WidgetRef delegating to ProviderContainer
class _MockWidgetRef implements WidgetRef {
  final ProviderContainer _container;
  _MockWidgetRef(this._container);

  @override
  BuildContext get context => throw UnimplementedError();

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  T watch<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  bool exists(ProviderBase<Object?> provider) => _container.exists(provider);

  @override
  void invalidate(ProviderOrFamily provider) => _container.invalidate(provider);

  @override
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    _container.listen(provider, listener, onError: onError);
  }

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) {
    return _container.listen(provider, listener, onError: onError, fireImmediately: fireImmediately);
  }

  @override
  T refresh<T>(Refreshable<T> provider) => _container.refresh(provider);
}
