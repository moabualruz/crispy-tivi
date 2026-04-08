import 'dart:async';

import 'os_media_session.dart';

/// Web stub — OS media session is a no-op on web.
OsMediaSessionPlatform createPlatformSession() => _WebMediaSession();

class _WebMediaSession implements OsMediaSessionPlatform {
  @override
  bool get isInitialized => false;

  @override
  Future<void> init(StreamController<MediaAction> actions) async {}

  @override
  Future<void> activate({
    required String title,
    String? artist,
    String? artUrl,
    Duration? duration,
  }) async {}

  @override
  Future<void> updatePlaybackState(bool isPlaying, Duration position) async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> dispose() async {}
}
