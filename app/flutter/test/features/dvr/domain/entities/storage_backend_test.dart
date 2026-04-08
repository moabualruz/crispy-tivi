import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/storage_backend.dart';

void main() {
  group('StorageType', () {
    test('has exactly six values', () {
      expect(StorageType.values.length, 6);
    });

    test('contains all expected values', () {
      expect(
        StorageType.values,
        containsAll([
          StorageType.local,
          StorageType.s3,
          StorageType.webdav,
          StorageType.smb,
          StorageType.googleDrive,
          StorageType.ftp,
        ]),
      );
    });

    test('each value has a human-readable label', () {
      expect(StorageType.local.label, 'Local');
      expect(StorageType.s3.label, 'S3-Compatible');
      expect(StorageType.webdav.label, 'WebDAV');
      expect(StorageType.smb.label, 'SMB / NAS');
      expect(StorageType.googleDrive.label, 'Google Drive');
      expect(StorageType.ftp.label, 'FTP / SFTP');
    });

    test('no label is empty', () {
      for (final type in StorageType.values) {
        expect(
          type.label,
          isNotEmpty,
          reason:
              '${type.name} should have a '
              'non-empty label',
        );
      }
    });
  });

  group('StorageBackend', () {
    StorageBackend createSubject({
      String id = 'backend-1',
      String name = 'My NAS',
      StorageType type = StorageType.smb,
      Map<String, String> config = const {
        'host': '192.168.1.100',
        'share': 'recordings',
      },
      bool isDefault = false,
    }) {
      return StorageBackend(
        id: id,
        name: name,
        type: type,
        config: config,
        isDefault: isDefault,
      );
    }

    group('constructor', () {
      test('creates with required fields', () {
        const backend = StorageBackend(
          id: 'b1',
          name: 'Test',
          type: StorageType.local,
        );

        expect(backend.id, 'b1');
        expect(backend.name, 'Test');
        expect(backend.type, StorageType.local);
        expect(backend.config, isEmpty);
        expect(backend.isDefault, isFalse);
      });

      test('creates with all fields', () {
        final backend = createSubject(isDefault: true);

        expect(backend.id, 'backend-1');
        expect(backend.name, 'My NAS');
        expect(backend.type, StorageType.smb);
        expect(backend.config, hasLength(2));
        expect(backend.isDefault, isTrue);
      });

      test('config defaults to empty map', () {
        const backend = StorageBackend(
          id: 'b1',
          name: 'Test',
          type: StorageType.s3,
        );

        expect(backend.config, equals(const {}));
      });

      test('isDefault defaults to false', () {
        const backend = StorageBackend(
          id: 'b1',
          name: 'Test',
          type: StorageType.webdav,
        );

        expect(backend.isDefault, isFalse);
      });
    });

    group('get', () {
      test('returns value for existing key', () {
        final backend = createSubject();

        expect(backend.get('host'), '192.168.1.100');
        expect(backend.get('share'), 'recordings');
      });

      test('returns empty string for missing key', () {
        final backend = createSubject();

        expect(backend.get('nonexistent'), '');
      });

      test('returns empty string for missing key '
          'with empty config', () {
        const backend = StorageBackend(
          id: 'b1',
          name: 'Test',
          type: StorageType.local,
        );

        expect(backend.get('anything'), '');
      });
    });

    group('copyWith', () {
      test('returns identical when no params given', () {
        final backend = createSubject(isDefault: true);
        final copy = backend.copyWith();

        expect(copy.id, backend.id);
        expect(copy.name, backend.name);
        expect(copy.type, backend.type);
        expect(copy.config, backend.config);
        expect(copy.isDefault, backend.isDefault);
      });

      test('overrides id', () {
        final backend = createSubject();
        final copy = backend.copyWith(id: 'new-id');

        expect(copy.id, 'new-id');
        expect(copy.name, backend.name);
      });

      test('overrides name', () {
        final backend = createSubject();
        final copy = backend.copyWith(name: 'Renamed');

        expect(copy.name, 'Renamed');
        expect(copy.id, backend.id);
      });

      test('overrides type', () {
        final backend = createSubject();
        final copy = backend.copyWith(type: StorageType.ftp);

        expect(copy.type, StorageType.ftp);
        expect(copy.id, backend.id);
      });

      test('overrides config', () {
        final backend = createSubject();
        final copy = backend.copyWith(config: {'bucket': 'my-bucket'});

        expect(copy.config, {'bucket': 'my-bucket'});
        expect(copy.id, backend.id);
      });

      test('overrides isDefault', () {
        final backend = createSubject();
        final copy = backend.copyWith(isDefault: true);

        expect(copy.isDefault, isTrue);
        expect(backend.isDefault, isFalse);
      });

      test('overrides multiple fields at once', () {
        final backend = createSubject();
        final copy = backend.copyWith(
          name: 'Updated',
          type: StorageType.s3,
          isDefault: true,
        );

        expect(copy.name, 'Updated');
        expect(copy.type, StorageType.s3);
        expect(copy.isDefault, isTrue);
        expect(copy.id, backend.id);
      });
    });

    group('equality', () {
      test('equal when ids match', () {
        final a = createSubject(id: 'same-id', name: 'Name A');
        final b = createSubject(id: 'same-id', name: 'Name B');

        expect(a, equals(b));
      });

      test('not equal when ids differ', () {
        final a = createSubject(id: 'id-1');
        final b = createSubject(id: 'id-2');

        expect(a, isNot(equals(b)));
      });

      test('equal to itself (identity)', () {
        final backend = createSubject();

        expect(backend, equals(backend));
      });

      test('not equal to object of different type', () {
        final backend = createSubject();

        expect(backend, isNot(equals('not a backend')));
      });
    });

    group('hashCode', () {
      test('equal for same id', () {
        final a = createSubject(id: 'same-id', name: 'A');
        final b = createSubject(id: 'same-id', name: 'B');

        expect(a.hashCode, equals(b.hashCode));
      });

      test('typically differs for different ids', () {
        final a = createSubject(id: 'id-1');
        final b = createSubject(id: 'id-2');

        // Not guaranteed but highly likely
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });

      test('is consistent across calls', () {
        final backend = createSubject();

        expect(backend.hashCode, equals(backend.hashCode));
      });
    });

    group('toString', () {
      test('includes name and type', () {
        final backend = createSubject(name: 'My NAS', type: StorageType.smb);

        expect(
          backend.toString(),
          'StorageBackend(My NAS, type=StorageType.smb)',
        );
      });

      test('works for all storage types', () {
        for (final type in StorageType.values) {
          final backend = StorageBackend(id: 'test', name: 'Test', type: type);
          final str = backend.toString();

          expect(str, contains('Test'));
          expect(str, contains(type.toString()));
        }
      });
    });
  });
}
