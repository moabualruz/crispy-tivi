/// No-op on native platforms.
void platformToggleWebFullscreen() {}

/// No-op on native platforms.
void Function() addWebFullscreenListener(
  void Function(bool isFullscreen) callback,
) {
  return () {};
}

/// Always returns `false` on native platforms.
bool platformIsWebFullscreen() => false;
