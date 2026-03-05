import 'package:dio/dio.dart';

/// No-op on web — browser handles gzip decompression correctly.
void configureNativeHttpClient(Dio dio) {}

/// No-op on web — browser already decompresses gzip transparently.
List<int> decompressIfGzip(List<int> bytes) => bytes;
