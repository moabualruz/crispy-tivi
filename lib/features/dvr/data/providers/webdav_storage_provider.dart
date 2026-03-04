import 'dart:io';

import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';

/// WebDAV storage provider (Nextcloud, ownCloud, etc.).
///
/// Config keys: url, username, password, pathPrefix.
class WebDavStorageProvider implements StorageProvider {
  @override
  StorageType get type => StorageType.webdav;

  late webdav.Client _client;
  late String _pathPrefix;

  @override
  Future<void> initialize(Map<String, String> config) async {
    final url = config['url'] ?? '';
    final username = config['username'] ?? '';
    final password = config['password'] ?? '';
    _pathPrefix = config['pathPrefix'] ?? 'recordings';

    _client = webdav.newClient(url, user: username, password: password);
    _client.setConnectTimeout(30000);
    _client.setSendTimeout(0); // No timeout for uploads.
    _client.setReceiveTimeout(0);
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _client.ping();
      return true;
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
    final remoteDir = '$_pathPrefix/';
    // Ensure directory exists.
    try {
      await _client.mkdir(remoteDir);
    } catch (_) {
      // Directory may already exist.
    }

    final file = File(localPath);
    final total = await file.length();

    await _client.writeFromFile(
      localPath,
      '$remoteDir$remotePath',
      onProgress: (sent, _) => onProgress(sent, total),
    );
  }

  @override
  Future<void> download(
    String remotePath,
    String localPath,
    void Function(int received, int total) onProgress,
  ) async {
    await _client.read2File(
      '$_pathPrefix/$remotePath',
      localPath,
      onProgress: (received, total) => onProgress(received, total),
    );
  }

  @override
  Future<String?> getStreamUrl(String remotePath) {
    // WebDAV URLs can be streamed directly with auth.
    // Return the full URL; caller must add auth headers.
    final url = _client.uri;
    return Future.value('$url/$_pathPrefix/$remotePath');
  }

  @override
  Future<List<RemoteFile>> listFiles(String path) async {
    final remotePath = '$_pathPrefix/$path'.replaceAll('//', '/');
    final files = await _client.readDir(remotePath);

    return files.map((f) {
      return RemoteFile(
        name: f.name ?? '',
        path: f.path ?? '',
        sizeBytes: f.size ?? 0,
        modifiedAt: f.mTime ?? DateTime.now(),
        isDirectory: f.isDir ?? false,
      );
    }).toList();
  }

  @override
  Future<void> delete(String remotePath) async {
    await _client.remove('$_pathPrefix/$remotePath');
  }

  @override
  Future<int> getUsedSpace() async {
    final files = await listFiles('');
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  @override
  Future<void> dispose() async {
    // WebDAV client has no explicit dispose.
  }
}
