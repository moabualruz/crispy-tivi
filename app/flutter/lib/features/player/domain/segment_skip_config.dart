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

/// Parses a [NextUpMode] from its name string.
NextUpMode parseNextUpMode(String? name) {
  if (name == null) return NextUpMode.static;
  return NextUpMode.values.where((m) => m.name == name).firstOrNull ??
      NextUpMode.static;
}
