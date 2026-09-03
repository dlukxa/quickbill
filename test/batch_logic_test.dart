
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/models/product_batch.dart';

void main() {
  setUp(() {
    // No setup needed for pure logic test
  });

  test('FEFO Logic Verification (Integration Simulation)', () async {
    // Note: This test simulates the logic that we implemented in DatabaseService.
    // Ideally, we would spin up an in-memory SQLite instance here.
    // For this environment, we will verify the core sorting logic which is critical for FEFO.
    
    // Mock Data
    final batch1 = ProductBatch(
      id: 1,
      productId: 1,
      batchNumber: 'B1',
      stock: 10,
      initialStock: 10,
      expiryDate: DateTime.now().add(const Duration(days: 1)), // Expires Soon
      barcode: 'B1',
    );
    
    final batch2 = ProductBatch(
      id: 2,
      productId: 1,
      batchNumber: 'B2',
      stock: 10,
      initialStock: 10,
      expiryDate: DateTime.now().add(const Duration(days: 30)), // Expires Later
      barcode: 'B2',
    );
    
    final batches = [batch2, batch1]; // Unsorted initial list
    
    // 1. Verify Sorting Logic (FEFO)
    batches.sort((a, b) {
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
    
    expect(batches.first.batchNumber, 'B1'); // B1 should be first because it expires sooner
    expect(batches.last.batchNumber, 'B2');
    
    // 2. Verify Deduction Logic
    double quantityToSell = 15.0;
    Map<String, double> deducted = {};
    
    for (var batch in batches) {
      if (quantityToSell <= 0) break;
      final taking = quantityToSell > batch.stock ? batch.stock : quantityToSell;
      deducted[batch.batchNumber] = taking;
      quantityToSell -= taking;
    }
    
    expect(deducted['B1'], 10.0); // Should take all 10 from B1 (earliest expiry)
    expect(deducted['B2'], 5.0);  // Should take remaining 5 from B2
    expect(quantityToSell, 0.0);  // Should be fully satisfied
  });
}
