import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final dbPath = '/Users/dlukxa/.local/share/quickbill/quickbill.db';
  final exists = await File(dbPath).exists();
  if(!exists) {
    print("No db at $dbPath");
    return;
  }
  final db = await databaseFactory.openDatabase(dbPath);
  final count = await db.rawQuery('SELECT count(*) as c FROM sync_queue WHERE synced = 0');
  print('Unsynced count: ${count.first['c']}');
}
