/// Mixin for domain entities that track playback progress.
///
/// Provides a shared [isInProgress] computed property.
/// Classes that mix this in must expose [playbackPositionMs]
/// and [isWatched].
mixin PlaybackProgressMixin {
  /// Playback position in milliseconds (for resume).
  /// Null means not started or position unknown.
  int? get playbackPositionMs;

  /// Whether this item has been completely watched.
  bool get isWatched;

  /// Returns true if playback has started but not completed.
  bool get isInProgress =>
      playbackPositionMs != null && playbackPositionMs! > 0 && !isWatched;
}
