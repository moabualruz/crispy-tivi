import '../failures/failure.dart';

/// Exception thrown by [MediaSource] implementations.
///
/// Wraps the underlying error with a [Failure] for domain-level
/// error categorization while maintaining exception semantics.
class MediaSourceException implements Exception {
  const MediaSourceException({required this.failure, this.cause});

  /// Factory for server/API errors.
  factory MediaSourceException.server({
    required String message,
    int? statusCode,
    Object? cause,
  }) {
    return MediaSourceException(
      failure: ServerFailure(message: message, statusCode: statusCode),
      cause: cause,
    );
  }

  /// Factory for network connectivity errors.
  factory MediaSourceException.network({
    required String message,
    Object? cause,
  }) {
    return MediaSourceException(
      failure: NetworkFailure(message: message),
      cause: cause,
    );
  }

  /// Factory for authentication errors.
  factory MediaSourceException.auth({required String message, Object? cause}) {
    return MediaSourceException(
      failure: AuthFailure(message: message),
      cause: cause,
    );
  }

  /// The domain-level failure describing the error.
  final Failure failure;

  /// The original cause (e.g., DioException).
  final Object? cause;

  @override
  String toString() => 'MediaSourceException: ${failure.message}';
}
