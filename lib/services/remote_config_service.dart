import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService instance = RemoteConfigService._internal();
  RemoteConfigService._internal();

  FirebaseRemoteConfig? get _remoteConfig {
    if (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux))) return null;
    try {
      return FirebaseRemoteConfig.instance;
    } catch (_) {
      return null;
    }
  }

  // Remote Config Parameter Keys
  static const String keyGeminiApiKey = 'gemini_api_key';

  bool _isInitialized = false;

  /// Initialize and fetch the latest configurations from Firebase Remote Config
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!kIsWeb && (Platform.isWindows || Platform.isLinux))) {
      _isInitialized = true;
      return;
    }

    final rc = _remoteConfig;
    if (rc == null) return;

    try {
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );

      // Default fallback values
      await rc.setDefaults({
        keyGeminiApiKey: '',
      });

      // Fetch and activate the latest parameters from cloud
      await rc.fetchAndActivate();
      _isInitialized = true;
      debugPrint('🚀 Firebase Remote Config initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ Firebase Remote Config initialization warning: $e');
    }
  }

  /// Get the current Gemini / Gemma AI API key
  String get geminiApiKey {
    final rc = _remoteConfig;
    if (rc == null) return '';
    try {
      return rc.getString(keyGeminiApiKey).trim();
    } catch (_) {
      return '';
    }
  }

  /// Check if AI Cloud features are enabled (API key provided in Remote Config)
  bool get isAiConfigured {
    return geminiApiKey.isNotEmpty;
  }

  /// Force fetch the latest configuration on demand
  Future<void> fetchLatest() async {
    final rc = _remoteConfig;
    if (rc == null) return;
    try {
      await rc.fetchAndActivate();
    } catch (e) {
      debugPrint('Failed to refresh Remote Config: $e');
    }
  }
}
