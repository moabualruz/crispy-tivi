import '../../../../core/data/crispy_backend.dart';
import '../../../cloud_sync/data/google_auth_service.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';
import 'ftp_storage_provider.dart';
import 'google_drive_storage_provider.dart';
import 'local_storage_provider.dart';
import 's3_storage_provider.dart';
import 'smb_storage_provider.dart';
import 'webdav_storage_provider.dart';

/// Factory that creates [StorageProvider] instances for a
/// given [StorageBackend].
class StorageProviderFactory {
  const StorageProviderFactory({
    required GoogleAuthService googleAuthService,
    required CrispyBackend backend,
  }) : _googleAuthService = googleAuthService,
       _backend = backend;

  final GoogleAuthService _googleAuthService;
  final CrispyBackend _backend;

  /// Creates and initializes a [StorageProvider] matching
  /// the backend's [StorageType].
  Future<StorageProvider> create(StorageBackend backend) async {
    final StorageProvider provider;

    switch (backend.type) {
      case StorageType.local:
        provider = LocalStorageProvider();
      case StorageType.s3:
        provider = S3StorageProvider(backend: _backend);
      case StorageType.webdav:
        provider = WebDavStorageProvider();
      case StorageType.smb:
        provider = SmbStorageProvider();
      case StorageType.googleDrive:
        provider = GoogleDriveStorageProvider(authService: _googleAuthService);
      case StorageType.ftp:
        provider = FtpStorageProvider();
    }

    await provider.initialize(backend.config);
    return provider;
  }
}
