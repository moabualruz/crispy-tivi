import 'package:flutter/material.dart';

import '../data/crispy_backend.dart';

/// Icon name to [IconData] mapping.
///
/// The Rust backend returns a string icon name from
/// [CrispyBackend.matchGroupIcon]; this map converts
/// that string to the corresponding Material icon.
const _iconMap = <String, IconData>{
  'star': Icons.star_rounded,
  'sports_soccer': Icons.sports_soccer_rounded,
  'newspaper': Icons.newspaper_rounded,
  'movie': Icons.movie_rounded,
  'music_note': Icons.music_note_rounded,
  'child_care': Icons.child_care_rounded,
  'video_library': Icons.video_library_rounded,
  'theater_comedy': Icons.theater_comedy_rounded,
  'tv': Icons.tv_rounded,
  'church': Icons.church_rounded,
  'location_on': Icons.location_on_rounded,
  'language': Icons.language_rounded,
  'hd': Icons.hd_rounded,
  'eighteen_up_rating': Icons.eighteen_up_rating_rounded,
  'folder': Icons.folder_rounded,
};

/// Returns an icon based on common group name patterns.
///
/// Delegates pattern matching to the Rust backend and
/// maps the resulting icon name string to [IconData].
/// Used by [GroupSidebar] and mobile groups drill-down
/// to display consistent icons for channel groups.
IconData getGroupIcon(String groupName, {required CrispyBackend backend}) {
  final name = backend.matchGroupIcon(groupName);
  return _iconMap[name] ?? Icons.folder_rounded;
}
