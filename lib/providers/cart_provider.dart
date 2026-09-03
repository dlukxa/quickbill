import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'discount_provider.dart';
import '../models/discount.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/service.dart';
import '../models/product_batch.dart';
import 'preference_provider.dart';
import '../services/unit_conversion_service.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref ref;
  CartNotifier(this.ref) : super([]);

  set state(List<CartItem> val) => super.state = val;

  // Add product to cart (with optional batch, unit, mode, and quantity)
  void addProduct(
    Product product, {
    double quantity = 1.0,
    String? unit,
    String? sellingMode,
    double? packSize,
    String? packSizeUnit,
    double? customPrice,
    ProductBatch? batch,
    double? manualDiscount,
  }) {
    final effectiveUnit = unit ?? (sellingMode == 'pack' ? (product.packUnit.isNotEmpty ? product.packUnit : 'pack') : product.baseUnit);
    final effectiveMode = sellingMode ?? (product.allowPack && !product.allowLoose ? 'pack' : (product.isVariableQuantity ? 'weight' : 'piece'));

    // Check if item exists in cart (same product AND same batch AND same unit AND same mode)
    final existingIndex = state.indexWhere(
      (item) => !item.isQuickItem && item.product?.id == product.id && item.batchId == batch?.id && item.itemUnit == effectiveUnit && item.sellingMode == effectiveMode,
    );

    // Calculate discount automatically if not provided manually
    double discount = manualDiscount ?? 0.0;
    final activePrice = customPrice ?? (effectiveMode == 'pack' && product.packPrice != null ? product.packPrice! : product.price);
    if (manualDiscount == null && product.id != null) {
      final discountRule = ref.read(discountsProvider.notifier).getActiveDiscountSync(product.id!);
      if (discountRule != null) {
        if (discountRule.discountType == 'percentage') {
          discount = (activePrice * (discountRule.discountValue / 100));
        } else {
          discount = discountRule.discountValue;
        }
      }
    }
 
    if (existingIndex >= 0) {
      // Product already in cart with same unit and mode, increase quantity
      final item = state[existingIndex];
      if (item.quantity + quantity <= item.availableStock) {
        state[existingIndex].quantity += quantity;
        state = [...state]; // Trigger rebuild
      }
    } else {
      // Add new item to cart
      state = [
        ...state, 
        CartItem(
          product: product, 
          quantity: quantity,
          selectedUnit: effectiveUnit,
          sellingMode: effectiveMode,
          packSize: packSize ?? (effectiveMode == 'pack' ? product.packSize : null),
          packSizeUnit: packSizeUnit ?? (effectiveMode == 'pack' ? product.packSizeUnit : null),
          customSellingPrice: customPrice ?? (effectiveMode == 'pack' ? product.packPrice : null),
          batchId: batch?.id,
          batchNumber: batch?.batchNumber,
          batchStock: batch?.stock,
          discount: discount,
        )
      ];
    }
  }

  // Update item unit and quantity
  void updateItemUnit(int index, String newUnit, double newQuantity) {
    if (index >= 0 && index < state.length) {
      final item = state[index];
      state[index] = item.copyWith(
        selectedUnit: newUnit,
        quantity: newQuantity,
      );
      state = [...state];
    }
  }

  // Add quick bill item (custom item without inventory)
  void addQuickItem({
    required String name,
    required double price,
    double quantity = 1.0,
  }) {
    // Quick items are always unique, don't merge duplicates
    state = [
      ...state,
      CartItem(
        isQuickItem: true,
        customItemName: name,
        customItemPrice: price,
        quantity: quantity,
      ),
    ];
  }

  // Add service item
  void addService(Service service, {double quantity = 1.0, double? manualDiscount}) {
    final existingIndex = state.indexWhere((item) => item.itemType == 'service' && item.serviceId == service.id);

    if (existingIndex >= 0) {
      state[existingIndex].quantity += quantity;
      state = [...state];
    } else {
      state = [
        ...state,
        CartItem(
          serviceObj: service,
          itemType: 'service',
          serviceId: service.id,
          quantity: quantity,
          discount: manualDiscount ?? 0.0,
        )
      ];
    }
  }
 
  // Remove item from cart
  void removeItem({int? productId, int? serviceId, int? batchId, int? index}) {
    if (index != null) {
      state = [...state]..removeAt(index);
    } else if (serviceId != null) {
      state = state.where((item) => item.serviceId != serviceId).toList();
    } else if (productId != null) {
      state = state.where((item) => 
        !(item.product?.id == productId && item.batchId == batchId)
      ).toList();
    }
  }
 
  // Update quantity (handle batch, services, and quick items)
  void updateQuantity({int? productId, int? serviceId, required double quantity, int? batchId, int? index}) {
    int idx = -1;
    
    if (index != null) {
      idx = index;
    } else if (serviceId != null) {
      idx = state.indexWhere((item) => item.itemType == 'service' && item.serviceId == serviceId);
    } else if (productId != null) {
      idx = state.indexWhere(
        (item) => !item.isQuickItem && item.product?.id == productId && item.batchId == batchId
      );
    }
    
    if (idx >= 0) {
      if (quantity <= 0) {
        removeItem(productId: productId, serviceId: serviceId, batchId: batchId, index: index);
      } else if (quantity <= state[idx].availableStock) {
        state[idx].quantity = quantity;
        
        // Recalculate discount
        final item = state[idx];
        if (!item.isQuickItem && item.product?.id != null) {
          final discountRule = ref.read(discountsProvider.notifier).getActiveDiscountSync(item.product!.id!);
          if (discountRule != null) {
            if (discountRule.discountType == 'percentage') {
              state[idx].discount = (item.itemPrice * quantity * (discountRule.discountValue / 100));
            } else {
              state[idx].discount = discountRule.discountValue * quantity;
            }
          }
        }
        
        state = [...state];
      }
    }
  }
 
  // Increment quantity
  void incrementQuantity({int? productId, int? serviceId, int? batchId, int? index}) {
    int idx = -1;
    
    if (index != null) {
      idx = index;
    } else if (serviceId != null) {
      idx = state.indexWhere((item) => item.itemType == 'service' && item.serviceId == serviceId);
    } else if (productId != null) {
      idx = state.indexWhere(
        (item) => !item.isQuickItem && item.product?.id == productId && item.batchId == batchId
      );
    }
    
    if (idx >= 0 && state[idx].canIncrement) {
      state[idx].increment();
      
      // Recalculate discount
      final item = state[idx];
      if (!item.isQuickItem && item.product?.id != null) {
        final discountRule = ref.read(discountsProvider.notifier).getActiveDiscountSync(item.product!.id!);
        if (discountRule != null) {
          if (discountRule.discountType == 'percentage') {
            state[idx].discount = (item.itemPrice * item.quantity * (discountRule.discountValue / 100));
          } else {
            state[idx].discount = discountRule.discountValue * item.quantity;
          }
        }
      }

      state = [...state];
    }
  }

  // Update item quantity, unit, and mode from dialog
  void updateItemQuantityAndUnit({
    required int index,
    required double quantity,
    required String unit,
    String? sellingMode,
    double? packSize,
    String? packSizeUnit,
    double? customPrice,
  }) {
    if (index >= 0 && index < state.length) {
      if (quantity <= 0) {
        removeItem(index: index);
        return;
      }
      final item = state[index];
      state[index] = item.copyWith(
        quantity: quantity,
        selectedUnit: unit,
        sellingMode: sellingMode ?? item.sellingMode,
        packSize: packSize ?? item.packSize,
        packSizeUnit: packSizeUnit ?? item.packSizeUnit,
        customSellingPrice: customPrice ?? item.customSellingPrice,
      );
      state = [...state];
    }
  }

  // Decrement quantity using unit-aware step
  void decrementQuantity({int? productId, int? serviceId, int? batchId, int? index}) {
    int idx = -1;
    
    if (index != null) {
      idx = index;
    } else if (serviceId != null) {
      idx = state.indexWhere((item) => item.itemType == 'service' && item.serviceId == serviceId);
    } else if (productId != null) {
      idx = state.indexWhere(
        (item) => !item.isQuickItem && item.product?.id == productId && item.batchId == batchId
      );
    }
    
    if (idx >= 0) {
      final item = state[idx];
      final step = UnitConversionService.getStepDecrement(item.quantity, item.itemUnit);
      if (item.quantity > step) {
        state[idx].decrement();
        state = [...state];
      } else {
        removeItem(productId: productId, serviceId: serviceId, batchId: batchId, index: index);
      }
    }
  }

  // Update item discount
  void updateItemDiscount({int? productId, int? serviceId, required double discount, int? batchId, int? index}) {
    int idx = -1;
    
    if (index != null) {
      idx = index;
    } else if (serviceId != null) {
      idx = state.indexWhere((item) => item.itemType == 'service' && item.serviceId == serviceId);
    } else if (productId != null) {
      idx = state.indexWhere(
        (item) => !item.isQuickItem && item.product?.id == productId && item.batchId == batchId
      );
    }
    
    if (idx >= 0) {
      state[idx] = state[idx].copyWith(discount: discount);
      state = [...state];
    }
  }

// Get raw subtotal (sum of item totals before bill discount)
  double getSubtotal() {
    return state.fold(0, (sum, item) => sum + item.total);
  }

  // Get total (sum of item totals which already include item discounts)
  double getTotal() {
    return getSubtotal(); // Legacy alias
  }

  // Get item count
  int getItemCount() => state.length;

  // Clear cart
  void clear() {
    state = [];
  }

  // Check if cart is empty
  bool get isEmpty => state.isEmpty;
  
  // Get cart items
  List<CartItem> get items => state;
}

// Provider
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(ref),
);

// Manual Bill Discount Provider (User overrides this)
final manualBillDiscountProvider = StateProvider<double?>((ref) => null);

// Auto-Calculated Bill Discount Provider
final autoBillDiscountProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return 0.0;
  
  final subtotal = ref.read(cartProvider.notifier).getSubtotal();
  final discountNotifier = ref.watch(discountsProvider.notifier);
  final bestDiscount = discountNotifier.getActiveBillDiscountSync(subtotal);
  
  if (bestDiscount != null) {
    if (bestDiscount.discountType == 'percentage') {
      return subtotal * (bestDiscount.discountValue / 100);
    } else {
      return bestDiscount.discountValue;
    }
  }
  return 0.0;
});

// Effective Bill Discount Provider (Returns manual if set, else auto)
final billDiscountProvider = Provider<double>((ref) {
  final manual = ref.watch(manualBillDiscountProvider);
  if (manual != null) return manual;
  return ref.watch(autoBillDiscountProvider);
});

// Total Subtotal after discount (used for Tax and Service Charge base)
final cartDiscountedSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  final subtotal = cart.fold(0.0, (sum, item) => sum + item.total);
  final effectiveDiscount = ref.watch(billDiscountProvider);
  return subtotal - effectiveDiscount;
});

// Service Charge Provider
final cartServiceChargeProvider = Provider<double>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.serviceChargeRate <= 0) return 0.0;
  
  final baseAmount = ref.watch(cartDiscountedSubtotalProvider);
  return baseAmount * (settings.serviceChargeRate / 100);
});

// Tax Provider
final cartTaxProvider = Provider<double>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.taxRate <= 0) return 0.0;
  
  final baseAmount = ref.watch(cartDiscountedSubtotalProvider);
  return baseAmount * (settings.taxRate / 100);
});

// Total provider (computed): Discounted Subtotal + Service Charge + Tax
final cartTotalProvider = Provider<double>((ref) {
  final discountedSubtotal = ref.watch(cartDiscountedSubtotalProvider);
  final serviceCharge = ref.watch(cartServiceChargeProvider);
  final tax = ref.watch(cartTaxProvider);
  return discountedSubtotal + serviceCharge + tax;
});

// Item count provider (computed)
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).length;
});
