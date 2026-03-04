import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_sync_service_stub.dart'
    if (dart.library.js_interop) 'web_sync_service_web.dart';

export 'web_sync_service_stub.dart'
    if (dart.library.js_interop) 'web_sync_service_web.dart';

/// Provider for WebSyncService.
///
/// On Web, this returns the implementation using File System Access API.
/// On other platforms, it returns a stub that throws UnimplementedError.
final webSyncServiceProvider = Provider<WebSyncService>((ref) {
  return WebSyncService();
});
