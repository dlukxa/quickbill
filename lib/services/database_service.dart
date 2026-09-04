import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/appointment.dart';
import '../models/custom_order.dart';
import '../models/custom_order_item.dart';
import '../models/staff_availability.dart';
import '../models/purchase_item.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/customer_payment.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/stock_history.dart';
import '../models/branch.dart';
import '../models/discount.dart';
import '../models/service.dart';
import '../models/price_history.dart';
import 'sinhala_search_service.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._init();
  static final Map<String, List<String>> _tableColumnsCache = {};

  DatabaseService._init();

  /// Generates a globally unique 64-bit integer ID based on timestamp and randomness.
  /// Format: (millisecondsSinceEpoch * 10000) + random(0-9999).
  /// The wider random range (10,000) reduces same-millisecond collision probability
  /// across multiple POS devices from 1-in-100 to 1-in-10,000.
  /// This prevents ID collisions across multiple devices that would otherwise
  /// overwrite each other in Firestore when using SQLite's AUTOINCREMENT IDs.
  static int generateUniqueId() {
    return (DateTime.now().millisecondsSinceEpoch * 10000) + _random.nextInt(10000);
  }

  static final _random = Random();

  /// List of tables that sync to the cloud where we MUST guarantee unique IDs
  static const List<String> _syncedTables = [
    'branches',
    'employees',
    'products',
    'product_batches',
    'sales',
    'customers',
    'customer_payments',
    'expenses',
    'purchases',
    'purchase_items',
    'suppliers',
    'sales_returns',
    'sales_return_items',
    'stock_history',
    'batch_stock_history',
    'employee_shifts',
    'discounts',
    'package_items', // NEW
    'price_history', // NEW: Daily price change log
  ];

  /// Intercepts insert operations to securely inject globally unique IDs
  /// for tables that sync to Firestore, bypassing native AUTOINCREMENT collisions.
  Future<int> _insertWithId(DatabaseExecutor executor, String table, Map<String, dynamic> data, {ConflictAlgorithm? conflictAlgorithm}) async {
    // Sanitize data (convert Timestamps to strings for SQLite)
    var mutableData = _sanitizeData(data);
    
    // Check if this is a table we sync to the cloud
    if (_syncedTables.contains(table)) {
      // Inject our globally unique time-based ID if one isn't already provided (e.g., from restoreRecord)
      if (!mutableData.containsKey('id') || mutableData['id'] == null) {
        mutableData['id'] = generateUniqueId();
      }
    }

    try {
      final cols = await getTableColumns(table, executor);
      if (cols.isNotEmpty) {
        mutableData.removeWhere((key, value) => !cols.contains(key));
      }
      return await executor.insert(table, mutableData, conflictAlgorithm: conflictAlgorithm);
    } catch (e) {
      if (e.toString().contains('no such table: $table') || e.toString().contains('no such table: price_history')) {
        debugPrint('🔧 Missing table detected during insert into $table. Auto-creating table...');
        if (table == 'price_history') {
          await executor.execute('''
            CREATE TABLE IF NOT EXISTS price_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER NOT NULL,
              branch_id INTEGER NOT NULL DEFAULT 1,
              old_price REAL NOT NULL,
              new_price REAL NOT NULL,
              old_cost_price REAL,
              new_cost_price REAL,
              old_unit TEXT,
              new_unit TEXT,
              reason TEXT,
              changed_by TEXT,
              created_at TEXT NOT NULL,
              synced INTEGER DEFAULT 0,
              deleted INTEGER DEFAULT 0,
              FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
            )
          ''');
          _tableColumnsCache.remove(table);
          final cols = await getTableColumns(table, executor);
          if (cols.isNotEmpty) {
            mutableData.removeWhere((key, value) => !cols.contains(key));
          }
          return await executor.insert(table, mutableData, conflictAlgorithm: conflictAlgorithm);
        }
      }
      if (e.toString().contains('no column named')) {
        debugPrint('⚠️ Missing column detected during insert into $table: $e.');
        _tableColumnsCache.remove(table);
        final cols = await getTableColumns(table, executor);
        if (cols.isNotEmpty) {
          mutableData.removeWhere((key, value) => !cols.contains(key));
        }
        return await executor.insert(table, mutableData, conflictAlgorithm: conflictAlgorithm);
      }
      rethrow;
    }
  }

  /// Safely insert or update a barcode lookup entry to avoid UNIQUE constraint violations.
  Future<void> _safeSetBarcodeLookup(DatabaseExecutor executor, String barcode, int productId, int? batchId) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      if (batchId != null) {
        await executor.delete(
          'barcode_lookup',
          where: 'batch_id = ?',
          whereArgs: [batchId],
        );
      }
      return;
    }

    // Check if the barcode already exists in the lookup table
    final existing = await executor.query(
      'barcode_lookup',
      where: 'barcode = ?',
      whereArgs: [trimmed],
      limit: 1,
    );

    if (existing.isEmpty) {
      // Barcode is completely new:
      // If we are updating a batch, it might already have a row with a different barcode,
      // so check if there is an existing row for this batch_id and update it, otherwise insert.
      int updatedRows = 0;
      if (batchId != null) {
        updatedRows = await executor.update(
          'barcode_lookup',
          {
            'barcode': trimmed,
            'product_id': productId,
            'is_primary': 0,
            'created_at': DateTime.now().toIso8601String(),
          },
          where: 'batch_id = ?',
          whereArgs: [batchId],
        );
      }
      if (updatedRows == 0) {
        await _insertWithId(executor, 'barcode_lookup', {
          'barcode': trimmed,
          'product_id': productId,
          'batch_id': batchId,
          'is_primary': batchId == null ? 1 : 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } else {
      // Barcode already exists!
      final existingId = existing.first['id'] as int;
      final existingProductId = existing.first['product_id'] as int;
      final existingBatchId = existing.first['batch_id'] as int?;

      if (existingProductId == productId) {
        // Same product:
        if (existingBatchId == null) {
          // If it was the product's primary barcode mapping, link it to this batch
          await executor.update(
            'barcode_lookup',
            {
              'batch_id': batchId,
              'created_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existingId],
          );
        }
      } else {
        // Different product! Skip to avoid constraint violations and cross-product barcode issues.
        debugPrint("⚠️ Barcode '$trimmed' is already mapped to product ID $existingProductId, skipping lookup insert.");
      }
    }
  }

  /// Recursively converts Firestore Timestamps to ISO 8601 strings for SQLite storage.
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final Map<String, dynamic> sanitized = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeData(value);
      } else if (value is List) {
        sanitized[key] = value.map((e) {
          if (e is Map<String, dynamic>) return _sanitizeData(e);
          if (e is Timestamp) return e.toDate().toIso8601String();
          if (e is bool) return e ? 1 : 0;
          return e;
        }).toList();
      } else if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  static Future<Database>? _initDbFuture;
  static bool _integrityChecked = false;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      if (!_integrityChecked) {
        _integrityChecked = true;
        await _ensureSchemaIntegrity(_database!);
      }
      return _database!;
    }
    
    if (_initDbFuture != null) {
      final db = await _initDbFuture!;
      if (db.isOpen) {
        _database = db;
        if (!_integrityChecked) {
          _integrityChecked = true;
          await _ensureSchemaIntegrity(_database!);
        }
        return db;
      } else {
        // The cached future contains a closed database (can happen during hot reload after restore)
        _initDbFuture = null;
      }
    }
    
    _initDbFuture = _initDatabase();
    _database = await _initDbFuture!;
    _integrityChecked = true;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      if (Platform.isWindows) {
        try {
          open.overrideFor(OperatingSystem.windows, () {
            final exeDir = File(Platform.resolvedExecutable).parent.path;
            final localDll = File('$exeDir\\sqlite3.dll');
            if (localDll.existsSync()) {
              return DynamicLibrary.open(localDll.path);
            }
            return DynamicLibrary.open('sqlite3.dll');
          });
        } catch (e) {
          debugPrint('DatabaseService: open.overrideFor notice: $e');
        }
      }
      databaseFactory = databaseFactoryFfi;
      try {
        sqfliteFfiInit();
      } catch (e) {
        debugPrint('DatabaseService: sqfliteFfiInit notice: $e');
      }
    }
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, 'quickbill.db');

    return await openDatabase(
      path,
      version: 29,  // Bumped to 29 for Sinhala/Singlish search fields (name_sinhala, name_english, search_aliases, normalized_terms)
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode=WAL;');
        } catch (e) {
          debugPrint('DatabaseService: Failed to enable WAL mode: $e');
        }
        // Enable Foreign Key enforcement — SQLite does NOT enforce them by default.
        // Without this, child records can reference non-existent parent IDs,
        // creating orphaned data that corrupts reports and analytics.
        try {
          await db.execute('PRAGMA foreign_keys = ON;');
        } catch (e) {
          debugPrint('DatabaseService: Failed to enable foreign keys: $e');
        }
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Run a quick integrity check on startup to detect corruption early.
        // This catches damage from battery death, OS force-kills, or storage errors
        // before the app silently operates on corrupted data.
        try {
          final result = await db.rawQuery('PRAGMA quick_check;');
          final status = result.first.values.first as String;
          if (status != 'ok') {
            debugPrint('⚠️ DATABASE INTEGRITY WARNING: $result');
          } else {
            debugPrint('✅ Database integrity check passed.');
          }
        } catch (e) {
          debugPrint('⚠️ Database integrity check failed: $e');
        }

        // Self-healing check: ensure all expected table columns exist
        await _ensureSchemaIntegrity(db);

        // Fix SQLite Foreign Key constraint for services (which use product_id = 999999999)
        try {
          await db.execute('''
            INSERT OR IGNORE INTO products 
            (id, branch_id, name, price, created_at, updated_at, deleted, synced) 
            VALUES 
            (999999999, 1, 'System Service Placeholder', 0, '${DateTime.now().toIso8601String()}', '${DateTime.now().toIso8601String()}', 1, 1)
          ''');
        } catch (e) {
          debugPrint('⚠️ Failed to insert dummy product for services: $e');
        }

        // AUTO-HEAL: If we have an authenticated user but zero products,
        // the database is likely empty from a failed sync (boolean corruption).
        // Clear last_pull_timestamp so the next sync downloads everything.
        try {
          final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM products WHERE deleted = 0'),
          ) ?? 0;
          if (count == 0) {
            final prefs = await SharedPreferences.getInstance();
            final hadTimestamp = prefs.getString('last_pull_timestamp');
            if (hadTimestamp != null) {
              await prefs.remove('last_pull_timestamp');
              debugPrint('🔄 AUTO-HEAL: Products table empty, cleared last_pull_timestamp to force full re-sync.');
            }
          }
        } catch (e) {
          debugPrint('Auto-heal check error (non-fatal): $e');
        }
      },
    );
  }

  /// Wipe all data from all tables.
  /// IMPORTANT: Delete child tables first to respect foreign key constraints,
  /// then delete parent tables. This prevents FK violation errors.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Child/junction tables first (they reference parent tables via FK)
      await txn.delete('sale_items');
      await txn.delete('sales_return_items');
      await txn.delete('purchase_items');
      await txn.delete('package_items');
      await txn.delete('customer_payments');
      await txn.delete('barcode_lookup');
      await txn.delete('batch_stock_history');
      await txn.delete('stock_history');
      await txn.delete('employee_shifts');
      // Parent tables
      await txn.delete('sales_returns');
      await txn.delete('sales');
      await txn.delete('purchases');
      await txn.delete('expenses');
      await txn.delete('discounts');
      await txn.delete('product_batches');
      await txn.delete('products');
      await txn.delete('customers');
      await txn.delete('suppliers');
      await txn.delete('employees');
      await txn.delete('branches');
      // System tables
      await txn.delete('sync_queue');
      debugPrint('🗑️ All 21 database tables cleared.');
    });
    
    // Also clear the last sync timestamp so the next sync pulls everything from scratch
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_pull_timestamp');
      debugPrint('🗑️ Cleared last_pull_timestamp from SharedPreferences.');
    } catch (e) {
      debugPrint('Error clearing last_pull_timestamp: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sync queue table first to allow seeding other tables to log to it
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)');

    // Branches table
    await db.execute('''
      CREATE TABLE branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        business_type TEXT,
        operating_hours TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0
      )
    ''');

    // Seed default branch
    final String timestamp = DateTime.now().toIso8601String();
    await _insertWithId(db, 'branches', {
      'id': 1,
      'name': 'Main Branch',
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        name_sinhala TEXT,
        name_english TEXT,
        search_aliases TEXT,
        normalized_terms TEXT,
        base_barcode TEXT,
        price REAL NOT NULL,
        cost_price REAL,
        stock REAL NOT NULL DEFAULT 0.0,
        min_stock REAL DEFAULT 10.0,
        category TEXT,
        unit TEXT DEFAULT 'pcs',
        type TEXT DEFAULT 'product',
        image_url TEXT,
        track_batches INTEGER DEFAULT 0,
        supplier_id INTEGER REFERENCES suppliers(id),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');

    // Product Batches table
    await db.execute('''
      CREATE TABLE product_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        batch_number TEXT NOT NULL,
        barcode TEXT UNIQUE NOT NULL,
        factory_location TEXT,
        supplier_name TEXT,
        production_date TEXT,
        expiry_date TEXT,
        purchase_date TEXT,
        purchase_price REAL,
        stock REAL NOT NULL DEFAULT 0.0,
        initial_stock REAL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    // Barcode Lookup table
    await db.execute('''
      CREATE TABLE barcode_lookup (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER,
        is_primary INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (batch_id) REFERENCES product_batches(id)
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        bill_number TEXT UNIQUE NOT NULL,
        total REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        service_charge REAL DEFAULT 0.0,
        items_count INTEGER,
        payment_method TEXT DEFAULT 'cash',
        customer_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        notes TEXT,
        employee_id INTEGER,
        cashier_name TEXT,
        appointment_id INTEGER,
        custom_order_id INTEGER,
        created_at TEXT NOT NULL,
        server_timestamp TEXT,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');

    // Sale items table (with batch support)
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER,
        item_type TEXT DEFAULT 'product',
        service_id INTEGER,
        product_name TEXT NOT NULL,
        batch_number TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (batch_id) REFERENCES product_batches(id)
      )
    ''');

    // Stock history table (original)
    await db.execute('''
      CREATE TABLE stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        quantity_change REAL NOT NULL,
        type TEXT NOT NULL,
        reference_id INTEGER,
        employee_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
 
    // Employees table
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        permissions TEXT,
        staff_id TEXT,
        must_change_password INTEGER DEFAULT 0,
        last_device_id TEXT,
        skill_service_ids TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');
    
    // Seed initial admin if not exists
    final adminCheck = await db.query('employees', where: 'id = ?', whereArgs: [1]);
    if (adminCheck.isEmpty) {
      final String timestamp = DateTime.now().toIso8601String();
      await _insertWithId(db, 'employees', {
        'id': 1,
        'name': 'Shop Owner',
        'pin': '1234', // Default, should be changed
        'role': 'owner',
        'status': 'active',
        'permissions': null, // Owner has full permissions
        'created_at': timestamp,
        'updated_at': timestamp,
        'synced': 0,
        'deleted': 0
      });
      // Register with sync queue
      await _insertWithId(db, 'sync_queue', {
        'table_name': 'employees',
        'record_id': 1,
        'operation': 'INSERT',
        'created_at': timestamp,
        'synced': 0,
      });
    }

    // Employee Shifts table
    await db.execute('''
      CREATE TABLE employee_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        clock_in TEXT NOT NULL,
        clock_out TEXT,
        sales_count INTEGER DEFAULT 0,
        sales_total REAL DEFAULT 0,
        cash_collected REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees(id)
      )
    ''');
 
    // Batch Stock history table
    await db.execute('''
      CREATE TABLE batch_stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        batch_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity_change REAL NOT NULL,
        type TEXT NOT NULL,
        reference_id INTEGER,
        employee_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (batch_id) REFERENCES product_batches(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');


    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        total_debt REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');

    // Customer payments table
    await db.execute('''
      CREATE TABLE customer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        note TEXT,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');

    // Suppliers table
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        category TEXT,
        notes TEXT,
        provided_items TEXT,
        total_pending REAL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )''');

    // Purchases table
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        supplier_id INTEGER REFERENCES suppliers(id),
        total_amount REAL NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        employee_id INTEGER,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )''');

    // Purchase Items table
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER REFERENCES purchases(id),
        product_id INTEGER REFERENCES products(id),
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        cost_price REAL NOT NULL,
        batch_number TEXT,
        expiry_date TEXT
      )''');

    // Create indexes
    await db.execute('CREATE INDEX idx_products_base_barcode ON products(base_barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products(name COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_products_category ON products(category)');
    await db.execute('CREATE INDEX idx_products_track_batches ON products(track_batches)');
    await db.execute('CREATE INDEX idx_products_synced ON products(synced)');
    await db.execute('CREATE INDEX idx_product_batches_product_id ON product_batches(product_id)');
    await db.execute('CREATE INDEX idx_product_batches_barcode ON product_batches(barcode)');
    await db.execute('CREATE INDEX idx_product_batches_expiry ON product_batches(expiry_date)');
    await db.execute('CREATE INDEX idx_barcode_lookup_barcode ON barcode_lookup(barcode)');
    await db.execute('CREATE INDEX idx_barcode_lookup_product_id ON barcode_lookup(product_id)');
    await db.execute('CREATE INDEX idx_sales_created_at ON sales(created_at)');
    await db.execute('CREATE INDEX idx_sales_synced ON sales(synced)');
    await db.execute('CREATE INDEX idx_product_batches_synced ON product_batches(synced)');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)');
    await db.execute('CREATE INDEX idx_sale_items_batch_id ON sale_items(batch_id)');
    await db.execute('CREATE INDEX idx_stock_history_product_id ON stock_history(product_id)');
    await db.execute('CREATE INDEX idx_batch_stock_history_batch_id ON batch_stock_history(batch_id)');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_customers_synced ON customers(synced)');
    await db.execute('CREATE INDEX idx_customer_payments_customer_id ON customer_payments(customer_id)');
    await db.execute('CREATE INDEX idx_sales_customer_id ON sales(customer_id)');
    await db.execute('CREATE INDEX idx_suppliers_name ON suppliers(name)');
    await db.execute('CREATE INDEX idx_purchases_supplier_id ON purchases(supplier_id)');
    await db.execute('CREATE INDEX idx_purchase_items_purchase_id ON purchase_items(purchase_id)');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        employee_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');

    // Sales Returns table
    await db.execute('''
      CREATE TABLE sales_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        sale_id INTEGER NOT NULL,
        return_date TEXT NOT NULL,
        refund_amount REAL NOT NULL,
        refund_type TEXT NOT NULL,
        reason TEXT,
        employee_id INTEGER,
        synced INTEGER DEFAULT 0,
        server_timestamp TEXT,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');

    // Sales Return Items table
    await db.execute('''
      CREATE TABLE sales_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_id INTEGER,
        quantity REAL NOT NULL,
        refund_amount REAL NOT NULL,
        condition TEXT NOT NULL,
        FOREIGN KEY (return_id) REFERENCES sales_returns(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (batch_id) REFERENCES product_batches(id)
      )
    ''');
    
    
    await db.execute('CREATE INDEX idx_sales_returns_sale_id ON sales_returns(sale_id)');
    await db.execute('CREATE INDEX idx_sales_return_items_return_id ON sales_return_items(return_id)');

    // Package Items table
    await db.execute('''
      CREATE TABLE package_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_id INTEGER NOT NULL,
        component_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (package_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (component_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_package_items_package_id ON package_items(package_id)');

    // Discounts table
    await db.execute('''
      CREATE TABLE discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER,
        category TEXT,
        discount_value REAL NOT NULL,
        discount_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_clearance INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_discounts_product_id ON discounts(product_id)');
    await db.execute('CREATE INDEX idx_discounts_dates ON discounts(start_date, end_date)');

    // New Multi-Vertical Tables
    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        category TEXT,
        price REAL NOT NULL,
        duration_minutes INTEGER DEFAULT 30,
        requires_booking INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER,
        employee_id INTEGER,
        service_ids TEXT NOT NULL,
        scheduled_start TEXT NOT NULL,
        scheduled_end TEXT NOT NULL,
        status TEXT DEFAULT 'booked',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (employee_id) REFERENCES employees(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE staff_availability (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT,
        end_time TEXT,
        is_off_day INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER NOT NULL DEFAULT 1,
        customer_id INTEGER,
        due_date TEXT NOT NULL,
        deposit_amount REAL DEFAULT 0,
        deposit_paid INTEGER DEFAULT 0,
        total_amount REAL NOT NULL,
        status TEXT DEFAULT 'placed',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES custom_orders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE price_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        branch_id INTEGER NOT NULL DEFAULT 1,
        old_price REAL NOT NULL,
        new_price REAL NOT NULL,
        old_cost_price REAL,
        new_cost_price REAL,
        old_unit TEXT,
        new_unit TEXT,
        reason TEXT,
        changed_by TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 29) {
      debugPrint('🚀 Migrating to Database v29: Adding Sinhala, English, and Search Aliases columns to products table');
      try {
        await db.execute('ALTER TABLE products ADD COLUMN name_sinhala TEXT');
      } catch (e) {
        debugPrint('⚠️ products.name_sinhala may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE products ADD COLUMN name_english TEXT');
      } catch (e) {
        debugPrint('⚠️ products.name_english may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE products ADD COLUMN search_aliases TEXT');
      } catch (e) {
        debugPrint('⚠️ products.search_aliases may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE products ADD COLUMN normalized_terms TEXT');
      } catch (e) {
        debugPrint('⚠️ products.normalized_terms may already exist: $e');
      }
    }

    if (oldVersion < 28) {
      debugPrint('🚀 Migrating to Database v28: Adding missing schema columns');
      
      // Products table
      try {
        await db.execute("ALTER TABLE products ADD COLUMN type TEXT DEFAULT 'product'");
      } catch (e) {
        debugPrint('⚠️ products.type may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE products ADD COLUMN image_url TEXT');
      } catch (e) {
        debugPrint('⚠️ products.image_url may already exist: $e');
      }

      // Employees table
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN staff_id TEXT');
      } catch (e) {
        debugPrint('⚠️ employees.staff_id may already exist: $e');
      }
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN must_change_password INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('⚠️ employees.must_change_password may already exist: $e');
      }

      // Purchases table
      try {
        await db.execute('ALTER TABLE purchases ADD COLUMN employee_id INTEGER');
      } catch (e) {
        debugPrint('⚠️ purchases.employee_id may already exist: $e');
      }
    }

    if (oldVersion < 27) {
      // Force a full re-sync for devices that ran the v26 migration
      // but didn't get the last_pull_timestamp clear.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_pull_timestamp');
        debugPrint('✅ Migration v27: Cleared last_pull_timestamp to force full re-sync.');
      } catch (e) {
        debugPrint('Migration v27: Error clearing last_pull_timestamp: $e');
      }
    }

    if (oldVersion < 26) {
      // Fix corrupted boolean values stored as strings 'false' and 'true'
      final tables = await db.query('sqlite_master', columns: ['name'], where: 'type = ?', whereArgs: ['table']);
      for (final table in tables) {
        final tableName = table['name'] as String;
        if (tableName.startsWith('sqlite_')) continue;
        try {
          final columns = await getTableColumns(tableName, db);
          
          if (columns.contains('deleted')) {
            await db.execute("UPDATE $tableName SET deleted = 0 WHERE deleted = 'false'");
            await db.execute("UPDATE $tableName SET deleted = 1 WHERE deleted = 'true'");
          }
          if (columns.contains('synced')) {
            await db.execute("UPDATE $tableName SET synced = 0 WHERE synced = 'false'");
            await db.execute("UPDATE $tableName SET synced = 1 WHERE synced = 'true'");
          }
          if (columns.contains('track_batches')) {
            await db.execute("UPDATE $tableName SET track_batches = 0 WHERE track_batches = 'false'");
            await db.execute("UPDATE $tableName SET track_batches = 1 WHERE track_batches = 'true'");
          }
          if (columns.contains('is_active')) {
            await db.execute("UPDATE $tableName SET is_active = 0 WHERE is_active = 'false'");
            await db.execute("UPDATE $tableName SET is_active = 1 WHERE is_active = 'true'");
          }
        } catch (e) {
          debugPrint('Migration error for table $tableName: $e');
        }
      }

      // Force a full re-sync from cloud.
      // Records may have been silently dropped during previous syncs because
      // boolean values from Firestore caused SQLite insert failures.
      // Clearing last_pull_timestamp ensures the next sync re-downloads everything
      // with the corrected bool→int conversion now in place.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_pull_timestamp');
        debugPrint('✅ Migration v26: Cleared last_pull_timestamp to force full re-sync.');
      } catch (e) {
        debugPrint('Migration v26: Error clearing last_pull_timestamp: $e');
      }
    }

    if (oldVersion < 2) {
      // Add batch tracking support to existing database
      
      // Add new columns to products table
      await db.execute('ALTER TABLE products ADD COLUMN unit TEXT DEFAULT "pcs"');
      await db.execute('ALTER TABLE products ADD COLUMN track_batches INTEGER DEFAULT 0');
      
      // Rename barcode to base_barcode
      await db.execute('ALTER TABLE products RENAME COLUMN barcode TO base_barcode');
      
      // Create new batch tables
      await db.execute('''
        CREATE TABLE product_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          batch_number TEXT NOT NULL,
          barcode TEXT UNIQUE NOT NULL,
          factory_location TEXT,
          supplier_name TEXT,
          production_date TEXT,
          expiry_date TEXT,
          purchase_date TEXT,
          purchase_price REAL,
          stock INTEGER NOT NULL DEFAULT 0,
          initial_stock INTEGER,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE barcode_lookup (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          barcode TEXT UNIQUE NOT NULL,
          product_id INTEGER NOT NULL,
          batch_id INTEGER,
          is_primary INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (product_id) REFERENCES products(id),
          FOREIGN KEY (batch_id) REFERENCES product_batches(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE batch_stock_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          batch_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity_change INTEGER NOT NULL,
          type TEXT NOT NULL,
          reference_id INTEGER,
          notes TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (batch_id) REFERENCES product_batches(id),
          FOREIGN KEY (product_id) REFERENCES products(id)
        )
      ''');

      // Add batch columns to sale_items
      await db.execute('ALTER TABLE sale_items ADD COLUMN batch_id INTEGER');
      await db.execute('ALTER TABLE sale_items ADD COLUMN batch_number TEXT');

      // Migrate existing barcodes to barcode_lookup table
      final products = await db.query('products', where: 'base_barcode IS NOT NULL AND base_barcode != ""');
      for (var product in products) {
        await _insertWithId(db, 'barcode_lookup', {
          'barcode': product['base_barcode'],
          'product_id': product['id'],
          'batch_id': null,
          'is_primary': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Create new indexes
      await db.execute('CREATE INDEX idx_products_track_batches ON products(track_batches)');
      await db.execute('CREATE INDEX idx_product_batches_product_id ON product_batches(product_id)');
      await db.execute('CREATE INDEX idx_product_batches_barcode ON product_batches(barcode)');
      await db.execute('CREATE INDEX idx_product_batches_expiry ON product_batches(expiry_date)');
      await db.execute('CREATE INDEX idx_barcode_lookup_barcode ON barcode_lookup(barcode)');
      await db.execute('CREATE INDEX idx_barcode_lookup_product_id ON barcode_lookup(product_id)');
      await db.execute('CREATE INDEX idx_sale_items_batch_id ON sale_items(batch_id)');
      await db.execute('CREATE INDEX idx_batch_stock_history_batch_id ON batch_stock_history(batch_id)');
    }

    if (oldVersion < 3) {
      // Add customer management support
      
      // Create customers table
      await db.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          total_debt REAL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''');

      // Create customer payments table
      await db.execute('''
        CREATE TABLE customer_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          note TEXT,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
        )
      ''');

      // Add customer_id to sales table
      await db.execute('ALTER TABLE sales ADD COLUMN customer_id INTEGER');

      // Create indexes for customer tables
      await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
      await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
      await db.execute('CREATE INDEX idx_customer_payments_customer_id ON customer_payments(customer_id)');
      await db.execute('CREATE INDEX idx_sales_customer_id ON sales(customer_id)');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          category TEXT,
          notes TEXT,
          provided_items TEXT,
          total_pending REAL DEFAULT 0.0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )''');

      await db.execute('''
        CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplier_id INTEGER REFERENCES suppliers(id),
          total_amount REAL NOT NULL,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          notes TEXT,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )''');

      await db.execute('''
        CREATE TABLE purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER REFERENCES purchases(id),
          product_id INTEGER REFERENCES products(id),
          product_name TEXT NOT NULL,
          quantity REAL NOT NULL,
          cost_price REAL NOT NULL,
          batch_number TEXT,
          expiry_date TEXT
        )''');

      await db.execute('CREATE INDEX idx_suppliers_name ON suppliers(name)');
      await db.execute('CREATE INDEX idx_purchases_supplier_id ON purchases(supplier_id)');
      await db.execute('CREATE INDEX idx_purchase_items_purchase_id ON purchase_items(purchase_id)');
    }

    if (oldVersion < 5) {
      // Add cost_price to sale_items for historical profit tracking
      await db.execute('ALTER TABLE sale_items ADD COLUMN cost_price REAL DEFAULT 0.0');
    }

    if (oldVersion < 6) {
      // Create employees table
      await db.execute('''
        CREATE TABLE employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'cashier',
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''');
      
      // Seed initial admin
      await _insertWithId(db, 'employees', {
        'name': 'Shop Owner',
        'pin': '1234',
        'role': 'admin',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (oldVersion < 7) {
      // Add employee tracking to sales and stock history
      await db.execute('ALTER TABLE sales ADD COLUMN employee_id INTEGER');
      await db.execute('ALTER TABLE stock_history ADD COLUMN employee_id INTEGER');
      await db.execute('ALTER TABLE batch_stock_history ADD COLUMN employee_id INTEGER');
      
      // Create index for performance
      await db.execute('CREATE INDEX idx_sales_employee_id ON sales(employee_id)');
    }

    if (oldVersion < 8) {
      // Phase 24: Bulk & Fractional Inventory Support
      // SQLite handles INTEGER to REAL transition naturally for existing columns.
      // We primarily need the version bump to ensure new installs get the REAL type 
      // and app code treats these values as doubles.
      // No explicit ALTER TABLE needed as SQLite dynamic typing allows REAL in INTEGER columns.
      debugPrint('🚀 Migrating to Database v8: Fractional Stock Support enabled.');
    }

    if (oldVersion < 9) {
      // Phase 25: Returns & Refunds
      await db.execute('''
        CREATE TABLE sales_returns (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          return_date TEXT NOT NULL,
          refund_amount REAL NOT NULL,
          refund_type TEXT NOT NULL,
          reason TEXT,
          employee_id INTEGER,
          synced INTEGER DEFAULT 0,
          server_timestamp TEXT,
          FOREIGN KEY (sale_id) REFERENCES sales(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE sales_return_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          return_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          batch_id INTEGER,
          quantity REAL NOT NULL,
          refund_amount REAL NOT NULL,
          condition TEXT NOT NULL,
          FOREIGN KEY (return_id) REFERENCES sales_returns(id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products(id),
          FOREIGN KEY (batch_id) REFERENCES product_batches(id)
        )
      ''');
      
      await db.execute('CREATE INDEX idx_sales_returns_sale_id ON sales_returns(sale_id)');
      await db.execute('CREATE INDEX idx_sales_return_items_return_id ON sales_return_items(return_id)');
      
      debugPrint('🚀 Migrating to Database v9: Returns & Refunds tables created.');
    }

    if (oldVersion < 11) {
      // Fix missing columns that were accidentally omitted from onCreate or previous milestones
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN discount REAL DEFAULT 0.0');
      } catch (e) {
        debugPrint('⚠️ sale_items.discount already exists: $e');
      }
      
      try {
        await db.execute('ALTER TABLE batch_stock_history ADD COLUMN employee_id INTEGER');
      } catch (e) {
        debugPrint('⚠️ batch_stock_history.employee_id already exists: $e');
      }
      
      debugPrint('🚀 Migrating to Database v11: Schema corrections applied.');
    }

    if (oldVersion < 12) {
      // Phase 1: Multi-User System
      
      // Add permissions and updated_at to employees
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN permissions TEXT');
        await db.execute('ALTER TABLE employees ADD COLUMN updated_at TEXT');
        await db.execute("ALTER TABLE employees ADD COLUMN status TEXT DEFAULT 'active'");
      } catch (e) {
        debugPrint('⚠️ Error altering employees table: $e');
      }

      // Migrate is_active to status
      try {
        await db.rawUpdate("UPDATE employees SET status = 'active' WHERE is_active = 1");
        await db.rawUpdate("UPDATE employees SET status = 'inactive' WHERE is_active = 0");
      } catch (e) {
        debugPrint('⚠️ Error migrating is_active: $e');
      }

      // Create employee_shifts table
      await db.execute('''
        CREATE TABLE employee_shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          clock_in TEXT NOT NULL,
          clock_out TEXT,
          sales_count INTEGER DEFAULT 0,
          sales_total REAL DEFAULT 0,
          cash_collected REAL DEFAULT 0,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (employee_id) REFERENCES employees(id)
        )
      ''');

      // Update existing admin role to 'owner' if needed
      try {
        await db.rawUpdate("UPDATE employees SET role = 'owner' WHERE role = 'admin'");
      } catch (e) {
        debugPrint('⚠️ Error updating roles: $e');
      }
      
      debugPrint('🚀 Migrating to Database v12: Multi-User System tables created.');
    }

    if (oldVersion < 13) {
      // Phase: Multi-Branch System
      
      // 1. Create branches table
      await db.execute('''
        CREATE TABLE branches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          address TEXT,
          phone TEXT,
          business_type TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''');

      // 2. Seed default branch
      final String timestamp = DateTime.now().toIso8601String();
      await _insertWithId(db, 'branches', {
        'id': 1,
        'name': 'Main Branch',
        'is_active': 1,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      // 3. Add branch_id to all relevant tables
      final tablesToUpdate = [
        'products', 'employees', 'sales', 'purchases', 
        'expenses', 'customers', 'suppliers', 'product_batches',
        'stock_history', 'batch_stock_history', 'sales_returns'
      ];
      
      for (var table in tablesToUpdate) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN branch_id INTEGER NOT NULL DEFAULT 1');
        } catch (e) {
          debugPrint('⚠️ Error adding branch_id to $table: $e');
        }
      }

      debugPrint('🚀 Migrating to Database v13: Multi-Branch System implemented.');
    }

    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN last_device_id TEXT');
        debugPrint('🚀 Migrating to Database v14: Staff Multi-Device support added.');
      } catch (e) {
        debugPrint('⚠️ Migration error (v14): $e');
      }
    }

    if (oldVersion < 15) {
      try {
        await db.execute('''
          CREATE TABLE discounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            branch_id INTEGER NOT NULL DEFAULT 1,
            product_id INTEGER,
            category TEXT,
            discount_value REAL NOT NULL,
            discount_type TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            is_clearance INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            deleted INTEGER DEFAULT 0,
            FOREIGN KEY (branch_id) REFERENCES branches(id),
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_discounts_product_id ON discounts(product_id)');
        await db.execute('CREATE INDEX idx_discounts_dates ON discounts(start_date, end_date)');
        debugPrint('🚀 Migrating to Database v15: Discounts table created.');
      } catch (e) {
        debugPrint('⚠️ Migration error (v15): $e');
      }
    }

    if (oldVersion < 16) {
      try {
        // Check if table exists before creating
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='discounts'");
        if (tables.isEmpty) {
          await db.execute('''
            CREATE TABLE discounts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              branch_id INTEGER NOT NULL DEFAULT 1,
              product_id INTEGER,
              category TEXT,
              discount_value REAL NOT NULL,
              discount_type TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT NOT NULL,
              is_clearance INTEGER DEFAULT 0,
              is_active INTEGER DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              synced INTEGER DEFAULT 0,
              deleted INTEGER DEFAULT 0,
              FOREIGN KEY (branch_id) REFERENCES branches(id),
              FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('CREATE INDEX idx_discounts_product_id ON discounts(product_id)');
          await db.execute('CREATE INDEX idx_discounts_dates ON discounts(start_date, end_date)');
          debugPrint('🚀 Migrating to Database v16: Discounts table created.');
        } else {
          debugPrint('✅ Database v16: Discounts table already exists.');
        }
      } catch (e) {
        debugPrint('⚠️ Migration error (v16): $e');
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN server_timestamp TEXT');
      } catch (e) {
        debugPrint('⚠️ sales.server_timestamp already exists: $e');
      }
      debugPrint('🚀 Migrating to Database v19: Added server_timestamp to sales table.');
    }
    if (oldVersion < 20) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN service_charge REAL DEFAULT 0.0');
      } catch (e) {
        debugPrint('⚠️ sales.service_charge may already exist: $e');
      }
      
      // Package Items table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS package_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_id INTEGER NOT NULL,
          component_id INTEGER NOT NULL,
          quantity REAL NOT NULL DEFAULT 1.0,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          FOREIGN KEY (package_id) REFERENCES products(id) ON DELETE CASCADE,
          FOREIGN KEY (component_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_package_items_package_id ON package_items(package_id)');
      
      debugPrint('🚀 Migrating to Database v20: Added service_charge, and package_items table.');
    }

    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN supplier_id INTEGER REFERENCES suppliers(id)');
      } catch (e) {
        debugPrint('⚠️ products.supplier_id may already exist: $e');
      }
      debugPrint('🚀 Migrating to Database v21: Added supplier_id to products table.');
    }

    if (oldVersion < 22) {
      try {
        await db.execute('ALTER TABLE sales_returns ADD COLUMN server_timestamp TEXT');
      } catch (e) {
        debugPrint('⚠️ sales_returns.server_timestamp may already exist: $e');
      }
      debugPrint('🚀 Migrating to Database v22: Added server_timestamp to sales_returns table.');
    }

    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN notes TEXT');
      } catch (e) {
        debugPrint('⚠️ suppliers.notes may already exist: $e');
      }
      debugPrint('🚀 Migrating to Database v23: Added notes to suppliers table.');
    }

    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN provided_items TEXT');
      } catch (e) {
        debugPrint('⚠️ suppliers.provided_items may already exist: $e');
      }
      debugPrint('🚀 Migrating to Database v24: Added provided_items to suppliers table.');
    }

    if (oldVersion < 25) {
      debugPrint('🚀 Migrating to Database v25: Multi-Vertical Architecture');
      
      // 1. ALTER existing tables
      try { await db.execute('ALTER TABLE branches ADD COLUMN operating_hours TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE sales ADD COLUMN appointment_id INTEGER'); } catch (e) {}
      try { await db.execute('ALTER TABLE sales ADD COLUMN custom_order_id INTEGER'); } catch (e) {}
      try { await db.execute('ALTER TABLE sales ADD COLUMN cashier_name TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE sale_items ADD COLUMN item_type TEXT DEFAULT "product"'); } catch (e) {}
      try { await db.execute('ALTER TABLE sale_items ADD COLUMN service_id INTEGER'); } catch (e) {}
      try { await db.execute('ALTER TABLE employees ADD COLUMN skill_service_ids TEXT'); } catch (e) {}

      // 2. CREATE new tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS services (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          name TEXT NOT NULL,
          category TEXT,
          price REAL NOT NULL,
          duration_minutes INTEGER DEFAULT 30,
          requires_booking INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (branch_id) REFERENCES branches(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS appointments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          customer_id INTEGER,
          employee_id INTEGER,
          service_ids TEXT NOT NULL,
          scheduled_start TEXT NOT NULL,
          scheduled_end TEXT NOT NULL,
          status TEXT DEFAULT 'booked',
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (branch_id) REFERENCES branches(id),
          FOREIGN KEY (customer_id) REFERENCES customers(id),
          FOREIGN KEY (employee_id) REFERENCES employees(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff_availability (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          day_of_week INTEGER NOT NULL,
          start_time TEXT,
          end_time TEXT,
          is_off_day INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          customer_id INTEGER,
          due_date TEXT NOT NULL,
          deposit_amount REAL DEFAULT 0,
          deposit_paid INTEGER DEFAULT 0,
          total_amount REAL NOT NULL,
          status TEXT DEFAULT 'placed',
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (branch_id) REFERENCES branches(id),
          FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          description TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (order_id) REFERENCES custom_orders(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // ==================== BRANCH OPERATIONS ====================
  
  Future<int> insertBranch(Branch branch) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'branches', branch.toMap());
      await _addToSyncQueue('branches', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<List<Branch>> getAllBranches() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'branches',
      where: 'deleted = 0',
      orderBy: 'id ASC', // Main branch (id:1) first
    );
    return List.generate(maps.length, (i) => Branch.fromMap(maps[i]));
  }

  Future<int> deleteBranch(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'branches',
        {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('branches', id, 'DELETE', executor: txn);
      return count;
    });
  }

  Future<Branch?> getBranch(int id) async {
    final db = await database;
    final maps = await db.query('branches', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Branch.fromMap(maps.first);
  }

  Future<int> updateBranch(Branch branch) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'branches',
        branch.toMap(),
        where: 'id = ?',
        whereArgs: [branch.id],
      );
      if (branch.id != null) {
        await _addToSyncQueue('branches', branch.id!, 'UPDATE', executor: txn);
      }
      return count;
    });
  }

  // ==================== SERVICE OPERATIONS ====================

  Future<int> insertService(Service service) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'services', service.toMap());
      await _addToSyncQueue('services', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<int> updateService(Service service) async {
    final db = await database;
    return await db.transaction((txn) async {
      final data = service.toMap();
      data['updated_at'] = DateTime.now().toIso8601String();
      data['synced'] = 0; // Mark for sync

      final count = await txn.update(
        'services',
        data,
        where: 'id = ?',
        whereArgs: [service.id],
      );
      if (service.id != null) {
        await _addToSyncQueue('services', service.id!, 'UPDATE', executor: txn);
      }
      return count;
    });
  }

  Future<int> deleteService(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'services',
        {
          'deleted': 1,
          'synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('services', id, 'UPDATE', executor: txn);
      return count;
    });
  }

  Future<List<Service>> getAllServices(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'services',
      where: 'branch_id = ? AND deleted = 0',
      whereArgs: [branchId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Service.fromMap(maps[i]));
  }

  Future<List<Service>> searchServices(String query, int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'services',
      where: 'branch_id = ? AND deleted = 0 AND (name LIKE ? OR category LIKE ?)',
      whereArgs: [branchId, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Service.fromMap(maps[i]));
  }

  Future<Service?> getServiceById(int id) async {
    final db = await database;
    final maps = await db.query(
      'services',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Service.fromMap(maps.first);
    }
    return null;
  }

  // ==================== PRODUCT OPERATIONS ====================

  Future<int> insertProduct(Product product) async {
    final db = await database;
    final tokens = SinhalaSearchService.generateSearchTokens(
      name: product.name,
      nameSinhala: product.nameSinhala,
      nameEnglish: product.nameEnglish,
      searchAliases: product.searchAliases,
      baseBarcode: product.baseBarcode,
    );
    final productToSave = product.normalizedTerms != null
        ? product
        : product.copyWith(normalizedTerms: tokens.join(','));

    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'products', productToSave.toMap());
      
      if (productToSave.baseBarcode != null) {
        await _safeSetBarcodeLookup(txn, productToSave.baseBarcode!, id, null);
      }

      // Log Initial Stock History if > 0
      if (productToSave.stock > 0) {
        final historyId = await _insertWithId(txn, 'stock_history', {
          'branch_id': productToSave.branchId,
          'product_id': id,
          'quantity_change': productToSave.stock,
          'type': 'adjustment',
          'notes': 'Initial Stock',
          'created_at': DateTime.now().toIso8601String(),
        });
        await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
      }
      
      await _addToSyncQueue('products', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<int> insertProductsBatch(List<Product> products) async {
    final db = await database;
    int count = 0;
    const int batchSize = 50;

    for (var i = 0; i < products.length; i += batchSize) {
      final end = (i + batchSize < products.length) ? i + batchSize : products.length;
      final batchProducts = products.sublist(i, end);

      await db.transaction((txn) async {
        for (var product in batchProducts) {
          final tokens = SinhalaSearchService.generateSearchTokens(
            name: product.name,
            nameSinhala: product.nameSinhala,
            nameEnglish: product.nameEnglish,
            searchAliases: product.searchAliases,
            baseBarcode: product.baseBarcode,
          );
          final productToSave = product.normalizedTerms != null
              ? product
              : product.copyWith(normalizedTerms: tokens.join(','));

          final id = await _insertWithId(txn, 'products', productToSave.toMap());
          
          if (productToSave.baseBarcode != null) {
            await _safeSetBarcodeLookup(txn, productToSave.baseBarcode!, id, null);
          }

          if (productToSave.stock > 0) {
            final historyId = await _insertWithId(txn, 'stock_history', {
              'branch_id': productToSave.branchId,
              'product_id': id,
              'quantity_change': productToSave.stock,
              'type': 'adjustment',
              'notes': 'Initial Stock',
              'created_at': DateTime.now().toIso8601String(),
            });
            await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
          }
          
          await _addToSyncQueue('products', id, 'INSERT', executor: txn);
          count++;
        }
      });
      // Yield between batches to allow UI threads and other queries to execute, preventing ANRs
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return count;
  }

  Future<List<Product>> getAllProducts(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, 
             COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) AS total_stock
      FROM products p
      WHERE p.branch_id = ? AND p.deleted = 0
      ORDER BY p.name ASC
    ''', [branchId]);
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, 
             COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) AS total_stock
      FROM products p
      WHERE p.id = ? AND p.deleted = 0
      LIMIT 1
    ''', [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getProductByBarcode(String barcode, int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, 
             COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) AS total_stock
      FROM products p
      WHERE p.base_barcode = ? AND p.branch_id = ? AND p.deleted = 0
      LIMIT 1
    ''', [barcode, branchId]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> searchProducts(String query, int branchId) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return await getAllProducts(branchId);
    }
    final allProducts = await getAllProducts(branchId);
    return SinhalaSearchService.filterAndRank(allProducts, clean);
  }

  Future<List<Product>> getLowStockProducts(int branchId, [int? threshold]) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, 
             COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) AS total_stock
      FROM products p 
      WHERE p.branch_id = ? AND p.deleted = 0 AND 
            (CASE WHEN p.track_batches = 1 
                  THEN COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) 
                  ELSE p.stock 
             END) < ?
      ORDER BY (CASE WHEN p.track_batches = 1 
                     THEN COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) 
                     ELSE p.stock 
                END) ASC
      LIMIT 70
    ''', [branchId, threshold ?? 10]);
    
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    final tokens = SinhalaSearchService.generateSearchTokens(
      name: product.name,
      nameSinhala: product.nameSinhala,
      nameEnglish: product.nameEnglish,
      searchAliases: product.searchAliases,
      baseBarcode: product.baseBarcode,
    );
    final productToSave = product.normalizedTerms != null
        ? product
        : product.copyWith(normalizedTerms: tokens.join(','));

    return await db.transaction((txn) async {
      // Check if price or cost or unit changed to log in price_history
      if (productToSave.id != null) {
        final existing = await txn.query(
          'products',
          columns: ['price', 'cost_price', 'unit'],
          where: 'id = ?',
          whereArgs: [productToSave.id],
        );
        if (existing.isNotEmpty) {
          final oldPrice = (existing.first['price'] as num?)?.toDouble() ?? 0.0;
          final oldCost = (existing.first['cost_price'] as num?)?.toDouble();
          final oldUnit = existing.first['unit'] as String?;

          if (oldPrice != productToSave.price || oldCost != productToSave.costPrice || oldUnit != productToSave.unit) {
            final historyId = await _insertWithId(txn, 'price_history', {
              'product_id': productToSave.id,
              'branch_id': productToSave.branchId,
              'old_price': oldPrice,
              'new_price': productToSave.price,
              'old_cost_price': oldCost,
              'new_cost_price': productToSave.costPrice,
              'old_unit': oldUnit,
              'new_unit': productToSave.unit,
              'reason': 'Product price/cost adjustment',
              'changed_by': 'Admin',
              'created_at': DateTime.now().toIso8601String(),
            });
            await _addToSyncQueue('price_history', historyId, 'INSERT', executor: txn);
          }
        }
      }

      final productMap = _sanitizeData(productToSave.toMap());
      final cols = await getTableColumns('products', txn);
      if (cols.isNotEmpty) {
        productMap.removeWhere((key, value) => !cols.contains(key));
      }
      final count = await txn.update(
        'products',
        productMap,
        where: 'id = ?',
        whereArgs: [productToSave.id],
      );

      // Update barcode lookup if barcode changed
      if (product.id != null && product.baseBarcode != null) {
        // Delete old primary lookup
        await txn.delete(
          'barcode_lookup',
          where: 'product_id = ? AND is_primary = ?',
          whereArgs: [product.id, 1],
        );
        
        // Safely set the new primary lookup
        await _safeSetBarcodeLookup(txn, product.baseBarcode!, product.id!, null);
      }

      if (product.id != null) {
        await _addToSyncQueue('products', product.id!, 'UPDATE', executor: txn);
      }
      return count;
    });
  }

  Future<int> updateProductStock(int productId, double newStock) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'products',
        {
          'stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
      await _addToSyncQueue('products', productId, 'UPDATE', executor: txn);
      return count;
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'products',
        {
          'deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Delete all barcode lookups for this product
      await txn.delete(
        'barcode_lookup',
        where: 'product_id = ?',
        whereArgs: [id],
      );

      // Soft-delete all batches of this product
      await txn.update(
        'product_batches',
        {
          'deleted': 1,
          'synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ?',
        whereArgs: [id],
      );
      
      await _addToSyncQueue('products', id, 'DELETE', executor: txn);
      return count;
    });
  }

  /// Retrieves price change history for a specific product.
  Future<List<PriceHistory>> getPriceHistory(int productId) async {
    final db = await database;
    final results = await db.query(
      'price_history',
      where: 'product_id = ? AND deleted = 0',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return results.map((m) => PriceHistory.fromMap(m)).toList();
  }

  /// Retrieves recent price changes across the branch.
  Future<List<PriceHistory>> getAllPriceHistory({int branchId = 1, int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'price_history',
      where: 'branch_id = ? AND deleted = 0',
      whereArgs: [branchId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((m) => PriceHistory.fromMap(m)).toList();
  }

  /// Returns all archived (soft-deleted) products for a branch.
  Future<List<Product>> getArchivedProducts(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'branch_id = ? AND deleted = 1',
      whereArgs: [branchId],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  /// Restores an archived product by setting deleted = 0.
  Future<int> restoreProduct(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'products',
        {
          'deleted': 0,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('products', id, 'UPDATE', executor: txn);
      return count;
    });
  }

  // ==================== SALE OPERATIONS ====================

  Future<int> insertSale(Sale sale, List<CartItem> cartItems) async {
    final db = await database;
    
    // Use transaction for atomic operation
    return await db.transaction((txn) async {
      // Insert sale
      final saleId = await _insertWithId(txn, 'sales', sale.toMap());
      await _addToSyncQueue('sales', saleId, 'INSERT', executor: txn);
      
      // If sale is on credit and has a customer, update customer debt
      if (sale.paymentMethod == 'credit' && sale.customerId != null) {
        await txn.rawUpdate('''
          UPDATE customers 
          SET total_debt = total_debt + ?, updated_at = ?, synced = 0
          WHERE id = ?
        ''', [sale.total, DateTime.now().toIso8601String(), sale.customerId]);
        await _addToSyncQueue('customers', sale.customerId!, 'UPDATE', executor: txn);
      }
      
      // Insert sale items
      for (var cartItem in cartItems) {
        
        // Skip inventory logic for quick items and services
        if (cartItem.isQuickItem || cartItem.itemType == 'service') {
          // Ensure a dummy product with ID 999999999 exists so the SQLite FOREIGN KEY constraint isn't violated
          await txn.execute('''
            INSERT OR IGNORE INTO products 
            (id, branch_id, name, price, created_at, updated_at, deleted, synced) 
            VALUES 
            (999999999, 1, 'System Service Placeholder', 0, '${DateTime.now().toIso8601String()}', '${DateTime.now().toIso8601String()}', 1, 1)
          ''');

          // Just insert the sale item record
          final saleItem = SaleItem(
            saleId: saleId,
            productId: 999999999, // Quick items/services don't have a standard product ID
            itemType: cartItem.itemType,
            serviceId: cartItem.serviceId,
            productName: cartItem.itemName,
            quantity: cartItem.quantity,
            unitPrice: cartItem.itemPrice,
            total: cartItem.total,
            costPrice: 0.0, // No cost price for quick items/services
            discount: cartItem.discount,
          );
          await _insertWithId(txn, 'sale_items', saleItem.toMap());
          continue; // Skip inventory updates
        }
        
        // Check if product tracks batches
        // We need to fetch product info inside transaction to be safe? 
        // Or rely on passing trackBatches via CartItem/Product?
        // Let's query the product's track_batches status
        final productParams = await txn.query(
          'products', 
          columns: ['track_batches', 'stock', 'cost_price', 'type'],
          where: 'id = ?', 
          whereArgs: [cartItem.product!.id]
        );
        
        final trackBatches = productParams.isNotEmpty && (productParams.first['track_batches'] as int) == 1;
        final double fallbackCost = (productParams.first['cost_price'] as num?)?.toDouble() ?? 0.0;
        final String productType = productParams.isNotEmpty ? ((productParams.first['type'] as String?) ?? 'product') : 'product';

        if (productType == 'service') {
          final saleItem = SaleItem(
            saleId: saleId,
            productId: cartItem.product!.id!,
            productName: cartItem.product!.name,
            quantity: cartItem.quantity,
            unitPrice: cartItem.product!.price,
            total: cartItem.total,
            costPrice: fallbackCost,
            discount: cartItem.discount,
          );
          await _insertWithId(txn, 'sale_items', saleItem.toMap());
          continue; // Skip stock updates completely for services
        }

        if (productType == 'package') {
          final saleItem = SaleItem(
            saleId: saleId,
            productId: cartItem.product!.id!,
            productName: cartItem.product!.name,
            quantity: cartItem.quantity,
            unitPrice: cartItem.product!.price,
            total: cartItem.total,
            costPrice: fallbackCost,
            discount: cartItem.discount,
          );
          await _insertWithId(txn, 'sale_items', saleItem.toMap());
          
          // Deplete stock for physical components of the package
          final components = await txn.query('package_items', where: 'package_id = ?', whereArgs: [cartItem.product!.id]);
          for (var comp in components) {
            final compId = comp['component_id'] as int;
            final qtyMultiplier = (comp['quantity'] as num).toDouble();
            final totalComponentQtyToDeplete = qtyMultiplier * cartItem.quantity;
            
            final compParams = await txn.query('products', columns: ['track_batches', 'type'], where: 'id = ?', whereArgs: [compId]);
            if (compParams.isEmpty) continue;
            
            final compType = (compParams.first['type'] as String?) ?? 'product';
            if (compType == 'service') continue;
            
            final compTrackBatches = (compParams.first['track_batches'] as int) == 1;
            
            if (compTrackBatches) {
              final batches = await txn.query(
                'product_batches',
                where: 'product_id = ? AND deleted = ? AND stock > ?',
                whereArgs: [compId, 0, 0],
                orderBy: 'expiry_date ASC',
              );
              
              double remainingToSell = totalComponentQtyToDeplete;
              for (var batch in batches) {
                if (remainingToSell <= 0) break;
                final batchStock = (batch['stock'] as num?)?.toDouble() ?? 0.0;
                final batchId = batch['id'] as int;
                final takeFromBatch = remainingToSell > batchStock ? batchStock : remainingToSell;
                
                await txn.rawUpdate('''
                  UPDATE product_batches SET stock = stock - ?, updated_at = ?, synced = 0 WHERE id = ?
                ''', [takeFromBatch, DateTime.now().toIso8601String(), batchId]);
                await _addToSyncQueue('product_batches', batchId, 'UPDATE', executor: txn);
                
                final batchHistoryId = await _insertWithId(txn, 'batch_stock_history', {
                  'branch_id': sale.branchId,
                  'batch_id': batchId,
                  'product_id': compId,
                  'quantity_change': -takeFromBatch,
                  'type': 'sale_package_component',
                  'reference_id': saleId,
                  'employee_id': sale.employeeId,
                  'created_at': DateTime.now().toIso8601String(),
                });
                await _addToSyncQueue('batch_stock_history', batchHistoryId, 'INSERT', executor: txn);
                remainingToSell -= takeFromBatch;
              }
            }
            
            // Deduct total component stock from products table
            await txn.rawUpdate('''
              UPDATE products SET stock = stock - ?, updated_at = ?, synced = 0 WHERE id = ?
            ''', [totalComponentQtyToDeplete, DateTime.now().toIso8601String(), compId]);
            await _addToSyncQueue('products', compId, 'UPDATE', executor: txn);
            
            final historyId = await _insertWithId(txn, 'stock_history', {
              'branch_id': sale.branchId,
              'product_id': compId,
              'quantity_change': -totalComponentQtyToDeplete,
              'type': 'sale_package_component',
              'reference_id': saleId,
              'employee_id': sale.employeeId,
              'created_at': DateTime.now().toIso8601String(),
            });
            await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
          }
          continue; // Done with package
        }
        
        if (trackBatches) {
          // BATCH TRACKING LOGIC
          
          if (cartItem.batchId != null) {
            // Case 1: Specific batch selected manually
            final batchData = await txn.query(
              'product_batches',
              columns: ['purchase_price'],
              where: 'id = ?',
              whereArgs: [cartItem.batchId],
              limit: 1
            );
            final double batchCost = (batchData.isNotEmpty ? (batchData.first['purchase_price'] as num?)?.toDouble() : null) ?? fallbackCost;

             final saleItem = SaleItem(
              saleId: saleId,
              productId: cartItem.product!.id!,
              productName: cartItem.product!.name,
              quantity: cartItem.quantity,
              unitPrice: cartItem.product!.price,
              total: cartItem.total,
              costPrice: batchCost,
              batchId: cartItem.batchId,
              batchNumber: cartItem.batchNumber,
              discount: cartItem.discount,
            );
            await _insertWithId(txn, 'sale_items', saleItem.toMap());
            
            // Update batch stock
             await txn.rawUpdate('''
              UPDATE product_batches 
              SET stock = stock - ?, updated_at = ?, synced = 0
              WHERE id = ?
            ''', [cartItem.quantity, DateTime.now().toIso8601String(), cartItem.batchId]);
            await _addToSyncQueue('product_batches', cartItem.batchId!, 'UPDATE', executor: txn);
            
            // Log batch history
            final batchHistoryId = await _insertWithId(txn, 'batch_stock_history', {
              'branch_id': sale.branchId,
              'batch_id': cartItem.batchId,
              'product_id': cartItem.product!.id,
              'quantity_change': -cartItem.quantity,
              'type': 'sale',
              'reference_id': saleId,
              'employee_id': sale.employeeId,
              'created_at': DateTime.now().toIso8601String(),
            });
            await _addToSyncQueue('batch_stock_history', batchHistoryId, 'INSERT', executor: txn);

          } else {
            // Case 2: No batch selected, use FEFO (First Expire First Out)
            // Get available batches sorted by expiry
            final batches = await txn.query(
              'product_batches',
              where: 'product_id = ? AND deleted = ? AND stock > ?',
              whereArgs: [cartItem.product!.id, 0, 0],
              orderBy: 'expiry_date ASC',
            );
            
            double remainingToSell = cartItem.quantity;
            
            for (var batch in batches) {
              if (remainingToSell <= 0) break;
              
              // Ensure we treat batch stock as double
              final batchStock = (batch['stock'] as num?)?.toDouble() ?? 0.0;
              final batchId = batch['id'] as int;
              final batchNumber = batch['batch_number'] as String;
              final double batchCost = (batch['purchase_price'] as num?)?.toDouble() ?? fallbackCost;
              
              final takeFromBatch = remainingToSell > batchStock ? batchStock : remainingToSell;
              
              // Create split sale item
              final saleItem = SaleItem(
                saleId: saleId,
                productId: cartItem.product!.id!,
                productName: cartItem.product!.name, // Could append batch info if needed
                quantity: takeFromBatch,
                unitPrice: cartItem.product!.price,
                total: (cartItem.product!.price * takeFromBatch) - ((takeFromBatch / cartItem.quantity) * cartItem.discount),
                costPrice: batchCost,
                batchId: batchId,
                batchNumber: batchNumber,
                discount: (takeFromBatch / cartItem.quantity) * cartItem.discount,
              );
              await _insertWithId(txn, 'sale_items', saleItem.toMap());
              
              // Update batch stock
               await txn.rawUpdate('''
                UPDATE product_batches 
                SET stock = stock - ?, updated_at = ?, synced = 0
                WHERE id = ?
              ''', [takeFromBatch, DateTime.now().toIso8601String(), batchId]);
              await _addToSyncQueue('product_batches', batchId, 'UPDATE', executor: txn);
              
              // Log batch history
              final batchHistoryId = await _insertWithId(txn, 'batch_stock_history', {
                'branch_id': sale.branchId,
                'batch_id': batchId,
                'product_id': cartItem.product!.id,
                'quantity_change': -takeFromBatch,
                'type': 'sale',
                'reference_id': saleId,
                'employee_id': sale.employeeId,
                'created_at': DateTime.now().toIso8601String(),
              });
              await _addToSyncQueue('batch_stock_history', batchHistoryId, 'INSERT', executor: txn);
              
              remainingToSell -= takeFromBatch;
            }
            
            // If we still have remaining (ran out of batch stock but selling anyway?)
            // We should probably allow selling even if negative, recording as "No Batch"
            // Or strict enforcement. For now, let's treat remainder as general stock (no batch)
            // to avoid blocking sale.
              if (remainingToSell > 0) {
                final saleItem = SaleItem(
                  saleId: saleId,
                  productId: cartItem.product!.id!,
                  productName: cartItem.product!.name,
                  quantity: remainingToSell,
                  unitPrice: cartItem.product!.price,
                  total: (cartItem.product!.price * remainingToSell) - ((remainingToSell / cartItem.quantity) * cartItem.discount),
                  costPrice: fallbackCost,
                  discount: (remainingToSell / cartItem.quantity) * cartItem.discount,
                );
              await _insertWithId(txn, 'sale_items', saleItem.toMap());
            }
          }
          
        } else {
          // NO BATCH TRACKING (Standard behavior)
          final saleItem = SaleItem(
            saleId: saleId,
            productId: cartItem.product!.id!,
            productName: cartItem.product!.name,
            quantity: cartItem.baseQuantity,
            unitPrice: cartItem.itemPrice,
            total: cartItem.total,
            costPrice: fallbackCost,
            discount: cartItem.discount,
            soldUnit: cartItem.itemUnit,
            soldQuantity: cartItem.quantity,
            sellingMode: cartItem.sellingMode,
            packSize: cartItem.packSize,
          );
          await _insertWithId(txn, 'sale_items', saleItem.toMap());
        }
        
        // Update product total stock (common for both cases) using baseQuantity
        await txn.rawUpdate('''
          UPDATE products 
          SET stock = stock - ?, updated_at = ?, synced = 0
          WHERE id = ?
        ''', [cartItem.baseQuantity, DateTime.now().toIso8601String(), cartItem.product!.id]);
        await _addToSyncQueue('products', cartItem.product!.id!, 'UPDATE', executor: txn);
        
        // Add stock history (common)
        final historyId = await _insertWithId(txn, 'stock_history', {
          'branch_id': sale.branchId,
          'product_id': cartItem.product!.id,
          'quantity_change': -cartItem.baseQuantity,
          'type': 'sale',
          'reference_id': saleId,
          'employee_id': sale.employeeId,
          'created_at': DateTime.now().toIso8601String(),
        });
        await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
      }
      
      return saleId;
    });
  }

  Future<List<Sale>> getAllSales(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'branch_id = ? AND deleted = ?',
      whereArgs: [branchId, 0],
      orderBy: 'created_at DESC',
    );
    return await _attachItemsToSales(maps);
  }

  Future<List<Sale>> _attachItemsToSales(List<Map<String, dynamic>> maps) async {
    if (maps.isEmpty) return [];
    
    final db = await database;
    final sales = List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
    final saleIds = sales.map((s) => s.id).whereType<int>().toList();
    
    if (saleIds.isEmpty) return sales;

    // Fetch employee names (cashiers) for these sales
    final employeeIds = sales.map((s) => s.employeeId).whereType<int>().toSet().toList();
    final Map<int, String> employeeNames = {};
    if (employeeIds.isNotEmpty) {
      final empPlaceholders = List.filled(employeeIds.length, '?').join(',');
      final empMaps = await db.query(
        'employees',
        columns: ['id', 'name'],
        where: 'id IN ($empPlaceholders)',
        whereArgs: employeeIds,
      );
      for (var emp in empMaps) {
        employeeNames[emp['id'] as int] = emp['name'] as String;
      }
    }

    // Use IN clause for efficiency (fetch all items for all sales in one go)
    final placeholders = List.filled(saleIds.length, '?').join(',');
    final itemMaps = await db.query(
      'sale_items',
      where: 'sale_id IN ($placeholders)',
      whereArgs: saleIds,
    );
    
    // Group items by sale_id
    final Map<int, List<SaleItem>> itemsBySaleId = {};
    for (var map in itemMaps) {
      final item = SaleItem.fromMap(map);
      itemsBySaleId.putIfAbsent(item.saleId, () => []).add(item);
    }
    
    // Attach items and cashier to sales
    return sales.map((s) => s.copyWith(
      items: itemsBySaleId[s.id] ?? [],
      cashierName: employeeNames[s.employeeId],
    )).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'id = ? AND deleted = ?',
      whereArgs: [id, 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    
    final sales = await _attachItemsToSales(maps);
    return sales.isNotEmpty ? sales.first : null;
  }

  Future<List<Sale>> getSalesToday(int branchId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'branch_id = ? AND deleted = ? AND created_at >= ?',
      whereArgs: [branchId, 0, startOfDay],
      orderBy: 'created_at DESC',
    );
    return await _attachItemsToSales(maps);
  }

  Future<List<Sale>> getSalesByRange(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'branch_id = ? AND deleted = ? AND created_at BETWEEN ? AND ?',
      whereArgs: [branchId, 0, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return await _attachItemsToSales(maps);
  }

  Future<Map<String, dynamic>> getTodayStats(int branchId) async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    
    // 1. Get raw sales and bill-level discounts
    final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as bill_count,
        COALESCE(SUM(total), 0) as total_sales,
        COALESCE(SUM(discount), 0) as bill_discounts,
        COALESCE(AVG(total), 0) as avg_bill
      FROM sales
      WHERE branch_id = ? AND deleted = 0 AND created_at >= ?
    ''', [branchId, startOfDay]);

    // 2. Get item-level discounts
    final itemDiscountsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(si.discount), 0) as item_discounts
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.branch_id = ? AND s.deleted = 0 AND s.created_at >= ?
    ''', [branchId, startOfDay]);

    // 3. Get today's refunds
    final refundsResult = await db.rawQuery('''
      SELECT COALESCE(SUM(refund_amount), 0) as total_refunds
      FROM sales_returns
      WHERE branch_id = ? AND return_date >= ?
    ''', [branchId, startOfDay]);

    final salesData = Map<String, dynamic>.from(salesResult.first);
    final double rawSales = (salesData['total_sales'] as num?)?.toDouble() ?? 0.0;
    final double billDiscounts = (salesData['bill_discounts'] as num?)?.toDouble() ?? 0.0;
    final double itemDiscounts = (itemDiscountsResult.first['item_discounts'] as num?)?.toDouble() ?? 0.0;
    final double refunds = (refundsResult.first['total_refunds'] as num?)?.toDouble() ?? 0.0;
    
    final data = Map<String, dynamic>.from(salesData);
    data['total_sales'] = rawSales - refunds;
    data['total_discounts'] = billDiscounts + itemDiscounts;
    data['avg_bill'] = (salesData['avg_bill'] as num?)?.toDouble() ?? 0.0;
    data['bill_count'] = salesData['bill_count'] as int? ?? 0;
    data['refunds'] = refunds;

    return data;
  }

  Future<List<Map<String, dynamic>>> getRefundsByRange(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        sr.id,
        sr.sale_id,
        s.bill_number,
        sr.return_date,
        sr.reason,
        sr.refund_amount,
        sr.refund_type as payment_method,
        s.customer_name,
        s.customer_id
      FROM sales_returns sr
      JOIN sales s ON sr.sale_id = s.id
      WHERE (s.branch_id = ? OR ? = 0) AND sr.return_date BETWEEN ? AND ?
      ORDER BY sr.return_date DESC
    ''', [branchId, branchId, start.toIso8601String(), end.toIso8601String()]);

    // For each refund, we need its items
    final List<Map<String, dynamic>> refundsWithItems = [];
    for (var row in result) {
      final refund = Map<String, dynamic>.from(row);
      final items = await db.rawQuery('''
        SELECT 
          sri.*,
          p.name as product_name,
          sri.refund_amount as total
        FROM sales_return_items sri
        JOIN products p ON sri.product_id = p.id
        WHERE sri.return_id = ?
      ''', [refund['id']]);
      refund['items'] = items;
      refundsWithItems.add(refund);
    }
    
    return refundsWithItems;
  }

  /// Get Damage and Waste report aggregating stock write-offs and damaged returns
  Future<List<Map<String, dynamic>>> getDamageAndWasteReport(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    
    // We combine two sources using UNION ALL:
    // 1. Manual stock adjustments (write-offs) where quantity_change < 0
    // 2. Customer returns marked as 'damaged'
    
    final result = await db.rawQuery('''
      SELECT 
        'write_off' as source,
        sh.created_at as date,
        p.name as product_name,
        ABS(sh.quantity_change) as quantity,
        ABS(sh.quantity_change) * p.cost_price as cost_value,
        sh.notes as reason
      FROM stock_history sh
      JOIN products p ON sh.product_id = p.id
      WHERE sh.type = 'adjustment' AND sh.quantity_change < 0
        AND (sh.notes NOT LIKE 'Write-off: Returned to Supplier%' OR sh.notes IS NULL)
        AND (sh.branch_id = ? OR ? = 0)
        AND sh.created_at BETWEEN ? AND ?
        
      UNION ALL
      
      SELECT 
        'return_damaged' as source,
        sr.return_date as date,
        p.name as product_name,
        sri.quantity as quantity,
        sri.quantity * p.cost_price as cost_value,
        'Customer Return (Damaged)' as reason
      FROM sales_return_items sri
      JOIN sales_returns sr ON sri.return_id = sr.id
      JOIN products p ON sri.product_id = p.id
      WHERE sri.condition = 'damaged'
        AND (sr.branch_id = ? OR ? = 0)
        AND sr.return_date BETWEEN ? AND ?
        
      ORDER BY date DESC
    ''', [
      branchId, branchId, start.toIso8601String(), end.toIso8601String(),
      branchId, branchId, start.toIso8601String(), end.toIso8601String(),
    ]);

    return result;
  }

  /// Get Supplier Returns report aggregating stock write-offs specifically for returning to suppliers
  Future<List<Map<String, dynamic>>> getSupplierReturnsReport(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT 
        'return_supplier' as source,
        sh.created_at as date,
        p.name as product_name,
        ABS(sh.quantity_change) as quantity,
        ABS(sh.quantity_change) * p.cost_price as cost_value,
        sh.notes as reason
      FROM stock_history sh
      JOIN products p ON sh.product_id = p.id
      WHERE sh.type = 'adjustment' AND sh.quantity_change < 0
        AND sh.notes LIKE 'Write-off: Returned to Supplier%'
        AND (sh.branch_id = ? OR ? = 0)
        AND sh.created_at BETWEEN ? AND ?
      ORDER BY date DESC
    ''', [
      branchId, branchId, start.toIso8601String(), end.toIso8601String(),
    ]);

    return result;
  }

  // Generate unique bill number according to formatting requirements:
  // YYMMM_QQQQ_XXXXX
  Future<String> generateBillNumber(String entityCode) async {
    final db = await database;
    final today = DateTime.now();
    
    // Calculate the start of the current month in local time to restart numbering monthly
    final startOfMonth = DateTime(today.year, today.month, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sales WHERE created_at >= ?
    ''', [startOfMonth]);
    
    final count = result.first['count'] as int;
    
    // YY: last two digits of calendar year
    final yearStr = today.year.toString();
    final yy = yearStr.substring(yearStr.length - 2);
    
    // MMM: first three characters of name of the calendar month in uppercase letters
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final mmm = months[today.month - 1];
    
    // QQQQ: Entity code (cleaned to ensure no spaces, limit to 15 characters)
    final cleanedEntityCode = entityCode.trim().replaceAll(' ', '');
    final qqqq = cleanedEntityCode.isEmpty ? '1' : (cleanedEntityCode.length > 15 ? cleanedEntityCode.substring(0, 15) : cleanedEntityCode);
    
    // XXXXX: Numeric serial number of the invoice (solely numerical characters, no symbols/alphabets, padded to 5 digits minimum)
    final xxxxx = (count + 1).toString().padLeft(5, '0');
    
    final serial = '$yy${mmm}_${qqqq}_$xxxxx';
    
    // Limit to 40 characters in length per requirement
    if (serial.length > 40) {
      return serial.substring(0, 40);
    }
    return serial;
  }

  // ==================== CUSTOMER OPERATIONS ====================

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'customers', customer.toMap());
      await _addToSyncQueue('customers', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<List<Customer>> getAllCustomers(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'deleted = 0 AND (branch_id = ? OR branch_id IS NULL OR branch_id = 0 OR ? = 0)',
      whereArgs: [branchId, branchId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ? AND deleted = ?',
      whereArgs: [id, 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  /// Get aggregated sales analytics for all customers (RFM Data)
  Future<List<Map<String, dynamic>>> getCustomerAnalytics(int branchId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        customer_id, 
        COUNT(*) as frequency, 
        SUM(total) as monetary, 
        MAX(created_at) as last_purchase_date
      FROM sales
      WHERE branch_id = ? AND customer_id IS NOT NULL AND deleted = 0
      GROUP BY customer_id
    ''', [branchId]);
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );
      if (customer.id != null) {
        await _addToSyncQueue('customers', customer.id!, 'UPDATE', executor: txn);
      }
      return count;
    });
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'customers',
        {
          'deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('customers', id, 'DELETE', executor: txn);
      return count;
    });
  }

  Future<int> insertCustomerPayment(CustomerPayment payment) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Insert payment
      final id = await _insertWithId(txn, 'customer_payments', payment.toMap());
      await _addToSyncQueue('customer_payments', id, 'INSERT', executor: txn);

      // 2. Update customer total debt
      await txn.rawUpdate('''
        UPDATE customers 
        SET total_debt = total_debt - ?, updated_at = ?, synced = 0
        WHERE id = ?
      ''', [payment.amount, DateTime.now().toIso8601String(), payment.customerId]);
      await _addToSyncQueue('customers', payment.customerId, 'UPDATE', executor: txn);

      return id;
    });
  }

  Future<List<CustomerPayment>> getCustomerPayments(int customerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customer_payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'payment_date DESC',
    );
    return List.generate(maps.length, (i) => CustomerPayment.fromMap(maps[i]));
  }

  Future<List<Sale>> getCustomerSales(int customerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: 'customer_id = ? AND deleted = ?',
      whereArgs: [customerId, 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Sale.fromMap(maps[i]));
  }

  Future<void> addDebtToCustomer(int customerId, double amount) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate('''
        UPDATE customers 
        SET total_debt = total_debt + ?, updated_at = ?, synced = 0
        WHERE id = ?
      ''', [amount, DateTime.now().toIso8601String(), customerId]);
      await _addToSyncQueue('customers', customerId, 'UPDATE', executor: txn);
    });
  }


  // ==================== BATCH OPERATIONS ====================

  /// Add new batch for a product
  Future<int> addProductBatch(ProductBatch batch) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      // Insert batch
      final batchId = await _insertWithId(txn, 'product_batches', batch.toMap());
      await _addToSyncQueue('product_batches', batchId, 'INSERT', executor: txn);
      
      // Add barcode to lookup table
      await _safeSetBarcodeLookup(txn, batch.barcode, batch.productId, batchId);
      
      // Record stock history
      final batchHistoryId = await _insertWithId(txn, 'batch_stock_history', {
        'batch_id': batchId,
        'product_id': batch.productId,
        'quantity_change': batch.stock,
        'type': 'purchase',
        'notes': 'Initial stock for batch ${batch.batchNumber}',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _addToSyncQueue('batch_stock_history', batchHistoryId, 'INSERT', executor: txn);
      
      return batchId;
    });
  }

  /// Update an existing batch
  Future<void> updateProductBatch(ProductBatch batch) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Get the current batch from the DB to find its old barcode
      final oldBatchMaps = await txn.query(
        'product_batches',
        where: 'id = ?',
        whereArgs: [batch.id],
        limit: 1,
      );
      
      if (oldBatchMaps.isNotEmpty) {
        final oldBarcode = (oldBatchMaps.first['barcode'] as String?)?.trim();
        final newBarcode = batch.barcode.trim();
        
        if (oldBarcode != null && oldBarcode.isNotEmpty && oldBarcode != newBarcode) {
          // Check if the product's base barcode is the same as the old barcode
          final productMaps = await txn.query(
            'products',
            columns: ['base_barcode'],
            where: 'id = ?',
            whereArgs: [batch.productId],
            limit: 1,
          );
          
          final baseBarcode = productMaps.isNotEmpty 
              ? (productMaps.first['base_barcode'] as String?)?.trim() 
              : null;
          
          if (baseBarcode != null && baseBarcode == oldBarcode) {
            // Revert the old barcode lookup to point only to the product (batch_id = null)
            await txn.update(
              'barcode_lookup',
              {'batch_id': null},
              where: 'barcode = ? AND product_id = ?',
              whereArgs: [oldBarcode, batch.productId],
            );
          } else {
            // Delete the old barcode mapping completely
            await txn.delete(
              'barcode_lookup',
              where: 'barcode = ? AND batch_id = ?',
              whereArgs: [oldBarcode, batch.id],
            );
          }
        }
      }

      // 2. Update the batch in the product_batches table
      await txn.update(
        'product_batches',
        batch.toMap(),
        where: 'id = ?',
        whereArgs: [batch.id],
      );
      
      // 3. Update/insert the new barcode in lookup table
      await _safeSetBarcodeLookup(txn, batch.barcode, batch.productId, batch.id);
      
      await _addToSyncQueue('product_batches', batch.id!, 'UPDATE', executor: txn);
    });
  }

  /// Delete a batch (soft delete)
  Future<void> deleteProductBatch(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Find batch details to get the barcode and product ID
      final batchMaps = await txn.query(
        'product_batches',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (batchMaps.isNotEmpty) {
        final barcode = (batchMaps.first['barcode'] as String?)?.trim();
        final productId = batchMaps.first['product_id'] as int;
        
        if (barcode != null && barcode.isNotEmpty) {
          // Check if it is the product's base barcode
          final productMaps = await txn.query(
            'products',
            columns: ['base_barcode'],
            where: 'id = ?',
            whereArgs: [productId],
            limit: 1,
          );
          
          final baseBarcode = productMaps.isNotEmpty
              ? (productMaps.first['base_barcode'] as String?)?.trim()
              : null;
              
          if (baseBarcode != null && baseBarcode == barcode) {
            // Revert it to point to product (batch_id = null)
            await txn.update(
              'barcode_lookup',
              {'batch_id': null},
              where: 'barcode = ? AND product_id = ?',
              whereArgs: [barcode, productId],
            );
          } else {
            // Delete it from barcode lookup
            await txn.delete(
              'barcode_lookup',
              where: 'batch_id = ?',
              whereArgs: [id],
            );
          }
        } else {
          // No barcode, just delete any batch lookup entries
          await txn.delete(
            'barcode_lookup',
            where: 'batch_id = ?',
            whereArgs: [id],
          );
        }
      } else {
        // Fallback
        await txn.delete(
          'barcode_lookup',
          where: 'batch_id = ?',
          whereArgs: [id],
        );
      }

      final currentBarcode = batchMaps.isNotEmpty
          ? (batchMaps.first['barcode'] as String?)?.trim() ?? ''
          : '';
      final updatedBarcode = currentBarcode.isNotEmpty && !currentBarcode.startsWith('deleted_')
          ? 'deleted_${id}_$currentBarcode'
          : currentBarcode;

      await txn.update(
        'product_batches',
        {
          'deleted': 1,
          'synced': 0,
          'barcode': updatedBarcode,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      await _addToSyncQueue('product_batches', id, 'DELETE', executor: txn);
    });
  }

  /// Free up the barcode of a deleted batch by renaming it
  Future<void> freeDeletedBatchBarcode(int batchId, String barcode) async {
    final db = await database;
    await db.update(
      'product_batches',
      {'barcode': 'deleted_${batchId}_${barcode.trim()}'},
      where: 'id = ? AND deleted = 1',
      whereArgs: [batchId],
    );
  }

  /// Get all batches for a product
  Future<List<ProductBatch>> getProductBatches(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_batches',
      where: 'product_id = ? AND deleted = ?',
      whereArgs: [productId, 0],
      orderBy: 'expiry_date ASC', // FEFO - First Expire First Out
    );
    return List.generate(maps.length, (i) => ProductBatch.fromMap(maps[i]));
  }

  /// Get batches with available stock for a product (sorted by expiry)
  Future<List<ProductBatch>> getAvailableBatches(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_batches',
      where: 'product_id = ? AND deleted = ? AND stock > ?',
      whereArgs: [productId, 0, 0],
      orderBy: 'expiry_date ASC',
    );
    return List.generate(maps.length, (i) => ProductBatch.fromMap(maps[i]));
  }

  /// Find batch by barcode directly from the product_batches table (including deleted ones)
  Future<ProductBatch?> getBatchByBarcodeDirect(String barcode, {bool includeDeleted = true}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_batches',
      where: includeDeleted ? 'barcode = ?' : 'barcode = ? AND deleted = 0',
      whereArgs: [barcode.trim()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProductBatch.fromMap(maps.first);
  }

  /// Find batch by barcode
  Future<ProductBatch?> getBatchByBarcode(String barcode) async {
    final db = await database;
    
    // First, lookup batch_id from barcode
    final lookup = await db.query(
      'barcode_lookup',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    
    if (lookup.isEmpty || lookup.first['batch_id'] == null) return null;
    
    final batchId = lookup.first['batch_id'] as int;
    
    // Get batch details
    final List<Map<String, dynamic>> maps = await db.query(
      'product_batches',
      where: 'id = ? AND deleted = ?',
      whereArgs: [batchId, 0],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return ProductBatch.fromMap(maps.first);
  }

  /// Find product by any barcode (base or batch)
  Future<Map<String, dynamic>?> findByBarcode(String barcode) async {
    final db = await database;
    
    // Lookup in barcode_lookup table
    final lookup = await db.query(
      'barcode_lookup',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    
    if (lookup.isEmpty) return null;
    
    final productId = lookup.first['product_id'] as int;
    final batchId = lookup.first['batch_id'] as int?;
    
    // Get product
    final product = await getProductById(productId);
    if (product == null) return null;
    
    // Get batch if specified
    ProductBatch? batch;
    if (batchId != null) {
      final batchMaps = await db.query(
        'product_batches',
        where: 'id = ? AND deleted = ?',
        whereArgs: [batchId, 0],
        limit: 1,
      );
      if (batchMaps.isNotEmpty) {
        batch = ProductBatch.fromMap(batchMaps.first);
      }
    }
    
    return {
      'product': product,
      'batch': batch,
    };
  }

  /// Rebuild the barcode lookup table from products and batches in small chunks to prevent locking the database.
  Future<void> rebuildBarcodeLookup() async {
    final db = await database;
    
    // Fetch products and batches outside of transaction to keep locks short
    final products = await db.query('products', where: 'deleted = 0');
    final batches = await db.query('product_batches', where: 'deleted = 0');

    final List<Map<String, dynamic>> rowsToInsert = [];
    final Set<String> processedBarcodes = {};

    // Index primary product barcodes
    for (var p in products) {
      final barcode = p['base_barcode'] as String?;
      if (barcode != null && barcode.isNotEmpty) {
        final trimmed = barcode.trim();
        if (!processedBarcodes.contains(trimmed)) {
          processedBarcodes.add(trimmed);
          rowsToInsert.add({
            'barcode': trimmed,
            'product_id': p['id'],
            'batch_id': null,
            'is_primary': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Index batch barcodes
    for (var b in batches) {
      final barcode = b['barcode'] as String?;
      if (barcode != null && barcode.isNotEmpty) {
        final trimmed = barcode.trim();
        if (!processedBarcodes.contains(trimmed)) {
          processedBarcodes.add(trimmed);
          rowsToInsert.add({
            'barcode': trimmed,
            'product_id': b['product_id'],
            'batch_id': b['id'],
            'is_primary': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Clear existing lookups in a quick transaction
    await db.transaction((txn) async {
      await txn.delete('barcode_lookup');
    });

    // Insert in chunks of 50 to avoid locking the database for too long
    const int chunkSize = 50;
    for (var i = 0; i < rowsToInsert.length; i += chunkSize) {
      final end = (i + chunkSize < rowsToInsert.length) ? i + chunkSize : rowsToInsert.length;
      final chunk = rowsToInsert.sublist(i, end);

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var row in chunk) {
          batch.insert('barcode_lookup', row);
        }
        await batch.commit(noResult: true);
      });

      // Yield thread control after each chunk
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Update batch stock
  Future<void> updateBatchStock(int batchId, int newStock, String type, {int? referenceId, String? notes}) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // Get current stock
      final batch = await txn.query(
        'product_batches',
        where: 'id = ?',
        whereArgs: [batchId],
        limit: 1,
      );
      
      if (batch.isEmpty) return;
      
      final oldStock = batch.first['stock'] as int;
      final productId = batch.first['product_id'] as int;
      final quantityChange = newStock - oldStock;
      
      // Update stock
      await txn.update(
        'product_batches',
        {
          'stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [batchId],
      );
      await _addToSyncQueue('product_batches', batchId, 'UPDATE', executor: txn);
      
      // Record history
      final batchHistoryId = await _insertWithId(txn, 'batch_stock_history', {
        'batch_id': batchId,
        'product_id': productId,
        'quantity_change': quantityChange,
        'type': type,
        'reference_id': referenceId,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _addToSyncQueue('batch_stock_history', batchHistoryId, 'INSERT', executor: txn);
    });
  }

  /// Get expiring batches (within specified days)
  Future<List<Map<String, dynamic>>> getExpiringBatches(int daysThreshold, int branchId) async {
    final db = await database;
    final String thresholdDate = DateTime.now().add(Duration(days: daysThreshold)).toIso8601String();
    
    return await db.rawQuery('''
      SELECT b.*, p.name as product_name 
      FROM product_batches b
      JOIN products p ON b.product_id = p.id
      WHERE (b.branch_id = ? OR ? = 0) AND b.deleted = 0 AND b.expiry_date <= ? AND b.stock > 0
      ORDER BY b.expiry_date ASC
    ''', [branchId, branchId, thresholdDate]);
  }

  /// Get expired batches
  Future<List<Map<String, dynamic>>> getExpiredBatches(int branchId) async {
    final db = await database;
    final String now = DateTime.now().toIso8601String();
    
    return await db.rawQuery('''
      SELECT b.*, p.name as product_name 
      FROM product_batches b
      JOIN products p ON b.product_id = p.id
      WHERE b.branch_id = ? AND b.deleted = 0 AND b.expiry_date < ? AND b.stock > 0
      ORDER BY b.expiry_date ASC
    ''', [branchId, now]);
  }

  /// Get product with all batches
  Future<Product?> getProductWithBatches(int productId) async {
    final product = await getProductById(productId);
    if (product == null) return null;
    
    final batches = await getProductBatches(productId);
    
    // Calculate total stock
    double totalStock = 0.0;
    if (batches.isNotEmpty) {
      totalStock = batches.fold(0.0, (sum, batch) => sum + batch.stock);
    }
    
    return product.copyWith(
      batches: batches,
      totalStock: totalStock,
    );
  }

  /// Get items for a specific sale
  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return List.generate(maps.length, (i) => SaleItem.fromMap(maps[i]));
  }

  /// Sell from batches (FEFO logic - First Expire First Out)
  Future<List<Map<String, dynamic>>> sellFromBatches(int productId, double quantityToSell) async {
    
    // Get available batches sorted by expiry
    final batches = await getAvailableBatches(productId);
    
    if (batches.isEmpty) {
      throw Exception('No stock available for this product');
    }
    
    final totalAvailable = batches.fold(0.0, (sum, batch) => sum + batch.stock);
    if (totalAvailable < quantityToSell) {
      throw Exception('Insufficient stock. Available: $totalAvailable, Required: $quantityToSell');
    }
    
    List<Map<String, dynamic>> soldBatches = [];
    double remaining = quantityToSell;
    
    for (var batch in batches) {
      if (remaining <= 0) break;
      
      final takeFromBatch = remaining > batch.stock ? batch.stock : remaining;
      
      soldBatches.add({
        'batch_id': batch.id,
        'batch_number': batch.batchNumber,
        'quantity': takeFromBatch,
        'barcode': batch.barcode,
      });
      
      remaining -= takeFromBatch;
    }
    
    return soldBatches;
  }

  // ==================== SUPPLIER OPERATIONS ====================

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'suppliers', supplier.toMap());
      await _addToSyncQueue('suppliers', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<List<Supplier>> getAllSuppliers(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'suppliers',
      where: 'branch_id = ? AND deleted = ?',
      whereArgs: [branchId, 0],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Supplier.fromMap(maps[i]));
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'suppliers',
        supplier.toMap(),
        where: 'id = ?',
        whereArgs: [supplier.id],
      );
      if (supplier.id != null) {
        await _addToSyncQueue('suppliers', supplier.id!, 'UPDATE', executor: txn);
      }
      return count;
    });
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'suppliers',
        {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('suppliers', id, 'DELETE', executor: txn);
      return count;
    });
  }

  // ==================== PURCHASE OPERATIONS ====================

  Future<int> insertPurchase(Purchase purchase) async {
    final db = await database;
    return await db.transaction((txn) async {
      final purchaseId = await _insertWithId(txn, 'purchases', purchase.toMap());

      for (var item in purchase.items) {
        await _insertWithId(txn, 'purchase_items', {
          ...item.toMap(),
          'purchase_id': purchaseId,
        });
      }

      // Only update stock immediately if status is already "Received"
      if (purchase.status == "Received") {
        await _processPurchaseReceipt(txn, purchaseId, purchase);
      }

      await _addToSyncQueue('purchases', purchaseId, 'INSERT', executor: txn);
      return purchaseId;
    });
  }

  Future<void> _processPurchaseReceipt(Transaction txn, int purchaseId, Purchase purchase) async {
    // We need to reload items if not provided, but usually they are
    final items = purchase.items;
    
    for (var item in items) {
      // 1. Update product stock
      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
        [item.quantity, DateTime.now().toIso8601String(), item.productId]
      );
      await _addToSyncQueue('products', item.productId, 'UPDATE', executor: txn);

      // 2. Create or update batch if batch info provided
      if (item.batchNumber != null) {
        final List<Map<String, dynamic>> existingBatch = await txn.query(
          'product_batches',
          where: 'product_id = ? AND batch_number = ? AND deleted = 0',
          whereArgs: [item.productId, item.batchNumber],
          limit: 1
        );

        if (existingBatch.isNotEmpty) {
          final int batchId = existingBatch.first['id'];
          await txn.rawUpdate(
            'UPDATE product_batches SET stock = stock + ?, updated_at = ? WHERE id = ?',
            [item.quantity, DateTime.now().toIso8601String(), batchId]
          );
          await _addToSyncQueue('product_batches', batchId, 'UPDATE', executor: txn);
        } else {
          final String barcode = item.batchNumber!;
          final batchId = await _insertWithId(txn, 'product_batches', {
            'branch_id': purchase.branchId,
            'product_id': item.productId,
            'batch_number': item.batchNumber,
            'barcode': barcode,
            'stock': item.quantity,
            'initial_stock': item.quantity,
            'purchase_date': purchase.date.toIso8601String(),
            'purchase_price': item.costPrice,
            'expiry_date': item.expiryDate?.toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          await _addToSyncQueue('product_batches', batchId, 'INSERT', executor: txn);

          await _safeSetBarcodeLookup(txn, barcode, item.productId, batchId);
        }
      }

      // 3. Log Stock History
      final historyId = await _insertWithId(txn, 'stock_history', {
        'branch_id': purchase.branchId,
        'product_id': item.productId,
        'quantity_change': item.quantity,
        'type': 'purchase',
        'reference_id': purchaseId,
        'employee_id': purchase.employeeId,
        'notes': 'Purchase #${purchaseId}',
        'created_at': DateTime.now().toIso8601String(),
      });
      await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
    }
  }

  Future<void> receivePurchase(int purchaseId) async {
    final db = await database;
    final purchaseMap = await db.query('purchases', where: 'id = ?', whereArgs: [purchaseId], limit: 1);
    if (purchaseMap.isEmpty) return;

    final itemMaps = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
    final List<PurchaseItem> items = itemMaps.map((m) => PurchaseItem.fromMap(m)).toList();
    final purchase = Purchase.fromMap(purchaseMap.first, items: items);

    await db.transaction((txn) async {
      await _processPurchaseReceipt(txn, purchaseId, purchase);
      await txn.update('purchases', 
        {'status': 'Received', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [purchaseId]
      );
      await _addToSyncQueue('purchases', purchaseId, 'UPDATE', executor: txn);
    });
  }

  Future<void> updatePurchase(Purchase purchase) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('purchases', purchase.toMap(), where: 'id = ?', whereArgs: [purchase.id]);
      await txn.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [purchase.id]);
      for (var item in purchase.items) {
        await _insertWithId(txn, 'purchase_items', {
          ...item.toMap(),
          'purchase_id': purchase.id,
        });
      }
      await _addToSyncQueue('purchases', purchase.id!, 'UPDATE', executor: txn);
    });
  }

  Future<void> deletePurchase(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('purchases', {'deleted': 1}, where: 'id = ?', whereArgs: [id]);
      await _addToSyncQueue('purchases', id, 'UPDATE', executor: txn);
    });
  }

  Future<List<Purchase>> getAllPurchases({int? branchId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      where: branchId != null ? 'branch_id = ? AND deleted = 0' : 'deleted = 0',
      whereArgs: branchId != null ? [branchId] : null,
      orderBy: 'date DESC',
    );
    
    final List<Purchase> purchases = [];
    for (var m in maps) {
      final itemMaps = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [m['id']]);
      purchases.add(Purchase.fromMap(m, items: itemMaps.map((i) => PurchaseItem.fromMap(i)).toList()));
    }
    return purchases;
  }

  Future<List<Purchase>> getPurchasesBySupplier(int supplierId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      where: 'supplier_id = ? AND deleted = ?',
      whereArgs: [supplierId, 0],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Purchase.fromMap(maps[i]));
  }

  // ==================== REPORTING & ANALYTICS ====================

  /// Get daily sales for a specific period (for charts)
  Future<List<Map<String, dynamic>>> getDailySalesForPeriod(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    final result = await db.rawQuery('''
      SELECT 
        DATE(created_at) as date,
        SUM(total) as revenue,
        COUNT(*) as count
      FROM sales
      WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND created_at BETWEEN ? AND ?
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at) ASC
    ''', [branchId, branchId, startDate, endDate]);

    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['revenue'] = (map['revenue'] as num?)?.toDouble() ?? 0.0;
      map['count'] = (map['count'] as num?)?.toInt() ?? 0;
      return map;
    }).toList();
  }

  /// Get Profit & Loss summary for a period
  Future<Map<String, dynamic>> getProfitLossSummary(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    // 1. Total Revenue
    final revResult = await db.rawQuery('''
      SELECT SUM(total) as revenue 
      FROM sales 
      WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND created_at BETWEEN ? AND ?
    ''', [branchId, branchId, startDate, endDate]);
    final double revenue = (revResult.first['revenue'] as num?)?.toDouble() ?? 0.0;

    // 2. Total Cost (COGS) for Sales
    final costResult = await db.rawQuery('''
      SELECT SUM(si.cost_price * si.quantity) as cogs
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
    ''', [branchId, branchId, startDate, endDate]);
    double cogs = (costResult.first['cogs'] as num?)?.toDouble() ?? 0.0;

    // 2.5 Deduct Restockable Returns from COGS
    final restockableCostResult = await db.rawQuery('''
      SELECT SUM(p.cost_price * sri.quantity) as restock_cogs
      FROM sales_return_items sri
      JOIN products p ON sri.product_id = p.id
      JOIN sales_returns sr ON sri.return_id = sr.id
      WHERE (sr.branch_id = ? OR ? = 0) AND sr.return_date BETWEEN ? AND ?
        AND sri.condition = 'restockable'
    ''', [branchId, branchId, startDate, endDate]);
    final double restockCogs = (restockableCostResult.first['restock_cogs'] as num?)?.toDouble() ?? 0.0;
    
    cogs = cogs - restockCogs;

    // 3. Refunds
    final refundResult = await db.rawQuery('''
      SELECT SUM(refund_amount) as total_refunds
      FROM sales_returns
      WHERE (branch_id = ? OR ? = 0) AND return_date BETWEEN ? AND ?
    ''', [branchId, branchId, startDate, endDate]);
    final double refunds = (refundResult.first['total_refunds'] as num?)?.toDouble() ?? 0.0;

    // 4. Total Discounts
    final billDiscountResult = await db.rawQuery('''
      SELECT SUM(discount) as total_bill_discount
      FROM sales
      WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND created_at BETWEEN ? AND ?
    ''', [branchId, branchId, startDate, endDate]);
    final double billDiscounts = (billDiscountResult.first['total_bill_discount'] as num?)?.toDouble() ?? 0.0;
    
    final itemDiscountResultCorrect = await db.rawQuery('''
        SELECT SUM(si.discount) as total_item_discount
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
    ''', [branchId, branchId, startDate, endDate]);
    final double itemDiscountsCorrect = (itemDiscountResultCorrect.first['total_item_discount'] as num?)?.toDouble() ?? 0.0;

    final double totalDiscounts = billDiscounts + itemDiscountsCorrect;
    final double netRevenue = revenue - refunds;

    return {
      'revenue': netRevenue,
      'gross_revenue': revenue + totalDiscounts,
      'cogs': cogs,
      'refunds': refunds,
      'discounts': totalDiscounts,
      'profit': netRevenue - cogs,
    };
  }

  /// Get summary profitability metrics (GP/NP/Margins)
  Future<Map<String, dynamic>> getSummaryProfitability(DateTime start, DateTime end, int branchId) async {
    final pl = await getProfitLossSummary(start, end, branchId);
    
    final db = await database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    // Fetch Operating Expenses
    final expResult = await db.rawQuery('''
      SELECT SUM(amount) as total_expenses 
      FROM expenses 
      WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND date BETWEEN ? AND ?
    ''', [branchId, branchId, startDate, endDate]);
    final double expenses = (expResult.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    final double grossProfit = pl['profit'] ?? 0.0;
    final double netProfit = grossProfit - expenses;
    final double revenue = pl['revenue'] ?? 0.0;
    final double grossRevenue = pl['gross_revenue'] ?? 0.0;
    final double cogs = pl['cogs'] ?? 0.0;

    return {
      'revenue': revenue,
      'gross_revenue': grossRevenue,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'net_profit': netProfit,
      'operating_expenses': expenses,
      'gross_margin': revenue > 0 ? (grossProfit / revenue) * 100 : 0.0,
      'net_margin': revenue > 0 ? (netProfit / revenue) * 100 : 0.0,
      'expense_ratio': revenue > 0 ? (expenses / revenue) * 100 : 0.0,
    };
  }

/// Get profitability breakdown by category
Future<List<Map<String, dynamic>>> getCategoryProfitability(DateTime start, DateTime end, int branchId) async {
  final db = await database;
  final startDate = start.toIso8601String();
  final endDate = end.toIso8601String();

  return await db.rawQuery('''
    SELECT 
      p.category,
      SUM(si.total) as revenue,
      SUM(si.cost_price * si.quantity) as cogs,
      SUM(si.total - (si.cost_price * si.quantity)) as profit,
      SUM(si.quantity) as quantity
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
    GROUP BY p.category
    ORDER BY profit DESC
  ''', [branchId, branchId, startDate, endDate]);
}

/// Get top profitable products (Contribution Margin)
Future<List<Map<String, dynamic>>> getTopProfitableProducts(int limit, DateTime start, DateTime end, int branchId) async {
  final db = await database;
  final startDate = start.toIso8601String();
  final endDate = end.toIso8601String();

  return await db.rawQuery('''
    SELECT 
      si.product_name,
      SUM(si.total) as revenue,
      SUM(si.cost_price * si.quantity) as cogs,
      SUM(si.total - (si.cost_price * si.quantity)) as profit,
      SUM(si.quantity) as quantity
    FROM sale_items si
    JOIN sales s ON si.sale_id = s.id
    WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
    GROUP BY si.product_id
    ORDER BY profit DESC
    LIMIT ?
  ''', [branchId, branchId, startDate, endDate, limit]);
}

/// Get operational expenses summary for the period
Future<List<Map<String, dynamic>>> getOperatingExpensesSummary(DateTime start, DateTime end, int branchId) async {
  final db = await database;
  final startDate = start.toIso8601String();
  final endDate = end.toIso8601String();

  return await db.rawQuery('''
    SELECT 
      category,
      SUM(amount) as total_amount,
      COUNT(*) as count
    FROM expenses
    WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND date BETWEEN ? AND ?
    GROUP BY category
    ORDER BY total_amount DESC
  ''', [branchId, branchId, startDate, endDate]);
}

/// Get daily profitability trends (Revenue vs COGS vs Expenses)
Future<List<Map<String, dynamic>>> getProfitabilityTrends(DateTime start, DateTime end, int branchId) async {
  final db = await database;
  final startDate = start.toIso8601String();
  final endDate = end.toIso8601String();

  // This is a complex join, better to do separate queries and merge in the service or use a UNION or temp table
  // For simplicity and clarity, we'll fetch them separately and return a merged structure
  
  final salesTrend = await db.rawQuery('''
    SELECT 
      DATE(created_at) as date,
      SUM(total) as revenue,
      (SELECT SUM(si.cost_price * si.quantity) FROM sale_items si JOIN sales s2 ON si.sale_id = s2.id WHERE DATE(s2.created_at) = DATE(s.created_at) AND (s2.branch_id = ? OR ? = 0) AND s2.deleted = 0) as cogs
    FROM sales s
    WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND created_at BETWEEN ? AND ?
    GROUP BY DATE(created_at)
  ''', [branchId, branchId, branchId, branchId, startDate, endDate]);

  final expenseTrend = await db.rawQuery('''
    SELECT 
      DATE(date) as date,
      SUM(amount) as total_expenses
    FROM expenses
    WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND date BETWEEN ? AND ?
    GROUP BY DATE(date)
  ''', [branchId, branchId, startDate, endDate]);

  return salesTrend.map((sRow) {
    final date = sRow['date'];
    final eRow = expenseTrend.firstWhere((e) => e['date'] == date, orElse: () => {'total_expenses': 0.0});
    
    return {
      'date': date,
      'revenue': (sRow['revenue'] as num?)?.toDouble() ?? 0.0,
      'cogs': (sRow['cogs'] as num?)?.toDouble() ?? 0.0,
      'expenses': (eRow['total_expenses'] as num?)?.toDouble() ?? 0.0,
    };
  }).toList();
}

  /// Get Inventory valuation (Retail vs Cost)
  Future<Map<String, dynamic>> getInventoryAudit(int branchId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT 
        SUM((CASE WHEN p.track_batches = 1 
                  THEN COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) 
                  ELSE p.stock 
             END) * p.price) as retail_value,
        SUM(CASE WHEN p.track_batches = 1 
                 THEN COALESCE((SELECT SUM(b.stock * COALESCE(b.purchase_price, p.cost_price, 0.0)) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0)
                 ELSE p.stock * COALESCE(p.cost_price, 0.0)
            END) as cost_value,
        COUNT(*) as product_count,
        SUM(CASE WHEN p.track_batches = 1 
                 THEN COALESCE((SELECT SUM(b.stock) FROM product_batches b WHERE b.product_id = p.id AND b.deleted = 0), 0.0) 
                 ELSE p.stock 
            END) as total_units
      FROM products p
      WHERE (p.branch_id = ? OR ? = 0) AND p.deleted = 0
    ''', [branchId, branchId]);
    
    final data = Map<String, dynamic>.from(result.first);
    
    // Handle NULLs from SUM() on empty tables
    data['retail_value'] = (data['retail_value'] as num?)?.toDouble() ?? 0.0;
    data['cost_value'] = (data['cost_value'] as num?)?.toDouble() ?? 0.0;
    data['total_units'] = (data['total_units'] as num?)?.toInt() ?? 0;
    data['product_count'] = (data['product_count'] as num?)?.toInt() ?? 0;
    
    return data;
  }

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProducts(int limit, DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        si.product_id,
        si.product_name,
        SUM(si.quantity) as total_qty,
        SUM(si.total) as total_sales
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
      GROUP BY si.product_id
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [branchId, branchId, start.toIso8601String(), end.toIso8601String(), limit]);

    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['total_qty'] = (map['total_qty'] as num?)?.toInt() ?? 0;
      map['total_sales'] = (map['total_sales'] as num?)?.toDouble() ?? 0.0;
      return map;
    }).toList();
  }

  /// Get high-value customers
  Future<List<Map<String, dynamic>>> getTopCustomers(int limit, DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        customer_id,
        customer_name,
        COUNT(*) as visit_count,
        SUM(total) as total_spent
      FROM sales
      WHERE (branch_id = ? OR ? = 0) AND deleted = 0 AND customer_id IS NOT NULL AND created_at BETWEEN ? AND ?
      GROUP BY customer_id
      ORDER BY total_spent DESC
      LIMIT ?
    ''', [branchId, branchId, start.toIso8601String(), end.toIso8601String(), limit]);

    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['visit_count'] = (map['visit_count'] as num?)?.toInt() ?? 0;
      map['total_spent'] = (map['total_spent'] as num?)?.toDouble() ?? 0.0;
      return map;
    }).toList();
  }

  /// Get sales breakdown by category
  Future<List<Map<String, dynamic>>> getSalesByCategory(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        p.category,
        SUM(si.total) as total_sales,
        SUM(si.quantity) as total_qty
      FROM sale_items si
      JOIN products p ON si.product_id = p.id
      JOIN sales s ON si.sale_id = s.id
      WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
      GROUP BY p.category
      ORDER BY total_sales DESC
    ''', [branchId, branchId, start.toIso8601String(), end.toIso8601String()]);

    return result.map((row) {
      final map = Map<String, dynamic>.from(row);
      map['total_sales'] = (map['total_sales'] as num?)?.toDouble() ?? 0.0;
      map['total_qty'] = (map['total_qty'] as num?)?.toInt() ?? 0;
      return map;
    }).toList();
  }

  /// Get average sales velocity (units per day) for a product
  Future<double> getProductSalesVelocity(int productId, int branchId, {int days = 30}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT SUM(si.quantity) as total_qty
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE si.product_id = ? AND (s.branch_id = ? OR ? = 0) 
      AND s.deleted = 0 AND s.created_at >= ?
    ''', [productId, branchId, branchId, startDate]);

    final double totalQty = (result.first['total_qty'] as num?)?.toDouble() ?? 0.0;
    return totalQty / days;
  }

  /// Get average sales velocity (units per day) for all products in a branch in a single query
  Future<Map<int, double>> getAllProductsSalesVelocity(int branchId, {int days = 30}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    
    final results = await db.rawQuery('''
      SELECT si.product_id, SUM(si.quantity) as total_qty
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at >= ?
      GROUP BY si.product_id
    ''', [branchId, branchId, startDate]);
    
    final Map<int, double> velocities = {};
    for (final row in results) {
      final productId = row['product_id'] as int?;
      if (productId != null) {
        final double totalQty = (row['total_qty'] as num?)?.toDouble() ?? 0.0;
        velocities[productId] = totalQty / days;
      }
    }
    return velocities;
  }

  /// Get comprehensive analytics for a single product (sales, profit, trends)
  Future<Map<String, dynamic>> getProductAnalytics(int productId, int branchId) async {
    final db = await database;

    // Overall stats (all time)
    final overallStats = await db.rawQuery('''
      SELECT 
        SUM(si.quantity) as total_qty,
        SUM(si.total) as total_revenue,
        SUM(si.total - (si.cost_price * si.quantity)) as total_profit,
        MAX(s.created_at) as last_sold
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE si.product_id = ? AND (s.branch_id = ? OR ? = 0) AND s.deleted = 0
    ''', [productId, branchId, branchId]);

    // Monthly sales (Last 6 months)
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180)).toIso8601String();
    final monthlySales = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', s.created_at) as month,
        SUM(si.quantity) as qty,
        SUM(si.total) as revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE si.product_id = ? AND (s.branch_id = ? OR ? = 0) AND s.deleted = 0 AND s.created_at >= ?
      GROUP BY strftime('%Y-%m', s.created_at)
      ORDER BY month ASC
    ''', [productId, branchId, branchId, sixMonthsAgo]);

    // Recent 10 sales
    final recentSales = await db.rawQuery('''
      SELECT 
        s.id as sale_id,
        s.bill_number as receipt_no,
        s.created_at as sale_date,
        si.quantity,
        si.total,
        si.unit_price,
        c.name as customer_name
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE si.product_id = ? AND (s.branch_id = ? OR ? = 0) AND s.deleted = 0
      ORDER BY s.created_at DESC
      LIMIT 10
    ''', [productId, branchId, branchId]);

    return {
      'overall': overallStats.isNotEmpty ? overallStats.first : {},
      'monthly': monthlySales,
      'recent': recentSales,
    };
  }

  // ==================== EMPLOYEE OPERATIONS ====================

  // ==================== EMPLOYEE OPERATIONS ====================

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'employees', {
        ...employee.toMap(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _addToSyncQueue('employees', id, 'INSERT', executor: txn);
      return id;
    });
  }

  // --- EXPENSES ---
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'expenses', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await _addToSyncQueue('expenses', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<void> updateExpense(Expense expense) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      await _addToSyncQueue('expenses', expense.id!, 'UPDATE', executor: txn);
    });
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'expenses',
        {'deleted': 1, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('expenses', id, 'DELETE', executor: txn);
    });
  }

  Future<List<Expense>> getAllExpenses(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'branch_id = ? AND deleted = 0',
      whereArgs: [branchId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'branch_id = ? AND deleted = 0 AND date BETWEEN ? AND ?',
      whereArgs: [branchId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Employee>> getAllEmployees(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees', 
      where: '(branch_id = ? OR role = ?) AND deleted = 0',
      whereArgs: [branchId, 'owner'],
      orderBy: 'name ASC'
    );
    return List.generate(maps.length, (i) => Employee.fromMap(maps[i]));
  }

  Future<void> ensureOwnerExists(int branchId) async {
    final db = await database;
    
    // Check if employee with ID 1 already exists
    final List<Map<String, dynamic>> idExists = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [1]
    );

    if (idExists.isNotEmpty) {
      final currentOwner = idExists.first;
      // If the owner is marked as deleted or inactive, restore them.
      if (currentOwner['deleted'] == 1 || currentOwner['status'] != 'active') {
        debugPrint('🛡️ Safety Check: Owner exists with ID 1 but is deleted or inactive. Updating...');
        await db.update(
          'employees',
          {
            'deleted': 0,
            'status': 'active',
            'role': 'owner',
          },
          where: 'id = ?',
          whereArgs: [1]
        );
      }
      return;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'employees', 
      where: 'role = ? AND branch_id = ?', 
      whereArgs: ['owner', branchId]
    );

    if (maps.isEmpty) {
      debugPrint('🛡️ Safety Check: No owner found for branch $branchId. Seeding default...');
      final String timestamp = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        // Prevent Foreign Key constraints from failing if the branch was wiped
        final branchCheck = await txn.query('branches', columns: ['id'], where: 'id = ?', whereArgs: [branchId]);
        if (branchCheck.isEmpty) {
          debugPrint('Branch $branchId missing. Creating dummy branch to satisfy foreign key constraints.');
          await txn.insert('branches', {
            'id': branchId,
            'name': 'Main Branch',
            'is_active': 1,
            'created_at': timestamp,
            'updated_at': timestamp,
            'synced': 0,
            'deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        await _insertWithId(txn, 'employees', {
          'id': 1, // Traditional ID for the primary owner
          'branch_id': branchId,
          'name': 'Shop Owner',
          'pin': '1234',
          'role': 'owner',
          'status': 'active',
          'created_at': timestamp,
          'updated_at': timestamp,
          'synced': 0,
          'deleted': 0,
        });
        
        // Register with sync queue so it pushes to cloud if missing there too
        await _addToSyncQueue('employees', 1, 'INSERT', executor: txn);
      });
    }
  }

  Future<Employee?> getEmployeeByPin(String pin, int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'pin = ? AND branch_id = ? AND status = ? AND deleted = 0',
      whereArgs: [pin, branchId, 'active'],
    );
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<Employee?> getEmployeeById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'id = ? AND status = ? AND deleted = 0',
      whereArgs: [id, 'active'],
    );
    if (maps.isEmpty) return null;
    return Employee.fromMap(maps.first);
  }

  Future<void> updateEmployee(Employee employee) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'employees',
        employee.toMap(),
        where: 'id = ?',
        whereArgs: [employee.id],
      );
      await _addToSyncQueue('employees', employee.id!, 'UPDATE', executor: txn);
    });
  }

  Future<void> deleteEmployee(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'employees',
        {'deleted': 1, 'status': 'inactive', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('employees', id, 'DELETE', executor: txn);
    });
  }

  // ==================== SHIFT OPERATIONS ====================

  Future<void> clockInEmployee(int employeeId) async {
     final db = await database;
     await db.transaction((txn) async {
       final id = await _insertWithId(txn, 'employee_shifts', {
         'employee_id': employeeId,
         'clock_in': DateTime.now().toIso8601String(),
         'created_at': DateTime.now().toIso8601String(),
         'synced': 0,
       });
       await _addToSyncQueue('employee_shifts', id, 'INSERT', executor: txn);
     });
  }

  Future<void> clockOutEmployee(int employeeId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Find open shift
      final shifts = await txn.query(
        'employee_shifts',
        where: 'employee_id = ? AND clock_out IS NULL',
        whereArgs: [employeeId],
        orderBy: 'clock_in DESC',
        limit: 1,
      );
      
      if (shifts.isNotEmpty) {
        final shiftId = shifts.first['id'] as int;
        await txn.update(
          'employee_shifts',
          {
            'clock_out': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [shiftId],
        );
        await _addToSyncQueue('employee_shifts', shiftId, 'UPDATE', executor: txn);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getEmployeePerformance(DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();

    return await db.rawQuery('''
      SELECT 
        e.id as employee_id,
        e.name as employee_name,
        COUNT(s.id) as bills_count,
        COALESCE(SUM(s.total), 0) as total_sales,
        (
          SELECT COALESCE(SUM(
            (JULIANDAY(clock_out) - JULIANDAY(clock_in)) * 24
          ), 0)
          FROM employee_shifts 
          WHERE employee_id = e.id 
          AND clock_in BETWEEN ? AND ?
        ) as hours_worked
      FROM employees e
      LEFT JOIN sales s ON s.employee_id = e.id AND s.deleted = 0 AND s.created_at BETWEEN ? AND ?
      WHERE (e.branch_id = ? OR ? = 0) AND e.deleted = 0
      GROUP BY e.id
    ''', [startDate, endDate, startDate, endDate, branchId, branchId]);
  }
  
  /// Returns sales grouped by hour-of-day and day-of-week for a heatmap.
  /// day_of_week: 0=Sunday, 1=Monday … 6=Saturday
  /// hour: 0–23
  Future<List<Map<String, dynamic>>> getPeakHoursSalesData(
      DateTime start, DateTime end, int branchId) async {
    final db = await database;
    final startDate = start.toIso8601String();
    final endDate = end.toIso8601String();
    return await db.rawQuery('''
      SELECT 
        CAST(strftime('%w', created_at) AS INTEGER) as day_of_week,
        CAST(strftime('%H', created_at) AS INTEGER) as hour,
        COUNT(id) as bill_count,
        COALESCE(SUM(total), 0.0) as total_sales
      FROM sales
      WHERE deleted = 0
        AND created_at BETWEEN ? AND ?
        AND (branch_id = ? OR ? = 0)
      GROUP BY day_of_week, hour
      ORDER BY day_of_week, hour
    ''', [startDate, endDate, branchId, branchId]);
  }

  // ==================== SYNC OPERATIONS ====================

  Future<void> _addToSyncQueue(String tableName, int recordId, String operation, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    try {
      await exec.insert('sync_queue', {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      });
    } catch (e) {
      debugPrint("Error adding to sync queue: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOperations() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markOperationSynced(int id) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> purgeSyncedOperations({int keepDays = 7}) async {
    final db = await database;
    try {
      final cutoff = DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
      final count = await db.delete(
        'sync_queue',
        where: 'synced = 1 AND created_at < ?',
        whereArgs: [cutoff],
      );
      if (count > 0) {
        debugPrint('🧹 Purged $count old synced operations from sync_queue.');
      }
    } catch (e) {
      debugPrint('Error purging synced operations: $e');
    }
  }

  // ==================== RESTORE OPERATIONS ====================

  Future<bool> isDatabaseEmpty() async {
    final db = await database;
    final productCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products WHERE deleted = 0')) ?? 0;
    final salesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sales WHERE deleted = 0')) ?? 0;
    return productCount == 0 && salesCount == 0;
  }

  Future<List<String>> getTableColumns(String tableName, DatabaseExecutor db) async {
    if (_tableColumnsCache.containsKey(tableName)) {
      return _tableColumnsCache[tableName]!;
    }
    try {
      final List<Map<String, dynamic>> results = await db.rawQuery('PRAGMA table_info($tableName)');
      final columns = results.map((row) => row['name'] as String).toList();
      _tableColumnsCache[tableName] = columns;
      return columns;
    } catch (e) {
      debugPrint('Error fetching columns for $tableName: $e');
      return [];
    }
  }

  /// Ensures all expected columns exist across core tables, adding any missing columns.
  /// This self-healing mechanism prevents runtime SQLite errors if a migration was skipped
  /// or if new columns were added to models.
  static Future<void> _ensureSchemaIntegrity(Database db) async {
    final expectedColumns = <String, Map<String, String>>{
      'products': {
        'type': "TEXT DEFAULT 'product'",
        'image_url': 'TEXT',
        'supplier_id': 'INTEGER REFERENCES suppliers(id)',
        'unit': "TEXT DEFAULT 'pcs'",
        'track_batches': 'INTEGER DEFAULT 0',
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
        'name_sinhala': 'TEXT',
        'name_english': 'TEXT',
        'search_aliases': 'TEXT',
        'normalized_terms': 'TEXT',
        'allow_loose': 'INTEGER DEFAULT 1',
        'allow_pack': 'INTEGER DEFAULT 0',
        'pack_price': 'REAL',
        'pack_cost_price': 'REAL',
        'pack_size': 'REAL DEFAULT 1.0',
        'pack_unit': "TEXT DEFAULT 'pack'",
        'pack_size_unit': "TEXT DEFAULT 'kg'",
      },
      'employees': {
        'staff_id': 'TEXT',
        'must_change_password': 'INTEGER DEFAULT 0',
        'last_device_id': 'TEXT',
        'skill_service_ids': 'TEXT',
        'status': "TEXT DEFAULT 'active'",
        'permissions': 'TEXT',
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
      },
      'purchases': {
        'employee_id': 'INTEGER',
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
      },
      'sales': {
        'service_charge': 'REAL DEFAULT 0.0',
        'cashier_name': 'TEXT',
        'appointment_id': 'INTEGER',
        'custom_order_id': 'INTEGER',
        'server_timestamp': 'TEXT',
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
      },
      'sale_items': {
        'item_type': "TEXT DEFAULT 'product'",
        'service_id': 'INTEGER',
        'cost_price': 'REAL DEFAULT 0.0',
        'discount': 'REAL DEFAULT 0.0',
        'sold_unit': "TEXT DEFAULT 'pcs'",
        'sold_quantity': 'REAL',
        'selling_mode': "TEXT DEFAULT 'standard'",
        'pack_size': 'REAL',
      },
      'price_history': {
        'product_id': 'INTEGER NOT NULL',
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
        'old_price': 'REAL NOT NULL',
        'new_price': 'REAL NOT NULL',
        'old_cost_price': 'REAL',
        'new_cost_price': 'REAL',
        'old_unit': 'TEXT',
        'new_unit': 'TEXT',
        'reason': 'TEXT',
        'changed_by': 'TEXT',
        'created_at': 'TEXT NOT NULL',
        'synced': 'INTEGER DEFAULT 0',
        'deleted': 'INTEGER DEFAULT 0',
      },
      'suppliers': {
        'notes': 'TEXT',
        'provided_items': 'TEXT',
        'branch_id': 'INTEGER NOT NULL DEFAULT 1',
      },
      'branches': {
        'operating_hours': 'TEXT',
      },
    };

    // 1. Ensure all expected tables exist (Self-healing table creation)
    final requiredTableSchemas = <String, String>{
      'price_history': '''
        CREATE TABLE IF NOT EXISTS price_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          branch_id INTEGER NOT NULL DEFAULT 1,
          old_price REAL NOT NULL,
          new_price REAL NOT NULL,
          old_cost_price REAL,
          new_cost_price REAL,
          old_unit TEXT,
          new_unit TEXT,
          reason TEXT,
          changed_by TEXT,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
        )
      ''',
      'package_items': '''
        CREATE TABLE IF NOT EXISTS package_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (package_id) REFERENCES products(id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
        )
      ''',
      'services': '''
        CREATE TABLE IF NOT EXISTS services (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          duration_minutes INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''',
      'appointments': '''
        CREATE TABLE IF NOT EXISTS appointments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          customer_id INTEGER,
          customer_name TEXT,
          customer_phone TEXT,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          service_id INTEGER,
          staff_id INTEGER,
          status TEXT NOT NULL DEFAULT 'scheduled',
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''',
      'staff_availability': '''
        CREATE TABLE IF NOT EXISTS staff_availability (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          staff_id INTEGER NOT NULL,
          day_of_week INTEGER NOT NULL,
          start_time TEXT NOT NULL,
          end_time TEXT NOT NULL,
          is_working INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''',
      'custom_orders': '''
        CREATE TABLE IF NOT EXISTS custom_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          customer_id INTEGER,
          customer_name TEXT NOT NULL,
          customer_phone TEXT,
          total_amount REAL NOT NULL,
          advance_paid REAL DEFAULT 0.0,
          status TEXT NOT NULL DEFAULT 'pending',
          due_date TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (branch_id) REFERENCES branches(id),
          FOREIGN KEY (customer_id) REFERENCES customers(id)
        )
      ''',
      'custom_order_items': '''
        CREATE TABLE IF NOT EXISTS custom_order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          description TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_price REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0,
          FOREIGN KEY (order_id) REFERENCES custom_orders(id) ON DELETE CASCADE
        )
      ''',
      'discounts': '''
        CREATE TABLE IF NOT EXISTS discounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          branch_id INTEGER NOT NULL DEFAULT 1,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          value REAL NOT NULL,
          scope TEXT NOT NULL,
          product_ids TEXT,
          category_ids TEXT,
          min_spend REAL,
          max_discount REAL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          deleted INTEGER DEFAULT 0
        )
      ''',
    };

    for (final tableEntry in requiredTableSchemas.entries) {
      try {
        final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableEntry.key],
        );
        if (tableCheck.isEmpty) {
          debugPrint('🔧 Self-healing schema: Creating missing table \${tableEntry.key}');
          await db.execute(tableEntry.value);
        }
      } catch (e) {
        debugPrint('⚠️ Error self-healing table \${tableEntry.key}: $e');
      }
    }

    for (final entry in expectedColumns.entries) {
      final table = entry.key;
      final columns = entry.value;

      try {
        final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (tableCheck.isEmpty) continue;

        final List<Map<String, dynamic>> results = await db.rawQuery('PRAGMA table_info($table)');
        final existingCols = results.map((row) => row['name'] as String).toSet();

        for (final colEntry in columns.entries) {
          final colName = colEntry.key;
          final colDef = colEntry.value;
          if (!existingCols.contains(colName)) {
            debugPrint('🔧 Self-healing schema: Adding missing column $table.$colName ($colDef)');
            try {
              await db.execute('ALTER TABLE $table ADD COLUMN $colName $colDef');
            } catch (e) {
              debugPrint('⚠️ Error adding column $table.$colName: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error checking schema integrity for $table: $e');
      }
    }
    _tableColumnsCache.clear();
  }

  /// RESTORE: Insert a record from cloud without triggering sync queue
  Future<void> restoreRecord(String table, Map<String, dynamic> data, {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    
    // Special handling for tables with child data if needed
    // In Firestore, Sales and Purchases are uploaded WITH items.
    // We need to extract them and save to separate local tables.
    
    if (table == 'sales' && data.containsKey('items')) {
      final List<dynamic> items = data['items'];
      final Map<String, dynamic> saleMap = Map<String, dynamic>.from(data)..remove('items');
      
      Future<void> executeBlock(DatabaseExecutor exec) async {
        await _insertWithId(exec, table, saleMap, conflictAlgorithm: ConflictAlgorithm.replace);
        
        // Clean existing local items to prevent duplicates on multiple pulls
        await exec.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleMap['id']]);
        
        if (items.isNotEmpty) {
          final batch = exec is Transaction ? exec.batch() : (exec as Database).batch();
          for (var item in items) {
            final itemMap = Map<String, dynamic>.from(item);
            itemMap.remove('id');
            var mutableData = _sanitizeData(itemMap);
            batch.insert('sale_items', mutableData, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      }

      if (db is Transaction) {
        await executeBlock(db);
      } else {
        await (db as Database).transaction((txn) async {
          await executeBlock(txn);
        });
      }
      return;
    }

    if (table == 'purchases' && data.containsKey('items')) {
      final List<dynamic> items = data['items'];
      final Map<String, dynamic> purchaseMap = Map<String, dynamic>.from(data)..remove('items');
      
      Future<void> executeBlock(DatabaseExecutor exec) async {
        await _insertWithId(exec, table, purchaseMap, conflictAlgorithm: ConflictAlgorithm.replace);
        
        await exec.delete('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseMap['id']]);
        
        if (items.isNotEmpty) {
          final batch = exec is Transaction ? exec.batch() : (exec as Database).batch();
          for (var item in items) {
            final itemMap = Map<String, dynamic>.from(item);
            itemMap.remove('id');
            var mutableData = _sanitizeData(itemMap);
            batch.insert('purchase_items', mutableData, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      }

      if (db is Transaction) {
        await executeBlock(db);
      } else {
        await (db as Database).transaction((txn) async {
          await executeBlock(txn);
        });
      }
      return;
    }

    if (table == 'sales_returns' && data.containsKey('items')) {
      final List<dynamic> items = data['items'];
      final Map<String, dynamic> returnMap = Map<String, dynamic>.from(data)..remove('items');
      
      Future<void> executeBlock(DatabaseExecutor exec) async {
        await _insertWithId(exec, table, returnMap, conflictAlgorithm: ConflictAlgorithm.replace);
        
        await exec.delete('sales_return_items', where: 'return_id = ?', whereArgs: [returnMap['id']]);
        
        if (items.isNotEmpty) {
          final batch = exec is Transaction ? exec.batch() : (exec as Database).batch();
          for (var item in items) {
            final itemMap = Map<String, dynamic>.from(item);
            itemMap.remove('id');
            var mutableData = _sanitizeData(itemMap);
            batch.insert('sales_return_items', mutableData, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      }

      if (db is Transaction) {
        await executeBlock(db);
      } else {
        await (db as Database).transaction((txn) async {
          await executeBlock(txn);
        });
      }
      return;
    }

    // PREVENT OVERWRITING LOCAL DELETIONS & RESOLVE LAST-WRITE-WINS CONFLICTS:
    if (data['deleted'] == 0 || data['deleted'] == false) {
      final existing = await db.query(
        table,
        columns: ['deleted', 'synced', 'updated_at'],
        where: 'id = ?',
        whereArgs: [data['id']],
      );
      if (existing.isNotEmpty) {
        if (existing.first['deleted'] == 1) {
          debugPrint('Skipping restore for $table:${data['id']} because it is already deleted locally.');
          return;
        }
        
        // LAST-WRITE-WINS: If local is unsynced, check if its updated_at is newer
        if (existing.first['synced'] == 0) {
          final localUpdatedAtStr = existing.first['updated_at'] as String?;
          final incomingUpdatedAtStr = data['updated_at'] as String?;
          
          if (localUpdatedAtStr != null && incomingUpdatedAtStr != null) {
             final localDate = DateTime.tryParse(localUpdatedAtStr);
             final incomingDate = DateTime.tryParse(incomingUpdatedAtStr);
             
             if (localDate != null && incomingDate != null && localDate.isAfter(incomingDate)) {
                 debugPrint('LAST-WRITE-WINS: Skipping restore for $table:${data['id']} because local edit ($localDate) is newer than incoming ($incomingDate).');
                 return;
             }
          }
        }
      }
    }

    // Standard insert/update with sanitization
    Map<String, dynamic> sanitizedData = Map<String, dynamic>.from(data);
    
    // Convert all Firestore Timestamps to ISO8601 Strings for local SQLite storage and model compatibility
    sanitizedData.keys.toList().forEach((key) {
      final value = sanitizedData[key];
      if (value != null) {
        if (value.runtimeType.toString() == 'Timestamp') {
          try {
            sanitizedData[key] = (value as dynamic).toDate().toIso8601String();
          } catch (e) {
            debugPrint('Error converting Timestamp for key $key: $e');
          }
        } else if (value is bool) {
          sanitizedData[key] = value ? 1 : 0;
        }
      }
    });

    // Remove server_timestamp for tables that don't support it (only 'sales' has it)
    if (table != 'sales') {
      sanitizedData.remove('server_timestamp');
    }

    if (table == 'employees') {
      sanitizedData.remove('is_active');
      try {
        final employee = Employee.fromMap(sanitizedData);
        sanitizedData = employee.toMap();
      } catch (e) {
        debugPrint('Error sanitizing employee record: $e');
      }
    }

    // DELTA STOCK PROTECTION on Pull:
    // If we are pulling a product or batch from the cloud and the local row has
    // un-pushed changes (synced = 0), preserve the local stock value.
    // Overwriting it with the cloud value would undo offline sales that haven't
    // been pushed yet — creating phantom stock that was already sold.
    if (table == 'products' || table == 'product_batches') {
      final recordId = sanitizedData['id'];
      if (recordId != null) {
        final existing = await db.query(
          table,
          columns: ['synced', 'stock'],
          where: 'id = ?',
          whereArgs: [recordId],
        );
        if (existing.isNotEmpty && existing.first['synced'] == 0) {
          // Keep the local stock value — don't let the pull overwrite it.
          final localStock = existing.first['stock'];
          if (localStock != null) {
            sanitizedData['stock'] = localStock;
            debugPrint(
              'DELTA STOCK PROTECT: Preserving local stock ($localStock) for $table:$recordId '
              '— local has unsynced changes, not overwriting with cloud stock (${data['stock']}).',
            );
          }
        }
      }
    }

    // Filter out any keys that do not exist as columns in the target SQLite table
    final columns = await getTableColumns(table, db);
    sanitizedData.removeWhere((key, value) => !columns.contains(key));

    // Safety check: ensure branch_id exists to prevent FOREIGN KEY constraint failures
    if (sanitizedData.containsKey('branch_id')) {
      final branchId = sanitizedData['branch_id'];
      if (branchId != null) {
        final res = await db.query('branches', columns: ['id'], where: 'id = ?', whereArgs: [branchId]);
        if (res.isEmpty) {
          debugPrint('Branch $branchId missing. Creating dummy branch to satisfy foreign key constraints.');
          final String timestamp = DateTime.now().toIso8601String();
          await db.insert('branches', {
            'id': branchId,
            'name': 'Branch $branchId',
            'is_active': 1,
            'created_at': timestamp,
            'updated_at': timestamp,
            'synced': 0,
            'deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }

    try {
      await _insertWithId(db, table, sanitizedData, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error restoring record to $table: $e');
      // If it's a constraint failure (like a missing foreign key branch_id), we safely drop this orphaned record
      // and allow the rest of the sync transaction to proceed successfully.
      return;
    }

    // Incrementally build secondary indexes (barcode_lookup) during cloud data restorations
    if (table == 'products') {
      final String? barcode = sanitizedData['base_barcode'] as String?;
      if (barcode != null && barcode.isNotEmpty) {
        await _safeSetBarcodeLookup(db, barcode, sanitizedData['id'] as int, null);
      }
    } else if (table == 'product_batches') {
      final String? barcode = sanitizedData['barcode'] as String?;
      final int? productId = sanitizedData['product_id'] as int?;
      if (barcode != null && barcode.isNotEmpty && productId != null) {
        await _safeSetBarcodeLookup(db, barcode, productId, sanitizedData['id'] as int);
      }
    }
  }

  Future<int> getTableRecordCount(String table) async {
    final db = await database;
    try {
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE deleted = 0'));
      return count ?? 0;
    } catch (e) {
      debugPrint("Error getting count for $table: $e");
      return 0;
    }
  }

  // --- STOCK HISTORY ---

  Future<void> adjustStock({
    required int productId,
    required int branchId,
    required double quantityChange,
    required String notes,
    int? employeeId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Update product stock
      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ?, updated_at = ?, synced = 0 WHERE id = ?',
        [quantityChange, DateTime.now().toIso8601String(), productId],
      );
      await _addToSyncQueue('products', productId, 'UPDATE', executor: txn);

      // 2. Log History
      final historyId = await _insertWithId(txn, 'stock_history', {
        'branch_id': branchId,
        'product_id': productId,
        'quantity_change': quantityChange,
        'type': 'adjustment',
        'notes': notes,
        'employee_id': employeeId,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
    });
  }

  Future<void> writeOffBatchStock({
    required int productId,
    required int batchId,
    required int branchId,
    required double quantity,
    required String reason,
    String? notes,
    int? employeeId,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.transaction((txn) async {
       // 1. Deduct from product scope
      await txn.rawUpdate(
        'UPDATE products SET stock = stock - ?, updated_at = ?, synced = 0 WHERE id = ?',
        [quantity, now, productId],
      );
      await _addToSyncQueue('products', productId, 'UPDATE', executor: txn);
      
       // 2. Deduct from batch scope
      await txn.rawUpdate(
        'UPDATE product_batches SET stock = stock - ?, updated_at = ?, synced = 0 WHERE id = ?',
        [quantity, now, batchId],
      );
      await _addToSyncQueue('product_batches', batchId, 'UPDATE', executor: txn);
      
      final typeDesc = 'wastage_$reason'; // e.g., wastage_expired
      
       // 3. Log to stock_history
      final historyId = await _insertWithId(txn, 'stock_history', {
        'branch_id': branchId,
        'product_id': productId,
        'quantity_change': -quantity,
        'type': typeDesc,
        'notes': notes,
        'employee_id': employeeId,
        'created_at': now,
      });
      await _addToSyncQueue('stock_history', historyId, 'INSERT', executor: txn);
      
       // 4. Log to batch_stock_history
      final batchHistoryId = await _insertWithId(txn, 'batch_stock_history', {
         'branch_id': branchId,
         'batch_id': batchId,
         'product_id': productId,
         'quantity_change': -quantity,
         'type': typeDesc,
         'notes': notes,
         'employee_id': employeeId,
         'created_at': now,
      });
      // batch_stock_history runs via separate sync pulls or ignores queue depending on setup.
      // Ensuring it's queued if it's supposed to sync:
      await _addToSyncQueue('batch_stock_history', batchHistoryId, 'INSERT', executor: txn);
    });
  }

  Future<List<StockHistory>> getProductStockHistory(int productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_history',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => StockHistory.fromMap(maps[i]));
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _initDbFuture = null;
  }

  // ==================== DISCOUNT OPERATIONS ====================

  Future<int> insertDiscount(Discount discount) async {
    final db = await database;
    return await db.transaction((txn) async {
      final id = await _insertWithId(txn, 'discounts', discount.toMap());
      await _addToSyncQueue('discounts', id, 'INSERT', executor: txn);
      return id;
    });
  }

  Future<List<Discount>> getAllDiscounts(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'discounts',
      where: 'branch_id = ? AND deleted = 0',
      whereArgs: [branchId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Discount.fromMap(maps[i]));
  }

  Future<Discount?> getActiveDiscountForProduct(int productId, int branchId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Check for product-specific active discounts or clearance
    final List<Map<String, dynamic>> maps = await db.query(
      'discounts',
      where: 'branch_id = ? AND product_id = ? AND is_active = 1 AND deleted = 0 AND '
             '(is_clearance = 1 OR (start_date <= ? AND end_date >= ?))',
      whereArgs: [branchId, productId, now, now],
      orderBy: 'discount_value DESC', // Apply the highest discount if multiples exist
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Discount.fromMap(maps.first);
  }

  Future<int> updateDiscount(Discount discount) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'discounts',
        discount.toMap(),
        where: 'id = ?',
        whereArgs: [discount.id],
      );
      if (discount.id != null) {
        await _addToSyncQueue('discounts', discount.id!, 'UPDATE', executor: txn);
      }
      return count;
    });
  }

  Future<int> deleteDiscount(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final count = await txn.update(
        'discounts',
        {
          'deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addToSyncQueue('discounts', id, 'DELETE', executor: txn);
      return count;
    });
  }

  // ==========================================
  // APPOINTMENTS CRUD
  // ==========================================

  Future<int> insertAppointment(Appointment appointment) async {
    final db = await database;
    final id = await _insertWithId(db, 'appointments', appointment.toMap());
    await _addToSyncQueue('appointments', id, 'INSERT');
    return id;
  }

  Future<void> updateAppointment(Appointment appointment) async {
    final db = await database;
    await db.update(
      'appointments',
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
    await _addToSyncQueue('appointments', appointment.id!, 'UPDATE');
  }

  Future<void> deleteAppointment(int id) async {
    final db = await database;
    await db.update(
      'appointments',
      {'deleted': 1, 'synced': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _addToSyncQueue('appointments', id, 'UPDATE');
  }

  Future<List<Appointment>> getAppointments({int? branchId, DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String where = 'deleted = 0';
    List<dynamic> whereArgs = [];

    if (branchId != null) {
      where += ' AND branch_id = ?';
      whereArgs.add(branchId);
    }
    
    if (startDate != null) {
      where += ' AND scheduled_start >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      where += ' AND scheduled_start <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'appointments',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'scheduled_start ASC',
    );
    return List.generate(maps.length, (i) => Appointment.fromMap(maps[i]));
  }
  
  Future<List<Appointment>> getAppointmentsByEmployee(int employeeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'appointments',
      where: 'deleted = 0 AND employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'scheduled_start ASC',
    );
    return List.generate(maps.length, (i) => Appointment.fromMap(maps[i]));
  }

  // ==========================================
  // STAFF AVAILABILITY CRUD
  // ==========================================

  Future<int> insertStaffAvailability(StaffAvailability availability) async {
    final db = await database;
    final id = await _insertWithId(db, 'staff_availability', availability.toMap());
    await _addToSyncQueue('staff_availability', id, 'INSERT');
    return id;
  }

  Future<void> updateStaffAvailability(StaffAvailability availability) async {
    final db = await database;
    await db.update(
      'staff_availability',
      availability.toMap(),
      where: 'id = ?',
      whereArgs: [availability.id],
    );
    await _addToSyncQueue('staff_availability', availability.id!, 'UPDATE');
  }

  Future<List<StaffAvailability>> getStaffAvailability(int employeeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'staff_availability',
      where: 'deleted = 0 AND employee_id = ?',
      whereArgs: [employeeId],
    );
    return List.generate(maps.length, (i) => StaffAvailability.fromMap(maps[i]));
  }


  // --- CUSTOM ORDERS ---

  Future<int> insertCustomOrder(CustomOrder order, List<CustomOrderItem> items) async {
    final db = await database;
    int orderId = 0;
    await db.transaction((txn) async {
      orderId = await txn.insert('custom_orders', order.toMap());
      for (var item in items) {
        final itemMap = item.copyWith(orderId: orderId).toMap();
        await txn.insert('custom_order_items', itemMap);
      }
    });
    return orderId;
  }

  Future<List<CustomOrder>> getCustomOrders(int branchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_orders',
      where: 'branch_id = ? AND deleted = 0',
      whereArgs: [branchId],
      orderBy: 'due_date ASC',
    );
    return maps.map((e) => CustomOrder.fromMap(e)).toList();
  }

  Future<List<CustomOrderItem>> getCustomOrderItems(int orderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_order_items',
      where: 'order_id = ? AND deleted = 0',
      whereArgs: [orderId],
    );
    return maps.map((e) => CustomOrderItem.fromMap(e)).toList();
  }

  Future<void> updateCustomOrderStatus(int orderId, String status) async {
    final db = await database;
    await db.update(
      'custom_orders',
      {'status': status, 'updated_at': DateTime.now().toIso8601String(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
  
  Future<void> updateCustomOrderDepositPaid(int orderId, int depositPaid) async {
    final db = await database;
    await db.update(
      'custom_orders',
      {'deposit_paid': depositPaid, 'updated_at': DateTime.now().toIso8601String(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> deleteCustomOrder(int id) async {
    final db = await database;
    await db.update(
      'custom_orders',
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String(), 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
