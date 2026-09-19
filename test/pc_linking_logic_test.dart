import 'package:flutter_test/flutter_test.dart';
import 'package:quickbill/screens/desktop/link_to_pc_screen.dart';

void main() {
  group('PC Linking Unit Tests', () {
    test('PcLinkingException contains correct type and message', () {
      const ex = PcLinkingException(
        PcLinkingErrorType.sessionNotFound,
        'Session not found on PC.',
      );
      expect(ex.type, PcLinkingErrorType.sessionNotFound);
      expect(ex.message, 'Session not found on PC.');
      expect(ex.toString(), 'Session not found on PC.');
    });

    test('All PcLinkingErrorType values are defined', () {
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.invalidQr));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.notAuthenticated));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.authRequired));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.sessionNotFound));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.sessionExpired));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.alreadyLinked));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.networkError));
      expect(PcLinkingErrorType.values, contains(PcLinkingErrorType.unknown));
    });

    test('QR Code deep-link URI parsing extracts session ID correctly', () {
      const validQrUrl = 'quickbill://link?session=test_session_id_123';
      final uri = Uri.tryParse(validQrUrl);

      expect(uri, isNotNull);
      expect(uri!.scheme, 'quickbill');
      expect(uri.host, 'link');
      expect(uri.queryParameters['session'], 'test_session_id_123');
    });

    test('Invalid QR code formats reject gracefully', () {
      final invalidUrls = [
        'https://quickbill.com/link?session=123',
        'quickbill://other?session=123',
        'quickbill://link',
        'random_text_here',
      ];

      for (final url in invalidUrls) {
        final uri = Uri.tryParse(url);
        final isValid = uri != null &&
            uri.scheme == 'quickbill' &&
            uri.host == 'link' &&
            (uri.queryParameters['session']?.isNotEmpty ?? false);
        expect(isValid, isFalse, reason: 'URL $url should not be accepted as valid PC link QR');
      }
    });

    test('Session expiration TTL logic validates ISO date correctly', () {
      // Past date (expired)
      final pastDate = DateTime.now().subtract(const Duration(minutes: 5));
      final pastIso = pastDate.toIso8601String();
      final parsedPast = DateTime.tryParse(pastIso);
      expect(parsedPast, isNotNull);
      expect(DateTime.now().isAfter(parsedPast!), isTrue);

      // Future date (valid)
      final futureDate = DateTime.now().add(const Duration(minutes: 2));
      final futureIso = futureDate.toIso8601String();
      final parsedFuture = DateTime.tryParse(futureIso);
      expect(parsedFuture, isNotNull);
      expect(DateTime.now().isAfter(parsedFuture!), isFalse);
    });

    test('6-digit code sanitizer trims and strips non-numeric characters', () {
      String sanitize(String raw) => raw.trim().replaceAll(RegExp(r'[^0-9]'), '');

      expect(sanitize(' 123 456 '), '123456');
      expect(sanitize('123-456'), '123456');
      expect(sanitize('abc123456xyz'), '123456');
      expect(sanitize('12345'), isNot(hasLength(6)));
      expect(sanitize('123456'), hasLength(6));
    });
  });
}
