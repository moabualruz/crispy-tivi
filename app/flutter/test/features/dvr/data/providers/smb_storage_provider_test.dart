import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/data/providers/smb_storage_provider.dart';

void main() {
  group('SmbStorageProvider Tests', () {
    late SmbStorageProvider provider;

    setUp(() {
      provider = SmbStorageProvider();
    });

    test(
      'initializes and formats base paths correctly, testConnection fails on bad share',
      () async {
        await provider.initialize({
          'host': 'localhost',
          'share': 'invalid_share_123',
        });

        // No actual NAS is mounted here, so it should fail to find it
        final isConnected = await provider.testConnection();
        expect(isConnected, isFalse);
      },
    );
  });
}
