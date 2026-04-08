// Cast helper conditional export.
// Uses stub for web/unsupported platforms, IO implementation for native.
export 'cast_helper_stub.dart' if (dart.library.io) 'cast_helper_io.dart';
