import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/settings_notifier.dart';
import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/widgets/focus_wrapper.dart';
import '../../../domain/crispy_player.dart';
import '../../providers/player_providers.dart';
import 'osd_shared.dart';

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
    } catch (_) {}
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
            _SheetHeader(
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
                    _SectionLabel(label: 'FONT WEIGHT', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _ChipRow<bool>(
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
                    _SectionLabel(label: 'FONT SIZE', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _FontSizeRow(
                      selected: _draft.fontSize,
                      onChanged: (v) => _apply(_draft.copyWith(fontSize: v)),
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 3. Vertical position
                    _SectionLabel(
                      label: 'POSITION (${_draft.verticalPosition}%)',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    _OsdSlider(
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
                    _SectionLabel(label: 'TEXT COLOR', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _ColorCircleRow(
                      selected: _draft.textColor,
                      onChanged: (v) => _apply(_draft.copyWith(textColor: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 5. Outline color
                    _SectionLabel(label: 'OUTLINE COLOR', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _OutlineColorRow(
                      selected: _draft.outlineColor,
                      onChanged:
                          (v) => _apply(_draft.copyWith(outlineColor: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 6. Outline size
                    _SectionLabel(
                      label:
                          'OUTLINE SIZE (${_draft.outlineSize.toStringAsFixed(1)})',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    _OsdSlider(
                      value: _draft.outlineSize,
                      min: 0,
                      max: 10,
                      divisions: 20,
                      onChanged: (v) => _apply(_draft.copyWith(outlineSize: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 7. Background
                    _SectionLabel(label: 'BACKGROUND', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _ChipRow<SubtitleBackground>(
                      values: SubtitleBackground.values,
                      selected: _draft.background,
                      labelOf: (v) => v.label,
                      onChanged: (v) => _apply(_draft.copyWith(background: v)),
                      colorScheme: colorScheme,
                    ),

                    const SizedBox(height: CrispySpacing.md),

                    // 8. Background opacity
                    _SectionLabel(
                      label:
                          'BG OPACITY (${(_draft.backgroundOpacity * 100).round()}%)',
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    _OsdSlider(
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
                    _SectionLabel(label: 'SHADOW', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _ChipRow<bool>(
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
                    _SectionLabel(label: 'PREVIEW', textTheme: textTheme),
                    const SizedBox(height: CrispySpacing.sm),
                    _PreviewBox(style: _draft),

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

// ─────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────

/// Header row with title and close button.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.onClose,
    required this.textTheme,
  });

  final String title;
  final VoidCallback onClose;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: CrispySpacing.md,
      vertical: CrispySpacing.sm,
    ),
    child: Row(
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Tooltip(
          message: context.l10n.commonClose,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
          ),
        ),
      ],
    ),
  );
}

/// A small uppercase section label.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.textTheme});

  final String label;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: textTheme.labelSmall?.copyWith(
      color: Colors.white60,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
  );
}

// ── Font size row ─────────────────────────────────────────────

class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({required this.selected, required this.onChanged});

  final SubtitleFontSize selected;
  final ValueChanged<SubtitleFontSize> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: CrispySpacing.sm,
      children:
          SubtitleFontSize.values.map((size) {
            final isSelected = size == selected;
            return FocusWrapper(
              onSelect: () => onChanged(size),
              borderRadius: CrispyRadius.tv,
              child: GestureDetector(
                onTap: () => onChanged(size),
                child: AnimatedContainer(
                  duration: CrispyAnimation.fast,
                  curve: CrispyAnimation.enterCurve,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.md,
                    vertical: CrispySpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colorScheme.primary
                            : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                  child: Text(
                    size.label,
                    style: TextStyle(
                      color:
                          isSelected ? colorScheme.onPrimary : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── Colour circle row ─────────────────────────────────────────

class _ColorCircleRow extends StatelessWidget {
  const _ColorCircleRow({
    required this.selected,
    required this.onChanged,
    required this.colorScheme,
  });

  final SubtitleTextColor selected;
  final ValueChanged<SubtitleTextColor> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children:
        SubtitleTextColor.values.map((tc) {
          final isSelected = tc == selected;
          return Padding(
            padding: const EdgeInsets.only(right: CrispySpacing.sm),
            child: Semantics(
              label: tc.label,
              selected: isSelected,
              button: true,
              child: FocusWrapper(
                onSelect: () => onChanged(tc),
                borderRadius: CrispyRadius.tv,
                child: GestureDetector(
                  onTap: () => onChanged(tc),
                  child: AnimatedContainer(
                    duration: CrispyAnimation.fast,
                    curve: CrispyAnimation.enterCurve,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tc.color,
                      border: Border.all(
                        color:
                            isSelected ? colorScheme.primary : Colors.white24,
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check,
                              color: Colors.black87,
                              size: 16,
                            )
                            : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
  );
}

// ── Outline colour circle row ──────────────────────────────────

class _OutlineColorRow extends StatelessWidget {
  const _OutlineColorRow({
    required this.selected,
    required this.onChanged,
    required this.colorScheme,
  });

  final SubtitleOutlineColor selected;
  final ValueChanged<SubtitleOutlineColor> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children:
        SubtitleOutlineColor.values.map((oc) {
          final isSelected = oc == selected;
          return Padding(
            padding: const EdgeInsets.only(right: CrispySpacing.sm),
            child: Semantics(
              label: oc.label,
              selected: isSelected,
              button: true,
              child: FocusWrapper(
                onSelect: () => onChanged(oc),
                borderRadius: CrispyRadius.tv,
                child: GestureDetector(
                  onTap: () => onChanged(oc),
                  child: AnimatedContainer(
                    duration: CrispyAnimation.fast,
                    curve: CrispyAnimation.enterCurve,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          oc == SubtitleOutlineColor.transparent
                              ? Colors.grey.shade800
                              : oc.color,
                      border: Border.all(
                        color:
                            isSelected ? colorScheme.primary : Colors.white24,
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                    child:
                        oc == SubtitleOutlineColor.transparent && !isSelected
                            ? const Icon(
                              Icons.block,
                              color: Colors.white38,
                              size: 16,
                            )
                            : isSelected
                            ? Icon(
                              Icons.check,
                              color:
                                  oc == SubtitleOutlineColor.white
                                      ? Colors.black87
                                      : Colors.white,
                              size: 16,
                            )
                            : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
  );
}

// ── Generic chip row ──────────────────────────────────────────

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    required this.colorScheme,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: CrispySpacing.sm,
      runSpacing: CrispySpacing.xs,
      children:
          values.map((v) {
            final isSelected = v == selected;
            return FocusWrapper(
              onSelect: () => onChanged(v),
              borderRadius: CrispyRadius.tv,
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: CrispyAnimation.fast,
                  curve: CrispyAnimation.enterCurve,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.sm,
                    vertical: CrispySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colorScheme.primary
                            : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                  child: Text(
                    labelOf(v),
                    style: textTheme.labelSmall?.copyWith(
                      color:
                          isSelected ? colorScheme.onPrimary : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── OSD-style slider ──────────────────────────────────────────

class _OsdSlider extends StatelessWidget {
  const _OsdSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.colorScheme,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderThemeData(
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: Colors.white12,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    ),
    child: Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
    ),
  );
}

// ── Live preview ──────────────────────────────────────────────

/// A small preview pane that renders subtitle text using the
/// current [SubtitleStyle] settings so the user sees a live
/// result before leaving the dialog.
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.style});

  final SubtitleStyle style;

  List<Shadow>? _shadows() {
    final shadows = <Shadow>[];

    // Outline simulation via multiple offset shadows.
    if (style.outlineSize > 0 &&
        style.outlineColor != SubtitleOutlineColor.transparent) {
      final oc = style.outlineColor.color;
      final d = style.outlineSize.clamp(0.5, 3.0);
      shadows.addAll([
        Shadow(color: oc, offset: Offset(-d, -d)),
        Shadow(color: oc, offset: Offset(d, -d)),
        Shadow(color: oc, offset: Offset(-d, d)),
        Shadow(color: oc, offset: Offset(d, d)),
      ]);
    }

    // Drop shadow.
    if (style.hasShadow) {
      shadows.add(
        const Shadow(
          color: Colors.black87,
          offset: Offset(1.5, 1.5),
          blurRadius: 3,
        ),
      );
    }

    return shadows.isEmpty ? null : shadows;
  }

  @override
  Widget build(BuildContext context) {
    // Background with user-controlled opacity.
    final bgAlpha = (style.backgroundOpacity * 255).round().clamp(0, 255);
    final bgColor = style.background.color.withAlpha(bgAlpha);

    // Vertical alignment: 0 = top, 100 = bottom → 0.0 to 1.0.
    final alignment = Alignment(
      0,
      -1.0 + 2.0 * (style.verticalPosition / 100.0),
    );

    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      alignment: alignment,
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        curve: CrispyAnimation.enterCurve,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.sm,
          vertical: CrispySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Text(
          context.l10n.playerSubtitleSampleText,
          style: TextStyle(
            color: style.textColor.color,
            fontSize: style.fontSize.pixels.clamp(12, 28),
            fontWeight: style.isBold ? FontWeight.bold : FontWeight.w500,
            shadows: _shadows(),
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
