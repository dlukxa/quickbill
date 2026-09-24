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

  /// Logs comprehensive hardware, OS, and runtime diagnostic metadata at application launch.
  /// Strictly omits sensitive user data, passwords, and private financial tokens.
  static void logSystemInfo({required String version}) {
    log('====================================================');
    log('QuickBill POS Application Launch - Version $version');
    log('====================================================');
    try {
      log('Platform: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
      log('Dart Runtime: ${Platform.version}');
      log('Executable: ${Platform.resolvedExecutable}');
      if (Platform.isWindows) {
        final cpuId = Platform.environment['PROCESSOR_IDENTIFIER'] ?? 'Unknown CPU';
        final cpuArch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'x64';
        final cpuCores = Platform.environment['NUMBER_OF_PROCESSORS'] ?? 'Unknown cores';
        log('CPU Architecture: $cpuArch | Cores: $cpuCores');
        log('CPU Identifier: $cpuId');
        log('Renderer / Graphics Engine: Flutter Windows Engine (Direct3D 11/12 via ANGLE / Skia)');
      } else {
        log('Renderer: Flutter Standard Platform Engine');
      }
      log('Startup diagnostic log destination: ${getLogFilePath()}');
    } catch (e) {
      log('Notice retrieving system information: $e');
    }
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
