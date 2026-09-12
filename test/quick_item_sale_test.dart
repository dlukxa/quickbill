import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbill/models/cart_item.dart';
import 'package:quickbill/models/sale.dart';
import 'package:quickbill/providers/sale_provider.dart';
import 'package:quickbill/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quick Custom Item Sale Test', () {
    test('createSale succeeds with custom quick item without throwing Bad state: No element', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final saleActions = container.read(saleActionsProvider);

      final quickCartItem = CartItem(
        isQuickItem: true,
        customItemName: 'siini 250',
        customItemPrice: 250.0,
        quantity: 1.0,
      );

      final createdSale = await saleActions.createSale(
        cartItems: [quickCartItem],
        total: 250.0,
        discount: 0.0,
        paymentMethod: 'cash',
      );

      expect(createdSale.id, isNotNull);
      expect(createdSale.total, equals(250.0));
      expect(createdSale.itemsCount, equals(1));
    });
  });
}
