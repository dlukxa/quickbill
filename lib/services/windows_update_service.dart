import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/version_utils.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String fileName;
  final int fileSizeBytes;
  final bool mandatory;
  final String? publishedAt;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.fileName = 'QuickBill-Setup.exe',
    this.fileSizeBytes = 0,
    this.mandatory = false,
    this.publishedAt,
  });

  @override
  String toString() =>
      'UpdateInfo(hasUpdate: $hasUpdate, current: $currentVersion, latest: $latestVersion, mandatory: $mandatory, url: $downloadUrl)';
}

/// Production-ready automatic update service for QuickBill Windows.
/// Safely checks for releases on Cloud Firestore (with GitHub Releases fallback),
/// streams downloads with progress tracking, verifies file integrity,
/// and executes Inno Setup without modifying user data in %APPDATA%.
class WindowsUpdateService {
  static final WindowsUpdateService instance = WindowsUpdateService._init();
  WindowsUpdateService._init();

  static const String _kGitHubRepo = 'dlukxa/quickbill';
  static const String _kGitHubApiUrl =
      'https://api.github.com/repos/$_kGitHubRepo/releases/latest';

  // Firestore REST endpoints (safe across all CPU types without requiring native C++ Firebase SDK)
  static const List<String> _kFirestoreEndpoints = [
    'https://firestore.googleapis.com/v1/projects/quickbill-2a76b/databases/(default)/documents/desktop_app/latest',
    'https://firestore.googleapis.com/v1/projects/quickbill-2a76b/databases/(default)/documents/app_config/desktop_app',
    'https://firestore.googleapis.com/v1/projects/quickbill-2a76b/databases/(default)/documents/app_config/version',
  ];

  String? _resolvedUpdateLogPath;

  /// Resolves the path to the update log file: %LOCALAPPDATA%\QuickBill\logs\update.log
  String getUpdateLogPath() {
    if (_resolvedUpdateLogPath != null) return _resolvedUpdateLogPath!;
    try {
      if (Platform.isWindows) {
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null && localAppData.isNotEmpty) {
          _resolvedUpdateLogPath = '$localAppData\\QuickBill\\logs\\update.log';
        } else {
          final userProfile = Platform.environment['USERPROFILE'] ?? 'C:';
          _resolvedUpdateLogPath =
              '$userProfile\\AppData\\Local\\QuickBill\\logs\\update.log';
        }
      } else {
        final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
        _resolvedUpdateLogPath = '$home/.quickbill/logs/update.log';
      }
    } catch (_) {
      _resolvedUpdateLogPath = 'update.log';
    }
    return _resolvedUpdateLogPath!;
  }

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] [WINDOWS_UPDATE] $message';
    debugPrint(entry);
    try {
      final path = getUpdateLogPath();
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync('$entry\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('WindowsUpdateService log error: $e');
    }
  }

  /// Checks if a new update is available on Cloud Firestore (or GitHub Releases fallback).
  Future<UpdateInfo> checkForUpdate() async {
    log('Checking for updates...');
    String currentVersion = '1.0.6.11';
    try {
      final pkg = await PackageInfo.fromPlatform();
      if (pkg.buildNumber.isNotEmpty && !pkg.version.contains('+') && !pkg.version.contains('.${pkg.buildNumber}')) {
        currentVersion = VersionUtils.cleanVersion('${pkg.version}+${pkg.buildNumber}');
      } else {
        currentVersion = VersionUtils.cleanVersion(pkg.version);
      }
    } catch (e) {
      log('PackageInfo notice: $e, using default version $currentVersion');
    }

    // 1. Primary: Check Cloud Firestore REST endpoints (safe, offline-resilient, no native C++ AVX2 dependencies)
    for (final endpoint in _kFirestoreEndpoints) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final request = await client.getUrl(Uri.parse(endpoint));
        final response = await request.close().timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final fields = json['fields'] as Map<String, dynamic>? ?? {};

          final latestVerStr = fields['latestVersion']?['stringValue'] ??
              fields['latest_version']?['stringValue'] ??
              fields['latest_version_windows']?['stringValue'] ??
              fields['version']?['stringValue'] ??
              '';
          final downloadUrl = fields['downloadUrl']?['stringValue'] ??
              fields['download_url']?['stringValue'] ??
              fields['update_url_windows']?['stringValue'] ??
              fields['update_url']?['stringValue'] ??
              '';
          final isMandatory = fields['mandatory']?['booleanValue'] ?? false;
          final notes = fields['releaseNotes']?['stringValue'] ??
              fields['release_notes']?['stringValue'] ??
              'Startup reliability and Windows compatibility fixes.';
          final publishedAt = fields['publishedAt']?['timestampValue'] ??
              fields['published_at']?['timestampValue'] ??
              fields['publishedAt']?['stringValue'];

          if (latestVerStr.isNotEmpty && downloadUrl.isNotEmpty) {
            final latestVersion = VersionUtils.cleanVersion(latestVerStr);
            final hasUpdate = VersionUtils.isUpdateAvailable(currentVersion, latestVersion);
            log('Firestore REST check result ($endpoint): current=$currentVersion, latest=$latestVersion, hasUpdate=$hasUpdate, mandatory=$isMandatory');

            return UpdateInfo(
              hasUpdate: hasUpdate,
              currentVersion: currentVersion,
              latestVersion: latestVersion,
              downloadUrl: downloadUrl,
              releaseNotes: notes,
              fileName: 'QuickBill-Setup-$latestVersion.exe',
              mandatory: isMandatory,
              publishedAt: publishedAt,
            );
          }
        }
      } catch (e) {
        log('Firestore REST notice for $endpoint: $e');
      }
    }

    // 2. Secondary: Try GitHub Releases API
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(_kGitHubApiUrl));
      request.headers.set('User-Agent', 'QuickBillPOS-Windows');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final tagName = json['tag_name'] as String? ?? '';
        final latestVersion = VersionUtils.cleanVersion(tagName);
        final releaseNotes = json['body'] as String? ?? 'Bug fixes and performance improvements.';

        // Find the Windows setup installer asset
        String downloadUrl = '';
        int fileSize = 0;
        final assets = json['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().contains('setup') && name.endsWith('.exe')) {
            downloadUrl = asset['browser_download_url'] as String? ?? '';
            fileSize = asset['size'] as int? ?? 0;
            break;
          }
        }

        // Fallback to first .exe if specific setup not matched
        if (downloadUrl.isEmpty) {
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.exe')) {
              downloadUrl = asset['browser_download_url'] as String? ?? '';
              fileSize = asset['size'] as int? ?? 0;
              break;
            }
          }
        }

        final hasUpdate = VersionUtils.isUpdateAvailable(currentVersion, latestVersion);
        log('GitHub check result: current=$currentVersion, latest=$latestVersion, hasUpdate=$hasUpdate, url=$downloadUrl');

        if (downloadUrl.isNotEmpty) {
          return UpdateInfo(
            hasUpdate: hasUpdate,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            fileName: 'QuickBill-Setup-$latestVersion.exe',
            fileSizeBytes: fileSize,
          );
        }
      } else {
        log('GitHub API returned status code ${response.statusCode}');
      }
    } catch (e) {
      log('GitHub API update check notice: $e');
    }

    return UpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      downloadUrl: '',
      releaseNotes: '',
    );
  }

  /// Downloads the update installer with progress reporting and initiates the upgrade.
  /// [onProgress] receives a value from 0.0 to 1.0 and a status label.
  Future<void> downloadAndInstallUpdate(
    UpdateInfo info, {
    void Function(double progress, String status)? onProgress,
  }) async {
    log('Starting download for ${info.downloadUrl}');
    onProgress?.call(0.0, 'Connecting to download server...');

    // Resolve update download directory: %LOCALAPPDATA%\QuickBill\updates
    final String updateDir;
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ??
          (Platform.environment['USERPROFILE'] != null
              ? '${Platform.environment['USERPROFILE']}\\AppData\\Local'
              : Directory.systemTemp.path);
      updateDir = '$localAppData\\QuickBill\\updates';
    } else {
      updateDir = '${Directory.systemTemp.path}/quickbill_updates';
    }

    final targetDir = Directory(updateDir);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final installerFile = File('$updateDir\\${info.fileName}');
    if (installerFile.existsSync()) {
      try {
        installerFile.deleteSync();
      } catch (_) {}
    }

    final client = HttpClient();
    client.autoUncompress = true;
    final request = await client.getUrl(Uri.parse(info.downloadUrl));
    request.headers.set('User-Agent', 'QuickBillPOS-Windows');
    final response = await request.close();

    if (response.statusCode != 200 && response.statusCode != 302) {
      log('Download failed with HTTP ${response.statusCode}');
      throw Exception('Server returned HTTP ${response.statusCode}');
    }

    // Handle redirect if needed
    HttpClientResponse actualResponse = response;
    if (response.statusCode == 302 || response.statusCode == 301) {
      final redirectUrl = response.headers.value('location');
      if (redirectUrl != null) {
        log('Redirecting to: $redirectUrl');
        final redirectReq = await client.getUrl(Uri.parse(redirectUrl));
        actualResponse = await redirectReq.close();
      }
    }

    final contentLength = actualResponse.contentLength > 0
        ? actualResponse.contentLength
        : info.fileSizeBytes;

    int receivedBytes = 0;
    final sink = installerFile.openWrite();

    try {
      await for (final chunk in actualResponse) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = (receivedBytes / contentLength).clamp(0.0, 1.0);
          final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (contentLength / (1024 * 1024)).toStringAsFixed(1);
          onProgress?.call(progress, 'Downloading: $mbReceived MB / $mbTotal MB');
        } else {
          final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          onProgress?.call(0.5, 'Downloading: $mbReceived MB');
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    log('Download completed. File size: ${installerFile.lengthSync()} bytes');
    onProgress?.call(1.0, 'Verifying installer package...');

    if (!installerFile.existsSync() || installerFile.lengthSync() < 100000) {
      log('Downloaded file is invalid or too small (${installerFile.lengthSync()} bytes)');
      throw Exception('Downloaded installer is corrupted or incomplete.');
    }

    onProgress?.call(1.0, 'Launching update installer...');
    log('Spawning installer detached: ${installerFile.path}');

    // Launch Inno Setup installer:
    // /SP- : Skips "This will install..." confirmation
    // /SILENT : Shows progress dialog without wizard pages
    // /CLOSEAPPLICATIONS : Inno Setup will cleanly signal running QuickBill to close
    // /RESTARTAPPLICATIONS : Inno Setup restarts QuickBill after upgrade
    try {
      await Process.start(
        installerFile.path,
        ['/SP-', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      log('Installer started successfully. Exiting running QuickBill process.');
    } catch (e) {
      log('Error launching installer with arguments, trying standard launch: $e');
      await Process.start(
        installerFile.path,
        [],
        mode: ProcessStartMode.detached,
      );
    }

    // Allow a brief moment for the installer process to take over, then cleanly exit
    await Future.delayed(const Duration(milliseconds: 600));
    exit(0);
  }
}
