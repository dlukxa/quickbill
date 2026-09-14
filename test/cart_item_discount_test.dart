import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/product.dart';
import 'package:quickbill/models/sale_item.dart';
import 'package:quickbill/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProduct = Product(
    id: 1,
    name: 'Basmati Rice',
    baseBarcode: '1234567890',
    price: 300.0,
    costPrice: 200.0,
    stock: 50.0,
    category: 'Grains',
    unit: 'kg',
    allowLoose: true,
    allowPack: true,
    packPrice: 1400.0,
    packSize: 5.0,
    packSizeUnit: 'kg',
    packUnit: 'bag',
  );

  group('CartItem Discount & Subtotal Model Tests', () {
    test('Calculates undiscounted subtotal and discount correctly for standard item', () {
      final item = CartItem(
        product: testProduct,
        quantity: 2.0,
        selectedUnit: 'kg',
        sellingMode: 'weight',
        discount: 60.0, // 10% discount on 600
      );

      expect(item.subtotal, 600.0);
      expect(item.discount, 60.0);
      expect(item.discountPercent, 10.0);
      expect(item.total, 540.0);
    });

    test('Calculates fractional subtotal and percentage discount', () {
      // 500g of Rs. 300/kg rice = Rs. 150 subtotal
      final item = CartItem(
        product: testProduct,
        quantity: 500.0,
        selectedUnit: 'g',
        sellingMode: 'weight',
        discount: 15.0, // 10% of 150
      );

      expect(item.subtotal, 150.0);
      expect(item.discount, 15.0);
      expect(item.discountPercent, 10.0);
      expect(item.total, 135.0);
    });

    test('Calculates pack mode subtotal and discount correctly', () {
      // 2 bags of packPrice 1400 = Rs. 2800 subtotal
      final item = CartItem(
        product: testProduct,
        quantity: 2.0,
        selectedUnit: 'bag',
        sellingMode: 'pack',
        customSellingPrice: 1400.0,
        discount: 280.0, // 10% of 2800
      );

      expect(item.subtotal, 2800.0);
      expect(item.discount, 280.0);
      expect(item.discountPercent, 10.0);
      expect(item.total, 2520.0);
    });

    test('Zero discount returns 0% and total equals subtotal', () {
      final item = CartItem(
        product: testProduct,
        quantity: 1.0,
        selectedUnit: 'kg',
        sellingMode: 'weight',
        discount: 0.0,
      );

      expect(item.subtotal, 300.0);
      expect(item.discount, 0.0);
      expect(item.discountPercent, 0.0);
      expect(item.total, 300.0);
    });
  });

  group('CartNotifier Item Discount State Operations', () {
    test('updateItemDiscount updates cart item and recalculates totals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addProduct(testProduct, quantity: 2.0, unit: 'kg', sellingMode: 'weight');

      expect(container.read(cartProvider).first.total, 600.0);
      expect(container.read(cartProvider).first.discount, 0.0);

      // Apply Rs. 50 discount
      notifier.updateItemDiscount(index: 0, discount: 50.0);

      final updated = container.read(cartProvider).first;
      expect(updated.subtotal, 600.0);
      expect(updated.discount, 50.0);
      expect(updated.total, 550.0);
      expect(notifier.getTotal(), 550.0);
    });

    test('updateItemQuantityAndUnit updates both quantity, unit, and discount in one call', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      notifier.addProduct(testProduct, quantity: 1.0, unit: 'kg', sellingMode: 'weight');

      // Update to 3kg and apply Rs. 90 discount (10% of 900)
      notifier.updateItemQuantityAndUnit(
        index: 0,
        quantity: 3.0,
        unit: 'kg',
        discount: 90.0,
      );

      final item = container.read(cartProvider).first;
      expect(item.quantity, 3.0);
      expect(item.subtotal, 900.0);
      expect(item.discount, 90.0);
      expect(item.discountPercent, 10.0);
      expect(item.total, 810.0);
    });

    test('SaleItem accurately captures line-level discount', () {
      final cartItem = CartItem(
        product: testProduct,
        quantity: 2.0,
        selectedUnit: 'kg',
        sellingMode: 'weight',
        discount: 100.0,
      );

      final saleItem = SaleItem(
        saleId: 10,
        productId: cartItem.product!.id!,
        productName: cartItem.itemName,
        quantity: cartItem.baseQuantity,
        unitPrice: cartItem.itemPrice,
        total: cartItem.total,
        costPrice: cartItem.product?.costPrice ?? 0.0,
        discount: cartItem.discount,
        soldUnit: cartItem.itemUnit,
        soldQuantity: cartItem.quantity,
        sellingMode: cartItem.sellingMode,
      );

      expect(saleItem.unitPrice, 300.0);
      expect(saleItem.discount, 100.0);
      expect(saleItem.total, 500.0);
    });
  });
}
