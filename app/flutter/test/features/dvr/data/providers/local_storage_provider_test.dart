import 'dart:io';

import 'package:crispy_tivi/features/dvr/data/providers/'
    'local_storage_provider.dart';
import 'package:crispy_tivi/features/dvr/domain/entities/'
    'storage_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalStorageProvider provider;
  late Directory tempDir;

  setUp(() async {
    provider = LocalStorageProvider();
    tempDir = await Directory.systemTemp.createTemp('local_storage_test_');
  });

  tearDown(() async {
    await provider.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalStorageProvider', () {
    group('type', () {
      test('returns StorageType.local', () {
        expect(provider.type, StorageType.local);
      });
    });

    group('initialize', () {
      test('accepts config with path key', () async {
        await provider.initialize({'path': tempDir.path});
        // Should not throw.
      });

      test('accepts empty config (defaults to empty path)', () async {
        await provider.initialize({});
        // Should not throw.
      });

      test('accepts config without path key', () async {
        await provider.initialize({'other': 'value'});
        // Should not throw; path defaults to ''.
      });
    });

    group('testConnection', () {
      test('returns true when base path directory exists', () async {
        await provider.initialize({'path': tempDir.path});
        final result = await provider.testConnection();
        expect(result, isTrue);
      });

      test('returns false when base path does not exist', () async {
        await provider.initialize({'path': '${tempDir.path}/nonexistent'});
        final result = await provider.testConnection();
        expect(result, isFalse);
      });

      test('returns false for empty base path', () async {
        await provider.initialize({});
        final result = await provider.testConnection();
        expect(result, isFalse);
      });
    });

    group('upload', () {
      test('copies file from source to destination', () async {
        await provider.initialize({'path': tempDir.path});

        // Create source file.
        final sourceDir = await Directory.systemTemp.createTemp('upload_src_');
        final sourceFile = File('${sourceDir.path}/test.txt');
        await sourceFile.writeAsString('hello world');

        final progressCalls = <List<int>>[];

        await provider.upload(
          sourceFile.path,
          'subdir/test.txt',
          (sent, total) => progressCalls.add([sent, total]),
        );

        // Verify file was copied.
        final destFile = File('${tempDir.path}/subdir/test.txt');
        expect(await destFile.exists(), isTrue);
        expect(await destFile.readAsString(), 'hello world');

        // Verify progress was reported.
        expect(progressCalls, isNotEmpty);
        expect(progressCalls.last[0], progressCalls.last[1]);

        // Cleanup.
        await sourceDir.delete(recursive: true);
      });

      test('creates destination directories recursively', () async {
        await provider.initialize({'path': tempDir.path});

        final sourceDir = await Directory.systemTemp.createTemp(
          'upload_mkdir_',
        );
        final sourceFile = File('${sourceDir.path}/data.bin');
        await sourceFile.writeAsBytes([1, 2, 3]);

        await provider.upload(sourceFile.path, 'a/b/c/data.bin', (_, _) {});

        final destFile = File('${tempDir.path}/a/b/c/data.bin');
        expect(await destFile.exists(), isTrue);
        expect(await destFile.readAsBytes(), [1, 2, 3]);

        await sourceDir.delete(recursive: true);
      });

      test('reports final sent equals total', () async {
        await provider.initialize({'path': tempDir.path});

        final sourceDir = await Directory.systemTemp.createTemp(
          'upload_progress_',
        );
        final sourceFile = File('${sourceDir.path}/big.txt');
        await sourceFile.writeAsString('abcdef' * 100);

        var lastSent = 0;
        var lastTotal = 0;
        await provider.upload(sourceFile.path, 'big.txt', (sent, total) {
          lastSent = sent;
          lastTotal = total;
        });

        expect(lastSent, lastTotal);
        expect(lastTotal, greaterThan(0));

        await sourceDir.delete(recursive: true);
      });
    });

    group('download', () {
      test('copies file from remote path to local path', () async {
        await provider.initialize({'path': tempDir.path});

        // Create "remote" file.
        final remoteFile = File('${tempDir.path}/remote.txt');
        await remoteFile.writeAsString('remote data');

        final localDir = await Directory.systemTemp.createTemp(
          'download_dest_',
        );
        final localPath = '${localDir.path}/downloaded.txt';

        final progressCalls = <List<int>>[];

        await provider.download(
          'remote.txt',
          localPath,
          (received, total) => progressCalls.add([received, total]),
        );

        final localFile = File(localPath);
        expect(await localFile.exists(), isTrue);
        expect(await localFile.readAsString(), 'remote data');

        expect(progressCalls, isNotEmpty);

        await localDir.delete(recursive: true);
      });

      test('reports progress during download', () async {
        await provider.initialize({'path': tempDir.path});

        final remoteFile = File('${tempDir.path}/progress_test.bin');
        await remoteFile.writeAsBytes(List.filled(1024, 42));

        final localDir = await Directory.systemTemp.createTemp(
          'download_progress_',
        );
        final localPath = '${localDir.path}/result.bin';

        var lastReceived = 0;
        await provider.download('progress_test.bin', localPath, (
          received,
          total,
        ) {
          lastReceived = received;
        });

        expect(lastReceived, greaterThan(0));

        await localDir.delete(recursive: true);
      });
    });

    group('getStreamUrl', () {
      test('returns local file path', () async {
        await provider.initialize({'path': '/storage'});
        final url = await provider.getStreamUrl('movie.mp4');
        expect(url, '/storage/movie.mp4');
      });

      test('combines base path and remote path', () async {
        await provider.initialize({'path': '/base'});
        final url = await provider.getStreamUrl('sub/file.ts');
        expect(url, '/base/sub/file.ts');
      });

      test('returns non-null value', () async {
        await provider.initialize({'path': '/any'});
        final url = await provider.getStreamUrl('test');
        expect(url, isNotNull);
      });
    });

    group('listFiles', () {
      test('returns empty list for nonexistent directory', () async {
        await provider.initialize({'path': tempDir.path});
        final files = await provider.listFiles('nonexistent');
        expect(files, isEmpty);
      });

      test('lists files in directory', () async {
        await provider.initialize({'path': tempDir.path});

        await File('${tempDir.path}/file1.txt').writeAsString('a');
        await File('${tempDir.path}/file2.txt').writeAsString('bb');

        final files = await provider.listFiles('');

        expect(files.length, 2);
        final names = files.map((f) => f.name).toSet();
        expect(names, contains('file1.txt'));
        expect(names, contains('file2.txt'));
      });

      test('includes directories in listing', () async {
        await provider.initialize({'path': tempDir.path});

        await Directory('${tempDir.path}/subdir').create();
        await File('${tempDir.path}/file.txt').writeAsString('x');

        final files = await provider.listFiles('');

        final dirs = files.where((f) => f.isDirectory);
        final regularFiles = files.where((f) => !f.isDirectory);

        expect(dirs.length, 1);
        expect(regularFiles.length, 1);
        expect(dirs.first.name, 'subdir');
      });

      test('returns correct file metadata', () async {
        await provider.initialize({'path': tempDir.path});

        final content = 'hello';
        await File('${tempDir.path}/meta.txt').writeAsString(content);

        final files = await provider.listFiles('');

        expect(files.length, 1);
        expect(files.first.name, 'meta.txt');
        expect(files.first.sizeBytes, greaterThanOrEqualTo(content.length));
        expect(files.first.modifiedAt, isA<DateTime>());
        expect(files.first.isDirectory, isFalse);
      });
    });

    group('delete', () {
      test('deletes existing file', () async {
        await provider.initialize({'path': tempDir.path});

        final file = File('${tempDir.path}/to_delete.txt');
        await file.writeAsString('delete me');
        expect(await file.exists(), isTrue);

        await provider.delete('to_delete.txt');

        expect(await file.exists(), isFalse);
      });

      test('does nothing for nonexistent file', () async {
        await provider.initialize({'path': tempDir.path});

        // Should not throw.
        await provider.delete('does_not_exist.txt');
      });

      test('only deletes targeted file', () async {
        await provider.initialize({'path': tempDir.path});

        await File('${tempDir.path}/keep.txt').writeAsString('keep');
        await File('${tempDir.path}/remove.txt').writeAsString('remove');

        await provider.delete('remove.txt');

        expect(await File('${tempDir.path}/keep.txt').exists(), isTrue);
        expect(await File('${tempDir.path}/remove.txt').exists(), isFalse);
      });
    });

    group('getUsedSpace', () {
      test('returns 0 for empty directory', () async {
        await provider.initialize({'path': tempDir.path});
        final space = await provider.getUsedSpace();
        expect(space, 0);
      });

      test('returns total size of files', () async {
        await provider.initialize({'path': tempDir.path});

        await File('${tempDir.path}/a.bin').writeAsBytes(List.filled(100, 0));
        await File('${tempDir.path}/b.bin').writeAsBytes(List.filled(200, 0));

        final space = await provider.getUsedSpace();

        // getUsedSpace sums top-level file sizes.
        expect(space, greaterThanOrEqualTo(300));
      });

      test('returns non-negative value', () async {
        await provider.initialize({'path': tempDir.path});
        final space = await provider.getUsedSpace();
        expect(space, greaterThanOrEqualTo(0));
      });
    });

    group('dispose', () {
      test('completes without error', () async {
        await provider.initialize({'path': tempDir.path});
        // Should not throw.
        await provider.dispose();
      });

      test('can be called multiple times', () async {
        await provider.initialize({'path': tempDir.path});
        await provider.dispose();
        await provider.dispose();
        // Should not throw.
      });
    });
  });
}
