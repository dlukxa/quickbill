import '../models/product.dart';
import '../models/product_batch.dart';
import '../services/database_service.dart';

import '../models/scan_result.dart';

class ScanService {
  final DatabaseService _db = DatabaseService.instance;
  String _lastBarcode = '';
  DateTime? _lastScanTime;

  Future<ScanResult> handleScan(String barcode) async {
    final now = DateTime.now();

    // Duplicate guard: Ignore if same barcode within 2 seconds
    if (barcode == _lastBarcode && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!).inSeconds < 2) {
      return ScanResult(
        status: ScanStatus.duplicate,
        message: '',
        barcode: barcode,
      );
    }

    _lastBarcode = barcode;
    _lastScanTime = now;

    final lookup = await _db.findByBarcode(barcode);

    if (lookup == null) {
      return ScanResult(
        status: ScanStatus.notFound,
        message: 'Product not found',
        barcode: barcode,
      );
    }

    final product = lookup['product'] as Product;
    ProductBatch? batch = lookup['batch'] as ProductBatch?;

    final isGenericScan = product.baseBarcode != null && barcode.trim() == product.baseBarcode!.trim();

    if (product.trackBatches && (batch == null || isGenericScan)) {
      if (product.calculatedStock <= 0) {
        return ScanResult(
          status: ScanStatus.outOfStock,
          product: product,
          message: '${product.name} out of stock',
          barcode: barcode,
        );
      }
      return ScanResult(
        status: ScanStatus.batchRequired,
        product: product,
        message: 'Batch selection required for ${product.name}',
        barcode: barcode,
      );
    }

    // Expiry check
    if (batch != null && batch.isExpired) {
      return ScanResult(
        status: ScanStatus.expired,
        product: product,
        batch: batch,
        message: '${product.name} EXPIRED',
        barcode: barcode,
      );
    }

    // Stock check
    if (product.trackBatches) {
      if (batch != null && batch.stock <= 0) {
        return ScanResult(
          status: ScanStatus.outOfStock,
          product: product,
          batch: batch,
          message: '${product.name} out of stock (batch)',
          barcode: barcode,
        );
      }
    } else if (product.calculatedStock <= 0) {
      return ScanResult(
        status: ScanStatus.outOfStock,
        product: product,
        message: '${product.name} out of stock',
        barcode: barcode,
      );
    }

    // Warning check
    if (batch != null && batch.expiresSoon) {
      return ScanResult(
        status: ScanStatus.addedWithWarning,
        product: product,
        batch: batch,
        message: '${product.name} added (Expires soon!)',
        barcode: barcode,
      );
    }

    // Success
    return ScanResult(
      status: ScanStatus.added,
      product: product,
      batch: batch,
      message: '${product.name} added',
      barcode: barcode,
    );
  }

  void reset() {
    _lastBarcode = '';
    _lastScanTime = null;
  }
}
