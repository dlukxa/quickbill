class VersionUtils {
  /// Compares two semantic version strings.
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if they are equal.
  static int compareSemver(String v1, String v2) {
    try {
      final pa = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final pb = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      final maxLength = pa.length > pb.length ? pa.length : pb.length;
      
      for (int i = 0; i < maxLength; i++) {
        final a = i < pa.length ? pa[i] : 0;
        final b = i < pb.length ? pb[i] : 0;
        if (a > b) return 1;
        if (a < b) return -1;
      }
      return 0;
    } catch (e) {
      // Fallback in case of weird format
      return v1.compareTo(v2);
    }
  }

  /// Returns true if [currentVersion] is strictly less than [minVersion].
  static bool isUpdateRequired(String currentVersion, String minVersion) {
    return compareSemver(currentVersion, minVersion) < 0;
  }
}
