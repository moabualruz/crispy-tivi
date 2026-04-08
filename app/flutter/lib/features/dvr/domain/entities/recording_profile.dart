/// Recording quality and format profiles for DVR.
///
/// Profiles control the quality level requested from HLS streams
/// and the output container format.
enum RecordingProfile {
  /// Record at original source quality (no bitrate limit).
  original(
    label: 'Original',
    description: 'Full quality, largest file size',
    maxBitrateKbps: null,
    container: RecordingContainer.ts,
  ),

  /// High quality recording (~8 Mbps max).
  high(
    label: 'High',
    description: 'Full HD quality, ~8 Mbps max',
    maxBitrateKbps: 8000,
    container: RecordingContainer.ts,
  ),

  /// Medium quality recording (~3 Mbps max).
  medium(
    label: 'Medium',
    description: 'HD quality, ~3 Mbps max',
    maxBitrateKbps: 3000,
    container: RecordingContainer.ts,
  ),

  /// Low quality recording (~1 Mbps max).
  low(
    label: 'Low',
    description: 'SD quality, ~1 Mbps max',
    maxBitrateKbps: 1000,
    container: RecordingContainer.ts,
  );

  const RecordingProfile({
    required this.label,
    required this.description,
    required this.maxBitrateKbps,
    required this.container,
  });

  /// User-friendly display label.
  final String label;

  /// Description of quality/size tradeoff.
  final String description;

  /// Maximum bitrate in Kbps, or null for unlimited.
  final int? maxBitrateKbps;

  /// Output container format.
  final RecordingContainer container;

  /// Estimated file size per hour of recording.
  String get estimatedSizePerHour {
    if (maxBitrateKbps == null) return 'Varies';
    // Approximate: bitrate * 3600s / 8 bits / 1024 KB / 1024 MB
    final mbPerHour = (maxBitrateKbps! * 3600) / (8 * 1024);
    if (mbPerHour >= 1024) {
      return '~${(mbPerHour / 1024).toStringAsFixed(1)} GB/hr';
    }
    return '~${mbPerHour.toStringAsFixed(0)} MB/hr';
  }
}

/// Output container format for recordings.
enum RecordingContainer {
  /// MPEG Transport Stream — direct capture, most compatible.
  ts(extension: '.ts', mimeType: 'video/mp2t', label: 'Transport Stream (.ts)'),

  /// MP4 container — requires remuxing after capture.
  mp4(extension: '.mp4', mimeType: 'video/mp4', label: 'MP4 (.mp4)');

  const RecordingContainer({
    required this.extension,
    required this.mimeType,
    required this.label,
  });

  /// File extension including dot.
  final String extension;

  /// MIME type for the container.
  final String mimeType;

  /// User-friendly label.
  final String label;
}
