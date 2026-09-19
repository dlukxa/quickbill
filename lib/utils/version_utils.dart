class VersionUtils {
  /// Cleans a version string by stripping leading 'v'/'V' and separating build number.
  static String cleanVersion(String version) {
    var v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    // Remove build metadata (e.g., "1.0.7+11" -> "1.0.7")
    if (v.contains('+')) {
      v = v.split('+').first;
    }
    return v;
  }

  /// Compares two semantic version strings.
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if they are equal.
  static int compareSemver(String v1, String v2) {
    try {
      final cleanV1 = cleanVersion(v1);
      final cleanV2 = cleanVersion(v2);

      final pa = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final pb = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      final maxLength = pa.length > pb.length ? pa.length : pb.length;
      
      for (int i = 0; i < maxLength; i++) {
        final a = i < pa.length ? pa[i] : 0;
        final b = i < pb.length ? pb[i] : 0;
        if (a > b) return 1;
        if (a < b) return -1;
      }
      return 0;
    } catch (e) {
      // Fallback in case of unexpected format
      return v1.compareTo(v2);
    }
  }

  /// Returns true if [currentVersion] is strictly less than [latestVersion].
  static bool isUpdateAvailable(String currentVersion, String latestVersion) {
    return compareSemver(currentVersion, latestVersion) < 0;
  }

  /// Returns true if [currentVersion] is strictly less than [minVersion].
  static bool isUpdateRequired(String currentVersion, String minVersion) {
    return compareSemver(currentVersion, minVersion) < 0;
  }
}
