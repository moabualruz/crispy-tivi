import 'package:dio/dio.dart';

import 'package:crispy_tivi/core/exceptions/media_source_exception.dart';

/// Converts a raw exception into a user-friendly error message.
///
/// Strips Dio stack traces and HTTP noise — only the human-readable
/// reason is shown.
String sanitizeError(Object e) {
  // Unwrap MediaSourceException → sanitize its cause if it has one.
  if (e is MediaSourceException) {
    if (e.cause is DioException) return sanitizeError(e.cause!);
    return e.failure.message;
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
