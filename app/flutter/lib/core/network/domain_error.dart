import 'package:dio/dio.dart';

import '../exceptions/media_source_exception.dart';

/// Domain-level error types for network operations.
///
/// Consumers in presentation/ and domain/ layers catch these types
/// instead of [DioException], keeping infrastructure details out of
/// non-data layers.
sealed class NetworkError implements Exception {
  const NetworkError({required this.message});

  /// Human-readable error description.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Server could not be reached (DNS, socket, proxy failure).
class ConnectionError extends NetworkError {
  const ConnectionError({required super.message});
}

/// Request or response exceeded the configured deadline.
class TimeoutError extends NetworkError {
  const TimeoutError({required super.message});
}

/// Server rejected credentials (HTTP 401 / 403).
class AuthenticationError extends NetworkError {
  const AuthenticationError({required super.message, this.statusCode});

  /// HTTP status code, if available.
  final int? statusCode;
}

/// Server returned an error response (5xx, 4xx other than auth).
class ServerError extends NetworkError {
  const ServerError({required super.message, this.statusCode});

  /// HTTP status code, if available.
  final int? statusCode;
}

/// Catch-all for unclassified network problems.
class UnknownNetworkError extends NetworkError {
  const UnknownNetworkError({required super.message});
}

/// Maps a raw exception to a domain [NetworkError].
///
/// Lives in `core/network/` where `package:dio` imports are allowed.
/// Callers in presentation/ catch [NetworkError] subtypes instead
/// of [DioException].
NetworkError networkErrorFromException(Object error) {
  if (error is DioException) {
    return _fromDioException(error);
  }
  return UnknownNetworkError(message: error.toString());
}

NetworkError _fromDioException(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => TimeoutError(
      message: 'Connection timed out. Check the server URL.',
    ),
    DioExceptionType.connectionError => ConnectionError(
      message: 'Cannot reach the server. Check the URL and your network.',
    ),
    DioExceptionType.badCertificate => ConnectionError(
      message: 'SSL certificate error — use http:// or fix the certificate.',
    ),
    DioExceptionType.badResponse => _fromBadResponse(e),
    DioExceptionType.cancel => const UnknownNetworkError(
      message: 'Request cancelled.',
    ),
    DioExceptionType.unknown => UnknownNetworkError(
      message:
          'Network error: ${e.message ?? e.error?.toString() ?? 'unknown'}',
    ),
  };
}

NetworkError _fromBadResponse(DioException e) {
  final status = e.response?.statusCode;
  if (status == 401 || status == 403) {
    return AuthenticationError(
      message: 'Authentication failed.',
      statusCode: status,
    );
  }
  return ServerError(
    message: 'Server returned HTTP ${status ?? 'unknown'}.',
    statusCode: status,
  );
}

/// Converts a [DioException] to a [MediaSourceException].
///
/// [label] is a human-readable server name used in error messages
/// (e.g. `'Plex'`, `'Jellyfin'`, `'Emby'`).
///
/// Moved here from `features/media_servers/shared/utils/dio_error_utils.dart`
/// so that only `core/network/` (which may import `package:dio`) does the
/// mapping.
MediaSourceException dioToMediaSourceException(DioException e, String label) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => MediaSourceException.network(
      message: 'Cannot connect to $label server: ${e.message}',
      cause: e,
    ),
    DioExceptionType.badResponse => _handleBadResponseMse(e, label),
    DioExceptionType.cancel => MediaSourceException.server(
      message: 'Request cancelled',
      cause: e,
    ),
    DioExceptionType.badCertificate => MediaSourceException.network(
      message: 'SSL certificate error',
      cause: e,
    ),
    DioExceptionType.unknown => MediaSourceException.network(
      message:
          'Network error: ${e.message ?? e.error?.toString() ?? 'unknown'}',
      cause: e,
    ),
  };
}

MediaSourceException _handleBadResponseMse(DioException e, String label) {
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

/// Maps any exception to a [MediaSourceException] for a given server [label].
///
/// If the exception is a [DioException], uses [dioToMediaSourceException].
/// Otherwise wraps it as a generic server error. Callers in non-data layers
/// use this instead of catching [DioException] directly, keeping `package:dio`
/// out of presentation and domain code.
MediaSourceException toMediaSourceException(Object e, String label) {
  if (e is MediaSourceException) return e;
  if (e is DioException) return dioToMediaSourceException(e, label);
  return MediaSourceException.server(message: '$label error: $e', cause: e);
}

/// Converts a raw exception to a user-friendly error message.
///
/// Strips Dio stack traces and HTTP noise — only the human-readable
/// reason is shown. Handles both [DioException] and [NetworkError].
///
/// Moved here from `features/media_servers/shared/utils/error_sanitizer.dart`
/// so that only `core/network/` (which may import `package:dio`) does the
/// dio-specific sanitization.
String sanitizeNetworkError(Object e) {
  if (e is MediaSourceException) {
    if (e.cause is DioException) return sanitizeNetworkError(e.cause!);
    return e.failure.message;
  }
  if (e is NetworkError) {
    return e.message;
  }
  if (e is DioException) {
    final response = e.response;
    if (response != null) {
      final status = response.statusCode ?? 0;
      return switch (status) {
        401 => 'Invalid username or password.',
        403 => 'Access denied. Check your credentials.',
        404 => 'Server not found at this URL.',
        500 => 'Server error — try again later.',
        _ => 'Server returned HTTP $status.',
      };
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType
          .sendTimeout => 'Connection timed out. Check the server URL.',
      DioExceptionType.connectionError =>
        'Cannot reach the server. '
            'Check the URL and your network.',
      DioExceptionType.badCertificate =>
        'SSL certificate error — use http:// or fix the certificate.',
      _ => 'Connection failed. Check the server URL.',
    };
  }
  // Trim any stack-trace lines from generic exceptions.
  final message = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+: '), '');
  final firstLine = message.split('\n').first.trim();
  return firstLine.isNotEmpty ? firstLine : 'An unexpected error occurred.';
}
