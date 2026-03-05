import 'package:dio/dio.dart';

import 'package:crispy_tivi/core/exceptions/media_source_exception.dart';

/// Converts a [DioException] to a [MediaSourceException].
///
/// [label] is a human-readable server name used in error messages
/// (e.g. `'Plex'`, `'Jellyfin'`, `'Emby'`).
MediaSourceException dioToMediaSourceException(DioException e, String label) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => MediaSourceException.network(
      message: 'Cannot connect to $label server: ${e.message}',
      cause: e,
    ),
    DioExceptionType.badResponse => _handleBadResponse(e, label),
    DioExceptionType.cancel => MediaSourceException.server(
      message: 'Request cancelled',
      cause: e,
    ),
    DioExceptionType.badCertificate => MediaSourceException.network(
      message: 'SSL certificate error',
      cause: e,
    ),
    DioExceptionType.unknown => MediaSourceException.network(
      message: 'Network error: ${e.message}',
      cause: e,
    ),
  };
}

MediaSourceException _handleBadResponse(DioException e, String label) {
  final statusCode = e.response?.statusCode;
  if (statusCode == 401 || statusCode == 403) {
    return MediaSourceException.auth(
      message: '$label authentication failed',
      cause: e,
    );
  }
  return MediaSourceException.server(
    message: '$label server error: ${e.message}',
    statusCode: statusCode,
    cause: e,
  );
}
