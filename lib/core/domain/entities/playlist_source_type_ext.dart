import 'package:flutter/material.dart';

import 'playlist_source.dart';

/// UI extension methods for [PlaylistSourceType].
///
/// Kept in the presentation layer to avoid importing Flutter into the
/// domain entity file (domain must stay pure Dart per architecture rules).
extension PlaylistSourceTypeUi on PlaylistSourceType {
  /// Returns the icon for this server type.
  IconData get icon => switch (this) {
    PlaylistSourceType.jellyfin => Icons.dns_rounded,
    PlaylistSourceType.emby => Icons.cast_connected_rounded,
    PlaylistSourceType.plex => Icons.play_circle_outline_rounded,
    _ => Icons.storage_rounded,
  };

  /// Returns the human-readable label for this server type.
  String get serverLabel => switch (this) {
    PlaylistSourceType.jellyfin => 'Jellyfin',
    PlaylistSourceType.emby => 'Emby',
    PlaylistSourceType.plex => 'Plex',
    _ => 'Server',
  };
}
