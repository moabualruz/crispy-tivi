import '../../../../core/utils/platform_info.dart';

/// Hardware decoder options for video playback.
///
/// Maps to mpv's `hwdec` option. Each decoder has platform
/// restrictions based on GPU vendor and OS support.
enum HardwareDecoder {
  /// Automatically select the best available hardware decoder.
  auto(
    label: 'Auto',
    description: 'Automatically select best decoder',
    mpvValue: 'auto',
  ),

  /// Force software decoding (CPU only).
  none(
    label: 'Software Only',
    description: 'Use CPU decoding (higher CPU usage)',
    mpvValue: 'no',
  ),

  /// NVIDIA NVDEC hardware decoder.
  nvdec(
    label: 'NVIDIA NVDEC',
    description: 'NVIDIA GPU hardware decoding',
    mpvValue: 'nvdec',
  ),

  /// NVIDIA CUDA decoder (older method).
  cuda(
    label: 'NVIDIA CUDA',
    description: 'NVIDIA CUDA-based decoding',
    mpvValue: 'cuda',
  ),

  /// DirectX 11 Video Acceleration (Windows).
  d3d11va(
    label: 'DirectX 11 (D3D11VA)',
    description: 'Windows DirectX 11 acceleration',
    mpvValue: 'd3d11va',
  ),

  /// DirectX Video Acceleration 2 (Windows, legacy).
  dxva2(
    label: 'DirectX 9 (DXVA2)',
    description: 'Windows DirectX 9 acceleration (legacy)',
    mpvValue: 'dxva2',
  ),

  /// VA-API (Video Acceleration API) for Linux.
  vaapi(
    label: 'VA-API',
    description: 'Linux Video Acceleration API',
    mpvValue: 'vaapi',
  ),

  /// VDPAU (Video Decode and Presentation API for Unix).
  vdpau(
    label: 'VDPAU',
    description: 'Linux NVIDIA VDPAU (legacy)',
    mpvValue: 'vdpau',
  ),

  /// VideoToolbox (macOS/iOS hardware decoder).
  videotoolbox(
    label: 'VideoToolbox',
    description: 'Apple hardware acceleration',
    mpvValue: 'videotoolbox',
  ),

  /// MediaCodec (Android hardware decoder).
  mediacodec(
    label: 'MediaCodec',
    description: 'Android hardware acceleration',
    mpvValue: 'mediacodec',
  );

  const HardwareDecoder({
    required this.label,
    required this.description,
    required this.mpvValue,
  });

  /// Human-readable label for UI display.
  final String label;

  /// Description explaining the decoder.
  final String description;

  /// Value to pass to mpv's hwdec option.
  final String mpvValue;

  /// Returns true if this decoder is available on the current platform.
  bool get isAvailableOnCurrentPlatform {
    if (PlatformInfo.instance.isWeb) return this == auto || this == none;

    switch (this) {
      case auto:
      case none:
        return true;

      case nvdec:
      case cuda:
        // NVIDIA decoders: Windows and Linux only
        return PlatformInfo.instance.isWindows || PlatformInfo.instance.isLinux;

      case d3d11va:
      case dxva2:
        // DirectX: Windows only
        return PlatformInfo.instance.isWindows;

      case vaapi:
      case vdpau:
        // Linux-specific APIs
        return PlatformInfo.instance.isLinux;

      case videotoolbox:
        // Apple platforms
        return PlatformInfo.instance.isMacOS || PlatformInfo.instance.isIOS;

      case mediacodec:
        // Android only
        return PlatformInfo.instance.isAndroid;
    }
  }

  /// Returns decoders available on the current platform.
  static List<HardwareDecoder> get availableDecoders {
    return values.where((d) => d.isAvailableOnCurrentPlatform).toList();
  }

  /// Returns a decoder by its mpv value, or [auto] if not found.
  static HardwareDecoder fromMpvValue(String value) {
    return values.firstWhere((d) => d.mpvValue == value, orElse: () => auto);
  }

  /// Returns a decoder by its name, or [auto] if not found.
  static HardwareDecoder fromName(String name) {
    return values.firstWhere((d) => d.name == name, orElse: () => auto);
  }
}
