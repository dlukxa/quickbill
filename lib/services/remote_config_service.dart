import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService instance = RemoteConfigService._internal();
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Remote Config Parameter Keys
  static const String keyGeminiApiKey = 'gemini_api_key';

  bool _isInitialized = false;

  /// Initialize and fetch the latest configurations from Firebase Remote Config
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );

      // Default fallback values
      await _remoteConfig.setDefaults({
        keyGeminiApiKey: '',
      });

      // Fetch and activate the latest parameters from cloud
      await _remoteConfig.fetchAndActivate();
      _isInitialized = true;
      debugPrint('🚀 Firebase Remote Config initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ Firebase Remote Config initialization warning: $e');
    }
  }

  /// Get the current Gemini / Gemma AI API key
  String get geminiApiKey {
    return _remoteConfig.getString(keyGeminiApiKey).trim();
  }

  /// Check if AI Cloud features are enabled (API key provided in Remote Config)
  bool get isAiConfigured {
    return geminiApiKey.isNotEmpty;
  }

  /// Force fetch the latest configuration on demand
  Future<void> fetchLatest() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Failed to refresh Remote Config: $e');
    }
  }
}
