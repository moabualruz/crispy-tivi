import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_service_providers.dart';
import '../../../../core/widgets/async_value_ui.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart' show SettingsBadge, SettingsCard;

// FE-S-05: Accessibility settings — subtitle font size, subtitle background
// opacity, audio description, high-contrast mode, text scale override.

// ── Persistence keys ──────────────────────────────────────
const String _kSubtitleFontSizeKey = 'accessibility.subtitleFontSize';
const String _kSubtitleBgOpacityKey = 'accessibility.subtitleBgOpacity';
const String _kAudioDescriptionKey = 'accessibility.audioDescription';
const String _kHighContrastKey = 'accessibility.highContrast';
const String _kTextScaleKey = 'accessibility.textScale';

// ── Default values ────────────────────────────────────────
const double _kDefaultSubtitleFontSize = 16.0;
const double _kDefaultSubtitleBgOpacity = 0.6;
const double _kDefaultTextScale = 1.0;

/// FE-S-05: Accessibility settings state.
class AccessibilitySettings {
  const AccessibilitySettings({
    this.subtitleFontSize = _kDefaultSubtitleFontSize,
    this.subtitleBgOpacity = _kDefaultSubtitleBgOpacity,
    this.audioDescriptionEnabled = false,
    this.highContrastMode = false,
    this.textScale = _kDefaultTextScale,
  });

  /// Subtitle font size in logical pixels (12–32 pt).
  final double subtitleFontSize;

  /// Subtitle background opacity (0.0–1.0).
  final double subtitleBgOpacity;

  /// Whether audio description tracks are preferred.
  final bool audioDescriptionEnabled;

  /// Whether high-contrast mode is enabled.
  final bool highContrastMode;

  /// Global text scale override (0.8–1.6). 1.0 = system default.
  final double textScale;

  AccessibilitySettings copyWith({
    double? subtitleFontSize,
    double? subtitleBgOpacity,
    bool? audioDescriptionEnabled,
    bool? highContrastMode,
    double? textScale,
  }) {
    return AccessibilitySettings(
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleBgOpacity: subtitleBgOpacity ?? this.subtitleBgOpacity,
      audioDescriptionEnabled:
          audioDescriptionEnabled ?? this.audioDescriptionEnabled,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      textScale: textScale ?? this.textScale,
    );
  }
}

// FE-S-05: Notifier for accessibility settings.
class AccessibilitySettingsNotifier
    extends AsyncNotifier<AccessibilitySettings> {
  late CacheService _cache;

  @override
  Future<AccessibilitySettings> build() async {
    _cache = ref.read(cacheServiceProvider);

    final fontSizeStr = await _cache.getSetting(_kSubtitleFontSizeKey);
    final bgOpacityStr = await _cache.getSetting(_kSubtitleBgOpacityKey);
    final audioDescStr = await _cache.getSetting(_kAudioDescriptionKey);
    final highContrastStr = await _cache.getSetting(_kHighContrastKey);
    final textScaleStr = await _cache.getSetting(_kTextScaleKey);

    return AccessibilitySettings(
      subtitleFontSize:
          fontSizeStr != null
              ? double.tryParse(fontSizeStr) ?? _kDefaultSubtitleFontSize
              : _kDefaultSubtitleFontSize,
      subtitleBgOpacity:
          bgOpacityStr != null
              ? double.tryParse(bgOpacityStr) ?? _kDefaultSubtitleBgOpacity
              : _kDefaultSubtitleBgOpacity,
      audioDescriptionEnabled: audioDescStr == 'true',
      highContrastMode: highContrastStr == 'true',
      textScale:
          textScaleStr != null
              ? double.tryParse(textScaleStr) ?? _kDefaultTextScale
              : _kDefaultTextScale,
    );
  }

  Future<void> setSubtitleFontSize(double size) async {
    await _cache.setSetting(_kSubtitleFontSizeKey, size.toString());
    state = AsyncData(
      (state.value ?? const AccessibilitySettings()).copyWith(
        subtitleFontSize: size,
      ),
    );
  }

  Future<void> setSubtitleBgOpacity(double opacity) async {
    await _cache.setSetting(_kSubtitleBgOpacityKey, opacity.toString());
    state = AsyncData(
      (state.value ?? const AccessibilitySettings()).copyWith(
        subtitleBgOpacity: opacity,
      ),
    );
  }

  Future<void> setAudioDescription(bool enabled) async {
    await _cache.setSetting(_kAudioDescriptionKey, enabled.toString());
    state = AsyncData(
      (state.value ?? const AccessibilitySettings()).copyWith(
        audioDescriptionEnabled: enabled,
      ),
    );
  }

  Future<void> setHighContrast(bool enabled) async {
    await _cache.setSetting(_kHighContrastKey, enabled.toString());
    state = AsyncData(
      (state.value ?? const AccessibilitySettings()).copyWith(
        highContrastMode: enabled,
      ),
    );
  }

  Future<void> setTextScale(double scale) async {
    await _cache.setSetting(_kTextScaleKey, scale.toString());
    state = AsyncData(
      (state.value ?? const AccessibilitySettings()).copyWith(textScale: scale),
    );
  }
}

/// Global accessibility settings provider.
final accessibilitySettingsProvider =
    AsyncNotifierProvider<AccessibilitySettingsNotifier, AccessibilitySettings>(
      AccessibilitySettingsNotifier.new,
    );

// ─────────────────────────────────────────────────────────
//  FE-S-05: Accessibility settings section widget
// ─────────────────────────────────────────────────────────

/// FE-S-05: Accessibility settings section.
///
/// Contains:
/// - Subtitle font size slider (12–32 pt)
/// - Subtitle background opacity slider (0–100 %)
/// - Audio description toggle
/// - High-contrast mode toggle
/// - Text scale override slider (0.8–1.6×)
class AccessibilitySettingsSection extends ConsumerWidget {
  const AccessibilitySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(accessibilitySettingsProvider);

    return settingsAsync.whenShrink(
      data: (settings) => _buildContent(context, ref, settings),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AccessibilitySettings settings,
  ) {
    // FE-S-05
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifier = ref.read(accessibilitySettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Accessibility',
          icon: Icons.accessibility_new,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            // ── Subtitle Font Size ──────────────────────
            _SliderTile(
              icon: Icons.text_fields,
              title: 'Subtitle Font Size',
              valueLabel: '${settings.subtitleFontSize.toStringAsFixed(0)} pt',
              value: settings.subtitleFontSize,
              min: 12,
              max: 32,
              divisions: 20,
              onChanged: notifier.setSubtitleFontSize,
              cs: cs,
              tt: tt,
            ),
            const Divider(height: 1),

            // ── Subtitle Background Opacity ─────────────
            _SliderTile(
              icon: Icons.opacity,
              title: 'Subtitle Background',
              valueLabel:
                  '${(settings.subtitleBgOpacity * 100).toStringAsFixed(0)} %',
              value: settings.subtitleBgOpacity,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: notifier.setSubtitleBgOpacity,
              cs: cs,
              tt: tt,
            ),
            const Divider(height: 1),

            // ── Audio Description ───────────────────────
            SwitchListTile(
              secondary: const Icon(Icons.hearing),
              title: Row(
                children: [
                  const Text('Audio Description'),
                  const SizedBox(width: CrispySpacing.sm),
                  const SettingsBadge.experimental(),
                ],
              ),
              subtitle: const Text(
                'Prefer audio description tracks when available',
              ),
              value: settings.audioDescriptionEnabled,
              onChanged: notifier.setAudioDescription,
            ),
            const Divider(height: 1),

            // ── High-Contrast Mode ──────────────────────
            SwitchListTile(
              secondary: const Icon(Icons.contrast),
              title: const Text('High-Contrast Mode'),
              subtitle: const Text(
                'Increases color contrast for better visibility',
              ),
              value: settings.highContrastMode,
              onChanged: notifier.setHighContrast,
            ),
            const Divider(height: 1),

            // ── Text Scale ─────────────────────────────
            _SliderTile(
              icon: Icons.format_size,
              title: 'Text Scale',
              valueLabel: '${settings.textScale.toStringAsFixed(1)}×',
              value: settings.textScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              onChanged: notifier.setTextScale,
              cs: cs,
              tt: tt,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Shared slider tile
// ─────────────────────────────────────────────────────────

/// FE-S-05: Compact slider list tile for accessibility settings.
///
/// Shows a leading [icon], [title], and current [valueLabel] with a
/// [Slider] below for interactive adjustment.
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: CrispySpacing.md),
              Expanded(child: Text(title, style: tt.bodyMedium)),
              Text(
                valueLabel,
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            semanticFormatterCallback: (v) => '$title $valueLabel',
          ),
        ],
      ),
    );
  }
}
