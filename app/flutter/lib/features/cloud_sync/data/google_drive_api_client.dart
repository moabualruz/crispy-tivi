import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../domain/entities/cloud_sync_state.dart';
import '../domain/entities/sync_conflict.dart';

/// Backup file name stored in Google Drive app data folder.
const _backupFileName = 'crispy_tivi_backup.json';

/// Low-level Google Drive API operations.
///
/// Handles CRUD operations for backup files in the app data folder.
class GoogleDriveApiClient {
  GoogleDriveApiClient(this._httpClient)
    : _driveApi = drive.DriveApi(_httpClient);

  final http.Client _httpClient;
  final drive.DriveApi _driveApi;

  /// Uploads backup JSON to Google Drive app data folder.
  ///
  /// Creates a new file if one doesn't exist, or updates existing.
  Future<CloudBackupMetadata> uploadBackup(String jsonContent) async {
    try {
      final existingFile = await _findBackupFile();

      if (existingFile != null) {
        // Update existing file.
        final updated = await _updateFile(existingFile.id!, jsonContent);
        debugPrint('CloudSync: Updated backup file ${updated.id}');
        return _toMetadata(updated);
      } else {
        // Create new file.
        final created = await _createFile(jsonContent);
        debugPrint('CloudSync: Created backup file ${created.id}');
        return _toMetadata(created);
      }
    } catch (e) {
      debugPrint('CloudSync: Upload error: $e');
      throw _mapError(e);
    }
  }

  /// Downloads backup JSON from Google Drive.
  ///
  /// Returns null if no backup exists.
  Future<String?> downloadBackup() async {
    try {
      final file = await _findBackupFile();
      if (file == null || file.id == null) {
        debugPrint('CloudSync: No backup file found');
        return null;
      }

      // Download file content.
      final media =
          await _driveApi.files.get(
                file.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = await _readMediaStream(media.stream);
      final content = utf8.decode(bytes);
      debugPrint('CloudSync: Downloaded ${bytes.length} bytes');
      return content;
    } catch (e) {
      debugPrint('CloudSync: Download error: $e');
      throw _mapError(e);
    }
  }

  /// Gets metadata for the cloud backup file.
  ///
  /// Returns null if no backup exists.
  Future<CloudBackupMetadata?> getBackupMetadata() async {
    try {
      final file = await _findBackupFile();
      if (file == null) return null;
      return _toMetadata(file);
    } catch (e) {
      debugPrint('CloudSync: Metadata error: $e');
      throw _mapError(e);
    }
  }

  /// Gets the modification time of the cloud backup.
  ///
  /// Returns null if no backup exists.
  Future<DateTime?> getCloudModifiedTime() async {
    final metadata = await getBackupMetadata();
    return metadata?.modifiedTime;
  }

  /// Deletes the backup file from Google Drive.
  Future<void> deleteBackup() async {
    try {
      final file = await _findBackupFile();
      if (file != null && file.id != null) {
        await _driveApi.files.delete(file.id!);
        debugPrint('CloudSync: Deleted backup file');
      }
    } catch (e) {
      debugPrint('CloudSync: Delete error: $e');
      throw _mapError(e);
    }
  }

  /// Finds the backup file in the app data folder.
  Future<drive.File?> _findBackupFile() async {
    final fileList = await _driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id, name, modifiedTime, appProperties)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) {
      return null;
    }
    return fileList.files!.first;
  }

  /// Creates a new backup file in the app data folder.
  Future<drive.File> _createFile(String content) async {
    final file =
        drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder']
          ..appProperties = {
            'syncVersion': '2',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          };

    final media = drive.Media(
      Stream.value(utf8.encode(content)),
      utf8.encode(content).length,
      contentType: 'application/json',
    );

    return await _driveApi.files.create(
      file,
      uploadMedia: media,
      $fields: 'id, name, modifiedTime, appProperties',
    );
  }

  /// Updates an existing backup file.
  Future<drive.File> _updateFile(String fileId, String content) async {
    final file =
        drive.File()
          ..appProperties = {
            'syncVersion': '2',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          };

    final media = drive.Media(
      Stream.value(utf8.encode(content)),
      utf8.encode(content).length,
      contentType: 'application/json',
    );

    return await _driveApi.files.update(
      file,
      fileId,
      uploadMedia: media,
      $fields: 'id, name, modifiedTime, appProperties',
    );
  }

  /// Reads all bytes from a media stream.
  Future<List<int>> _readMediaStream(Stream<List<int>> stream) async {
    final chunks = <List<int>>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }
    return chunks.expand((x) => x).toList();
  }

  /// Converts a Drive file to our metadata type.
  CloudBackupMetadata _toMetadata(drive.File file) {
    return CloudBackupMetadata(
      fileId: file.id!,
      modifiedTime: file.modifiedTime ?? DateTime.now().toUtc(),
      deviceId: file.appProperties?['deviceId'],
      syncVersion: int.tryParse(file.appProperties?['syncVersion'] ?? ''),
    );
  }

  /// Maps API errors to our error types.
  CloudSyncError _mapError(dynamic error) {
    final message = error.toString();

    if (message.contains('403')) {
      if (message.contains('quota') || message.contains('storageQuota')) {
        return const QuotaExceededError();
      }
      return const AuthSyncError('Access denied');
    }

    if (message.contains('401') || message.contains('invalid_grant')) {
      return const AuthSyncError('Session expired, please sign in again');
    }

    if (message.contains('429') || message.contains('rateLimitExceeded')) {
      return const RateLimitError();
    }

    if (message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('connection')) {
      return const NetworkSyncError();
    }

    return GeneralSyncError(message);
  }

  /// Disposes of the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
