/// Base class for domain-layer failures.
///
/// All errors surfacing from repositories or use cases
/// must be expressed as [Failure] subclasses — never
/// throw raw exceptions across layer boundaries.
sealed class Failure {
  const Failure({required this.message, this.stackTrace});

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// Server returned an error (HTTP 4xx/5xx).
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    this.statusCode,
    super.stackTrace,
  });

  final int? statusCode;
}

/// No network connectivity.
class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.stackTrace});
}

/// Local database read/write error.
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.stackTrace});
}

/// Input validation failed.
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.stackTrace});
}

/// Feature or platform not supported.
class UnsupportedFailure extends Failure {
  const UnsupportedFailure({required super.message, super.stackTrace});
}

/// Parse error (e.g. malformed M3U / EPG XML).
class ParseFailure extends Failure {
  const ParseFailure({required super.message, super.stackTrace});
}

/// Authentication failed (e.g. invalid credentials).
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.stackTrace});
}

/// FFI bridge execution error (Rust panic or anyhow err).
class FfiFailure extends Failure {
  const FfiFailure({required super.message, super.stackTrace});
}
