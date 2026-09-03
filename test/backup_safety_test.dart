import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService — Daily Snapshots & Safety Protocol', () {
    test('Formats file byte sizes accurately for backup history', () {
      final service = BackupService.instance;
      expect(service.formatSize(512), '512 B');
      expect(service.formatSize(1024 * 50), '50.0 KB');
      expect(service.formatSize(1024 * 1024 * 5), '5.0 MB');
    });
  });
}
