import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/data/crispy_backend.dart';
import '../../domain/entities/storage_backend.dart';
import '../../domain/storage_provider.dart';

/// S3-compatible storage provider (AWS, MinIO, Wasabi, B2).
///
/// Uses Dio with AWS Signature V4 for authentication.
/// Crypto operations (HMAC-SHA256 signing) are delegated
/// to [CrispyBackend] (Rust).
/// Config keys: endpoint, bucket, region, accessKey,
///   secretKey, pathPrefix.
class S3StorageProvider implements StorageProvider {
  S3StorageProvider({required CrispyBackend backend}) : _backend = backend;

  final CrispyBackend _backend;

  @override
  StorageType get type => StorageType.s3;

  late Dio _dio;
  late String _endpoint;
  late String _bucket;
  late String _region;
  late String _accessKey;
  late String _secretKey;
  late String _pathPrefix;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _endpoint = config['endpoint'] ?? '';
    _bucket = config['bucket'] ?? '';
    _region = config['region'] ?? 'us-east-1';
    _accessKey = config['accessKey'] ?? '';
    _secretKey = config['secretKey'] ?? '';
    _pathPrefix = config['pathPrefix'] ?? 'recordings';

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(hours: 6),
        sendTimeout: const Duration(hours: 6),
      ),
    );
  }

  @override
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_endpoint/$_bucket');
      final now = DateTime.now().toUtc();
      final headers = await _signRequest('HEAD', '/', now, {});
      final response = await _dio.headUri(
        uri,
        options: Options(headers: headers),
      );
      return response.statusCode == 200;
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
    final file = File(localPath);
    final fileSize = await file.length();
    final objectKey = '$_pathPrefix/$remotePath';
    final uri = Uri.parse('$_endpoint/$_bucket/$objectKey');
    final now = DateTime.now().toUtc();

    final headers = await _signRequest('PUT', '/$objectKey', now, {
      'content-length': fileSize.toString(),
    });

    await _dio.putUri(
      uri,
      data: file.openRead(),
      options: Options(
        headers: {
          ...headers,
          'Content-Length': fileSize,
          'Content-Type': 'application/octet-stream',
        },
      ),
      onSendProgress: onProgress,
    );
  }

  @override
  Future<void> download(
    String remotePath,
    String localPath,
    void Function(int received, int total) onProgress,
  ) async {
    final objectKey = '$_pathPrefix/$remotePath';
    final uri = Uri.parse('$_endpoint/$_bucket/$objectKey');
    final now = DateTime.now().toUtc();

    final headers = await _signRequest('GET', '/$objectKey', now, {});

    await _dio.downloadUri(
      uri,
      localPath,
      options: Options(headers: headers),
      onReceiveProgress: onProgress,
    );
  }

  @override
  Future<String?> getStreamUrl(String remotePath) async {
    final objectKey = '$_pathPrefix/$remotePath';
    return _backend.generatePresignedUrl(
      endpoint: _endpoint,
      bucket: _bucket,
      objectKey: objectKey,
      region: _region,
      accessKey: _accessKey,
      secretKey: _secretKey,
      expirySecs: 3600,
      nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<RemoteFile>> listFiles(String path) async {
    final prefix = '$_pathPrefix/$path'.replaceAll('//', '/');
    final uri = Uri.parse('$_endpoint/$_bucket?list-type=2&prefix=$prefix');
    final now = DateTime.now().toUtc();
    final headers = await _signRequest('GET', '/', now, {});

    final response = await _dio.getUri(uri, options: Options(headers: headers));

    // Parse XML response via Rust.
    final body = response.data.toString();
    final json = await _backend.parseS3ListObjects(body);
    final objects = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    return objects.map((obj) {
      final key = obj['key'] as String;
      return RemoteFile(
        name: key.split('/').last,
        path: key,
        sizeBytes: (obj['size'] as num).toInt(),
        modifiedAt: DateTime.parse(obj['last_modified'] as String),
      );
    }).toList();
  }

  @override
  Future<void> delete(String remotePath) async {
    final objectKey = '$_pathPrefix/$remotePath';
    final uri = Uri.parse('$_endpoint/$_bucket/$objectKey');
    final now = DateTime.now().toUtc();
    final headers = await _signRequest('DELETE', '/$objectKey', now, {});

    await _dio.deleteUri(uri, options: Options(headers: headers));
  }

  @override
  Future<int> getUsedSpace() async {
    final files = await listFiles('');
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }

  @override
  Future<void> dispose() async {
    _dio.close();
  }

  // ── AWS SigV4 (delegated to Rust) ──

  Future<Map<String, String>> _signRequest(
    String method,
    String path,
    DateTime now,
    Map<String, String> extraHeaders,
  ) async {
    final result = await _backend.signS3Request(
      method: method,
      path: path,
      nowUtcMs: now.millisecondsSinceEpoch,
      host: Uri.parse('$_endpoint/$_bucket').host,
      region: _region,
      accessKey: _accessKey,
      secretKey: _secretKey,
      extraHeadersJson: extraHeaders.isEmpty ? null : jsonEncode(extraHeaders),
    );
    return (jsonDecode(result) as Map<String, dynamic>).cast<String, String>();
  }
}
