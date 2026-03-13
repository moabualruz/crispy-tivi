// Dio-specific error mapping now lives in core/network/domain_error.dart.
// This file re-exports the functions for backward compatibility with
// existing callers (e.g. plex_source.dart in data/ layer).
export 'package:crispy_tivi/core/network/domain_error.dart'
    show dioToMediaSourceException, toMediaSourceException;
