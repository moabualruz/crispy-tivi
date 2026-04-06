import 'package:meta/meta.dart';

/// Type of remote storage backend.
enum StorageType {
  /// Local device storage (default).
  local('Local'),

  /// S3-compatible object storage (AWS, MinIO, Wasabi, B2).
  s3('S3-Compatible'),

  /// WebDAV server (Nextcloud, ownCloud, etc.).
  webdav('WebDAV'),

  /// SMB/CIFS network share (NAS, Windows share).
  smb('SMB / NAS'),

  /// Google Drive (reuses existing auth).
  googleDrive('Google Drive'),

  /// FTP or SFTP server.
  ftp('FTP / SFTP');

  const StorageType(this.label);

  /// Human-readable label.
  final String label;
}

/// A configured remote storage backend.
@immutable
class StorageBackend {
  const StorageBackend({
    required this.id,
    required this.name,
    required this.type,
    this.config = const {},
    this.isDefault = false,
  });

  /// Unique identifier.
  final String id;

  /// User-given display name.
  final String name;

  /// Backend type.
  final StorageType type;

  /// Type-specific configuration parameters.
  ///
  /// Keys vary by [type]:
  /// - **s3**: endpoint, bucket, region, accessKey,
  ///   secretKey, pathPrefix
  /// - **webdav**: url, username, password, pathPrefix
  /// - **smb**: host, share, username, password,
  ///   pathPrefix
  /// - **googleDrive**: folderId
  /// - **ftp**: host, port, username, password,
  ///   pathPrefix, useSftp
  /// - **local**: path
  final Map<String, String> config;

  /// Whether this is the default upload target.
  final bool isDefault;

  /// Gets a config value or empty string.
  String get(String key) => config[key] ?? '';

  StorageBackend copyWith({
    String? id,
    String? name,
    StorageType? type,
    Map<String, String>? config,
    bool? isDefault,
  }) {
    return StorageBackend(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      config: config ?? this.config,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageBackend &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'StorageBackend($name, type=$type)';
}
