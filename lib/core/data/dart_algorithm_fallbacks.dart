import 'dart:convert';

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
