import 'package:sqflite/sqflite.dart';
import '../models/sales_return.dart';
import '../models/sales_return_item.dart';
import 'database_service.dart';

class ReturnService {
  final DatabaseService _dbService;

  ReturnService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<void> processReturn({
    required SalesReturn returnData,
    required List<SalesReturnItem> items,
  }) async {
    final db = await _dbService.database;
    
    await db.transaction((txn) async {
      // 1. Insert Return Record
      final returnId = await txn.insert('sales_returns', returnData.toMap());
      
      // 2. Insert Items & Update Stock
      for (var item in items) {
        // Link item to the created return ID
         final itemWithId = SalesReturnItem(
          returnId: returnId,
          productId: item.productId,
          batchId: item.batchId,
          quantity: item.quantity,
          refundAmount: item.refundAmount,
          condition: item.condition,
        );
        
        await txn.insert('sales_return_items', itemWithId.toMap());

        // Stock Update Logic
        if (item.condition == 'restockable') {
          // Update Product Stock
          await txn.rawUpdate('''
            UPDATE products 
            SET stock = stock + ?, updated_at = ?, synced = 0
            WHERE id = ?
          ''', [item.quantity, DateTime.now().toIso8601String(), item.productId]);
          
          await _addToSyncQueue(txn, 'products', item.productId, 'UPDATE');

          // Update Batch Stock (if applicable)
          if (item.batchId != null) {
            await txn.rawUpdate('''
              UPDATE product_batches 
              SET stock = stock + ?, updated_at = ?, synced = 0
              WHERE id = ?
            ''', [item.quantity, DateTime.now().toIso8601String(), item.batchId]);
            
            await _addToSyncQueue(txn, 'product_batches', item.batchId!, 'UPDATE');
            
            // Log Batch History
            await txn.insert('batch_stock_history', {
              'branch_id': returnData.branchId,
              'batch_id': item.batchId,
              'product_id': item.productId,
              'quantity_change': item.quantity,
              'type': 'return',
              'reference_id': returnId,
              'employee_id': returnData.employeeId,
              'notes': 'Return #${returnData.saleId}',
              'created_at': DateTime.now().toIso8601String(),
            });
            await _addToSyncQueue(txn, 'batch_stock_history', item.batchId!, 'INSERT');
          }

          // Log General Stock History
          await txn.insert('stock_history', {
            'branch_id': returnData.branchId,
            'product_id': item.productId,
            'quantity_change': item.quantity,
            'type': 'return',
            'reference_id': returnId,
            'employee_id': returnData.employeeId,
            'notes': 'Return #${returnData.saleId}',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 3. Handle Refund (Credit)
      if (returnData.refundType == 'credit') {
        // Find customer linked to sale
        final List<Map<String, dynamic>> sale = await txn.query(
          'sales',
          columns: ['customer_id'],
          where: 'id = ?',
          whereArgs: [returnData.saleId],
        );

        if (sale.isNotEmpty && sale.first['customer_id'] != null) {
          final customerId = sale.first['customer_id'] as int;
          
          // Reduce Total Debt (Refund = Payment essentially)
          await txn.rawUpdate('''
            UPDATE customers 
            SET total_debt = total_debt - ?, updated_at = ?, synced = 0
            WHERE id = ?
          ''', [returnData.refundAmount, DateTime.now().toIso8601String(), customerId]);
           
          await _addToSyncQueue(txn, 'customers', customerId, 'UPDATE');

          final paymentId = await txn.insert('customer_payments', {
            'customer_id': customerId,
            'amount': returnData.refundAmount,
            'payment_date': DateTime.now().toIso8601String(),
            'note': 'Refund for Sale #${returnData.saleId}',
            'synced': 0,
          });
          
          await _addToSyncQueue(txn, 'customer_payments', paymentId, 'INSERT');
        }
      }
      
      await _addToSyncQueue(txn, 'sales_returns', returnId, 'INSERT');
    });
  }
  
  // Helper to add to sync queue within transaction
  Future<void> _addToSyncQueue(Transaction txn, String table, int id, String op) async {
    await txn.insert('sync_queue', {
      'table_name': table,
      'record_id': id,
      'operation': op,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  // Get Returns for a specific sale
  Future<List<SalesReturn>> getReturnsForSale(int saleId, int branchId) async {
    final db = await _dbService.database;
    final res = await db.query(
      'sales_returns',
      where: 'sale_id = ? AND branch_id = ?',
      whereArgs: [saleId, branchId],
    );
    return res.map((e) => SalesReturn.fromMap(e)).toList();
  }
}
