import 'package:crispy_tivi/core/network/domain_error.dart';

/// Converts a raw exception into a user-friendly error message.
///
/// Delegates to [sanitizeNetworkError] in `core/network/` which handles
/// Dio-specific error types internally.
String sanitizeError(Object e) => sanitizeNetworkError(e);
