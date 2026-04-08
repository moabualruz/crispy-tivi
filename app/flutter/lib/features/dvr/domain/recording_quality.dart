/// User-facing recording quality selection.
///
/// This is a simplified quality tier for the schedule UI.
/// Internally, each tier maps to a [RecordingProfile] for
/// stream-level quality control.
enum RecordingQuality {
  /// Automatically select the highest available quality.
  auto(
    label: 'Auto (Best Available)',
    shortLabel: 'Auto',
    description: 'Selects the best stream quality automatically',
    icon: 0xe429,
  ),

  /// High-definition quality (720p / 1080p).
  hd(
    label: 'HD',
    shortLabel: 'HD',
    description: 'High-definition (720p / 1080p)',
    icon: 0xe333,
  ),

  /// Standard-definition quality (480p and below).
  sd(
    label: 'SD',
    shortLabel: 'SD',
    description: 'Standard-definition (480p and below)',
    icon: 0xe333,
  );

  const RecordingQuality({
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.icon,
  });

  /// Full user-visible label.
  final String label;

  /// Short label for badges and chips.
  final String shortLabel;

  /// Description shown in the quality picker.
  final String description;

  /// Codepoint for the associated Material icon.
  final int icon;
}
