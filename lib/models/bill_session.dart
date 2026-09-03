import 'cart_item.dart';
import 'customer.dart';

class BillSession {
  final String id;
  final String name;
  final List<CartItem> items;
  final Customer? customer;
  final double? manualDiscount;
  final DateTime updatedAt;

  BillSession({
    required this.id,
    required this.name,
    required this.items,
    this.customer,
    this.manualDiscount,
    required this.updatedAt,
  });

  BillSession copyWith({
    String? name,
    List<CartItem>? items,
    Customer? customer,
    double? manualDiscount,
    DateTime? updatedAt,
  }) {
    return BillSession(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      customer: customer ?? this.customer,
      manualDiscount: manualDiscount ?? this.manualDiscount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
