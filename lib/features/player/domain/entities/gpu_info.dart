/// GPU information for video upscaling tier selection.
///
/// Mirrors the Rust `GpuInfo` struct from
/// `rust/crates/crispy-core/src/gpu.rs`.
/// Serialized as JSON across the FFI bridge.
///
/// See `.ai/docs/project-specs/video_upscaling_spec.md` §4.2.
class GpuInfo {
  /// Creates a [GpuInfo] instance.
  const GpuInfo({
    required this.vendor,
    required this.name,
    this.vramMb,
    required this.supportsHwVsr,
    required this.vsrMethod,
  });

  /// Deserializes from the Rust JSON representation.
  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      vendor: GpuVendor.fromString(json['vendor'] as String? ?? 'Unknown'),
      name: json['name'] as String? ?? 'Unknown',
      vramMb: json['vram_mb'] as int?,
      supportsHwVsr: json['supports_hw_vsr'] as bool? ?? false,
      vsrMethod: VsrMethod.fromString(json['vsr_method'] as String? ?? 'None'),
    );
  }

  /// GPU hardware vendor.
  final GpuVendor vendor;

  /// GPU model name (e.g. "NVIDIA GeForce RTX 4090").
  final String name;

  /// Dedicated VRAM in megabytes, if detectable.
  final int? vramMb;

  /// Whether the GPU supports hardware video
  /// super-resolution.
  final bool supportsHwVsr;

  /// The specific VSR method available.
  final VsrMethod vsrMethod;

  /// Sentinel for unknown / undetected GPU.
  static const unknown = GpuInfo(
    vendor: GpuVendor.unknown,
    name: 'Unknown',
    supportsHwVsr: false,
    vsrMethod: VsrMethod.none,
  );

  /// Serializes to the Rust-compatible JSON format.
  Map<String, dynamic> toJson() => {
    'vendor': vendor.toRustString(),
    'name': name,
    'vram_mb': vramMb,
    'supports_hw_vsr': supportsHwVsr,
    'vsr_method': vsrMethod.toRustString(),
  };
}

/// GPU hardware vendor.
enum GpuVendor {
  /// NVIDIA Corporation.
  nvidia,

  /// Advanced Micro Devices.
  amd,

  /// Intel Corporation.
  intel,

  /// Apple Inc.
  apple,

  /// Qualcomm Technologies.
  qualcomm,

  /// Arm Holdings.
  arm,

  /// Unknown or undetected vendor.
  unknown;

  /// Parses from Rust PascalCase enum variant.
  static GpuVendor fromString(String s) {
    // Rust serializes as PascalCase enum variant
    switch (s) {
      case 'Nvidia':
        return GpuVendor.nvidia;
      case 'Amd':
        return GpuVendor.amd;
      case 'Intel':
        return GpuVendor.intel;
      case 'Apple':
        return GpuVendor.apple;
      case 'Qualcomm':
        return GpuVendor.qualcomm;
      case 'Arm':
        return GpuVendor.arm;
      default:
        return GpuVendor.unknown;
    }
  }

  /// Serializes to Rust PascalCase format.
  String toRustString() {
    switch (this) {
      case GpuVendor.nvidia:
        return 'Nvidia';
      case GpuVendor.amd:
        return 'Amd';
      case GpuVendor.intel:
        return 'Intel';
      case GpuVendor.apple:
        return 'Apple';
      case GpuVendor.qualcomm:
        return 'Qualcomm';
      case GpuVendor.arm:
        return 'Arm';
      case GpuVendor.unknown:
        return 'Unknown';
    }
  }
}

/// Video super-resolution method.
enum VsrMethod {
  /// NVIDIA RTX VSR via D3D11.
  d3d11Nvidia,

  /// Intel VSR via D3D11.
  d3d11Intel,

  /// AMD Radeon Super Resolution (driver-level).
  amdDriverRsr,

  /// Apple MetalFX Spatial Upscaler.
  metalFxSpatial,

  /// WebGPU CNN-based upscaler.
  webGpuCnn,

  /// WebGL FSR port.
  webGlFsr,

  /// Software FSR (GLSL shader).
  softwareFsr,

  /// Software Lanczos scaler.
  softwareLanczos,

  /// NVIDIA RTX Video SDK (direct AI upscaling).
  rtxVideoSdk,

  /// Apple Core ML super resolution.
  coreMlSuperRes,

  /// Qualcomm GSR (Game Super Resolution) shader.
  qualcommGsr,

  /// No VSR method available.
  none;

  /// Parses from Rust PascalCase enum variant.
  static VsrMethod fromString(String s) {
    switch (s) {
      case 'D3d11Nvidia':
        return VsrMethod.d3d11Nvidia;
      case 'D3d11Intel':
        return VsrMethod.d3d11Intel;
      case 'AmdDriverRsr':
        return VsrMethod.amdDriverRsr;
      case 'MetalFxSpatial':
        return VsrMethod.metalFxSpatial;
      case 'WebGpuCnn':
        return VsrMethod.webGpuCnn;
      case 'WebGlFsr':
        return VsrMethod.webGlFsr;
      case 'SoftwareFsr':
        return VsrMethod.softwareFsr;
      case 'SoftwareLanczos':
        return VsrMethod.softwareLanczos;
      case 'RtxVideoSdk':
        return VsrMethod.rtxVideoSdk;
      case 'CoreMlSuperRes':
        return VsrMethod.coreMlSuperRes;
      case 'QualcommGsr':
        return VsrMethod.qualcommGsr;
      default:
        return VsrMethod.none;
    }
  }

  /// Serializes to Rust PascalCase format.
  String toRustString() {
    switch (this) {
      case VsrMethod.d3d11Nvidia:
        return 'D3d11Nvidia';
      case VsrMethod.d3d11Intel:
        return 'D3d11Intel';
      case VsrMethod.amdDriverRsr:
        return 'AmdDriverRsr';
      case VsrMethod.metalFxSpatial:
        return 'MetalFxSpatial';
      case VsrMethod.webGpuCnn:
        return 'WebGpuCnn';
      case VsrMethod.webGlFsr:
        return 'WebGlFsr';
      case VsrMethod.softwareFsr:
        return 'SoftwareFsr';
      case VsrMethod.softwareLanczos:
        return 'SoftwareLanczos';
      case VsrMethod.rtxVideoSdk:
        return 'RtxVideoSdk';
      case VsrMethod.coreMlSuperRes:
        return 'CoreMlSuperRes';
      case VsrMethod.qualcommGsr:
        return 'QualcommGsr';
      case VsrMethod.none:
        return 'None';
    }
  }
}
