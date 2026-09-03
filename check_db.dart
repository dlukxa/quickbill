import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // Need to find the path in the simulator. 
  // It's tricky to run this from a script since it's an Android app. 
  print("Use adb to check instead.");
}
