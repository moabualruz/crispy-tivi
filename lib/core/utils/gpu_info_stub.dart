import 'package:flutter/foundation.dart';

import '../../features/player/domain/entities/hardware_decoder.dart';

/// GPU information result.
class GpuInfo {
  const GpuInfo({
    this.gpuName,
    this.vendor,
    this.recommendedDecoder = HardwareDecoder.auto,
    this.availableDecoders = const [HardwareDecoder.auto, HardwareDecoder.none],
  });

  /// GPU name (e.g., "NVIDIA GeForce RTX 3080").
  final String? gpuName;

  /// GPU vendor (e.g., "NVIDIA", "AMD", "Intel").
  final String? vendor;

  /// Recommended decoder based on detected GPU.
  final HardwareDecoder recommendedDecoder;

  /// List of available decoders for this platform/GPU.
  final List<HardwareDecoder> availableDecoders;

  /// True if GPU info was successfully detected.
  bool get isDetected => gpuName != null;
}

/// GPU information utility.
///
/// Web stub returns minimal info - hardware decoding is not
/// supported on web platform.
class GpuInfoHelper {
  /// Detects GPU information on the current platform.
  Future<GpuInfo> detectGpu() async {
    debugPrint('GpuInfo: Web platform - hardware decoding not available');
    return const GpuInfo(
      gpuName: 'Web Browser',
      vendor: 'Browser',
      recommendedDecoder: HardwareDecoder.auto,
      availableDecoders: [HardwareDecoder.auto],
    );
  }
}
