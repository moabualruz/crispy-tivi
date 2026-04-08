import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Configures Dio's HTTP client adapter for native platforms.
///
/// Disables `HttpClient.autoUncompress` to prevent Dart's streaming
/// zlib filter from silently dropping trailing bytes on large gzip
/// responses (Dart SDK #32994, Dio #1352).
void configureNativeHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.autoUncompress = false;
      return client;
    },
  );
}

/// Decompresses gzip bytes if the magic header is detected.
///
/// Some IPTV servers ignore `Accept-Encoding: identity` and send
/// gzip regardless. With `autoUncompress = false`, we receive raw
/// gzip bytes that must be manually decompressed.
List<int> decompressIfGzip(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    return gzip.decode(bytes);
  }
  return bytes;
}
