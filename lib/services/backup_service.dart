import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'database_service.dart';
import 'auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart' as import_main;
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';

final latestCloudBackupProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final backups = await BackupService.instance.getCloudBackups();
    if (backups.isNotEmpty) {
      return backups.first;
    }
  } catch (e) {
    debugPrint('Error getting latest cloud backup: $e');
  }
  return null;
});

final cloudBackupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await BackupService.instance.getCloudBackups();
  } catch (e) {
    debugPrint('Error getting cloud backups list: $e');
    return [];
  }
});

final localBackupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await BackupService.instance.getLocalBackupHistory();
  } catch (e) {
    debugPrint('Error getting local backups list: $e');
    return [];
  }
});

class BackupService {
  static final BackupService instance = BackupService._internal();

  BackupService._internal();

  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Gets the dedicated persistent directory for local SQLite snapshots.
  Future<Directory> _getBackupsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(join(docsDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Creates a safe, non-locking SQLite snapshot using VACUUM INTO.
  /// Retains the last 10 snapshots to prevent unbounded disk usage.
  Future<File?> createLocalSnapshot({String prefix = 'snapshot'}) async {
    try {
      final backupsDir = await _getBackupsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'quickbill_${prefix}_$timestamp.db';
      final backupPath = join(backupsDir.path, backupFileName);

      final db = await DatabaseService.instance.database;
      await db.execute("VACUUM INTO '$backupPath'");

      // Clean up old snapshots if count exceeds 15
      final files = backupsDir.listSync().whereType<File>().toList();
      if (files.length > 15) {
        files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        for (var i = 0; i < files.length - 15; i++) {
          try {
            await files[i].delete();
          } catch (_) {}
        }
      }

      return File(backupPath);
    } catch (e) {
      debugPrint('Error creating local snapshot ($prefix): $e');
      return null;
    }
  }

  /// Runs automated daily backup if not already completed today.
  Future<void> runDailyAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastAutoDate = prefs.getString('last_auto_backup_date');

      if (lastAutoDate == todayStr) {
        return; // Already backed up today
      }

      debugPrint('📦 Starting automated daily backup for $todayStr...');
      final localSnapshot = await createLocalSnapshot(prefix: 'daily');

      if (localSnapshot != null) {
        await prefs.setString('last_auto_backup_date', todayStr);
        debugPrint('✅ Automated daily backup completed: ${localSnapshot.path}');
      }
    } catch (e) {
      debugPrint('⚠️ Daily auto-backup failed: $e');
    }
  }

  /// Retrieves list of all persistent local snapshots.
  Future<List<Map<String, dynamic>>> getLocalBackupHistory() async {
    try {
      final backupsDir = await _getBackupsDirectory();
      final files = backupsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.db')).toList();

      final List<Map<String, dynamic>> results = [];
      for (final f in files) {
        final stat = f.statSync();
        results.add({
          'name': basename(f.path),
          'path': f.path,
          'size': stat.size,
          'created': stat.modified,
          'file': f,
        });
      }

      results.sort((a, b) => (b['created'] as DateTime).compareTo(a['created'] as DateTime));
      return results;
    } catch (e) {
      debugPrint('Error getting local backup history: $e');
      return [];
    }
  }

  /// Validates SQLite database integrity.
  Future<bool> validateDatabaseIntegrity(String dbPath) async {
    try {
      final db = await openDatabase(dbPath, readOnly: true);
      final check = await db.rawQuery('PRAGMA integrity_check;');
      await db.close();
      if (check.isNotEmpty && check.first.values.first == 'ok') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Database integrity check failed: $e');
      return false;
    }
  }

  Future<void> createBackup(BuildContext context) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final backupFileName = 'quickbill_backup_$timestamp.db';
      
      final tempDir = Directory.systemTemp;
      final tempPath = join(tempDir.path, backupFileName);
      
      final db = await DatabaseService.instance.database;
      await db.execute("VACUUM INTO '$tempPath'");
      
      // Also preserve in local persistent backups
      await createLocalSnapshot(prefix: 'manual');

      final xFile = XFile(tempPath);
      
      await Share.shareXFiles(
        [xFile],
        text: 'QuickBill Database Backup ($timestamp)',
        subject: 'QuickBill Backup',
      );
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> restoreBackup(BuildContext context) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled
      }

      final backupPath = result.files.single.path!;
      final backupFile = File(backupPath);

      // Confirm dialog
      if (!context.mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Database?'),
          content: const Text(
            'This will replace your current data with the selected backup. A safety backup of your current data will be created automatically.\n\nThe app will restart after restore.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RESTORE'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 1. CREATE PRE-RESTORE SAFETY SNAPSHOT FIRST
      await createLocalSnapshot(prefix: 'pre_restore_safety');

      // 2. Perform Restore
      final dbFolder = await getDatabasesPath();
      final dbPath = join(dbFolder, 'quickbill.db');
      
      await DatabaseService.instance.close();
      
      final dbFile = File(dbPath);
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');
      
      if (await dbFile.exists()) await dbFile.delete();
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      
      await backupFile.copy(dbPath);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore successful. Restarting app...')),
        );
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (context.mounted) {
            import_main.RestartWidget.restartApp(context);
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Format byte size to human readable string
  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// List all database backups stored in the cloud for the active shop.
  Future<List<Map<String, dynamic>>> getCloudBackups() async {
    if (!await _hasInternetAccess()) {
      return [];
    }
    final shopUid = await AuthService.instance.getShopUid();
    if (shopUid == null) return [];

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(shopUid)
          .child('backups');
      final listResult = await storageRef.listAll();
      
      final List<Map<String, dynamic>> backups = [];
      for (var item in listResult.items) {
        try {
          final metadata = await item.getMetadata();
          backups.add({
            'name': item.name,
            'path': item.fullPath,
            'size': metadata.size ?? 0,
            'created': metadata.timeCreated ?? DateTime.now(),
            'ref': item,
          });
        } catch (e) {
          debugPrint('Error getting metadata for backup ${item.name}: $e');
        }
      }
      backups.sort((a, b) => (b['created'] as DateTime).compareTo(a['created'] as DateTime));
      return backups;
    } catch (e) {
      debugPrint('Error listing cloud backups: $e');
      return [];
    }
  }

  /// Performs the raw file download and SQLite database overwrite with pre-restore safety snapshot.
  Future<void> performRawBackupRestore(Reference cloudRef) async {
    if (!await _hasInternetAccess()) {
      throw Exception('No internet access to download cloud backup.');
    }

    // 1. TAKE PRE-RESTORE SAFETY SNAPSHOT BEFORE TOUCHING CURRENT DATA
    await createLocalSnapshot(prefix: 'pre_cloud_restore_safety');

    final tempDir = Directory.systemTemp;
    final tempFile = File(join(tempDir.path, 'downloaded_backup_temp.db'));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      await cloudRef.writeToFile(tempFile);

      final dbFolder = await getDatabasesPath();
      final dbPath = join(dbFolder, 'quickbill.db');
      
      await DatabaseService.instance.close();
      
      final dbFile = File(dbPath);
      final walFile = File('$dbPath-wal');
      final shmFile = File('$dbPath-shm');
      
      if (await dbFile.exists()) await dbFile.delete();
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      
      await tempFile.copy(dbPath);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Download and restore a database backup from the cloud.
  Future<void> restoreCloudBackup(BuildContext context, Reference cloudRef) async {
    try {
      if (!context.mounted) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Cloud Backup?'),
          content: const Text(
            'This will download this cloud backup and replace your current database on this device.\n\nA safety backup of your current data will be saved before restoring.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RESTORE'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final progressNotifier = ValueNotifier<String>('Downloading and restoring backup...');

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: progressNotifier,
                  builder: (context, value, child) => Text(value),
                ),
              ),
            ],
          ),
        ),
      );

      await performRawBackupRestore(cloudRef);

      progressNotifier.value = 'Syncing latest live data...';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_pull_timestamp');
      
      await SyncService.instance.syncNow(
        onProgress: (status, _) {
          progressNotifier.value = status;
        },
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore and sync completed successfully!')),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cloud restore failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
