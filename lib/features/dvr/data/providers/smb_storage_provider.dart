import 'dart:io';

import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';

/// SMB/NAS storage provider.
///
/// Uses mapped network drive paths on desktop and direct
/// UNC/SMB paths where supported.
/// Config keys: host, share, username, password, pathPrefix.
class SmbStorageProvider implements StorageProvider {
  @override
  StorageType get type => StorageType.smb;

  late String _host;
  late String _share;
  late String _pathPrefix;
  late String _basePath;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _host = config['host'] ?? '';
    _share = config['share'] ?? '';
    _pathPrefix = config['pathPrefix'] ?? 'recordings';

    // Build base path depending on platform.
    if (Platform.isWindows) {
      // UNC path: \\host\share\prefix
      _basePath = '\\\\$_host\\$_share\\$_pathPrefix';
    } else {
      // Unix SMB mount path or CIFS mount point.
      _basePath = '/mnt/$_share/$_pathPrefix';
    }
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
    final source = File(localPath);
    final total = await source.length();
    final destPath = _resolvePath(remotePath);

    // Ensure directory exists.
    final destDir = Directory(
      destPath.substring(0, destPath.lastIndexOf(Platform.pathSeparator)),
    );
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
    final source = File(_resolvePath(remotePath));
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
    // SMB files can be accessed via local path.
    return Future.value(_resolvePath(remotePath));
  }

  @override
  Future<List<RemoteFile>> listFiles(String path) async {
    final dirPath = _resolvePath(path);
    final dir = Directory(dirPath);

    if (!await dir.exists()) return [];

    final entries = await dir.list().toList();
    final files = <RemoteFile>[];

    for (final entity in entries) {
      final stat = await entity.stat();
      final name = entity.path.split(Platform.pathSeparator).last;

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
    final file = File(_resolvePath(remotePath));
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
    // No resources to release for SMB file access.
  }

  String _resolvePath(String relativePath) {
    final sep = Platform.isWindows ? '\\' : '/';
    final cleaned = relativePath.replaceAll('/', sep).replaceAll('\\', sep);
    return '$_basePath$sep$cleaned';
  }
}
