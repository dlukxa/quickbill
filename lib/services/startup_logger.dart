import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized diagnostic logger for QuickBill POS.
/// Persists logs directly to `%LOCALAPPDATA%\QuickBill\logs\startup.log` on Windows
/// and maintains in-memory history for Developer Diagnostic Screens.
class StartupLogger {
  static final List<String> _inMemoryLogs = [];
  static String? _resolvedLogPath;

  static List<String> get inMemoryLogs => List.unmodifiable(_inMemoryLogs);

  /// Resolves the absolute path to the startup log file.
  /// On Windows: `%LOCALAPPDATA%\QuickBill\logs\startup.log`
  /// Fallback: user home or temp directory.
  static String getLogFilePath() {
    if (_resolvedLogPath != null) return _resolvedLogPath!;
    try {
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          _resolvedLogPath = '$localAppData\\QuickBill\\logs\\startup.log';
        } else {
          final userProfile = Platform.environment['USERPROFILE'] ?? 'C:';
          _resolvedLogPath = '$userProfile\\AppData\\Local\\QuickBill\\logs\\startup.log';
        }
      } else {
        final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
        _resolvedLogPath = '$home/.quickbill/logs/startup.log';
      }
    } catch (_) {
      _resolvedLogPath = 'startup.log';
    }
    return _resolvedLogPath!;
  }

  /// Logs a milestone or diagnostic step.
  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] [STARTUP] $message';
    _inMemoryLogs.add(entry);
    debugPrint(entry);
    _appendToFile(entry);
  }

  /// Logs an error or unhandled exception with its full stack trace.
  static void logError(String context, Object error, [StackTrace? stack]) {
    final timestamp = DateTime.now().toIso8601String();
    final stackStr = stack != null ? '\nSTACK TRACE:\n$stack' : '';
    final entry = '[$timestamp] [ERROR] [$context] $error$stackStr\n----------------------------------------';
    _inMemoryLogs.add(entry);
    debugPrint(entry);
    _appendToFile(entry);
  }

  static void _appendToFile(String text) {
    try {
      final path = getLogFilePath();
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync('$text\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('StartupLogger: write error: $e');
    }
  }
}
