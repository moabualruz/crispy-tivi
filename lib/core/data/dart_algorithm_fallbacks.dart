import 'dart:convert';

import 'package:crispy_tivi/core/constants.dart';
import 'package:crispy_tivi/core/utils/file_extensions.dart';
import 'package:crypto/crypto.dart';

/// Pure-Dart fallback implementations for algorithms that have
/// canonical Rust counterparts in crispy-core.
///
/// These are synchronous and used by both [WsBackend] (which cannot
/// issue async WebSocket calls for sync methods) and [MemoryBackend]
/// (which runs fully in-memory without FFI or WebSocket).
///
/// All functions are top-level so they can be imported by any
/// backend's part files.

// ── Group Icon ────────────────────────────────────────────────────

/// Map a channel/VOD group name to a Material icon name.
///
/// Mirrors `crispy-core::algorithms::group_icon::match_group_icon`.
String dartMatchGroupIcon(String groupName) {
  final lower = groupName.toLowerCase();
  if (lower.contains('favorite')) return 'star';
  if (lower.contains('sport')) return 'sports_soccer';
  if (lower.contains('news')) return 'newspaper';
  if (lower.contains('movie')) return 'movie';
  if (lower.contains('music')) return 'music_note';
  if (lower.contains('kid') || lower.contains('child')) {
    return 'child_care';
  }
  if (lower.contains('documentary') || lower.contains('doc')) {
    return 'video_library';
  }
  if (lower.contains('entertainment')) {
    return 'theater_comedy';
  }
  if (lower.contains('general')) return 'tv';
  if (lower.contains('religious') || lower.contains('faith')) {
    return 'church';
  }
  if (lower.contains('local')) return 'location_on';
  if (lower.contains('international')) {
    return 'language';
  }
  if (lower.contains('premium') || lower.contains('hd')) {
    return 'hd';
  }
  if (lower.contains('xxx') || lower.contains('adult')) {
    return 'eighteen_up_rating';
  }
  return 'folder';
}

// ── Channel Name & URL Normalization ─────────────────────────────

/// Lowercase, strip non-alphanumeric (except spaces), collapse spaces.
///
/// Mirrors `crispy-core::algorithms::normalize::normalize_channel_name`.
String dartNormalizeChannelName(String name) =>
    name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Lowercase URL and strip query/fragment; trim trailing slash.
///
/// Mirrors `crispy-core::algorithms::normalize::normalize_url`.
String dartNormalizeStreamUrl(String url) {
  final normalized = url.toLowerCase().replaceAll(RegExp(r'[?#].*'), '');
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}

// ── API Base URL Normalization ────────────────────────────────────

/// Normalize a server URL to `scheme://host[:port]`, dropping the path.
///
/// Returns an error string (not null) on invalid input, to match
/// the Rust function's `String` return type.
///
/// Mirrors `crispy-core::algorithms::url_normalize::normalize_api_base_url`.
String dartNormalizeApiBaseUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return 'URL must not be empty';
  final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    return 'Invalid URL format: $trimmed';
  }
  final isDefault =
      (uri.scheme == 'http' && uri.port == 80) ||
      (uri.scheme == 'https' && uri.port == 443);
  final port = uri.hasPort && !isDefault ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

// ── Config Merge ──────────────────────────────────────────────────

/// Recursively merge two JSON objects, with [overridesJson] values
/// taking precedence.
///
/// Mirrors `crispy-core::algorithms::config_merge::deep_merge_json`.
String dartDeepMergeJson(String baseJson, String overridesJson) {
  dynamic base;
  dynamic overrides;
  try {
    base = jsonDecode(baseJson);
  } catch (_) {
    base = <String, dynamic>{};
  }
  try {
    overrides = jsonDecode(overridesJson);
  } catch (_) {
    overrides = <String, dynamic>{};
  }
  return jsonEncode(_deepMerge(base, overrides));
}

dynamic _deepMerge(dynamic base, dynamic overrides) {
  if (base is Map<String, dynamic> && overrides is Map<String, dynamic>) {
    final result = Map<String, dynamic>.from(base);
    for (final key in overrides.keys) {
      result[key] =
          result.containsKey(key)
              ? _deepMerge(result[key], overrides[key])
              : overrides[key];
    }
    return result;
  }
  return overrides;
}

/// Set a value at a dot-separated [dotPath] inside a JSON map.
///
/// Intermediate map nodes are created as needed. Existing non-map
/// values at intermediate paths are overwritten.
///
/// Mirrors `crispy-core::algorithms::config_merge::set_nested_value`.
String dartSetNestedValue(String mapJson, String dotPath, String valueJson) {
  dynamic root;
  try {
    root = jsonDecode(mapJson);
  } catch (_) {
    root = <String, dynamic>{};
  }
  dynamic value;
  try {
    value = jsonDecode(valueJson);
  } catch (_) {
    value = valueJson;
  }
  if (dotPath.isEmpty) return jsonEncode(root);
  final keys = dotPath.split('.');
  Map<String, dynamic> current;
  if (root is Map<String, dynamic>) {
    current = root;
  } else {
    current = <String, dynamic>{};
  }
  for (var i = 0; i < keys.length - 1; i++) {
    final child = current[keys[i]];
    if (child is Map<String, dynamic>) {
      current = child;
    } else {
      final next = <String, dynamic>{};
      current[keys[i]] = next;
      current = next;
    }
  }
  current[keys.last] = value;
  return jsonEncode(root);
}

// ── Permission ────────────────────────────────────────────────────

/// Returns true when [role] allows viewing [recordingOwnerId]'s
/// recording by [currentProfileId].
///
/// Mirrors `crispy-core::algorithms::permission::can_view_recording`.
bool dartCanViewRecording(
  String role,
  String recordingOwnerId,
  String currentProfileId,
) {
  switch (role) {
    case 'admin':
      return true;
    case 'full_dvr':
      return true;
    case 'view_only':
      return recordingOwnerId == currentProfileId;
    default:
      return false;
  }
}

/// Returns true when [role] allows deleting [recordingOwnerId]'s
/// recording by [currentProfileId].
///
/// Mirrors `crispy-core::algorithms::permission::can_delete_recording`.
bool dartCanDeleteRecording(
  String role,
  String recordingOwnerId,
  String currentProfileId,
) {
  switch (role) {
    case 'admin':
      return true;
    case 'full_dvr':
      return recordingOwnerId == currentProfileId;
    default:
      return false;
  }
}

// ── PIN / Security ────────────────────────────────────────────────

/// Returns true when [value] looks like a hex-encoded SHA-256 hash
/// (64 lowercase or uppercase hex digits).
///
/// Sync fallback — mirrors
/// `crispy-core` PIN hashing checks in ws_backend and memory_backend.
bool dartIsHashedPin(String value) =>
    value.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);

// ── Filename / Path ───────────────────────────────────────────────

/// Replace characters that are invalid in filenames with underscores.
///
/// Keeps word characters (`\w`), spaces, and hyphens; replaces
/// everything else with `_`.
///
/// Sync fallback — mirrors `crispy-core` DVR filename sanitisation.
String dartSanitizeFilename(String name) =>
    name.replaceAll(RegExp(r'[^\w\s-]'), '_');

// ── Logo Domain Guessing ──────────────────────────────────────────

/// Derive candidate logo/CDN domains from a provider/channel [name].
///
/// Returns the first lowercase word plus common TLD variants.
/// E.g. `"Sky News"` → `["sky", "sky.com", "sky.tv", "sky.org"]`.
///
/// Sync fallback — mirrors
/// `crispy-core::algorithms::group_icon::guess_logo_domains`.
List<String> dartGuessLogoDomains(String name) {
  final trimmed = name.trim().toLowerCase();
  if (trimmed.isEmpty) return [];
  final word = trimmed.split(RegExp(r'\s+')).first;
  if (word.isEmpty) return [];
  return [word, '$word.com', '$word.tv', '$word.org'];
}

// ── Favorites Sort ────────────────────────────────────────────────

/// Sort a JSON-encoded list of favourite channels by [sortMode].
///
/// Modes: `"recentlyAdded"` (no-op), `"nameAsc"`, `"nameDesc"`,
/// `"contentType"` (group then name).
///
/// Mirrors `crispy-core::algorithms::sorting::sort_favorites`.
String dartSortFavorites(String channelsJson, String sortMode) {
  final list = (jsonDecode(channelsJson) as List).cast<Map<String, dynamic>>();
  switch (sortMode) {
    case 'nameAsc':
      list.sort(
        (a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo(
          (b['name'] as String? ?? '').toLowerCase(),
        ),
      );
    case 'nameDesc':
      list.sort(
        (a, b) => (b['name'] as String? ?? '').toLowerCase().compareTo(
          (a['name'] as String? ?? '').toLowerCase(),
        ),
      );
    case 'contentType':
      list.sort((a, b) {
        final ga = (a['channel_group'] as String? ?? '');
        final gb = (b['channel_group'] as String? ?? '');
        final cmp = ga.compareTo(gb);
        if (cmp != 0) return cmp;
        return (a['name'] as String? ?? '').toLowerCase().compareTo(
          (b['name'] as String? ?? '').toLowerCase(),
        );
      });
    // 'recentlyAdded' — preserve order.
  }
  return jsonEncode(list);
}

// ── Category Sort ─────────────────────────────────────────────────

/// Sort [categoriesJson] with [favoritesJson] items first (both groups
/// sorted alphabetically within themselves).
///
/// Mirrors `crispy-core::algorithms::sorting::sort_categories_with_favorites`.
String dartSortCategoriesWithFavorites(
  String categoriesJson,
  String favoritesJson,
) {
  final categories = (jsonDecode(categoriesJson) as List).cast<String>();
  final favorites = (jsonDecode(favoritesJson) as List).cast<String>();
  final favSet = favorites.toSet();
  final favs = categories.where((c) => favSet.contains(c)).toList()..sort();
  final rest = categories.where((c) => !favSet.contains(c)).toList()..sort();
  return jsonEncode([...favs, ...rest]);
}

// ── Watch Streak ──────────────────────────────────────────────────

/// Compute the current watch streak from a JSON array of epoch-ms
/// timestamps and a [nowMs] reference time.
///
/// Mirrors `crispy-core::algorithms::watch_history::compute_watch_streak`.
int dartComputeWatchStreak(String timestampsJson, int nowMs) {
  List<dynamic> raw;
  try {
    raw = jsonDecode(timestampsJson) as List;
  } catch (_) {
    return 0;
  }
  if (raw.isEmpty) return 0;

  // Collect distinct calendar days.
  final days = <DateTime>{};
  for (final ts in raw) {
    final ms = ts is int ? ts : (ts as num).toInt();
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    days.add(DateTime(d.year, d.month, d.day));
  }

  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final todayNorm = DateTime(now.year, now.month, now.day);

  var current =
      days.contains(todayNorm)
          ? todayNorm
          : todayNorm.subtract(const Duration(days: 1));

  if (!days.contains(current)) return 0;

  var streak = 0;
  while (days.contains(current)) {
    streak++;
    current = current.subtract(const Duration(days: 1));
  }
  return streak;
}

// ── Continue-Watching Filter ──────────────────────────────────────

/// Filter a WatchHistory JSON array by [filter] status.
///
/// Mirrors `crispy-core::algorithms::watch_history::filter_by_cw_status`.
List<Map<String, dynamic>> dartFilterByCwStatus(
  List<Map<String, dynamic>> entries,
  String filter,
) {
  if (filter == 'all') return entries;
  return entries.where((e) {
    final pos = (e['position_ms'] as num?)?.toInt() ?? 0;
    final dur = (e['duration_ms'] as num?)?.toInt() ?? 0;
    final progress = dur > 0 ? pos / dur : 0.0;
    final nearlyComplete = progress >= kCompletionThreshold;
    if (filter == 'watching') return progress > 0 && !nearlyComplete;
    if (filter == 'completed') return nearlyComplete;
    return true;
  }).toList();
}

// ── Count In-Progress Episodes ────────────────────────────────────

/// Count in-progress episodes for [seriesId] from a watch-history
/// JSON array.
///
/// Mirrors `crispy-core::algorithms::watch_history::count_in_progress_episodes`.
int dartCountInProgressEpisodes(String historyJson, String seriesId) {
  List<dynamic> raw;
  try {
    raw = jsonDecode(historyJson) as List;
  } catch (_) {
    return 0;
  }
  var count = 0;
  for (final item in raw) {
    final e = item as Map<String, dynamic>;
    final sid = e['series_id'] as String?;
    final mediaType = e['media_type'] as String? ?? '';
    final dur = (e['duration_ms'] as num?)?.toInt() ?? 0;
    final pos = (e['position_ms'] as num?)?.toInt() ?? 0;
    if (sid != seriesId) continue;
    if (mediaType != 'episode') continue;
    if (dur <= 0) continue;
    final progress = pos / dur;
    if (progress >= kCompletionThreshold) continue;
    count++;
  }
  return count;
}

// ── Dedup ─────────────────────────────────────────────────────────

/// Returns true if [channelId] appears in the `channel_ids` list
/// of any duplicate group.
///
/// [groupsJson] is a JSON list of duplicate-group objects, each
/// containing a `channel_ids` string list.
///
/// Sync fallback — mirrors
/// `crispy-core::algorithms::dedup::is_duplicate` (checks any
/// group membership, not just `duplicate_ids`).
bool dartIsDuplicate(String groupsJson, String channelId) {
  final groups = (jsonDecode(groupsJson) as List).cast<Map<String, dynamic>>();
  for (final g in groups) {
    final ids = (g['channel_ids'] as List).cast<String>();
    if (ids.contains(channelId)) return true;
  }
  return false;
}

// ── Search Categories ──────────────────────────────────────────────

/// Merge VOD categories and channel groups into a unique sorted list.
///
/// Mirrors `crispy-core::algorithms::categories::build_search_categories`.
String dartBuildSearchCategories(
  String vodCategoriesJson,
  String channelGroupsJson,
) {
  List<dynamic> vodCats;
  List<dynamic> groups;
  try {
    vodCats = jsonDecode(vodCategoriesJson) as List;
  } catch (_) {
    vodCats = [];
  }
  try {
    groups = jsonDecode(channelGroupsJson) as List;
  } catch (_) {
    groups = [];
  }
  final set = <String>{};
  for (final c in vodCats) {
    if (c is String) {
      final trimmed = c.trim();
      if (trimmed.isNotEmpty) set.add(trimmed);
    }
  }
  for (final g in groups) {
    if (g is String) {
      final trimmed = g.trim();
      if (trimmed.isNotEmpty) set.add(trimmed);
    }
  }
  final sorted = set.toList()..sort();
  return jsonEncode(sorted);
}

// ── File Classification ────────────────────────────────────────────

/// Classify a file by its extension.
///
/// Mirrors `crispy-core::algorithms::dvr::classify_file_type`.
String dartClassifyFileType(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return 'other';
  final ext = filename.substring(dot + 1).toLowerCase();
  if (FileExtensions.video.contains(ext)) return 'video';
  if (FileExtensions.audio.contains(ext)) return 'audio';
  if (FileExtensions.subtitle.contains(ext)) return 'subtitle';
  return 'other';
}

// ── Episode Count by Season ────────────────────────────────────────

/// Count episodes grouped by season number.
///
/// Mirrors `crispy-core::algorithms::watch_history::episode_count_by_season`.
String dartEpisodeCountBySeason(String episodesJson) {
  List<dynamic> items;
  try {
    items = jsonDecode(episodesJson) as List;
  } catch (_) {
    return '{}';
  }
  final counts = <int, int>{};
  for (final item in items) {
    if (item is Map<String, dynamic>) {
      final season = item['season_number'] as int?;
      if (season != null) {
        counts[season] = (counts[season] ?? 0) + 1;
      }
    }
  }
  final obj = <String, int>{};
  for (final key in (counts.keys.toList()..sort())) {
    obj[key.toString()] = counts[key]!;
  }
  return jsonEncode(obj);
}

// ── VOD Badge Kind ─────────────────────────────────────────────────

/// Determines the badge label for a VOD card.
///
/// Mirrors `crispy-core::algorithms::watch_history::vod_badge_kind`.
String dartVodBadgeKind(int? year, int? addedAtMs, int nowMs) {
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  if (year != null && year >= now.year - 1) {
    return 'new_release';
  }
  const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
  if (addedAtMs != null && nowMs - addedAtMs <= thirtyDaysMs) {
    return 'new_to_library';
  }
  return 'new_to_library';
}

// ── PIN Lockout ────────────────────────────────────────────────────

/// Check if a PIN lockout is currently active.
///
/// Mirrors `crispy-core::algorithms::pin::is_lock_active`.
bool dartIsLockActive(int lockedUntilMs, int nowMs) {
  if (lockedUntilMs <= 0) return false;
  return nowMs < lockedUntilMs;
}

/// Remaining milliseconds in a PIN lockout.
///
/// Mirrors `crispy-core::algorithms::pin::lock_remaining_ms`.
int dartLockRemainingMs(int lockedUntilMs, int nowMs) {
  if (lockedUntilMs <= 0) return 0;
  final remaining = lockedUntilMs - nowMs;
  return remaining > 0 ? remaining : 0;
}

// ── Watch History ID ─────────────────────────────────────────────────

/// Derives a stable, platform-independent watch-history ID from
/// a stream URL.
///
/// Returns the first 16 hex characters of the SHA-256 hash of
/// the URL — identical output to the Rust
/// `crispy-core::algorithms::watch_history::derive_watch_history_id`.
///
/// Used as a sync fallback in [WsBackend] and [MemoryBackend].
String dartDeriveWatchHistoryId(String url) {
  final bytes = sha256.convert(utf8.encode(url)).bytes;
  return bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
