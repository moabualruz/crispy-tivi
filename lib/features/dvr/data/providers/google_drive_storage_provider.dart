import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;

import '../../../cloud_sync/data/google_auth_service.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';

/// Google Drive storage provider for recording files.
///
/// Reuses existing [GoogleAuthService] for authentication.
/// Config keys: folderId.
class GoogleDriveStorageProvider implements StorageProvider {
  GoogleDriveStorageProvider({required GoogleAuthService authService})
    : _authService = authService;

  @override
  StorageType get type => StorageType.googleDrive;

  final GoogleAuthService _authService;
  late String _folderId;
  drive.DriveApi? _driveApi;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _folderId = config['folderId'] ?? '';
  }

  Future<drive.DriveApi> _getApi() async {
    if (_driveApi != null) return _driveApi!;
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw StateError('Not signed in to Google');
    }
    _driveApi = drive.DriveApi(client);
    return _driveApi!;
  }

  /// Ensures the recordings folder exists, creating it
  /// if needed. Returns the folder ID.
  Future<String> _ensureFolder() async {
    if (_folderId.isNotEmpty) return _folderId;

    final api = await _getApi();
    // Search for existing folder.
    const folderName = 'CrispyTivi Recordings';
    final query =
        "name='$folderName' and mimeType="
        "'application/vnd.google-apps.folder' "
        "and trashed=false";
    final result = await api.files.list(q: query);

    if (result.files != null && result.files!.isNotEmpty) {
      _folderId = result.files!.first.id!;
      return _folderId;
    }

    // Create folder.
    final folder =
        drive.File()
          ..name = folderName
          ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    _folderId = created.id!;
    return _folderId;
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _getApi();
      await _ensureFolder();
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
    final api = await _getApi();
    final folderId = await _ensureFolder();
    final file = File(localPath);
    final fileSize = await file.length();

    final driveFile =
        drive.File()
          ..name = remotePath
          ..parents = [folderId];

    final media = drive.Media(file.openRead(), fileSize);

    // Use resumable upload for large files.
    await api.files.create(
      driveFile,
      uploadMedia: media,
      uploadOptions: drive.UploadOptions.resumable,
    );

    // Drive API doesn't support granular progress for
    // simple uploads. Report completion.
    onProgress(fileSize, fileSize);
  }

  @override
  Future<void> download(
    String remotePath,
    String localPath,
    void Function(int received, int total) onProgress,
  ) async {
    final api = await _getApi();

    // Find file by name in folder.
    final fileId = await _findFileId(remotePath);
    if (fileId == null) {
      throw FileSystemException('File not found on Google Drive', remotePath);
    }

    final response =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final outFile = File(localPath);
    final sink = outFile.openWrite();
    var received = 0;
    final total = response.length ?? 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(received, total);
    }

    await sink.close();
  }

  @override
  Future<String?> getStreamUrl(String remotePath) async {
    final fileId = await _findFileId(remotePath);
    if (fileId == null) return null;

    // Direct download link (requires auth token).
    return 'https://www.googleapis.com/drive/v3/'
        'files/$fileId?alt=media';
  }

  @override
  Future<List<RemoteFile>> listFiles(String path) async {
    final api = await _getApi();
    final folderId = await _ensureFolder();

    final query =
        "'$folderId' in parents "
        "and trashed=false";
    final result = await api.files.list(
      q: query,
      $fields: 'files(id,name,size,modifiedTime,mimeType)',
    );

    return (result.files ?? []).map((f) {
      return RemoteFile(
        name: f.name ?? '',
        path: f.id ?? '',
        sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
        modifiedAt: f.modifiedTime ?? DateTime.now(),
        isDirectory: f.mimeType == 'application/vnd.google-apps.folder',
      );
    }).toList();
  }

  @override
  Future<void> delete(String remotePath) async {
    final api = await _getApi();
    final fileId = await _findFileId(remotePath);
    if (fileId != null) {
      await api.files.delete(fileId);
    }
  }

  @override
  Future<int> getUsedSpace() async {
    final files = await listFiles('');
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  @override
  Future<void> dispose() async {
    _driveApi = null;
  }

  Future<String?> _findFileId(String fileName) async {
    final api = await _getApi();
    final folderId = await _ensureFolder();

    final query =
        "name='$fileName' "
        "and '$folderId' in parents "
        "and trashed=false";
    final result = await api.files.list(q: query);

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id;
    }
    return null;
  }
}
