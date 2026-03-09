import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_timeouts.dart';

/// Shared [Dio] singleton for general HTTP requests.
///
/// Consumers use `ref.watch(dioProvider)` or `ref.read(dioProvider)`
/// instead of creating `Dio()` inline. This consolidates connection
/// pools and configuration.
///
/// For IPTV-specific HTTP (resilient JSON, gzip workaround), use
/// [httpServiceProvider] instead — its Dio has IPTV-tailored config.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: NetworkTimeouts.connectTimeout,
      receiveTimeout: NetworkTimeouts.receiveTimeout,
    ),
  );
  ref.onDispose(() => dio.close(force: false));
  return dio;
});
