import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/utils/version_utils.dart';

void main() {
  group('VersionUtils Tests', () {
    test('cleanVersion correctly strips leading v and build metadata', () {
      expect(VersionUtils.cleanVersion('v1.0.7'), '1.0.7');
      expect(VersionUtils.cleanVersion('V1.0.6.11'), '1.0.6.11');
      expect(VersionUtils.cleanVersion('1.0.7+11'), '1.0.7');
      expect(VersionUtils.cleanVersion('  v1.0.6.10+5  '), '1.0.6.10');
    });

    test('compareSemver handles 3-part and 4-part versions', () {
      // 1.0.6.10 < 1.0.6.11
      expect(VersionUtils.compareSemver('1.0.6.10', '1.0.6.11'), -1);
      expect(VersionUtils.compareSemver('1.0.6.11', '1.0.6.10'), 1);

      // 1.0.6.11 < 1.0.7
      expect(VersionUtils.compareSemver('1.0.6.11', '1.0.7'), -1);
      expect(VersionUtils.compareSemver('1.0.7', '1.0.6.11'), 1);

      // Equal versions with v prefix or build numbers
      expect(VersionUtils.compareSemver('v1.0.7', '1.0.7'), 0);
      expect(VersionUtils.compareSemver('1.0.7+11', 'v1.0.7'), 0);
      expect(VersionUtils.compareSemver('1.0.6.10', '1.0.6.10'), 0);
    });

    test('isUpdateAvailable correctly detects newer releases', () {
      expect(VersionUtils.isUpdateAvailable('1.0.6.10', '1.0.6.11'), isTrue);
      expect(VersionUtils.isUpdateAvailable('1.0.6.10', 'v1.0.7'), isTrue);
      expect(VersionUtils.isUpdateAvailable('1.0.6.11', '1.0.7'), isTrue);
      expect(VersionUtils.isUpdateAvailable('1.0.7', '1.0.6.11'), isFalse);
      expect(VersionUtils.isUpdateAvailable('1.0.7+11', '1.0.7'), isFalse);
    });
  });
}
