import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/data/providers/s3_storage_provider.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';

void main() {
  group('S3StorageProvider Tests', () {
    late HttpServer mockServer;
    late S3StorageProvider provider;
    late MemoryBackend backend;

    setUp(() async {
      mockServer = await HttpServer.bind('127.0.0.1', 0);
      backend = MemoryBackend();
      provider = S3StorageProvider(backend: backend);
    });

    tearDown(() async {
      await provider.dispose();
      await mockServer.close();
    });

    test('testConnection success', () async {
      // Provide an empty JSON string to mimic _backend.signS3Request which returns "{}" by default in memory mock,
      // or we handle local server logic correctly.
      final endpoint = 'http://127.0.0.1:${mockServer.port}';

      mockServer.listen((HttpRequest request) {
        if (request.method == 'HEAD') {
          request.response.statusCode = 200;
          request.response.close();
        } else {
          request.response.statusCode = 404;
          request.response.close();
        }
      });

      await provider.initialize({
        'endpoint': endpoint,
        'bucket': 'test-bucket',
        'region': 'us-east-1',
        'accessKey': 'foo',
        'secretKey': 'bar',
      });

      final isConnected = await provider.testConnection();
      expect(isConnected, isTrue);
    });

    test('testConnection failure', () async {
      final endpoint = 'http://127.0.0.1:${mockServer.port}';

      mockServer.listen((HttpRequest request) {
        request.response.statusCode = 403;
        request.response.close();
      });

      await provider.initialize({
        'endpoint': endpoint,
        'bucket': 'test-bucket',
        'region': 'us-east-1',
        'accessKey': 'foo',
        'secretKey': 'bar',
      });

      final isConnected = await provider.testConnection();
      expect(isConnected, isFalse);
    });
  });
}
