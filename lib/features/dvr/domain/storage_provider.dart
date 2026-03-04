import 'entities/storage_backend.dart';

/// Abstract interface for remote storage operations.
///
/// Each [StorageType] has a concrete implementation that
/// handles upload, download, streaming, and file management
/// for that specific backend.
abstract class StorageProvider {
  /// The storage type this provider handles.
  StorageType get type;

  /// Initializes the provider with backend-specific config.
  Future<void> initialize(Map<String, String> config);

  /// Tests the connection and returns true if successful.
  Future<bool> testConnection();

  /// Uploads a local file to the remote storage.
  ///
  /// [localPath] — absolute path to local file.
  /// [remotePath] — destination path on remote storage.
  /// [onProgress] — callback with (bytesSent, totalBytes).
  Future<void> upload(
    String localPath,
    String remotePath,
    void Function(int sent, int total) onProgress,
  );

  /// Downloads a remote file to local storage.
  ///
  /// [remotePath] — source path on remote storage.
  /// [localPath] — destination absolute path.
  /// [onProgress] — callback with (bytesReceived, total).
  Future<void> download(
    String remotePath,
    String localPath,
    void Function(int received, int total) onProgress,
  );

  /// Returns a streamable URL for the remote file, or
  /// null if the backend doesn't support direct streaming.
  ///
  /// For S3, this returns a pre-signed URL.
  /// For WebDAV/Google Drive, this returns an auth'd URL.
  /// For FTP/SMB, returns null (must download first).
  Future<String?> getStreamUrl(String remotePath);

  /// Lists files at the given remote path.
  Future<List<RemoteFile>> listFiles(String path);

  /// Deletes a file from remote storage.
  Future<void> delete(String remotePath);

  /// Returns total bytes used on the remote storage.
  ///
  /// Returns -1 if the backend doesn't support quota info.
  Future<int> getUsedSpace();

  /// Releases any resources held by the provider.
  Future<void> dispose();
}

/// A file on remote storage.
class RemoteFile {
  const RemoteFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
    this.isDirectory = false,
  });

  /// File name (without path).
  final String name;

  /// Full path on the remote storage.
  final String path;

  /// File size in bytes.
  final int sizeBytes;

  /// Last modified timestamp.
  final DateTime modifiedAt;

  /// Whether this entry is a directory.
  final bool isDirectory;
}
