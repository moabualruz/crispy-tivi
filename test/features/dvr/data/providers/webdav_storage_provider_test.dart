import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/data/providers/webdav_storage_provider.dart';

void main() {
  group('WebDavStorageProvider Tests', () {
    late WebDavStorageProvider provider;

    setUp(() {
      provider = WebDavStorageProvider();
    });

    tearDown(() async {
      await provider.dispose();
    });

    test(
      'initializes and testConnection fails gracefully on invalid address',
      () async {
        await provider.initialize({
          'url': 'http://127.0.0.1:9999/webdav',
          'username': 'foo',
          'password': 'bar',
        });

        // No server on 9999, so it should fail to connect gracefully
        final isConnected = await provider.testConnection();
        expect(isConnected, isFalse);
      },
    );
  });
}
