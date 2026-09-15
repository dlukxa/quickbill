import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../services/database_service.dart';
import '../utils/formatters.dart';

/// Result outcome of a barcode scan operation
class BarcodeScanResult {
  final bool isSuccess;
  final Product? product;
  final ProductBatch? batch;
  final String barcode;
  final String message;
  final double quantityAdded;
  final double totalQuantityInCart;
  final String? priceDisplay;

  const BarcodeScanResult({
    required this.isSuccess,
    this.product,
    this.batch,
    required this.barcode,
    required this.message,
    this.quantityAdded = 0.0,
    this.totalQuantityInCart = 0.0,
    this.priceDisplay,
  });

  factory BarcodeScanResult.success({
    required Product product,
    ProductBatch? batch,
    required String barcode,
    required double quantityAdded,
    required double totalQuantityInCart,
    required String priceDisplay,
  }) {
    return BarcodeScanResult(
      isSuccess: true,
      product: product,
      batch: batch,
      barcode: barcode,
      message: '✓ ${product.sinhalaOrName} added ($priceDisplay)',
      quantityAdded: quantityAdded,
      totalQuantityInCart: totalQuantityInCart,
      priceDisplay: priceDisplay,
    );
  }

  factory BarcodeScanResult.notFound(String barcode) {
    return BarcodeScanResult(
      isSuccess: false,
      barcode: barcode,
      message: 'Product not found: $barcode',
    );
  }

  factory BarcodeScanResult.expired({
    required Product product,
    ProductBatch? batch,
    required String barcode,
  }) {
    final batchInfo = batch != null ? ' (Batch: ${batch.batchNumber})' : '';
    return BarcodeScanResult(
      isSuccess: false,
      product: product,
      batch: batch,
      barcode: barcode,
      message: '⚠️ Expired stock: ${product.sinhalaOrName}$batchInfo is expired! Cannot sell expired goods.',
    );
  }
}

/// Centralized barcode scan-to-cart service for QuickBill POS
class PosBarcodeService {
  PosBarcodeService._();
  static final PosBarcodeService instance = PosBarcodeService._();

  /// Looks up a product by exact barcode, and if found, automatically adds 1 unit to cart
  /// (or increments the existing cart item quantity if already in the cart).
  Future<BarcodeScanResult> processBarcodeScan({
    required String barcode,
    required WidgetRef ref,
    double quantity = 1.0,
    bool playSound = true,
  }) async {
    final clean = barcode.trim();
    if (clean.isEmpty) {
      return BarcodeScanResult.notFound(clean);
    }

    Product? foundProduct;
    ProductBatch? foundBatch;

    // 1. Try SQLite database findByBarcode (covers barcode_lookup, base_barcode, and batch barcodes)
    try {
      final lookup = await DatabaseService.instance.findByBarcode(clean);
      if (lookup != null && lookup['product'] != null) {
        foundProduct = lookup['product'] as Product;
        foundBatch = lookup['batch'] as ProductBatch?;
      }
    } catch (_) {
      // Database service might not be initialized in mock or unit test environments
    }

    // 2. Fallback to in-memory productsProvider
    if (foundProduct == null) {
      List<Product> products = ref.read(productsProvider).valueOrNull ?? [];
      if (products.isEmpty) {
        try {
          products = await ref.read(productsProvider.future);
        } catch (_) {}
      }
      for (final p in products) {
        if (p.baseBarcode?.trim() == clean || p.barcode?.trim() == clean) {
          foundProduct = p;
          break;
        }
        if (p.batches != null) {
          for (final b in p.batches!) {
            if (b.barcode.trim() == clean) {
              foundProduct = p;
              foundBatch = b;
              break;
            }
          }
          if (foundProduct != null) break;
        }
      }

      // Search by ID if clean barcode is purely numeric
      if (foundProduct == null) {
        final id = int.tryParse(clean);
        if (id != null) {
          for (final p in products) {
            if (p.id == id) {
              foundProduct = p;
              break;
            }
          }
        }
      }
    }

    // 3. Product Not Found
    if (foundProduct == null) {
      if (playSound) {
        try {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        } catch (_) {}
      }
      return BarcodeScanResult.notFound(clean);
    }

    // 4. Product Found: Determine selling mode, unit, custom price
    final p = foundProduct;
    final sellingMode = (p.allowPack && !p.allowLoose) || (p.allowPack && p.packPrice != null && p.packPrice! > 0)
        ? 'pack'
        : (p.isVariableQuantity ? 'weight' : 'piece');
    final effectiveUnit = sellingMode == 'pack' ? (p.packUnit.isNotEmpty ? p.packUnit : 'pack') : p.baseUnit;
    final customPrice = sellingMode == 'pack' ? p.packPrice : null;

    // Check for expired batch or product
    final isBatchExpired = foundBatch != null && foundBatch.isExpired;
    DateTime? exp = foundBatch?.expiryDate ?? p.expiryDate;
    final isProductExpired = exp != null && DateTime.now().isAfter(exp);
    if (isBatchExpired || isProductExpired) {
      if (playSound) {
        try {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        } catch (_) {}
      }
      return BarcodeScanResult.expired(
        product: p,
        batch: foundBatch,
        barcode: clean,
      );
    }

    // 5. Add to cart (automatically increments quantity if already present)
    ref.read(cartProvider.notifier).addProduct(
      p,
      quantity: quantity,
      unit: effectiveUnit,
      sellingMode: sellingMode,
      packSize: sellingMode == 'pack' ? p.packSize : null,
      packSizeUnit: sellingMode == 'pack' ? p.packSizeUnit : null,
      customPrice: customPrice,
      batch: foundBatch,
    );

    // 6. Calculate new total quantity in cart
    final cart = ref.read(cartProvider);
    final cartItem = cart.firstWhere(
      (item) => item.product?.id == p.id && (foundBatch == null || item.batchId == foundBatch.id),
      orElse: () => cart.last,
    );
    final totalQty = cartItem.quantity;
    final priceDisplay = Formatters.currency(customPrice ?? p.price);

    // 7. Positive feedback
    if (playSound) {
      try {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }

    return BarcodeScanResult.success(
      product: p,
      batch: foundBatch,
      barcode: clean,
      quantityAdded: quantity,
      totalQuantityInCart: totalQty,
      priceDisplay: priceDisplay,
    );
  }
}
