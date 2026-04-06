import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/settings_notifier.dart';
import '../../../../../config/subtitle_style.dart';
import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/widgets/focus_wrapper.dart';
import '../../../domain/crispy_player.dart';
import '../../providers/player_providers.dart';
import 'osd_shared.dart';
import 'subtitle_style_widgets.dart';

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

/// Exposes the current [SubtitleStyle] from settings.
///
/// Rebuilds widgets only when the subtitle style changes —
/// not on every unrelated settings mutation.
final subtitleStyleProvider = Provider<SubtitleStyle>((ref) {
  return ref.watch(
    settingsNotifierProvider.select(
      (s) => s.value?.subtitleStyle ?? SubtitleStyle.defaults,
    ),
  );
});

// ─────────────────────────────────────────────────────────────
//  mpv property application
// ─────────────────────────────────────────────────────────────

/// Apply all [SubtitleStyle] fields to the player's mpv backend
/// via [CrispyPlayer.setProperty]. Safe to call on non-mpv
/// backends (they no-op).
void applySubtitleStyleToPlayer(CrispyPlayer player, SubtitleStyle style) {
  player.setProperty('sub-font-size', '${style.fontSize.pixels}');
  player.setProperty('sub-bold', style.isBold ? 'yes' : 'no');
  player.setProperty('sub-pos', '${style.verticalPosition}');
  player.setProperty('sub-color', _colorToMpvHex(style.textColor.color));
  player.setProperty(
    'sub-border-color',
    _colorToMpvHex(style.outlineColor.color),
  );
  player.setProperty('sub-border-size', '${style.outlineSize}');

  // Background: combine background color with opacity.
  final bgColor = style.background.color;
  final bgAlpha = (style.backgroundOpacity * 255).round().clamp(0, 255);
  final bgWithAlpha = bgColor.withAlpha(bgAlpha);
  player.setProperty('sub-back-color', _colorToMpvHex(bgWithAlpha));

  player.setProperty('sub-shadow-offset', style.hasShadow ? '2' : '0');
}

/// Convert a Flutter [Color] to mpv hex format `#AARRGGBB`.
String _colorToMpvHex(Color c) {
  final a = (c.a * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#$a$r$g$b';
}

// ─────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────

/// Opens the CC style customisation sheet as a [showGeneralDialog]
/// anchored to the bottom-right of the screen (matches OSD panel
/// style used by [showSubtitleTrackPicker]).
void showSubtitleStyleDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close CC Style',
    barrierColor: Colors.black38,
    transitionDuration: CrispyAnimation.osdShow,
    transitionBuilder:
        (ctx, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0.3),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: anim, curve: CrispyAnimation.enterCurve),
          ),
          child: FadeTransition(opacity: anim, child: child),
        ),
    pageBuilder:
        (ctx, anim2, sec) => Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(
              right: CrispySpacing.lg,
              bottom: kOsdBottomBarHeight + CrispySpacing.sm,
            ),
            child: _SubtitleStyleSheet(onClose: () => Navigator.pop(ctx)),
          ),
        ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Sheet widget
// ─────────────────────────────────────────────────────────────

class _SubtitleStyleSheet extends ConsumerStatefulWidget {
  const _SubtitleStyleSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_SubtitleStyleSheet> createState() =>
      _SubtitleStyleSheetState();
}

class _SubtitleStyleSheetState extends ConsumerState<_SubtitleStyleSheet> {
  /// Working copy — applied on every change so the preview is live.
  late SubtitleStyle _draft;

  @override
  void initState() {
    super.initState();
    _draft =
        ref.read(settingsNotifierProvider).value?.subtitleStyle ??
        SubtitleStyle.defaults;
  }

  Future<void> _apply(SubtitleStyle next) async {
    setState(() => _draft = next);
    await ref.read(settingsNotifierProvider.notifier).setSubtitleStyle(next);
    // Apply to mpv immediately for live feedback.
    try {
      final player = ref.read(playerProvider);
      applySubtitleStyleToPlayer(player, next);
    } catch (_) {
      // Player may not be active (e.g. settings screen).
    }
  }

  Future<void> _reset() async {
    final defaults = SubtitleStyle.defaults;
    setState(() => _draft = defaults);
    await ref.read(settingsNotifierProvider.notifier).resetSubtitleStyle();
    try {
      final player = ref.read(playerProvider);
      applySubtitleStyleToPlayer(player, defaults);
    } catch (e) {
      debugPrint('[SubtitleStyleDialog] reset subtitle style failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: osdPanelColor,
      borderRadius: BorderRadius.circular(CrispyRadius.tv),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 440,
          minWidth: 320,
          maxHeight: 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────
            SubtitleStyleSheetHeader(
              title: context.l10n.playerSubtitlesCcStyle,
              onClose: widget.onClose,
              textTheme: textTheme,
            ),

            const Divider(color: Colors.white12, height: 1),

            // ── Scrollable body ─────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(CrispySpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Font weight
                    SubtitleSectionLabel(
                      label: 'FONT WEIGHT',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitleChipRow<bool>(
                      values: const [false, true],
                      selected: _draft.isBold,
                      labelOf:
                          (v) =>
                              v
                                  ? context.l10n.playerSubtitleBold
                                  : context.l10n.playerSubtitleNormal,
                      onChanged: (v) => _apply(_draft.copyWith(isBold: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 2. Font size
                    SubtitleSectionLabel(
                      label: 'FONT SIZE',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitleFontSizeRow(
                      selected: _draft.fontSize,
                      onChanged: (v) => _apply(_draft.copyWith(fontSize: v)),
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 3. Vertical position
                    SubtitleSectionLabel(
                      label: 'POSITION (${_draft.verticalPosition}%)',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    SubtitleOsdSlider(
                      value: _draft.verticalPosition.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged:
                          (v) => _apply(
                            _draft.copyWith(verticalPosition: v.round()),
                          ),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 4. Text colour
                    SubtitleSectionLabel(
                      label: 'TEXT COLOR',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitleColorCircleRow(
                      selected: _draft.textColor,
                      onChanged: (v) => _apply(_draft.copyWith(textColor: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 5. Outline color
                    SubtitleSectionLabel(
                      label: 'OUTLINE COLOR',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitleOutlineColorRow(
                      selected: _draft.outlineColor,
                      onChanged:
                          (v) => _apply(_draft.copyWith(outlineColor: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 6. Outline size
                    SubtitleSectionLabel(
                      label:
                          'OUTLINE SIZE (${_draft.outlineSize.toStringAsFixed(1)})',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    SubtitleOsdSlider(
                      value: _draft.outlineSize,
                      min: 0,
                      max: 10,
                      divisions: 20,
                      onChanged: (v) => _apply(_draft.copyWith(outlineSize: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 7. Background
                    SubtitleSectionLabel(
                      label: 'BACKGROUND',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitleChipRow<SubtitleBackground>(
                      values: SubtitleBackground.values,
                      selected: _draft.background,
                      labelOf: (v) => v.label,
                      onChanged: (v) => _apply(_draft.copyWith(background: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 8. Background opacity
                    SubtitleSectionLabel(
                      label:
                          'BG OPACITY (${(_draft.backgroundOpacity * 100).round()}%)',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    SubtitleOsdSlider(
                      value: _draft.backgroundOpacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged:
                          (v) => _apply(_draft.copyWith(backgroundOpacity: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 9. Shadow toggle
                    SubtitleSectionLabel(label: 'SHADOW', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitleChipRow<bool>(
                      values: const [true, false],
                      selected: _draft.hasShadow,
                      labelOf:
                          (v) =>
                              v
                                  ? context.l10n.commonOn
                                  : context.l10n.commonOff,
                      onChanged: (v) => _apply(_draft.copyWith(hasShadow: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // Live preview
                    SubtitleSectionLabel(
                      label: 'PREVIEW',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    SubtitlePreviewBox(style: _draft),

                    const SizedBox(height: CrispySpacing.md),

                    // Reset button
                    Center(
                      child: FocusWrapper(
                        onSelect: _reset,
                        borderRadius: CrispyRadius.tv,
                        child: TextButton.icon(
                          onPressed: _reset,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white54,
                            size: 18,
                          ),
                          label: Text(
                            context.l10n.playerSubtitleResetDefaults,
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
