import 'dart:io';

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

/// GPU information utility for native platforms.
///
/// Detects GPU vendor and available hardware decoders.
class GpuInfoHelper {
  /// Detects GPU information on the current platform.
  Future<GpuInfo> detectGpu() async {
    if (Platform.isWindows) {
      return _detectWindows();
    } else if (Platform.isLinux) {
      return _detectLinux();
    } else if (Platform.isAndroid) {
      return _detectAndroid();
    } else if (Platform.isMacOS) {
      return _detectMacOS();
    }

    return GpuInfo(availableDecoders: HardwareDecoder.availableDecoders);
  }

  /// Windows GPU detection using WMIC.
  Future<GpuInfo> _detectWindows() async {
    try {
      final result = await Process.run('wmic', [
        'path',
        'win32_VideoController',
        'get',
        'name',
      ]);

      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        final lines = output.split('\n').skip(1); // Skip header
        final gpuName =
            lines.map((l) => l.trim()).where((l) => l.isNotEmpty).firstOrNull;

        if (gpuName != null) {
          final vendor = _detectVendor(gpuName);
          final recommended = _recommendDecoder(vendor, Platform.isWindows);
          final available = _getAvailableDecoders(vendor, Platform.isWindows);

          debugPrint('GpuInfo: Detected $gpuName ($vendor)');
          return GpuInfo(
            gpuName: gpuName,
            vendor: vendor,
            recommendedDecoder: recommended,
            availableDecoders: available,
          );
        }
      }
    } catch (e) {
      debugPrint('GpuInfo: Windows detection error: $e');
    }

    return GpuInfo(availableDecoders: HardwareDecoder.availableDecoders);
  }

  /// Linux GPU detection using lspci.
  Future<GpuInfo> _detectLinux() async {
    try {
      final result = await Process.run('lspci', []);

      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');

        for (final line in lines) {
          if (line.contains('VGA') || line.contains('3D')) {
            // Extract GPU name from lspci output
            final colonIdx = line.indexOf(': ');
            if (colonIdx != -1) {
              final gpuName = line.substring(colonIdx + 2).trim();
              final vendor = _detectVendor(gpuName);
              final recommended = _recommendDecoder(vendor, false);
              final available = _getAvailableDecoders(vendor, false);

              debugPrint('GpuInfo: Detected $gpuName ($vendor)');
              return GpuInfo(
                gpuName: gpuName,
                vendor: vendor,
                recommendedDecoder: recommended,
                availableDecoders: available,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('GpuInfo: Linux detection error: $e');
    }

    return GpuInfo(availableDecoders: HardwareDecoder.availableDecoders);
  }

  /// Android GPU detection via system properties.
  Future<GpuInfo> _detectAndroid() async {
    // On Android we can't easily detect GPU name without native code,
    // but we know MediaCodec is available.
    debugPrint('GpuInfo: Android - using MediaCodec');
    return const GpuInfo(
      gpuName: 'Android GPU',
      vendor: 'Android',
      recommendedDecoder: HardwareDecoder.mediacodec,
      availableDecoders: [
        HardwareDecoder.auto,
        HardwareDecoder.mediacodec,
        HardwareDecoder.none,
      ],
    );
  }

  /// macOS GPU detection using system_profiler.
  Future<GpuInfo> _detectMacOS() async {
    try {
      final result = await Process.run('system_profiler', [
        'SPDisplaysDataType',
        '-json',
      ]);

      if (result.exitCode == 0) {
        // Parse JSON output (simplified - just extract first GPU name)
        final output = result.stdout as String;
        // Look for "chipset_model" in the output
        final match = RegExp(
          r'"chipset_model"\s*:\s*"([^"]+)"',
        ).firstMatch(output);
        if (match != null) {
          final gpuName = match.group(1);
          debugPrint('GpuInfo: Detected $gpuName (Apple)');
          return GpuInfo(
            gpuName: gpuName,
            vendor: 'Apple',
            recommendedDecoder: HardwareDecoder.videotoolbox,
            availableDecoders: [
              HardwareDecoder.auto,
              HardwareDecoder.videotoolbox,
              HardwareDecoder.none,
            ],
          );
        }
      }
    } catch (e) {
      debugPrint('GpuInfo: macOS detection error: $e');
    }

    return const GpuInfo(
      gpuName: 'Apple GPU',
      vendor: 'Apple',
      recommendedDecoder: HardwareDecoder.videotoolbox,
      availableDecoders: [
        HardwareDecoder.auto,
        HardwareDecoder.videotoolbox,
        HardwareDecoder.none,
      ],
    );
  }

  /// Detects GPU vendor from name string.
  String _detectVendor(String gpuName) {
    final lower = gpuName.toLowerCase();
    if (lower.contains('nvidia') || lower.contains('geforce')) {
      return 'NVIDIA';
    } else if (lower.contains('amd') || lower.contains('radeon')) {
      return 'AMD';
    } else if (lower.contains('intel')) {
      return 'Intel';
    } else if (lower.contains('apple') ||
        lower.contains('m1') ||
        lower.contains('m2') ||
        lower.contains('m3')) {
      return 'Apple';
    }
    return 'Unknown';
  }

  /// Recommends the best decoder for the detected vendor.
  HardwareDecoder _recommendDecoder(String vendor, bool isWindows) {
    switch (vendor) {
      case 'NVIDIA':
        return HardwareDecoder.nvdec;
      case 'AMD':
      case 'Intel':
        return isWindows ? HardwareDecoder.d3d11va : HardwareDecoder.vaapi;
      case 'Apple':
        return HardwareDecoder.videotoolbox;
      default:
        return HardwareDecoder.auto;
    }
  }

  /// Returns available decoders for the detected vendor and platform.
  List<HardwareDecoder> _getAvailableDecoders(String vendor, bool isWindows) {
    final decoders = <HardwareDecoder>[
      HardwareDecoder.auto,
      HardwareDecoder.none,
    ];

    if (isWindows) {
      decoders.add(HardwareDecoder.d3d11va);
      decoders.add(HardwareDecoder.dxva2);
      if (vendor == 'NVIDIA') {
        decoders.insert(2, HardwareDecoder.nvdec);
        decoders.add(HardwareDecoder.cuda);
      }
    } else if (Platform.isLinux) {
      decoders.add(HardwareDecoder.vaapi);
      if (vendor == 'NVIDIA') {
        decoders.insert(2, HardwareDecoder.nvdec);
        decoders.add(HardwareDecoder.vdpau);
      }
    }

    return decoders;
  }
}
