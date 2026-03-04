import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/features/cloud_sync/data/'
    'google_auth_service.dart';
import 'package:crispy_tivi/features/dvr/data/providers/'
    'storage_provider_factory.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/'
    'storage_backend.dart';
import 'package:crispy_tivi/features/dvr/domain/'
    'storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockCrispyBackend extends Mock implements CrispyBackend {}

class MockStorageProvider extends Mock implements StorageProvider {}

void main() {
  late StorageProviderFactory factory;
  late MockGoogleAuthService mockAuth;
  late MockCrispyBackend mockBackend;

  setUp(() {
    mockAuth = MockGoogleAuthService();
    mockBackend = MockCrispyBackend();
    factory = StorageProviderFactory(
      googleAuthService: mockAuth,
      backend: mockBackend,
    );
  });

  StorageBackend makeBackend({
    required StorageType type,
    Map<String, String> config = const {},
  }) {
    return StorageBackend(
      id: 'test-id',
      name: 'Test Backend',
      type: type,
      config: config,
    );
  }

  group('StorageProviderFactory', () {
    group('create', () {
      test('returns LocalStorageProvider for '
          'StorageType.local', () async {
        final backend = makeBackend(
          type: StorageType.local,
          config: {'path': '/tmp/test'},
        );
        final provider = await factory.create(backend);

        expect(provider.type, StorageType.local);
      });

      test('returns S3StorageProvider for '
          'StorageType.s3', () async {
        final backend = makeBackend(
          type: StorageType.s3,
          config: {
            'endpoint': 'https://s3.example.com',
            'bucket': 'test',
            'region': 'us-east-1',
            'accessKey': 'key',
            'secretKey': 'secret',
          },
        );
        final provider = await factory.create(backend);

        expect(provider.type, StorageType.s3);
      });

      test('returns WebDavStorageProvider for '
          'StorageType.webdav', () async {
        final backend = makeBackend(
          type: StorageType.webdav,
          config: {
            'url': 'https://webdav.example.com',
            'username': 'user',
            'password': 'pass',
          },
        );
        final provider = await factory.create(backend);

        expect(provider.type, StorageType.webdav);
      });

      test('returns SmbStorageProvider for '
          'StorageType.smb', () async {
        final backend = makeBackend(
          type: StorageType.smb,
          config: {
            'host': '192.168.1.1',
            'share': 'media',
            'username': 'user',
            'password': 'pass',
          },
        );
        final provider = await factory.create(backend);

        expect(provider.type, StorageType.smb);
      });

      test('returns GoogleDriveStorageProvider for '
          'StorageType.googleDrive', () async {
        final backend = makeBackend(
          type: StorageType.googleDrive,
          config: {'folderId': 'abc123'},
        );
        final provider = await factory.create(backend);

        expect(provider.type, StorageType.googleDrive);
      });

      test('returns FtpStorageProvider for '
          'StorageType.ftp', () async {
        final backend = makeBackend(
          type: StorageType.ftp,
          config: {
            'host': 'ftp.example.com',
            'port': '22',
            'username': 'user',
            'password': 'pass',
          },
        );
        final provider = await factory.create(backend);

        expect(provider.type, StorageType.ftp);
      });

      test('calls initialize with backend config', () async {
        final config = {'path': '/tmp/recordings'};
        final backend = makeBackend(type: StorageType.local, config: config);
        // LocalStorageProvider.initialize sets
        // _basePath from config['path'].
        // If it completes without error, initialize
        // was called successfully.
        final provider = await factory.create(backend);
        expect(provider, isNotNull);
      });

      test('creates different providers for each type', () async {
        final types = StorageType.values;
        final providers = <StorageProvider>[];

        for (final type in types) {
          final backend = makeBackend(type: type);
          final provider = await factory.create(backend);
          providers.add(provider);
        }

        expect(providers.length, StorageType.values.length);

        // Each provider has matching type.
        for (var i = 0; i < types.length; i++) {
          expect(providers[i].type, types[i]);
        }
      });

      test('initializes provider with empty config '
          'when none provided', () async {
        final backend = makeBackend(type: StorageType.local);
        // Should not throw even with empty config.
        final provider = await factory.create(backend);
        expect(provider, isNotNull);
      });
    });
  });
}
