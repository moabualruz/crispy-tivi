import '../domain/entities/gpu_info.dart';

/// Codec for converting [GpuInfo] to/from the Rust-compatible JSON format.
///
/// Keeps infrastructure concerns out of the domain layer.
/// JSON shape mirrors the Rust `GpuInfo` struct in
/// `rust/crates/crispy-core/src/gpu.rs`.
abstract final class GpuJsonCodec {
  /// Deserializes a [GpuInfo] from the Rust JSON representation.
  static GpuInfo fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      vendor: GpuVendor.fromString(json['vendor'] as String? ?? 'Unknown'),
      name: json['name'] as String? ?? 'Unknown',
      vramMb: json['vram_mb'] as int?,
      supportsHwVsr: json['supports_hw_vsr'] as bool? ?? false,
      vsrMethod: VsrMethod.fromString(json['vsr_method'] as String? ?? 'None'),
    );
  }

  /// Serializes a [GpuInfo] to the Rust-compatible JSON format.
  static Map<String, dynamic> toJson(GpuInfo info) => {
    'vendor': info.vendor.toRustString(),
    'name': info.name,
    'vram_mb': info.vramMb,
    'supports_hw_vsr': info.supportsHwVsr,
    'vsr_method': info.vsrMethod.toRustString(),
  };
}
