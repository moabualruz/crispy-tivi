import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../config/settings_notifier.dart';

// ─────────────────────────────────────────────────────────────
//  Shader Preset Type
// ─────────────────────────────────────────────────────────────

/// Types of shader presets.
enum ShaderPresetType { none, nvscaler, anime4k }

/// Quality tiers for Anime4K presets.
enum Anime4KQuality { fast, hq }

/// Anime4K modes defining shader combinations.
enum Anime4KMode { modeA, modeB, modeC, modeAA, modeBB, modeCA }

// ─────────────────────────────────────────────────────────────
//  Shader Preset
// ─────────────────────────────────────────────────────────────

/// A GPU shader preset configuration.
class ShaderPreset {
  const ShaderPreset({
    required this.id,
    required this.name,
    required this.type,
    this.anime4kQuality,
    this.anime4kMode,
    this.autoHdrSkip = false,
  });

  final String id;
  final String name;
  final ShaderPresetType type;
  final Anime4KQuality? anime4kQuality;
  final Anime4KMode? anime4kMode;

  /// For NVScaler: skip shaders on HDR content.
  final bool autoHdrSkip;

  bool get isEnabled => type != ShaderPresetType.none;

  /// No shader preset (off).
  static const none = ShaderPreset(
    id: 'none',
    name: 'Off',
    type: ShaderPresetType.none,
  );

  /// NVScaler with auto HDR skip.
  static const nvscaler = ShaderPreset(
    id: 'nvscaler',
    name: 'NVScaler',
    type: ShaderPresetType.nvscaler,
    autoHdrSkip: true,
  );

  /// Create an Anime4K preset.
  static ShaderPreset anime4k(Anime4KQuality quality, Anime4KMode mode) {
    final q = quality == Anime4KQuality.fast ? 'Fast' : 'HQ';
    final m = _modeName(mode);
    return ShaderPreset(
      id: 'anime4k_${quality.name}_${mode.name}',
      name: 'Anime4K $q $m',
      type: ShaderPresetType.anime4k,
      anime4kQuality: quality,
      anime4kMode: mode,
    );
  }

  static String _modeName(Anime4KMode mode) => switch (mode) {
    Anime4KMode.modeA => 'A',
    Anime4KMode.modeB => 'B',
    Anime4KMode.modeC => 'C',
    Anime4KMode.modeAA => 'A+A',
    Anime4KMode.modeBB => 'B+B',
    Anime4KMode.modeCA => 'C+A',
  };

  /// All 14 built-in presets: Off + NVScaler + 12 Anime4K.
  static List<ShaderPreset> get allPresets => [
    none,
    nvscaler,
    for (final q in Anime4KQuality.values)
      for (final m in Anime4KMode.values) anime4k(q, m),
  ];

  /// Find a preset by its ID.
  static ShaderPreset? fromId(String id) {
    for (final p in allPresets) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ShaderPreset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─────────────────────────────────────────────────────────────
//  Settings Key
// ─────────────────────────────────────────────────────────────

/// Key for persisting the selected shader preset ID.
const kShaderPresetKey = 'crispy_shader_preset';

// ─────────────────────────────────────────────────────────────
//  Shader Service
// ─────────────────────────────────────────────────────────────

/// Manages GPU shader presets for media_kit (mpv backend).
///
/// Desktop-only — on mobile/web, all operations are no-ops.
/// Shader files must be installed on the system; the service
/// tells mpv which GLSL files to load via `glsl-shaders`.
class ShaderService {
  ShaderService(this._player);

  final Player _player;
  ShaderPreset _currentPreset = ShaderPreset.none;

  /// The currently applied shader preset.
  ShaderPreset get currentPreset => _currentPreset;

  /// Apply a shader preset.
  ///
  /// Clears existing shaders, then appends the preset's GLSL
  /// files. For NVScaler with [autoHdrSkip], skips if content
  /// is HDR.
  Future<void> applyPreset(ShaderPreset preset) async {
    if (!_isDesktop) return;

    try {
      // HDR auto-skip for NVScaler.
      if (preset.type == ShaderPresetType.nvscaler && preset.autoHdrSkip) {
        final isHdr = await _isHdrContent();
        if (isHdr) {
          await _clearShaders();
          _currentPreset = ShaderPreset.none;
          return;
        }
      }

      await _clearShaders();

      if (preset.type == ShaderPresetType.none) {
        _currentPreset = preset;
        return;
      }

      // Build shader file paths for the preset.
      final paths = _shaderPaths(preset);
      for (final path in paths) {
        await _mpvCommand(['change-list', 'glsl-shaders', 'append', path]);
      }

      _currentPreset = preset;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShaderService: Failed to apply preset: $e');
      }
    }
  }

  /// Cycle to the next preset.
  Future<ShaderPreset> cyclePreset() async {
    final presets = ShaderPreset.allPresets;
    final idx = presets.indexWhere((p) => p.id == _currentPreset.id);
    final next = presets[(idx + 1) % presets.length];
    await applyPreset(next);
    return _currentPreset;
  }

  /// Clear all shaders (set to "Off").
  Future<void> disable() async {
    await applyPreset(ShaderPreset.none);
  }

  /// Reapply the current preset after a video source change.
  Future<void> reapply() async {
    if (_currentPreset.isEnabled) {
      await applyPreset(_currentPreset);
    }
  }

  // ── Private ──────────────────────────────────────────────

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<void> _clearShaders() async {
    try {
      await _mpvCommand(['change-list', 'glsl-shaders', 'clr', '']);
    } catch (_) {}
  }

  Future<void> _mpvCommand(List<String> args) async {
    if (kIsWeb) return;
    final dynamic np = _player.platform;
    if (np is NativePlayer) {
      await (np as dynamic).command(args);
    }
  }

  Future<bool> _isHdrContent() async {
    if (kIsWeb) return false;
    try {
      final np = _player.platform;
      if (np is! NativePlayer) return false;

      final dynamic dnp = np;
      final colormatrix =
          await dnp.getProperty('video-params/colormatrix') as String?;
      if (colormatrix?.contains('bt.2020') == true) return true;

      final primaries =
          await dnp.getProperty('video-params/primaries') as String?;
      if (primaries?.contains('bt.2020') == true) return true;

      final gamma = await dnp.getProperty('video-params/gamma') as String?;
      if (gamma?.contains('pq') == true || gamma?.contains('hlg') == true) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Resolves shader file paths for a preset.
  ///
  /// NVScaler: single `NVScaler.glsl` file.
  /// Anime4K: combination of Clamp/Restore/Upscale/Downscale
  /// based on mode and quality tier.
  List<String> _shaderPaths(ShaderPreset preset) {
    switch (preset.type) {
      case ShaderPresetType.none:
        return [];
      case ShaderPresetType.nvscaler:
        return ['~~/shaders/NVScaler.glsl'];
      case ShaderPresetType.anime4k:
        return _anime4kPaths(preset.anime4kQuality!, preset.anime4kMode!);
    }
  }

  List<String> _anime4kPaths(Anime4KQuality quality, Anime4KMode mode) {
    final q = quality == Anime4KQuality.fast ? 'L' : 'VL';
    final base = '~~/shaders/Anime4K';

    return switch (mode) {
      Anime4KMode.modeA => [
        '$base/Anime4K_Clamp_Highlights.glsl',
        '$base/Anime4K_Restore_CNN_$q.glsl',
      ],
      Anime4KMode.modeB => [
        '$base/Anime4K_Clamp_Highlights.glsl',
        '$base/Anime4K_Restore_CNN_$q.glsl',
        '$base/Anime4K_Upscale_CNN_x2_$q.glsl',
        '$base/Anime4K_AutoDownscalePre_x2.glsl',
        '$base/Anime4K_AutoDownscalePre_x4.glsl',
      ],
      Anime4KMode.modeC => [
        '$base/Anime4K_Clamp_Highlights.glsl',
        '$base/Anime4K_Upscale_Denoise_CNN_x2_$q.glsl',
        '$base/Anime4K_AutoDownscalePre_x2.glsl',
        '$base/Anime4K_AutoDownscalePre_x4.glsl',
      ],
      Anime4KMode.modeAA => [
        '$base/Anime4K_Clamp_Highlights.glsl',
        '$base/Anime4K_Restore_CNN_$q.glsl',
        '$base/Anime4K_Restore_CNN_M.glsl',
      ],
      Anime4KMode.modeBB => [
        '$base/Anime4K_Clamp_Highlights.glsl',
        '$base/Anime4K_Restore_CNN_$q.glsl',
        '$base/Anime4K_Restore_CNN_M.glsl',
        '$base/Anime4K_Upscale_CNN_x2_$q.glsl',
        '$base/Anime4K_AutoDownscalePre_x2.glsl',
        '$base/Anime4K_AutoDownscalePre_x4.glsl',
      ],
      Anime4KMode.modeCA => [
        '$base/Anime4K_Clamp_Highlights.glsl',
        '$base/Anime4K_Upscale_Denoise_CNN_x2_$q.glsl',
        '$base/Anime4K_Restore_CNN_M.glsl',
        '$base/Anime4K_AutoDownscalePre_x2.glsl',
        '$base/Anime4K_AutoDownscalePre_x4.glsl',
      ],
    };
  }
}

// ─────────────────────────────────────────────────────────────
//  Providers
// ─────────────────────────────────────────────────────────────

/// Current shader preset ID, read from settings.
final shaderPresetProvider = Provider<ShaderPreset>((ref) {
  final id = ref.watch(
    settingsNotifierProvider.select((s) => s.value?.shaderPresetId ?? 'none'),
  );
  return ShaderPreset.fromId(id) ?? ShaderPreset.none;
});
