import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../player/presentation/providers/pip_provider.dart';
import '../../domain/entities/multiview_session.dart';
import 'multiview_preset_ui.dart';
import '../providers/multiview_providers.dart';

/// Horizontal row of [ChoiceChip]s for each [MultiViewPreset].
///
/// Selection drives [MultiViewNotifier.setPreset] which updates
/// both the named preset and the underlying grid layout.
class MultiviewPresetChipRow extends ConsumerWidget {
  const MultiviewPresetChipRow({required this.session, super.key});

  final MultiViewSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          MultiViewPreset.values.map((preset) {
            final isSelected = session.preset == preset;
            return Padding(
              padding: const EdgeInsets.only(right: CrispySpacing.xs),
              child: ChoiceChip(
                avatar: Icon(
                  preset.icon,
                  size: 16,
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                label: Text(preset.label),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(multiViewProvider.notifier).setPreset(preset);
                },
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: Colors.white10,
                labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface.withValues(alpha: 0.85),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  side: BorderSide(
                    color: isSelected ? colorScheme.primary : Colors.white24,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.xs,
                  vertical: CrispySpacing.xxs,
                ),
              ),
            );
          }).toList(),
    );
  }
}

/// PiP toggle button shown in the multiview controls overlay.
///
/// Only rendered on Android and iOS (guard at call site). Tapping
/// enters PiP for the currently focused slot via [PipNotifier].
/// Tapping again while PiP is active calls [PipNotifier.exitPip].
///
/// NOTE: The native MethodChannel handler is a stub — see
/// [PipNotifier] for items needed to complete native wiring.
/// TODO(BACKLOG): native PiP wiring — aspirational feature.
class MultiviewPipButton extends ConsumerWidget {
  const MultiviewPipButton({this.focusedSlotIndex, super.key});

  /// Index of the slot currently receiving focus / digit input.
  /// Passed to [PipNotifier.enterPip] so the native side can
  /// select the correct video surface.
  final int? focusedSlotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipState = ref.watch(pipProvider);
    final isActive = pipState.isActive;

    return Tooltip(
      message: isActive ? 'Exit Picture-in-Picture' : 'Picture-in-Picture',
      child: IconButton(
        onPressed: () {
          if (isActive) {
            ref.read(pipProvider.notifier).exitPip();
          } else {
            ref
                .read(pipProvider.notifier)
                .enterPip(slotIndex: focusedSlotIndex);
          }
        },
        icon: Icon(
          isActive ? Icons.picture_in_picture : Icons.picture_in_picture_alt,
          color: isActive ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}

/// Shows a "Press Esc / Back to return" hint that fades out after
/// [_kHintDuration].
class MultiviewEscapeHint extends StatefulWidget {
  const MultiviewEscapeHint({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  State<MultiviewEscapeHint> createState() => _MultiviewEscapeHintState();
}

class _MultiviewEscapeHintState extends State<MultiviewEscapeHint>
    with SingleTickerProviderStateMixin {
  static const _kHintDuration = Duration(seconds: 3);

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: CrispyAnimation.normal,
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: CrispyAnimation.exitCurve,
    );
    // Auto-fade after hint duration.
    Future.delayed(_kHintDuration, () {
      if (mounted) _fadeController.reverse();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: CrispyColors.scrimMid,
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fullscreen_exit, size: 16, color: Colors.white70),
            const SizedBox(width: CrispySpacing.xs),
            Text(
              'Press Esc or tap \u2715 to return to grid',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
