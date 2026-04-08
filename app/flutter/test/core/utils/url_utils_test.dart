import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/utils/url_utils.dart';

void main() {
  group('URL Normalization', () {
    test('BUG-004: normalizes double-преfixed URLs gracefully', () {
      expect(normalizeServerUrl('https://example.com'), 'https://example.com');
      expect(normalizeServerUrl('http://example.com'), 'http://example.com');
    });

    test('adds http:// if no protocol present', () {
      expect(normalizeServerUrl('example.com'), 'http://example.com');
    });

    test('removes trailing slash', () {
      expect(normalizeServerUrl('https://example.com/'), 'https://example.com');
    });
  });
}
