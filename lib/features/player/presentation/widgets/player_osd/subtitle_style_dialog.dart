import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/settings_notifier.dart';
import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/widgets/focus_wrapper.dart';
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
  }

  Future<void> _reset() async {
    setState(() => _draft = SubtitleStyle.defaults);
    await ref.read(settingsNotifierProvider.notifier).resetSubtitleStyle();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: osdPanelColor,
      borderRadius: BorderRadius.circular(CrispyRadius.tv),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, minWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────
            _SheetHeader(
              title: 'CC Style',
              onClose: widget.onClose,
              textTheme: textTheme,
            ),

            const Divider(color: Colors.white12, height: 1),

            // ── Body ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(CrispySpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Font size
                  _SectionLabel(label: 'FONT SIZE', textTheme: textTheme),
                  const SizedBox(height: CrispySpacing.sm),
                  _FontSizeRow(
                    selected: _draft.fontSize,
                    onChanged: (v) => _apply(_draft.copyWith(fontSize: v)),
                  ),

                  const SizedBox(height: CrispySpacing.md),

                  // Text colour
                  _SectionLabel(label: 'TEXT COLOR', textTheme: textTheme),
                  const SizedBox(height: CrispySpacing.sm),
                  _ColorCircleRow(
                    selected: _draft.textColor,
                    onChanged: (v) => _apply(_draft.copyWith(textColor: v)),
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: CrispySpacing.md),

                  // Background
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

                  // Edge style
                  _SectionLabel(label: 'EDGE STYLE', textTheme: textTheme),
                  const SizedBox(height: CrispySpacing.sm),
                  _ChipRow<SubtitleEdgeStyle>(
                    values: SubtitleEdgeStyle.values,
                    selected: _draft.edgeStyle,
                    labelOf: (v) => v.label,
                    onChanged: (v) => _apply(_draft.copyWith(edgeStyle: v)),
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
                          'Reset to defaults',
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
          message: 'Close',
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
      color: osdGrayText,
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
                      color: isSelected ? colorScheme.onPrimary : osdGrayText,
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
                      color: isSelected ? colorScheme.onPrimary : osdGrayText,
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

// ── Live preview ──────────────────────────────────────────────

/// A small preview pane that renders subtitle text using the
/// current [SubtitleStyle] settings so the user sees a live
/// result before leaving the dialog.
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.style});

  final SubtitleStyle style;

  List<Shadow>? _shadows() => switch (style.edgeStyle) {
    SubtitleEdgeStyle.none => null,
    SubtitleEdgeStyle.dropShadow => const [
      Shadow(color: Colors.black87, offset: Offset(1, 1), blurRadius: 3),
    ],
    SubtitleEdgeStyle.raised => const [
      Shadow(color: Colors.black87, offset: Offset(1, 1), blurRadius: 0),
      Shadow(color: Colors.white30, offset: Offset(-1, -1), blurRadius: 0),
    ],
    SubtitleEdgeStyle.depressed => const [
      Shadow(color: Colors.white30, offset: Offset(1, 1), blurRadius: 0),
      Shadow(color: Colors.black87, offset: Offset(-1, -1), blurRadius: 0),
    ],
    SubtitleEdgeStyle.outline => const [
      Shadow(color: Colors.black, offset: Offset(-1, -1), blurRadius: 0),
      Shadow(color: Colors.black, offset: Offset(1, -1), blurRadius: 0),
      Shadow(color: Colors.black, offset: Offset(-1, 1), blurRadius: 0),
      Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        curve: CrispyAnimation.enterCurve,
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.sm,
          vertical: CrispySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: style.background.color,
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Text(
          'Sample subtitle text',
          style: TextStyle(
            color: style.textColor.color,
            fontSize: style.fontSize.pixels,
            fontWeight: FontWeight.w500,
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
