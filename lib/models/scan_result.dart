import 'product.dart';
import 'product_batch.dart';

enum ScanStatus {
  added,
  addedWithWarning,
  notFound,
  expired,
  outOfStock,
  duplicate,
  error,
  batchRequired
}

class ScanResult {
  final ScanStatus status;
  final String message;
  final String barcode;
  final Product? product;
  final ProductBatch? batch;

  const ScanResult({
    required this.status,
    required this.message,
    required this.barcode,
    this.product,
    this.batch,
  });
}
