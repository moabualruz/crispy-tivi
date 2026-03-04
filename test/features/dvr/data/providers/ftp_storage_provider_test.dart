import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/data/providers/ftp_storage_provider.dart';

void main() {
  group('FtpStorageProvider Tests', () {
    late FtpStorageProvider provider;

    setUp(() {
      provider = FtpStorageProvider();
    });

    tearDown(() async {
      await provider.dispose();
    });

    test(
      'initializes correctly and testConnection fails gracefully on bad host',
      () async {
        // Setup with a dummy config that will fail to connect
        await provider.initialize({
          'host': '127.0.0.1',
          'port': '9999', // Port nobody uses
          'username': 'foo',
          'password': 'bar',
        });

        // Should return false because SSH connection will fail
        final isConnected = await provider.testConnection();
        expect(isConnected, isFalse);
      },
    );
  });
}
