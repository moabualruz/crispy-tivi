import 'dart:async';

import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/crispy_spacing.dart';
import '../../../domain/crispy_player.dart';
import '../../providers/player_providers.dart';

/// Dialog for adjusting audio and subtitle sync offsets.
///
/// Each offset control has a slider (±5 s, 50 ms steps),
/// tap buttons (±100 ms), long-press acceleration (1 s per
/// 200 ms tick), and an absolute clamp of ±60 s.
///
/// Sets mpv `audio-delay` and `sub-delay` properties via
/// [CrispyPlayer.setProperty].
///
/// Hidden on web (no mpv property access).
class SyncOffsetDialog extends ConsumerStatefulWidget {
  const SyncOffsetDialog({super.key});

  @override
  ConsumerState<SyncOffsetDialog> createState() => _SyncOffsetDialogState();
}

class _SyncOffsetDialogState extends ConsumerState<SyncOffsetDialog> {
  double _audioOffsetMs = 0;
  double _subOffsetMs = 0;

  CrispyPlayer get _player => ref.read(playerProvider);

  @override
  void initState() {
    super.initState();
    // Read current offsets from the player.
    final audioStr = _player.getProperty('audio-delay');
    final subStr = _player.getProperty('sub-delay');
    if (audioStr != null) {
      _audioOffsetMs = (double.tryParse(audioStr) ?? 0) * 1000;
    }
    if (subStr != null) {
      _subOffsetMs = (double.tryParse(subStr) ?? 0) * 1000;
    }
  }

  void _applyAudioOffset(double ms) {
    setState(() => _audioOffsetMs = ms);
    _player.setProperty('audio-delay', (ms / 1000).toString());
  }

  void _applySubOffset(double ms) {
    setState(() => _subOffsetMs = ms);
    _player.setProperty('sub-delay', (ms / 1000).toString());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: context.l10n.playerSyncOffset,
      child: Dialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CrispySpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.playerSyncOffset,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: CrispySpacing.lg),
              _SyncOffsetRow(
                label: context.l10n.playerSyncOffsetAudio,
                offsetMs: _audioOffsetMs,
                onChanged: _applyAudioOffset,
              ),
              const SizedBox(height: CrispySpacing.md),
              _SyncOffsetRow(
                label: context.l10n.playerSyncOffsetSubtitle,
                offsetMs: _subOffsetMs,
                onChanged: _applySubOffset,
              ),
              const SizedBox(height: CrispySpacing.lg),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.commonClose),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single row for one sync offset: label, -, slider, +,
/// value display, reset.
class _SyncOffsetRow extends StatefulWidget {
  const _SyncOffsetRow({
    required this.label,
    required this.offsetMs,
    required this.onChanged,
  });

  final String label;
  final double offsetMs;
  final ValueChanged<double> onChanged;

  @override
  State<_SyncOffsetRow> createState() => _SyncOffsetRowState();
}

class _SyncOffsetRowState extends State<_SyncOffsetRow> {
  // Slider range: ±5 s in ms.
  static const double _sliderMin = -5000;
  static const double _sliderMax = 5000;
  // Absolute clamp: ±60 s in ms.
  static const double _absoluteMin = -60000;
  static const double _absoluteMax = 60000;
  // Tap step: 100 ms.
  static const double _tapStep = 100;
  // Long-press step: 1 s.
  static const double _longPressStep = 1000;
  // Slider divisions: 200 (50 ms steps across 10 s range).
  static const int _sliderDivisions = 200;

  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _increment() {
    final v = (widget.offsetMs + _tapStep).clamp(_absoluteMin, _absoluteMax);
    widget.onChanged(v);
  }

  void _decrement() {
    final v = (widget.offsetMs - _tapStep).clamp(_absoluteMin, _absoluteMax);
    widget.onChanged(v);
  }

  void _reset() => widget.onChanged(0);

  void _startLongPressIncrement() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final v = (widget.offsetMs + _longPressStep).clamp(
        _absoluteMin,
        _absoluteMax,
      );
      widget.onChanged(v);
    });
  }

  void _startLongPressDecrement() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final v = (widget.offsetMs - _longPressStep).clamp(
        _absoluteMin,
        _absoluteMax,
      );
      widget.onChanged(v);
    });
  }

  void _stopLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sliderValue = widget.offsetMs.clamp(_sliderMin, _sliderMax);
    final isZero = widget.offsetMs.abs() < 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                widget.label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: CrispySpacing.xs),
            SizedBox(
              width: 72,
              child: Text(
                _formatOffset(widget.offsetMs),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isZero
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (!isZero) ...[
              const SizedBox(width: CrispySpacing.xs),
              IconButton(
                icon: Icon(
                  Icons.restart_alt_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                tooltip: context.l10n.playerSyncOffsetResetToZero,
                onPressed: _reset,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove_rounded,
              onTap: _decrement,
              onLongPressStart: _startLongPressDecrement,
              onLongPressEnd: _stopLongPress,
            ),
            Expanded(
              child: Slider(
                value: sliderValue,
                min: _sliderMin,
                max: _sliderMax,
                divisions: _sliderDivisions,
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.outlineVariant,
                onChanged: (value) => widget.onChanged(value),
                onChangeEnd: (value) => widget.onChanged(value),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              onTap: _increment,
              onLongPressStart: _startLongPressIncrement,
              onLongPressEnd: _stopLongPress,
            ),
          ],
        ),
      ],
    );
  }

  /// Formats offset in ms to a display string like
  /// "+0.50 s" or "-1.20 s".
  static String _formatOffset(double ms) {
    final sign = ms >= 0 ? '+' : '';
    final seconds = ms / 1000;
    return '$sign${seconds.toStringAsFixed(2)} s';
  }
}

/// Tap + long-press step button for sync offset controls.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressEnd: (_) => onLongPressEnd(),
      onLongPressCancel: onLongPressEnd,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colorScheme.onSurface, size: 22),
      ),
    );
  }
}
