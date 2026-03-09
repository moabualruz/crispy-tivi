import 'dart:convert';

/// Segment type identifiers used by the skip system.
///
/// Type is inferred from position heuristics in
/// [segmentLabel] but can be explicitly tagged by
/// media server metadata (Jellyfin/Emby segments).
enum SegmentType {
  intro,
  outro,
  recap,
  commercial,
  preview;

  /// User-facing label for settings UI.
  String get label => switch (this) {
    SegmentType.intro => 'Intro',
    SegmentType.outro => 'Outro / Credits',
    SegmentType.recap => 'Recap',
    SegmentType.commercial => 'Commercial',
    SegmentType.preview => 'Preview',
  };
}

/// Skip behavior for a segment type.
enum SegmentSkipMode {
  /// Do not show skip UI or auto-skip.
  none,

  /// Show a "Skip" button; user must tap to skip.
  ask,

  /// Auto-skip the first occurrence per session, then ask.
  once,

  /// Always auto-skip without user interaction.
  auto;

  /// User-facing label for settings UI.
  String get label => switch (this) {
    SegmentSkipMode.none => 'None',
    SegmentSkipMode.ask => 'Ask to Skip',
    SegmentSkipMode.once => 'Skip Once',
    SegmentSkipMode.auto => 'Always Skip',
  };
}

/// Next-up overlay trigger mode.
enum NextUpMode {
  /// Never show next-up overlay.
  off,

  /// Show 32 seconds before end of content.
  static,

  /// Show when playhead enters the credits/outro segment.
  smart;

  /// User-facing label for settings UI.
  String get label => switch (this) {
    NextUpMode.off => 'Off',
    NextUpMode.static => 'Static (32s before end)',
    NextUpMode.smart => 'Smart (credits-aware)',
  };
}

/// Default skip behavior per segment type.
const Map<SegmentType, SegmentSkipMode> defaultSegmentSkipConfig = {
  SegmentType.intro: SegmentSkipMode.ask,
  SegmentType.outro: SegmentSkipMode.ask,
  SegmentType.recap: SegmentSkipMode.ask,
  SegmentType.commercial: SegmentSkipMode.ask,
  SegmentType.preview: SegmentSkipMode.ask,
};

/// Encodes a per-type skip config map to a JSON string for persistence.
String encodeSegmentSkipConfig(Map<SegmentType, SegmentSkipMode> config) {
  final map = <String, String>{};
  for (final entry in config.entries) {
    map[entry.key.name] = entry.value.name;
  }
  return jsonEncode(map);
}

/// Decodes a JSON string back to a per-type skip config map.
///
/// Returns [defaultSegmentSkipConfig] for null or empty input.
Map<SegmentType, SegmentSkipMode> decodeSegmentSkipConfig(String? json) {
  if (json == null || json.isEmpty) {
    return Map.of(defaultSegmentSkipConfig);
  }
  try {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    final result = Map.of(defaultSegmentSkipConfig);
    for (final entry in raw.entries) {
      final type = SegmentType.values.where((t) => t.name == entry.key);
      final mode = SegmentSkipMode.values.where((m) => m.name == entry.value);
      if (type.isNotEmpty && mode.isNotEmpty) {
        result[type.first] = mode.first;
      }
    }
    return result;
  } catch (_) {
    return Map.of(defaultSegmentSkipConfig);
  }
}

/// Parses a [NextUpMode] from its name string.
NextUpMode parseNextUpMode(String? name) {
  if (name == null) return NextUpMode.static;
  return NextUpMode.values.where((m) => m.name == name).firstOrNull ??
      NextUpMode.static;
}
