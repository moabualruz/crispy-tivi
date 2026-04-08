import 'dart:io';

import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';

/// Local device storage provider (default backend).
///
/// Wraps local filesystem operations with the
/// [StorageProvider] interface for uniform handling.
/// Config keys: path.
class LocalStorageProvider implements StorageProvider {
  @override
  StorageType get type => StorageType.local;

  late String _basePath;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _basePath = config['path'] ?? '';
  }

  @override
  Future<bool> testConnection() async {
    try {
      final dir = Directory(_basePath);
      return await dir.exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> upload(
    String localPath,
    String remotePath,
    void Function(int sent, int total) onProgress,
  ) async {
    // "Upload" to local = copy file.
    final source = File(localPath);
    final total = await source.length();
    final destPath = '$_basePath/$remotePath';

    final destDir = Directory(destPath.substring(0, destPath.lastIndexOf('/')));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final dest = File(destPath);
    final sink = dest.openWrite();
    var sent = 0;

    await for (final chunk in source.openRead()) {
      sink.add(chunk);
      sent += chunk.length;
      onProgress(sent, total);
    }

    await sink.close();
  }

  @override
  Future<void> download(
    String remotePath,
    String localPath,
    void Function(int received, int total) onProgress,
  ) async {
    // "Download" from local = copy file.
    final source = File('$_basePath/$remotePath');
    final total = await source.length();
    final dest = File(localPath);
    final sink = dest.openWrite();
    var received = 0;

    await for (final chunk in source.openRead()) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(received, total);
    }

    await sink.close();
  }

  @override
  Future<String?> getStreamUrl(String remotePath) {
    // Local files can be played directly.
    return Future.value('$_basePath/$remotePath');
  }

  @override
  Future<List<RemoteFile>> listFiles(String path) async {
    final dirPath = '$_basePath/$path'.replaceAll('//', '/');
    final dir = Directory(dirPath);

    if (!await dir.exists()) return [];

    final entries = await dir.list().toList();
    final files = <RemoteFile>[];

    for (final entity in entries) {
      final stat = await entity.stat();
      final name = entity.path.split('/').last;

      files.add(
        RemoteFile(
          name: name,
          path: entity.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          isDirectory: entity is Directory,
        ),
      );
    }

    return files;
  }

  @override
  Future<void> delete(String remotePath) async {
    final file = File('$_basePath/$remotePath');
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<int> getUsedSpace() async {
    final files = await listFiles('');
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  @override
  Future<void> dispose() async {
    // No resources to release.
  }
}
