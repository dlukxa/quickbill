import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../services/database_service.dart';

/// Helper class to seed the database with sample data for testing
class DataSeeder {
  static Future<void> seedSampleProducts() async {
    final db = DatabaseService.instance;
    
    // Check if products already exist (using default branch ID: 1)
    final existing = await db.getAllProducts(1);
    if (existing.isNotEmpty) {
      debugPrint('Database already has ${existing.length} products. Skipping seed.');
      return;
    }
    
    // Sample products
    final sampleProducts = [
      Product(
        name: 'Rice (1kg)',
        baseBarcode: '8901234567890',
        price: 60.00,
        costPrice: 45.00,
        stock: 50,
        minStock: 10,
        category: 'Rice & Grains',
      ),
      Product(
        name: 'Milk (1L)',
        baseBarcode: '8901234567891',
        price: 50.00,
        costPrice: 40.00,
        stock: 30,
        minStock: 10,
        category: 'Beverages',
      ),
      Product(
        name: 'Bread',
        baseBarcode: '8901234567892',
        price: 40.00,
        costPrice: 30.00,
        stock: 20,
        minStock: 5,
        category: 'Snacks & Biscuits',
      ),
      Product(
        name: 'Coca Cola (500ml)',
        baseBarcode: '8901234567893',
        price: 40.00,
        costPrice: 30.00,
        stock: 100,
        minStock: 20,
        category: 'Beverages',
      ),
      Product(
        name: 'Water Bottle (1L)',
        baseBarcode: '8901234567894',
        price: 20.00,
        costPrice: 15.00,
        stock: 200,
        minStock: 50,
        category: 'Beverages',
      ),
      Product(
        name: 'Chips (50g)',
        baseBarcode: '8901234567895',
        price: 10.00,
        costPrice: 7.00,
        stock: 150,
        minStock: 30,
        category: 'Snacks & Biscuits',
      ),
      Product(
        name: 'Biscuits',
        baseBarcode: '8901234567896',
        price: 30.00,
        costPrice: 22.00,
        stock: 80,
        minStock: 20,
        category: 'Snacks & Biscuits',
      ),
      Product(
        name: 'Shampoo (200ml)',
        baseBarcode: '8901234567897',
        price: 150.00,
        costPrice: 120.00,
        stock: 15,
        minStock: 5,
        category: 'Personal Care',
      ),
      Product(
        name: 'Soap',
        baseBarcode: '8901234567898',
        price: 35.00,
        costPrice: 25.00,
        stock: 60,
        minStock: 15,
        category: 'Personal Care',
      ),
      Product(
        name: 'Detergent (1kg)',
        baseBarcode: '8901234567899',
        price: 200.00,
        costPrice: 160.00,
        stock: 25,
        minStock: 10,
        category: 'Household Cleaning',
      ),
      // Add a few low stock items for testing
      Product(
        name: 'Sugar (1kg)',
        price: 45.00,
        costPrice: 35.00,
        stock: 5,
        minStock: 10,
        category: 'Spices & Seasonings',
      ),
      Product(
        name: 'Tea Powder (250g)',
        price: 120.00,
        costPrice: 95.00,
        stock: 3,
        minStock: 10,
        category: 'Beverages',
      ),
    ];
    
    // Insert all products
    for (final product in sampleProducts) {
      await db.insertProduct(product);
    }
    
    // Seed a product with specific batches for testing
    final biscuitId = await db.insertProduct(Product(
      name: 'Parle-G Biscuits',
      baseBarcode: 'biscuit_base',
      price: 10.00,
      costPrice: 7.00,
      stock: 100,
      minStock: 20,
      category: 'Snacks & Biscuits',
      trackBatches: true,
    ));

    await db.addProductBatch(ProductBatch(
      productId: biscuitId,
      batchNumber: 'BATCH-001',
      barcode: 'biscuit_batch_1',
      stock: 50,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      notes: 'Standard batch',
    ));

    await db.addProductBatch(ProductBatch(
      productId: biscuitId,
      batchNumber: 'BATCH-002',
      barcode: 'biscuit_batch_2',
      stock: 50,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      notes: 'Low sugar batch',
    ));


    
    debugPrint('✅ Seeded ${sampleProducts.length + 1} sample products and batches');
  }
}
