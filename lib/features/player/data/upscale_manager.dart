import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../domain/crispy_player.dart';
import '../domain/entities/gpu_info.dart';
import '../domain/entities/upscale_mode.dart';
import '../domain/entities/upscale_quality.dart';
import 'metalfx_bridge.dart' as metalfx_bridge;
import 'upscale_tier.dart';

/// Orchestrates video upscaling detection and filter
/// application via [CrispyPlayer].
///
/// Supports GPU-aware hardware tiers (RTX VSR, Intel
/// VSR, MetalFX) when [GpuInfo] indicates capability,
/// with software tiers (FSR GLSL, ewa_lanczossharp,
/// spline36) as fallback.
///
/// See `the project video upscaling specification` §4.4.
class UpscaleManager {
  /// Cached path to the extracted FSR shader file.
  String? _cachedShaderPath;

  /// Applies the best available upscaling method to
  /// [player] based on [mode], [quality], and [gpu].
  ///
  /// Returns the tier level that succeeded, or `null`
  /// if all tiers failed (unprocessed playback).
  ///
  /// When [mode] is [UpscaleMode.off], removes any
  /// active upscaling and returns `null`.
  Future<int?> applyUpscaling(
    CrispyPlayer player,
    UpscaleMode mode,
    UpscaleQuality quality,
    GpuInfo gpu,
  ) async {
    if (mode == UpscaleMode.off) {
      await removeUpscaling(player);
      return null;
    }

    final chain = _buildFallbackChain(player, mode, quality, gpu);

    for (final tier in chain) {
      try {
        final ok = await tier.apply();
        if (ok) {
          debugPrint(
            'UpscaleManager: active — '
            '${tier.name} (tier ${tier.level})',
          );
          return tier.level;
        }
      } catch (e) {
        debugPrint(
          'UpscaleManager: tier ${tier.level} '
          '(${tier.name}) failed: $e',
        );
        // Continue to next tier.
      }
    }

    // All tiers failed — unprocessed playback.
    debugPrint(
      'UpscaleManager: all tiers failed. '
      'Unprocessed playback.',
    );
    return null;
  }

  /// Removes all upscaling filters from [player].
  ///
  /// Clears GLSL shaders and resets the scale algorithm
  /// to mpv's default (bilinear).
  Future<void> removeUpscaling(CrispyPlayer player) async {
    if (kIsWeb) return;
    try {
      player.setProperty('glsl-shaders', '');
      player.setProperty('scale', 'bilinear');
      player.setProperty('vf', '');

      // Dispose MetalFX resources if active.
      if (metalfx_bridge.isMetalFxPlatform) {
        await metalfx_bridge.disposeMetalFx();
      }

      debugPrint('UpscaleManager: upscaling removed');
    } catch (e) {
      debugPrint('UpscaleManager: removeUpscaling failed: $e');
    }
  }

  /// Builds the fallback chain with GPU-aware tiers.
  ///
  /// Chain order (when [gpu] supports HW VSR):
  /// - **Tier 0**: RTX Video SDK (NVIDIA AI upscaling)
  /// - **Tier 1**: Hardware AI (RTX VSR / Intel VSR)
  /// - **Tier 2**: MetalFX (Apple platforms)
  /// - **Tier 2.5**: Core ML SR (Apple platforms)
  /// - **Tier 3**: FSR GLSL shader (maximum quality)
  /// - **Tier 3.5**: Qualcomm GSR (Android Adreno)
  /// - **Tier 4**: ewa_lanczossharp / spline36
  ///
  /// When [mode] is [UpscaleMode.forceSoftware], HW
  /// tiers (0-2.5) are skipped.
  List<UpscaleTier> _buildFallbackChain(
    CrispyPlayer player,
    UpscaleMode mode,
    UpscaleQuality quality,
    GpuInfo gpu,
  ) {
    final tiers = <UpscaleTier>[];

    // Tier 0: NVIDIA RTX Video SDK AI upscaling.
    if (mode != UpscaleMode.forceSoftware &&
        gpu.vendor == GpuVendor.nvidia &&
        gpu.supportsHwVsr) {
      tiers.add(
        UpscaleTier(
          level: 0,
          name: 'RTX Video SDK',
          apply: () => _tryRtxVideoSdk(player),
        ),
      );
    }

    // Tier 1: Hardware AI (Windows NVIDIA/Intel).
    if (mode != UpscaleMode.forceSoftware && gpu.supportsHwVsr) {
      if (gpu.vsrMethod == VsrMethod.d3d11Nvidia) {
        tiers.add(
          UpscaleTier(
            level: 1,
            name: 'RTX VSR',
            apply: () => _trySetVf(player, 'd3d11vpp:scaling-mode=nvidia'),
          ),
        );
      }
      if (gpu.vsrMethod == VsrMethod.d3d11Intel) {
        tiers.add(
          UpscaleTier(
            level: 1,
            name: 'Intel VSR',
            apply: () => _trySetVf(player, 'd3d11vpp:scaling-mode=intel'),
          ),
        );
      }
    }

    // Tier 2: MetalFX (Apple platforms).
    if (mode != UpscaleMode.forceSoftware &&
        gpu.vsrMethod == VsrMethod.metalFxSpatial) {
      tiers.add(
        UpscaleTier(level: 2, name: 'MetalFX', apply: () => _tryMetalFx()),
      );
    }

    // Tier 2.5: Core ML Super Resolution (Apple).
    if (mode != UpscaleMode.forceSoftware &&
        gpu.vendor == GpuVendor.apple &&
        (Platform.isMacOS || Platform.isIOS)) {
      tiers.add(
        UpscaleTier(
          level: 2,
          name: 'Core ML SR',
          apply: () => _tryCoremlSr(player),
        ),
      );
    }

    // Tier 3: FSR GLSL shader (maximum quality only).
    if (quality == UpscaleQuality.maximum) {
      tiers.add(
        UpscaleTier(
          level: 3,
          name: 'FSR GLSL',
          apply: () => _trySetShader(player, 'assets/shaders/FSR.glsl'),
        ),
      );
    }

    // Tier 3.5: Qualcomm GSR (Android Adreno).
    if (Platform.isAndroid &&
        gpu.vendor == GpuVendor.qualcomm &&
        (quality == UpscaleQuality.maximum ||
            quality == UpscaleQuality.balanced)) {
      tiers.add(
        UpscaleTier(
          level: 3,
          name: 'Qualcomm GSR',
          apply: () => _trySetShader(player, 'assets/shaders/QualcommGSR.glsl'),
        ),
      );
    }

    // Tier 4: ewa_lanczossharp (balanced+ quality).
    if (quality == UpscaleQuality.maximum ||
        quality == UpscaleQuality.balanced) {
      tiers.add(
        UpscaleTier(
          level: 4,
          name: 'ewa_lanczossharp',
          apply: () => _trySetScale(player, 'ewa_lanczossharp'),
        ),
      );
    }

    // Tier 4b: spline36 (all quality levels).
    tiers.add(
      UpscaleTier(
        level: 4,
        name: 'spline36',
        apply: () => _trySetScale(player, 'spline36'),
      ),
    );

    return tiers;
  }

  /// Attempts to set a GLSL shader on [player].
  ///
  /// Extracts the shader from Flutter assets to a temp
  /// directory (cached across calls), then sets the
  /// `glsl-shaders` mpv property.
  ///
  /// Returns `true` on success, `false` if the shader
  /// could not be loaded or applied.
  Future<bool> _trySetShader(CrispyPlayer player, String assetPath) async {
    if (kIsWeb) return false;
    try {
      final path = await extractShaderAsset(assetPath);
      if (path == null) return false;

      player.setProperty('glsl-shaders', path);
      debugPrint('UpscaleManager: shader applied — $path');
      return true;
    } catch (e) {
      debugPrint('UpscaleManager: _trySetShader failed: $e');
      return false;
    }
  }

  /// Attempts to set the mpv `scale` property on
  /// [player].
  ///
  /// Returns `true` on success, `false` otherwise.
  Future<bool> _trySetScale(CrispyPlayer player, String scaler) async {
    if (kIsWeb) return false;
    try {
      player.setProperty('scale', scaler);
      debugPrint('UpscaleManager: scaler applied — $scaler');
      return true;
    } catch (e) {
      debugPrint(
        'UpscaleManager: _trySetScale($scaler) '
        'failed: $e',
      );
      return false;
    }
  }

  /// Attempts to set a video filter on [player].
  ///
  /// Used for D3D11 hardware VSR (NVIDIA RTX VSR,
  /// Intel VSR). Returns `true` on success.
  Future<bool> _trySetVf(CrispyPlayer player, String filter) async {
    if (kIsWeb) return false;
    try {
      player.setProperty('vf', filter);
      // Verify it applied.
      final actual = player.getProperty('vf');
      return actual?.contains('d3d11vpp') ?? false;
    } catch (e) {
      debugPrint(
        'UpscaleManager: _trySetVf($filter) '
        'failed: $e',
      );
      return false;
    }
  }

  /// Attempts NVIDIA RTX Video SDK AI upscaling.
  ///
  /// Uses mpv's `vf=rtx-upscale` video filter. Only
  /// available on NVIDIA GPUs with RTX Video SDK
  /// support.
  Future<bool> _tryRtxVideoSdk(CrispyPlayer player) async {
    if (kIsWeb) return false;
    try {
      player.setProperty('vf', 'rtx-upscale');
      final actual = player.getProperty('vf');
      return actual?.contains('rtx') ?? false;
    } catch (e) {
      debugPrint('UpscaleManager: RTX Video SDK failed: $e');
      return false;
    }
  }

  /// Attempts Apple Core ML super resolution.
  ///
  /// Uses mpv's `vf=coreml-sr` video filter. Only
  /// available on macOS and iOS with Apple GPUs.
  Future<bool> _tryCoremlSr(CrispyPlayer player) async {
    if (kIsWeb) return false;
    try {
      player.setProperty('vf', 'coreml-sr');
      final actual = player.getProperty('vf');
      return actual?.contains('coreml') ?? false;
    } catch (e) {
      debugPrint('UpscaleManager: Core ML SR failed: $e');
      return false;
    }
  }

  /// Attempts MetalFX upscaling on Apple Silicon devices.
  ///
  /// Uses the MetalFX bridge (platform channel to Swift
  /// `MTLFXSpatialScaler`) for hardware-accelerated upscaling.
  /// Falls back gracefully if the bridge reports unavailability.
  Future<bool> _tryMetalFx() async {
    if (!metalfx_bridge.isMetalFxPlatform) return false;

    try {
      final initialized = await metalfx_bridge.initMetalFx();
      if (!initialized) return false;

      // Default 2× spatial upscale; the tier chain only calls
      // this when the GPU tier indicates Apple Silicon support.
      const scaleFactor = 2.0;

      final applied = await metalfx_bridge.applyMetalFx(
        scaleFactor: scaleFactor,
      );
      if (applied) {
        debugPrint(
          'UpscaleManager: MetalFX spatial upscaling active '
          '(${scaleFactor}x)',
        );
      }
      return applied;
    } catch (e) {
      debugPrint('UpscaleManager: MetalFX failed: $e');
      return false;
    }
  }

  /// Extracts a shader asset from the Flutter bundle
  /// to a temporary file and returns its absolute path.
  ///
  /// Returns `null` if the asset cannot be loaded or
  /// written to disk. The extracted file is cached; only
  /// the first call performs I/O.
  @visibleForTesting
  Future<String?> extractShaderAsset(String assetPath) async {
    // Return cached path if already extracted.
    if (_cachedShaderPath != null) {
      final cached = File(_cachedShaderPath!);
      if (cached.existsSync()) return _cachedShaderPath;
    }

    try {
      final data = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${tempDir.path}/crispy_shaders/$fileName');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      _cachedShaderPath = file.path;
      debugPrint(
        'UpscaleManager: shader extracted to '
        '${file.path}',
      );
      return file.path;
    } catch (e) {
      debugPrint(
        'UpscaleManager: extractShaderAsset '
        'failed: $e',
      );
      return null;
    }
  }
}
