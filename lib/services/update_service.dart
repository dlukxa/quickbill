import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/version_utils.dart';

class UpdateRequiredException implements Exception {
  final String updateUrl;
  final String latestVersion;
  
  UpdateRequiredException(this.updateUrl, this.latestVersion);
  
  @override
  String toString() => 'UpdateRequiredException: $latestVersion ($updateUrl)';
}

class UpdateService {
  static final UpdateService instance = UpdateService._init();
  UpdateService._init();

  /// Checks if the current app version is lower than the minimum required version.
  /// Throws [UpdateRequiredException] if an update is mandatory.
  Future<void> checkUpdateRequired() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('version').get();
      if (!doc.exists || doc.data() == null) return;
      
      final data = doc.data()!;
      // Determine correct versions and URLs based on platform
      String? minVersion;
      String? latestVersion;
      String updateUrl = '';

      if (kIsWeb) {
        minVersion = data['min_version_web'] ?? data['min_version'];
        latestVersion = data['latest_version_web'] ?? data['latest_version'];
        updateUrl = data['update_url_web'] ?? '';
      } else if (Platform.isAndroid) {
        minVersion = data['min_version_android'] ?? data['min_version'];
        latestVersion = data['latest_version_android'] ?? data['latest_version'];
        updateUrl = data['update_url_android'] ?? data['update_url'] ?? '';
      } else if (Platform.isIOS) {
        minVersion = data['min_version_ios'] ?? data['min_version'];
        latestVersion = data['latest_version_ios'] ?? data['latest_version'];
        updateUrl = data['update_url_ios'] ?? data['update_url'] ?? '';
      } else {
        minVersion = data['min_version'];
        latestVersion = data['latest_version'];
        updateUrl = data['update_url'] ?? '';
      }

      if (minVersion == null || minVersion.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (VersionUtils.isUpdateRequired(currentVersion, minVersion)) {
        throw UpdateRequiredException(
          updateUrl, 
          latestVersion ?? minVersion
        );
      }
    } on UpdateRequiredException {
      rethrow; // Rethrow specifically to be caught by the UI
    } catch (e) {
      debugPrint('Update check failed, bypassing: $e');
      // On network failure or missing document, allow app to continue offline
    }
  }
}
