import 'dart:ui' show Color;

// ─────────────────────────────────────────────────────────────
//  SubtitleStyle — immutable value object + related enums
// ─────────────────────────────────────────────────────────────

/// Subtitle font-size options.
enum SubtitleFontSize {
  small,
  medium,
  large,
  extraLarge;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleFontSize.small => 'Small',
    SubtitleFontSize.medium => 'Medium',
    SubtitleFontSize.large => 'Large',
    SubtitleFontSize.extraLarge => 'XL',
  };

  /// Actual font size in logical pixels.
  double get pixels => switch (this) {
    SubtitleFontSize.small => 14,
    SubtitleFontSize.medium => 18,
    SubtitleFontSize.large => 24,
    SubtitleFontSize.extraLarge => 32,
  };
}

/// Subtitle text-color presets.
enum SubtitleTextColor {
  white,
  yellow,
  green,
  cyan;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleTextColor.white => 'White',
    SubtitleTextColor.yellow => 'Yellow',
    SubtitleTextColor.green => 'Green',
    SubtitleTextColor.cyan => 'Cyan',
  };

  /// The concrete [Color] value.
  Color get color => switch (this) {
    SubtitleTextColor.white => const Color(0xFFFFFFFF),
    SubtitleTextColor.yellow => const Color(0xFFFFEA00),
    SubtitleTextColor.green => const Color(0xFF00E676),
    SubtitleTextColor.cyan => const Color(0xFF00E5FF),
  };
}

/// Subtitle background presets.
enum SubtitleBackground {
  black,
  semiTransparent,
  transparent;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleBackground.black => 'Black',
    SubtitleBackground.semiTransparent => 'Semi',
    SubtitleBackground.transparent => 'None',
  };

  /// The concrete [Color] value.
  Color get color => switch (this) {
    SubtitleBackground.black => const Color(0xFF000000),
    SubtitleBackground.semiTransparent => const Color(0x99000000),
    SubtitleBackground.transparent => const Color(0x00000000),
  };
}

/// Subtitle edge / shadow style.
enum SubtitleEdgeStyle {
  none,
  dropShadow,
  raised,
  depressed,
  outline;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleEdgeStyle.none => 'None',
    SubtitleEdgeStyle.dropShadow => 'Shadow',
    SubtitleEdgeStyle.raised => 'Raised',
    SubtitleEdgeStyle.depressed => 'Depressed',
    SubtitleEdgeStyle.outline => 'Outline',
  };
}

/// Subtitle outline color presets.
enum SubtitleOutlineColor {
  black,
  white,
  red,
  transparent;

  /// Display label shown in the UI.
  String get label => switch (this) {
    SubtitleOutlineColor.black => 'Black',
    SubtitleOutlineColor.white => 'White',
    SubtitleOutlineColor.red => 'Red',
    SubtitleOutlineColor.transparent => 'None',
  };

  /// The concrete [Color] value.
  Color get color => switch (this) {
    SubtitleOutlineColor.black => const Color(0xFF000000),
    SubtitleOutlineColor.white => const Color(0xFFFFFFFF),
    SubtitleOutlineColor.red => const Color(0xFFFF0000),
    SubtitleOutlineColor.transparent => const Color(0x00000000),
  };
}

/// Immutable subtitle CC style configuration.
///
/// All fields have sensible defaults matching broadcast standards.
class SubtitleStyle {
  /// Creates a subtitle style with sensible defaults.
  const SubtitleStyle({
    this.fontSize = SubtitleFontSize.medium,
    this.textColor = SubtitleTextColor.white,
    this.background = SubtitleBackground.semiTransparent,
    this.edgeStyle = SubtitleEdgeStyle.dropShadow,
    this.isBold = false,
    this.verticalPosition = 100,
    this.outlineColor = SubtitleOutlineColor.black,
    this.outlineSize = 2.0,
    this.backgroundOpacity = 0.6,
    this.hasShadow = true,
  });

  /// Font size preset.
  final SubtitleFontSize fontSize;

  /// Text color preset.
  final SubtitleTextColor textColor;

  /// Background style preset.
  final SubtitleBackground background;

  /// Legacy edge style — kept for backward-compatible deserialization.
  final SubtitleEdgeStyle edgeStyle;

  /// Whether subtitle text is bold.
  final bool isBold;

  /// Vertical position from top (0) to bottom (100).
  final int verticalPosition;

  /// Outline (border) color around subtitle text.
  final SubtitleOutlineColor outlineColor;

  /// Outline thickness in pixels (0-10).
  final double outlineSize;

  /// Background box opacity (0.0 transparent - 1.0 opaque).
  final double backgroundOpacity;

  /// Whether to render a drop shadow behind text.
  final bool hasShadow;

  /// Default style matching broadcast CC standards.
  static const SubtitleStyle defaults = SubtitleStyle();

  /// Creates a copy with the given fields replaced.
  SubtitleStyle copyWith({
    SubtitleFontSize? fontSize,
    SubtitleTextColor? textColor,
    SubtitleBackground? background,
    SubtitleEdgeStyle? edgeStyle,
    bool? isBold,
    int? verticalPosition,
    SubtitleOutlineColor? outlineColor,
    double? outlineSize,
    double? backgroundOpacity,
    bool? hasShadow,
  }) => SubtitleStyle(
    fontSize: fontSize ?? this.fontSize,
    textColor: textColor ?? this.textColor,
    background: background ?? this.background,
    edgeStyle: edgeStyle ?? this.edgeStyle,
    isBold: isBold ?? this.isBold,
    verticalPosition: verticalPosition ?? this.verticalPosition,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineSize: outlineSize ?? this.outlineSize,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    hasShadow: hasShadow ?? this.hasShadow,
  );

  /// Serialise to a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() => {
    'fontSize': fontSize.name,
    'textColor': textColor.name,
    'background': background.name,
    'edgeStyle': edgeStyle.name,
    'isBold': isBold,
    'verticalPosition': verticalPosition,
    'outlineColor': outlineColor.name,
    'outlineSize': outlineSize,
    'backgroundOpacity': backgroundOpacity,
    'hasShadow': hasShadow,
  };

  /// Deserialise from a JSON-compatible map.
  factory SubtitleStyle.fromJson(Map<String, dynamic> json) => SubtitleStyle(
    fontSize: SubtitleFontSize.values.firstWhere(
      (e) => e.name == json['fontSize'],
      orElse: () => SubtitleFontSize.medium,
    ),
    textColor: SubtitleTextColor.values.firstWhere(
      (e) => e.name == json['textColor'],
      orElse: () => SubtitleTextColor.white,
    ),
    background: SubtitleBackground.values.firstWhere(
      (e) => e.name == json['background'],
      orElse: () => SubtitleBackground.semiTransparent,
    ),
    edgeStyle: SubtitleEdgeStyle.values.firstWhere(
      (e) => e.name == json['edgeStyle'],
      orElse: () => SubtitleEdgeStyle.dropShadow,
    ),
    isBold: json['isBold'] as bool? ?? false,
    verticalPosition: json['verticalPosition'] as int? ?? 100,
    outlineColor: SubtitleOutlineColor.values.firstWhere(
      (e) => e.name == json['outlineColor'],
      orElse: () => SubtitleOutlineColor.black,
    ),
    outlineSize: (json['outlineSize'] as num?)?.toDouble() ?? 2.0,
    backgroundOpacity: (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.6,
    hasShadow: json['hasShadow'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is SubtitleStyle &&
      fontSize == other.fontSize &&
      textColor == other.textColor &&
      background == other.background &&
      edgeStyle == other.edgeStyle &&
      isBold == other.isBold &&
      verticalPosition == other.verticalPosition &&
      outlineColor == other.outlineColor &&
      outlineSize == other.outlineSize &&
      backgroundOpacity == other.backgroundOpacity &&
      hasShadow == other.hasShadow;

  @override
  int get hashCode => Object.hash(
    fontSize,
    textColor,
    background,
    edgeStyle,
    isBold,
    verticalPosition,
    outlineColor,
    outlineSize,
    backgroundOpacity,
    hasShadow,
  );
}
