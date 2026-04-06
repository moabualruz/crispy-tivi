import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';

import '../../../../../config/subtitle_style.dart';
import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/widgets/focus_wrapper.dart';

// ─────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────

/// Header row with title and close button.
class SubtitleStyleSheetHeader extends StatelessWidget {
  const SubtitleStyleSheetHeader({
    required this.title,
    required this.onClose,
    required this.textTheme,
    super.key,
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

// ─────────────────────────────────────────────────────────────
//  Section label
// ─────────────────────────────────────────────────────────────

/// A small uppercase section label.
class SubtitleSectionLabel extends StatelessWidget {
  const SubtitleSectionLabel({
    required this.label,
    required this.textTheme,
    super.key,
  });

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

// ─────────────────────────────────────────────────────────────
//  Font size row
// ─────────────────────────────────────────────────────────────

class SubtitleFontSizeRow extends StatelessWidget {
  const SubtitleFontSizeRow({
    required this.selected,
    required this.onChanged,
    super.key,
  });

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

// ─────────────────────────────────────────────────────────────
//  Text colour circle row
// ─────────────────────────────────────────────────────────────

class SubtitleColorCircleRow extends StatelessWidget {
  const SubtitleColorCircleRow({
    required this.selected,
    required this.onChanged,
    required this.colorScheme,
    super.key,
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

// ─────────────────────────────────────────────────────────────
//  Outline colour circle row
// ─────────────────────────────────────────────────────────────

class SubtitleOutlineColorRow extends StatelessWidget {
  const SubtitleOutlineColorRow({
    required this.selected,
    required this.onChanged,
    required this.colorScheme,
    super.key,
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

// ─────────────────────────────────────────────────────────────
//  Generic chip row
// ─────────────────────────────────────────────────────────────

class SubtitleChipRow<T> extends StatelessWidget {
  const SubtitleChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    required this.colorScheme,
    super.key,
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

// ─────────────────────────────────────────────────────────────
//  OSD-style slider
// ─────────────────────────────────────────────────────────────

class SubtitleOsdSlider extends StatelessWidget {
  const SubtitleOsdSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.colorScheme,
    this.divisions,
    super.key,
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

// ─────────────────────────────────────────────────────────────
//  Live preview box
// ─────────────────────────────────────────────────────────────

/// A small preview pane that renders subtitle text using the
/// current [SubtitleStyle] settings so the user sees a live
/// result before leaving the dialog.
class SubtitlePreviewBox extends StatelessWidget {
  const SubtitlePreviewBox({required this.style, super.key});

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
