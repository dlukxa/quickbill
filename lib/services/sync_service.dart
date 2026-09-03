import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../models/expense.dart';
import '../models/employee.dart';
import '../models/branch.dart';
import '../services/database_service.dart';
import 'auth_service.dart';
import 'stock_alert_service.dart';
import 'local_media_storage_service.dart';
import '../providers/product_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/report_provider.dart';
import '../providers/supplier_provider.dart';
import '../models/discount.dart';
import '../providers/employee_provider.dart';
import '../providers/preference_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/branch_provider.dart';
import '../providers/discount_provider.dart';
import '../providers/purchase_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  SyncService.instance.setRef(ref);
  ref.onDispose(() {
    SyncService.instance.stopSync();
    SyncService.instance.markDisposed();
  });
  return SyncService.instance;
});

final settingsSyncProvider = FutureProvider<void>((ref) async {
  final shopUid = ref.watch(activeShopUidProvider);
  if (shopUid == null) return;
  await ref.read(syncServiceProvider).syncEssentialData();
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);
final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

enum SyncStatus { idle, syncing, error, restoring }

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _syncTimer;
  Timer? _pullTimer;
  bool _isSyncing = false;
  Ref? _ref;

bool _isDisposed = false;

  void setRef(Ref ref) {
    _ref = ref;
    _isDisposed = false;
  }

  void markDisposed() {
    _isDisposed = true;
  }

  T? _safeRead<T>(ProviderListenable<T> provider) {
    if (_ref == null || _isDisposed) return null;
    try {
      return _ref!.read(provider);
    } catch (e) {
      return null;
    }
  }
  void _safeInvalidate(dynamic provider) {
    if (_ref == null || _isDisposed) return;
    try {
      _ref!.invalidate(provider);
    } catch (e) {
      // ignore
    }
  }


  bool _isInitSyncRunning = false;

  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void startSync() {
    if (_ref == null) return;
    
    // Delay initial sync to let the home screen UI finish its initial database reads.
    // Without this delay, sync transactions block all UI database queries, causing ANR.
    Future.delayed(const Duration(seconds: 5), () {
      _initialSync();
    });
    
    // Push local changes every 5 minutes
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      pushLocalChanges();
      uploadScheduledDatabaseBackup();
    });

    // Pull remote changes every 5 minutes (for multi-device sync)
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _pullRemoteChanges();
      if (_ref != null && !_isDisposed) StockAlertService.instance.checkAndNotify(_ref!);
    });
  }

  Future<void> _initialSync() async {
    if (_isInitSyncRunning) return;
    _isInitSyncRunning = true;
    
    try {
      // Sync shop settings first to ensure we know if setup is complete
      await syncSettings();

      // Pull remote changes silently in the background on startup
      await _pullRemoteChanges();
      
      // Also push any pending local changes
      await pushLocalChanges();

      // Upload scheduled database backup to server if needed
      await uploadScheduledDatabaseBackup();
    } finally {
      _isInitSyncRunning = false;
    }
  }

  Future<void> syncSettings() async {
    if (_ref == null) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!await _hasInternetAccess()) {
      debugPrint("SyncSettings aborted: No internet access.");
      return;
    }

    final settingsNotifier = _safeRead(settingsProvider.notifier);
    final settings = _safeRead(settingsProvider);
    final configRef = _firestore.collection('users').doc(shopUid).collection('config').doc('shop_info');

    try {
      // 1. Pull settings from Firestore
      final doc = await configRef.get().timeout(const Duration(seconds: 10));
      if (doc.exists) {
        final data = doc.data()!;
        await settingsNotifier?.updateFromMap(data);
      } else if (settings != null) {
        // 2. If doc doesn't exist, push current local settings
        await configRef.set(settings.toMap(), SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("Error syncing settings: $e");
    }
  }

  Future<void> pushSettings(AppSettings settings) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!await _hasInternetAccess()) {
      debugPrint("PushSettings aborted: No internet access.");
      return;
    }

    try {
      final configRef = _firestore.collection('users').doc(shopUid).collection('config').doc('shop_info');
      await configRef.set(settings.toMap(), SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Error pushing settings: $e");
    }
  }

  void stopSync() {
    _syncTimer?.cancel();
    _pullTimer?.cancel();
  }

  // Helper method for periodic pulls (doesn't set restoring status)
  Future<void> _pullRemoteChanges() async {
    if (_isSyncing || _ref == null) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!await _hasInternetAccess()) {
      debugPrint("Background pull remote changes aborted: No internet access.");
      return;
    }

    final autoSyncEnabled = _safeRead(settingsProvider)?.autoSync ?? false;
    if (!autoSyncEnabled) return;

    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPullStr = prefs.getString('last_pull_timestamp');
      
      // If this is a fresh install (never pulled before) OR the database is completely empty,
      // do NOT run silent background pulls. We want to keep the local database empty 
      // so the "Restore Data" banner stays visible, allowing the user to explicitly choose.
      final isDbEmpty = await DatabaseService.instance.isDatabaseEmpty();
      if (lastPullStr == null || isDbEmpty) {
        _isSyncing = false;
        return;
      }
      
      final lastPull = DateTime.parse(lastPullStr);

      final collections = [
        'branches',
        'employees',
        'services',
        'staff_availability',
        'customers',
        'suppliers',
        'products',
        'product_batches',
        'stock_history',
        'batch_stock_history',
        'customer_payments',
        'employee_shifts',
        'purchases',
        'expenses',
        'sales_returns',
        'appointments',
        'custom_orders',
        'sales',
        'discounts',
      ];

      final db = await DatabaseService.instance.database;
      for (var collection in collections) {
        // Pull changes from the last pull time (with a 5-min overlap for safety)
        final querySnapshot = await _firestore
            .collection('users')
            .doc(shopUid)
            .collection(collection)
            .where('updated_at', isGreaterThan: lastPull.subtract(const Duration(minutes: 5)).toIso8601String())
            .get()
            .timeout(const Duration(seconds: 15));

        if (querySnapshot.docs.isEmpty) continue;

        // Process in chunks to prevent locking the database for too long on massive pulls
        const int chunkSize = 10;
        for (var i = 0; i < querySnapshot.docs.length; i += chunkSize) {
          final int end = (i + chunkSize < querySnapshot.docs.length) ? i + chunkSize : querySnapshot.docs.length;
          final chunk = querySnapshot.docs.sublist(i, end);

          await db.transaction((txn) async {
            for (var doc in chunk) {
              final data = doc.data();
              await DatabaseService.instance.restoreRecord(collection, data, executor: txn);
            }
          });
          
          // Yield for 200ms between chunks to let the UI thread process frames and prevent ANR.
          // 10ms was too short — sqflite re-acquires the lock almost instantly, starving UI queries.
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Yield between collections to allow other DB read operations and refresh UI
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await prefs.setString('last_pull_timestamp', DateTime.now().toIso8601String());

      // Invalidate relevant providers to refresh UI
      _safeInvalidate(productsProvider);
      _safeInvalidate(lowStockProductsProvider);
      _safeInvalidate(salesProvider);
      _safeInvalidate(todaySalesProvider);
      _safeInvalidate(todayStatsProvider);
      _safeInvalidate(customersProvider);
      _safeInvalidate(suppliersProvider);
      _safeInvalidate(inventoryAuditProvider);
      _safeInvalidate(inventoryAlertsProvider);
      _safeInvalidate(employeeListProvider);
      _safeInvalidate(expenseListProvider);
      _safeInvalidate(purchasesProvider);
      _safeInvalidate(discountsProvider);
      _safeInvalidate(trialDaysRemainingProvider);
      _safeRead(branchProvider.notifier)?.refreshBranches();

      // Proactively pre-download product images to local device storage
      unawaited(() async {
        try {
          final allProducts = await DatabaseService.instance.getAllProducts(1);
          await LocalMediaStorageService.instance.prefetchAllProductImages(allProducts);
        } catch (_) {}
      }());
    } catch (e) {
      debugPrint("Background pull sync failed: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncNow({Function(String status, double progress)? onProgress}) async {
    if (_isSyncing) return;
    onProgress?.call('Pushing local changes...', 0.1);
    await pushLocalChanges(isManual: true, onProgress: onProgress);
    await pullRemoteChanges(isManual: true, onProgress: onProgress);
  }

  Future<void> pushLocalChanges({bool isManual = false, Function(String status, double progress)? onProgress}) async {
    if (_isSyncing || _ref == null) return;
    
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!await _hasInternetAccess()) {
      debugPrint("Push local changes aborted: No internet access.");
      _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.error;
      return;
    }

    if (!isManual) {
      final autoSyncEnabled = (_safeRead(settingsProvider)?.autoSync ?? false);
      if (!autoSyncEnabled) return;
    }

    _isSyncing = true;
    _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.syncing;

    try {
      final operations = await DatabaseService.instance.getUnsyncedOperations();
      if (operations.isEmpty) {
        _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.idle;
        _safeRead(lastSyncTimeProvider.notifier)?.state = DateTime.now();
        _isSyncing = false;
        return;
      }

      int i = 0;
      for (var op in operations) {
        final id = op['id'] as int;
        final tableName = op['table_name'] as String;
        final recordId = op['record_id'] as int;
        final operation = op['operation'] as String;

        i++;
        onProgress?.call('Uploading $tableName ($i/${operations.length})...', 0.1 + (0.1 * (i / operations.length)));

        bool success = await _syncRecord(shopUid, tableName, recordId, operation);
        if (success) {
          await DatabaseService.instance.markOperationSynced(id);
        } else {
          // Abort the entire push sync if a record fails (likely due to network timeout)
          // This prevents hammering the network and causing ANRs when offline
          debugPrint("Push sync aborted due to failure syncing $tableName record $recordId.");
          _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.error;
          _isSyncing = false;
          return;
        }
      }

      // Purge old synced operations from sync_queue to prevent it from growing forever
      try {
        await DatabaseService.instance.purgeSyncedOperations();
      } catch (e) {
        debugPrint("Error purging synced operations during sync: $e");
      }

      // Reset state to idle after processing all operations
      _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.idle;
      _safeRead(lastSyncTimeProvider.notifier)?.state = DateTime.now();

      // Trigger daily database backup check sequentially after successful sync processing
      await uploadScheduledDatabaseBackup(isFromSync: true);
    } catch (e) {
      debugPrint("Push sync failed: $e");
      _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  /// Lazy load older historical data for a specific collection
  Future<void> pullHistoricalData(String collection) async {
    if (_ref == null) return;
    
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!await _hasInternetAccess()) {
      debugPrint("Pull historical data for $collection aborted: No internet access.");
      return;
    }

    try {
      final db = await DatabaseService.instance.database;
      
      // Fetch everything older than 7 days that hasn't been pulled yet
      // We rely on Firestore returning the data. If the local DB already has it, restoreRecord handles ConflictAlgorithm.replace
      final querySnapshot = await _firestore
          .collection('users')
          .doc(shopUid)
          .collection(collection)
          .get()
          .timeout(const Duration(seconds: 20));

      if (querySnapshot.docs.isEmpty) return;

      const int chunkSize = 100;
      for (var i = 0; i < querySnapshot.docs.length; i += chunkSize) {
        final int end = (i + chunkSize < querySnapshot.docs.length) ? i + chunkSize : querySnapshot.docs.length;
        final chunk = querySnapshot.docs.sublist(i, end);

        await db.transaction((txn) async {
          for (var doc in chunk) {
            final data = doc.data();
            await DatabaseService.instance.restoreRecord(collection, data, executor: txn);
          }
        });
        
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Invalidate the relevant provider depending on the collection
      if (collection == 'sales') _safeInvalidate(salesProvider);
      if (collection == 'purchases') _safeInvalidate(purchasesProvider);
      if (collection == 'expenses') _safeInvalidate(expenseListProvider);
      if (collection == 'stock_history' || collection == 'batch_stock_history') {
        _safeInvalidate(inventoryAuditProvider);
        _safeInvalidate(inventoryAlertsProvider);
      }
      if (collection == 'sales_returns') {
        // Assume sales provider handles returns or create a specific one
        _safeInvalidate(salesProvider);
        _safeInvalidate(refundsProvider);
      }

    } catch (e) {
      debugPrint("Failed to pull historical data for $collection: $e");
    }
  }

  Future<void> syncEssentialData() async {
    if (_ref == null) return;
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    if (!await _hasInternetAccess()) {
      debugPrint("Sync essential data aborted: No internet access.");
      return;
    }

    // Sync settings
    await syncSettings();

    // Pull branches and employees (critical for Profile Picker). Branches MUST come first due to foreign key constraints on employees.
    try {
      final db = await DatabaseService.instance.database;
      final collections = ['branches', 'employees', 'categories', 'products', 'customers'];
      for (var collection in collections) {
         final querySnapshot = await _firestore
            .collection('users')
            .doc(shopUid)
            .collection(collection)
            .get()
            .timeout(const Duration(seconds: 15));

        if (querySnapshot.docs.isEmpty) continue;

        // Use a single transaction per collection to minimize lock contention.
        // Without this, each restoreRecord call creates an implicit transaction,
        // queuing up dozens of sequential locks that starve UI-thread DB reads
        // (like ensureOwnerExists) and cause ANR.
        await db.transaction((txn) async {
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            await DatabaseService.instance.restoreRecord(collection, data, executor: txn);
          }
        });
        
        // Yield to let UI-thread DB operations execute
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Refresh providers
      _safeInvalidate(employeeListProvider);
      _safeInvalidate(productsProvider);
      _safeInvalidate(customersProvider);
      await _safeRead(branchProvider.notifier)?.refreshBranches();

      // Proactively pre-download product images to local device storage
      unawaited(() async {
        try {
          final allProducts = await DatabaseService.instance.getAllProducts(1);
          await LocalMediaStorageService.instance.prefetchAllProductImages(allProducts);
        } catch (_) {}
      }());
    } catch (e) {
      debugPrint("Essential data sync failed: $e");
    }
  }

  Future<bool> _syncRecord(String uid, String tableName, int recordId, String operation) async {
    try {
      final db = DatabaseService.instance;
      final docRef = _firestore.collection('users').doc(uid).collection(tableName).doc(recordId.toString());

      if (operation == 'DELETE') {
        await docRef.update({
          'deleted': 1, 
          'synced': 1,
          'updated_at': DateTime.now().toIso8601String(),
          'server_timestamp': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 10));
        return true;
      }

      Map<String, dynamic>? data;
      dynamic quantityChange;
      String? parentCollection;
      String? parentId;

      switch (tableName) {
        case 'products':
          final p = await db.getProductById(recordId);
          data = p?.toMap();
          data?.remove('stock');
          break;
        case 'sales':
          final s = await db.getSaleById(recordId);
          data = s?.toJson();
          break;
        case 'customers':
          final c = await db.getCustomerById(recordId);
          data = c?.toMap();
          break;
        case 'suppliers':
          final maps = await (await db.database).query('suppliers', where: 'id = ?', whereArgs: [recordId]);
          if (maps.isNotEmpty) data = Map<String, dynamic>.from(maps.first);
          break;
        case 'product_batches':
          final batchMaps = await (await db.database).query('product_batches', where: 'id = ?', whereArgs: [recordId]);
          if (batchMaps.isNotEmpty) {
            data = Map<String, dynamic>.from(batchMaps.first);
            data.remove('stock');
          }
          break;
        case 'customer_payments':
          final paymentMaps = await (await db.database).query('customer_payments', where: 'id = ?', whereArgs: [recordId]);
          if (paymentMaps.isNotEmpty) data = Map<String, dynamic>.from(paymentMaps.first);
          break;
        case 'stock_history':
          final historyMaps = await (await db.database).query('stock_history', where: 'id = ?', whereArgs: [recordId]);
          if (historyMaps.isNotEmpty) {
            final rec = historyMaps.first;
            data = Map<String, dynamic>.from(rec);
            quantityChange = rec['quantity_change'];
            parentCollection = 'products';
            parentId = rec['product_id'].toString();
          }
          break;
        case 'batch_stock_history':
          final batchHistoryMaps = await (await db.database).query('batch_stock_history', where: 'id = ?', whereArgs: [recordId]);
          if (batchHistoryMaps.isNotEmpty) {
            final rec = batchHistoryMaps.first;
            data = Map<String, dynamic>.from(rec);
            quantityChange = rec['quantity_change'];
            parentCollection = 'product_batches';
            parentId = rec['batch_id'].toString();
          }
          break;
        case 'purchases':
          final purchaseMaps = await (await db.database).query('purchases', where: 'id = ?', whereArgs: [recordId]);
          if (purchaseMaps.isNotEmpty) {
            final items = await (await db.database).query('purchase_items', where: 'purchase_id = ?', whereArgs: [recordId]);
            final purchase = Purchase.fromMap(purchaseMaps.first, items: items.map((m) => PurchaseItem.fromMap(m)).toList());
            data = purchase.toJson();
          }
          break;
        case 'expenses':
          final maps = await (await db.database).query('expenses', where: 'id = ?', whereArgs: [recordId]);
          if (maps.isNotEmpty) data = Expense.fromMap(maps.first).toMap();
          break;
        case 'employees':
          final maps = await (await db.database).query('employees', where: 'id = ?', whereArgs: [recordId]);
          if (maps.isNotEmpty) data = Employee.fromMap(maps.first).toMap();
          break;
        case 'employee_shifts':
          final shifts = await (await db.database).query('employee_shifts', where: 'id = ?', whereArgs: [recordId]);
          if (shifts.isNotEmpty) data = Map<String, dynamic>.from(shifts.first);
          break;
        case 'sales_returns':
          final returns = await (await db.database).query('sales_returns', where: 'id = ?', whereArgs: [recordId]);
          if (returns.isNotEmpty) {
            final returnMap = Map<String, dynamic>.from(returns.first);
            final items = await (await db.database).query('sales_return_items', where: 'return_id = ?', whereArgs: [recordId]);
            returnMap['items'] = items;
            data = returnMap;
          }
          break;
        case 'branches':
          final maps = await (await db.database).query('branches', where: 'id = ?', whereArgs: [recordId]);
          if (maps.isNotEmpty) data = Branch.fromMap(maps.first).toMap();
          break;
        case 'discounts':
          final maps = await (await db.database).query('discounts', where: 'id = ?', whereArgs: [recordId]);
          if (maps.isNotEmpty) data = Discount.fromMap(maps.first).toMap();
          break;
      }

      if (data != null) {
        data['synced'] = 1;
        data['server_timestamp'] = FieldValue.serverTimestamp();
        await docRef.set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
        
        // Apply the delta atomically to parent product/batch if this is a stock history record.
        // Using set+merge so it works even if the parent doc doesn't exist in Firestore yet.
        if (parentCollection != null && parentId != null && quantityChange != null) {
          final parentRef = _firestore
              .collection('users')
              .doc(uid)
              .collection(parentCollection)
              .doc(parentId);
          await parentRef.set(
            {
              'stock': FieldValue.increment(quantityChange),
              'updated_at': DateTime.now().toIso8601String(),
            },
            SetOptions(merge: true),
          ).timeout(const Duration(seconds: 10));
        }
        return true;
      }
      
      debugPrint("Warning: Record $recordId in table $tableName not found locally. Skipping sync.");
      return true;
    } catch (e) {
      debugPrint("Error syncing $tableName record $recordId: $e");
      return false;
    }
  }
  Future<void> pullRemoteChanges({bool isManual = false, bool forceFullRestore = false, Function(String status, double progress)? onProgress}) async {
    debugPrint('=== [SyncService] pullRemoteChanges starting (isManual: $isManual, forceFullRestore: $forceFullRestore) ===');
    if (_isSyncing || _ref == null) {
      debugPrint('=== [SyncService] pullRemoteChanges aborted: _isSyncing=$_isSyncing, _ref=${_ref != null} ===');
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      debugPrint('=== [SyncService] pullRemoteChanges aborted: user is null ===');
      return;
    }
    
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) {
      debugPrint('=== [SyncService] pullRemoteChanges aborted: shopUid is null ===');
      return;
    }
    debugPrint('=== [SyncService] pullRemoteChanges: shopUid = $shopUid ===');

    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('=== [SyncService] pullRemoteChanges: connectivity = $connectivityResult ===');
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('=== [SyncService] pullRemoteChanges aborted: no connectivity ===');
      return;
    }

    if (!await _hasInternetAccess()) {
      debugPrint('=== [SyncService] pullRemoteChanges aborted: no internet access ===');
      _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.error;
      return;
    }

    if (!isManual) {
      final autoSyncEnabled = (_safeRead(settingsProvider)?.autoSync ?? false);
      debugPrint('=== [SyncService] pullRemoteChanges: autoSyncEnabled = $autoSyncEnabled ===');
      if (!autoSyncEnabled) return;
    }

    _isSyncing = true;
    _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.restoring;
    debugPrint('=== [SyncService] pullRemoteChanges: syncStatus set to restoring ===');

    onProgress?.call('Preparing to sync...', 0.2);

    try {
      // Split collections to optimize initial startup speed
      final coreCollections = [
        'branches',
        'employees',
        'services',
        'staff_availability',
        'products',
        'product_batches',
        'discounts',
        'customers',
        'suppliers',
      ];
      
      final historicalCollections = [
        'stock_history',
        'batch_stock_history',
        'customer_payments',
        'employee_shifts',
        'purchases',
        'expenses',
        'appointments',
        'custom_orders',
        'sales',
        'sales_returns',
      ];
      
      final collections = [...coreCollections, ...historicalCollections];

      final prefs = await SharedPreferences.getInstance();
      
      // If forceFullRestore, wipe the lastPull timestamp so ALL records are fetched from Firestore
      if (forceFullRestore) {
        await prefs.remove('last_pull_timestamp');
        debugPrint('=== [SyncService] pullRemoteChanges: forceFullRestore=true, cleared last_pull_timestamp ===');
      }
      
      final lastPullStr = prefs.getString('last_pull_timestamp');
      final lastPull = lastPullStr != null ? DateTime.parse(lastPullStr) : DateTime.now().subtract(const Duration(days: 30));
      debugPrint('=== [SyncService] pullRemoteChanges: lastPull = $lastPull ===');

      debugPrint('=== [SyncService] pullRemoteChanges: opening database... ===');
      final db = await DatabaseService.instance.database;
      debugPrint('=== [SyncService] pullRemoteChanges: database opened ===');
      int processedCount = 0;
      
      for (var collection in collections) {
        debugPrint('=== [SyncService] pullRemoteChanges: processing $collection ($processedCount/${collections.length}) ===');
        onProgress?.call('Syncing $collection...', 0.2 + (0.7 * (processedCount / collections.length)));
        
        Query<Map<String, dynamic>> query = _firestore
            .collection('users')
            .doc(shopUid)
            .collection(collection);

        if (lastPullStr != null) {
          query = query.where('updated_at', isGreaterThan: lastPull.subtract(const Duration(minutes: 5)).toIso8601String());
        } else if (historicalCollections.contains(collection)) {
          // LAZY LOADING: On a fresh install, only download the last 7 days of historical data to keep startup lightning fast.
          // Older data will be fetched on-demand when the user visits those specific screens.
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
          query = query.where('updated_at', isGreaterThan: sevenDaysAgo);
        }

        debugPrint('=== [SyncService] pullRemoteChanges: querying firestore for $collection... ===');
        final querySnapshot = await query.get().timeout(const Duration(seconds: 15));
        debugPrint('=== [SyncService] pullRemoteChanges: firestore returned ${querySnapshot.docs.length} docs for $collection ===');

        processedCount++;
        if (querySnapshot.docs.isEmpty) continue;

        // Process in very small chunks to prevent locking the database for too long on massive pulls,
        // which causes ANRs and sqflite 10-second lock warnings on slower devices.
        const int chunkSize = 15;
        for (var i = 0; i < querySnapshot.docs.length; i += chunkSize) {
          final int end = (i + chunkSize < querySnapshot.docs.length) ? i + chunkSize : querySnapshot.docs.length;
          final chunk = querySnapshot.docs.sublist(i, end);

          debugPrint('=== [SyncService] pullRemoteChanges: writing chunk ${i ~/ chunkSize + 1} (${chunk.length} docs) to db for $collection ===');
          for (var doc in chunk) {
            final data = doc.data();
            await DatabaseService.instance.restoreRecord(collection, data);
          }
          
          // Yield for 200ms between chunks to let the UI thread process frames and prevent ANR
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Yield between collections to allow other DB read operations and refresh UI
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint('=== [SyncService] pullRemoteChanges: invalidating providers... ===');
      // Invalidate all providers to refresh UI
      _safeInvalidate(productsProvider);
      _safeInvalidate(lowStockProductsProvider);
      _safeInvalidate(salesProvider);
      _safeInvalidate(todaySalesProvider);
      _safeInvalidate(todayStatsProvider);
      _safeInvalidate(customersProvider);
      _safeInvalidate(suppliersProvider);
      _safeInvalidate(inventoryAuditProvider);
      _safeInvalidate(inventoryAlertsProvider);
      _safeInvalidate(employeeListProvider);
      _safeInvalidate(expenseListProvider);
      _safeInvalidate(purchasesProvider);
      _safeInvalidate(discountsProvider);
      _safeInvalidate(trialDaysRemainingProvider);
      _safeRead(branchProvider.notifier)?.refreshBranches();

      await prefs.setString('last_pull_timestamp', DateTime.now().toIso8601String());

      _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.idle;
      _safeRead(lastSyncTimeProvider.notifier)?.state = DateTime.now();
      debugPrint('=== [SyncService] pullRemoteChanges: completed successfully ===');
    } catch (e, stack) {
      debugPrint("=== [SyncService] Pull sync failed: $e ===");
      debugPrint(stack.toString());
      _safeRead(syncStatusProvider.notifier)?.state = SyncStatus.error;
    } finally {
      _isSyncing = false;
      debugPrint('=== [SyncService] pullRemoteChanges finished ===');
    }
  }

  /// Uploads the local SQLite database file to Firebase Storage based on the configured frequency.
  Future<void> uploadScheduledDatabaseBackup({bool isFromSync = false}) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;
      
      final shopUid = await AuthService.instance.getShopUid();
      if (shopUid == null) return;

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return;

      if (!await _hasInternetAccess()) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final frequency = prefs.getString('cloud_backup_frequency') ?? 'Daily';
      final lastBackupTimestampStr = prefs.getString('last_db_backup_upload_timestamp');
      final now = DateTime.now();
      
      if (lastBackupTimestampStr != null) {
        final lastBackup = DateTime.tryParse(lastBackupTimestampStr);
        if (lastBackup != null) {
          final difference = now.difference(lastBackup);
          bool shouldBackup = false;
          
          switch (frequency) {
            case '3h':
              shouldBackup = difference.inHours >= 3;
              break;
            case '6h':
              shouldBackup = difference.inHours >= 6;
              break;
            case '12h':
              shouldBackup = difference.inHours >= 12;
              break;
            case 'Daily':
              shouldBackup = difference.inHours >= 24 || now.day != lastBackup.day;
              break;
            case 'Weekly':
              shouldBackup = difference.inDays >= 7;
              break;
            case 'Monthly':
              shouldBackup = difference.inDays >= 30;
              break;
            default:
              shouldBackup = difference.inHours >= 24;
          }
          
          if (!shouldBackup) {
            return; // Not time for a backup yet
          }
        }
      }

      // If active synchronization is already running and this is called externally, abort to prevent resource contention
      if (!isFromSync && _isSyncing) {
        debugPrint('Skipping database backup because synchronization is currently active.');
        return;
      }

      bool setSyncing = false;
      if (!_isSyncing) {
        _isSyncing = true;
        setSyncing = true;
      }

      try {
        final dbFolder = await getDatabasesPath();
        final dbPath = join(dbFolder, 'quickbill.db');
        final dbFile = File(dbPath);

        if (!await dbFile.exists()) {
          debugPrint('Warning: local SQLite database file not found at $dbPath');
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final tempDbFile = File(join(tempDir.path, 'quickbill_backup_temp.db'));
        if (await tempDbFile.exists()) {
          await tempDbFile.delete();
        }

        // Use SQLite's online safe backup command VACUUM INTO instead of File.copy
        final db = await DatabaseService.instance.database;
        await db.execute("VACUUM INTO '${tempDbFile.path}'");

        final timestampStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
        debugPrint('Uploading scheduled database backup to Firebase Storage ($timestampStr) for shop: $shopUid...');
        final backupsRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(shopUid)
            .child('backups');
            
        final storageRef = backupsRef.child('quickbill_backup_$timestampStr.db');

        final uploadTask = storageRef.putFile(tempDbFile);
        await uploadTask;
        
        // Clean up the temporary copy
        if (await tempDbFile.exists()) {
          await tempDbFile.delete();
        }

        await prefs.setString('last_db_backup_upload_timestamp', now.toIso8601String());
        debugPrint('Scheduled database backup uploaded successfully.');
        
        // Auto-cleanup backups older than 30 days
        await _cleanupOldBackups(backupsRef);
        
      } finally {
        if (setSyncing) {
          _isSyncing = false;
        }
      }
    } catch (e) {
      debugPrint('Error uploading scheduled database backup: $e');
    }
  }

  Future<void> _cleanupOldBackups(Reference backupsRef) async {
    try {
      final listResult = await backupsRef.listAll();
      final now = DateTime.now();
      
      for (var item in listResult.items) {
        final metadata = await item.getMetadata();
        final created = metadata.timeCreated;
        if (created != null) {
          if (now.difference(created).inDays > 30) {
            await item.delete();
            debugPrint('Deleted old backup: ${item.name}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }
}
