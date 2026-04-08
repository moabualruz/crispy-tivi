/// Stream quality profile for bandwidth/quality control.
///
/// Profiles limit the maximum bitrate for HLS/DASH adaptive streams,
/// allowing users to balance quality vs data usage.
enum StreamProfile {
  /// Auto — let the player adapt based on network conditions.
  auto(
    label: 'Auto',
    description: 'Automatically adjust quality based on network',
    maxBitrateKbps: null,
  ),

  /// Low — max 1 Mbps, suitable for mobile data or slow connections.
  low(
    label: 'Low',
    description: 'SD quality, ~1 Mbps max',
    maxBitrateKbps: 1000,
  ),

  /// Medium — max 3 Mbps, good balance of quality and data usage.
  medium(
    label: 'Medium',
    description: 'HD quality, ~3 Mbps max',
    maxBitrateKbps: 3000,
  ),

  /// High — max 8 Mbps, for fast connections and large screens.
  high(
    label: 'High',
    description: 'Full HD quality, ~8 Mbps max',
    maxBitrateKbps: 8000,
  ),

  /// Maximum — no limit, use the highest available quality.
  maximum(
    label: 'Maximum',
    description: 'Best available quality, no limit',
    maxBitrateKbps: null,
  );

  const StreamProfile({
    required this.label,
    required this.description,
    required this.maxBitrateKbps,
  });

  /// Display name for the profile.
  final String label;

  /// Description of the profile's characteristics.
  final String description;

  /// Maximum bitrate in Kbps, or null for no limit (auto/max).
  final int? maxBitrateKbps;

  /// Returns the profile as mpv-compatible option value.
  ///
  /// For HLS streams, mpv uses `hls-bitrate` option:
  /// - `no` = auto select
  /// - `min` = lowest quality
  /// - `max` = highest quality
  /// - `<number>` = max bitrate in bps
  String? get mpvHlsBitrate {
    if (this == StreamProfile.auto) return 'no';
    if (this == StreamProfile.maximum) return 'max';
    if (maxBitrateKbps != null) {
      // Convert Kbps to bps for mpv
      return '${maxBitrateKbps! * 1000}';
    }
    return null;
  }

  /// Returns bandwidth limit for web HLS.js in bits per second.
  int? get hlsJsBandwidthLimit {
    if (maxBitrateKbps != null) {
      return maxBitrateKbps! * 1000;
    }
    return null; // No limit
  }
}
