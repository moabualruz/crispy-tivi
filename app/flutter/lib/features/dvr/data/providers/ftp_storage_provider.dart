import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';

/// SFTP storage provider.
///
/// Uses SSH/SFTP for secure file transfers.
/// Config keys: host, port, username, password,
///   pathPrefix.
class FtpStorageProvider implements StorageProvider {
  @override
  StorageType get type => StorageType.ftp;

  late String _host;
  late int _port;
  late String _username;
  late String _password;
  late String _pathPrefix;
  SSHClient? _client;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _host = config['host'] ?? '';
    _port = int.tryParse(config['port'] ?? '22') ?? 22;
    _username = config['username'] ?? '';
    _password = config['password'] ?? '';
    _pathPrefix = config['pathPrefix'] ?? 'recordings';
  }

  Future<SftpClient> _connect() async {
    _client = SSHClient(
      await SSHSocket.connect(_host, _port),
      username: _username,
      onPasswordRequest: () => _password,
    );
    return await _client!.sftp();
  }

  @override
  Future<bool> testConnection() async {
    try {
      final sftp = await _connect();
      await sftp.listdir('/');
      _client?.close();
      _client = null;
      return true;
    } catch (_) {
      _client?.close();
      _client = null;
      return false;
    }
  }

  @override
  Future<void> upload(
    String localPath,
    String remotePath,
    void Function(int sent, int total) onProgress,
  ) async {
    final sftp = await _connect();

    // Ensure directory exists.
    try {
      await sftp.mkdir(_pathPrefix);
    } catch (_) {
      // May already exist.
    }

    final file = File(localPath);
    final total = await file.length();
    final remoteFile = await sftp.open(
      '$_pathPrefix/$remotePath',
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );

    var sent = 0;
    await for (final chunk in file.openRead()) {
      final bytes = Uint8List.fromList(chunk);
      await remoteFile.write(Stream.value(bytes), offset: sent);
      sent += bytes.length;
      onProgress(sent, total);
    }

    await remoteFile.close();
    _client?.close();
    _client = null;
  }

  @override
  Future<void> download(
    String remotePath,
    String localPath,
    void Function(int received, int total) onProgress,
  ) async {
    final sftp = await _connect();

    // Get file size first.
    final stat = await sftp.stat('$_pathPrefix/$remotePath');
    final total = stat.size ?? 0;

    final remoteFile = await sftp.open(
      '$_pathPrefix/$remotePath',
      mode: SftpFileOpenMode.read,
    );

    final outFile = File(localPath);
    final sink = outFile.openWrite();
    var received = 0;

    await for (final chunk in remoteFile.read()) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(received, total);
    }

    await sink.close();
    await remoteFile.close();
    _client?.close();
    _client = null;
  }

  @override
  Future<String?> getStreamUrl(String remotePath) {
    // SFTP doesn't support direct streaming URLs.
    return Future.value(null);
  }

  @override
  Future<List<RemoteFile>> listFiles(String path) async {
    final sftp = await _connect();
    final remotePath = '$_pathPrefix/$path'.replaceAll('//', '/');

    final entries = await sftp.listdir(remotePath);
    final files =
        entries.where((e) => e.filename != '.' && e.filename != '..').map((e) {
          return RemoteFile(
            name: e.filename,
            path: '$remotePath/${e.filename}',
            sizeBytes: e.attr.size ?? 0,
            modifiedAt:
                e.attr.modifyTime != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                      e.attr.modifyTime! * 1000,
                    )
                    : DateTime.now(),
            isDirectory: e.attr.isDirectory,
          );
        }).toList();

    _client?.close();
    _client = null;
    return files;
  }

  @override
  Future<void> delete(String remotePath) async {
    final sftp = await _connect();
    await sftp.remove('$_pathPrefix/$remotePath');
    _client?.close();
    _client = null;
  }

  @override
  Future<int> getUsedSpace() async {
    final files = await listFiles('');
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  @override
  Future<void> dispose() async {
    _client?.close();
    _client = null;
  }
}
