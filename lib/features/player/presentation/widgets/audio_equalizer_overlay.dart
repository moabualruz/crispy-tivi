// FE-PS-13: Audio boost / 5-band equalizer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../providers/player_providers.dart';

// ─────────────────────────────────────────────────────────────
//  EQ band constants
// ─────────────────────────────────────────────────────────────

/// Centre frequencies for the 5-band EQ, in Hz.
const _kBandFrequencies = [60, 230, 910, 3600, 14000];

/// Labels displayed under each band slider.
const _kBandLabels = ['60\nHz', '230\nHz', '910\nHz', '3.6\nkHz', '14\nkHz'];

// ─────────────────────────────────────────────────────────────
//  EQ presets
// ─────────────────────────────────────────────────────────────

/// Named EQ preset with 5 gain values in dB (−12 to +12).
@immutable
class EqPreset {
  const EqPreset({required this.name, required this.gains});

  final String name;

  /// Gains for [_kBandFrequencies] in order (−12 to +12 dB).
  final List<double> gains;

  static const flat = EqPreset(name: 'Flat', gains: [0, 0, 0, 0, 0]);

  static const bassBoost = EqPreset(name: 'Bass Boost', gains: [9, 6, 0, 0, 0]);

  static const trebleBoost = EqPreset(
    name: 'Treble Boost',
    gains: [0, 0, 0, 6, 9],
  );

  static const vocal = EqPreset(name: 'Vocal', gains: [-3, 0, 5, 4, -1]);

  static const cinema = EqPreset(name: 'Cinema', gains: [3, 2, -1, 2, -2]);

  static const allPresets = [flat, bassBoost, trebleBoost, vocal, cinema];
}

// ─────────────────────────────────────────────────────────────
//  EQ state + provider
// ─────────────────────────────────────────────────────────────

/// State for the 5-band EQ.
@immutable
class EqualizerState {
  const EqualizerState({
    this.gains = const [0, 0, 0, 0, 0],
    this.activePreset = 'Flat',
    this.isVisible = false,
    this.isEnabled = true,
  });

  /// Gain values in dB for each of the 5 bands.
  final List<double> gains;

  /// Name of the active preset (or 'Custom' when manually adjusted).
  final String activePreset;

  /// Whether the EQ panel is currently shown.
  final bool isVisible;

  /// Whether EQ processing is enabled.
  final bool isEnabled;

  EqualizerState copyWith({
    List<double>? gains,
    String? activePreset,
    bool? isVisible,
    bool? isEnabled,
  }) {
    return EqualizerState(
      gains: gains ?? this.gains,
      activePreset: activePreset ?? this.activePreset,
      isVisible: isVisible ?? this.isVisible,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// Manages 5-band EQ state.
class EqualizerNotifier extends Notifier<EqualizerState> {
  @override
  EqualizerState build() => const EqualizerState();

  /// Sets the gain for band [index] to [gainDb].
  ///
  /// Also calls [_applyToMpv] to notify the player.
  void setBandGain(int index, double gainDb) {
    assert(index >= 0 && index < 5, 'Band index must be 0-4');
    final newGains = List<double>.from(state.gains);
    newGains[index] = gainDb.clamp(-12.0, 12.0);
    state = state.copyWith(gains: newGains, activePreset: 'Custom');
    _applyToMpv();
  }

  /// Applies [preset] to all 5 bands.
  void applyPreset(EqPreset preset) {
    state = state.copyWith(gains: preset.gains, activePreset: preset.name);
    _applyToMpv();
  }

  /// Resets all bands to flat.
  void reset() => applyPreset(EqPreset.flat);

  /// Toggles EQ processing on/off.
  void toggleEnabled() {
    state = state.copyWith(isEnabled: !state.isEnabled);
    _applyToMpv();
  }

  /// Shows or hides the EQ panel.
  void toggleVisibility() =>
      state = state.copyWith(isVisible: !state.isVisible);

  void show() => state = state.copyWith(isVisible: true);
  void hide() => state = state.copyWith(isVisible: false);

  /// Applies the current EQ settings to mpv via the audio
  /// filter chain (`af=equalizer`).
  ///
  /// The equalizer filter string format is:
  ///   `equalizer=f0:width_type:w:g:f1:width_type:w:g:...`
  /// where f=centre freq, w=bandwidth, g=gain in dB.
  ///
  /// Example gains=[6,0,0,0,0]:
  ///   `af=equalizer=60:h:60:6.0:230:h:230:0.0:...`
  void _applyToMpv() {
    if (!state.isEnabled) {
      ref.read(playerServiceProvider).setAudioFilter('');
      return;
    }
    final parts = <String>[];
    for (var i = 0; i < 5; i++) {
      final freq = _kBandFrequencies[i];
      final gain = state.gains[i].toStringAsFixed(1);
      parts.add('$freq:h:$freq:$gain');
    }
    final filterStr = 'equalizer=${parts.join(':')}';
    ref.read(playerServiceProvider).setAudioFilter(filterStr);
    debugPrint('[EQ] mpv af=$filterStr');
  }
}

/// Global equalizer provider.
final equalizerProvider = NotifierProvider<EqualizerNotifier, EqualizerState>(
  EqualizerNotifier.new,
);

// ─────────────────────────────────────────────────────────────
//  EQ overlay widget (FE-PS-13)
// ─────────────────────────────────────────────────────────────

/// Full equalizer overlay panel.
///
/// Slides in from the right side when visible (similar to the
/// queue panel). Shows 5 vertical sliders and preset buttons.
///
/// Integration: add this to the player stack and toggle via
/// `ref.read(equalizerProvider.notifier).toggleVisibility()`.
class AudioEqualizerOverlay extends ConsumerWidget {
  const AudioEqualizerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSlide(
      offset: eq.isVisible ? Offset.zero : const Offset(1.0, 0.0),
      duration: CrispyAnimation.normal,
      curve:
          eq.isVisible ? CrispyAnimation.enterCurve : CrispyAnimation.exitCurve,
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 340,
          child: _EqualizerPanel(
            eq: eq,
            colorScheme: colorScheme,
            onClose: () => ref.read(equalizerProvider.notifier).hide(),
            onBandChanged:
                (i, v) =>
                    ref.read(equalizerProvider.notifier).setBandGain(i, v),
            onPreset:
                (p) => ref.read(equalizerProvider.notifier).applyPreset(p),
            onToggleEnabled:
                () => ref.read(equalizerProvider.notifier).toggleEnabled(),
            onReset: () => ref.read(equalizerProvider.notifier).reset(),
          ),
        ),
      ),
    );
  }
}

class _EqualizerPanel extends StatelessWidget {
  const _EqualizerPanel({
    required this.eq,
    required this.colorScheme,
    required this.onClose,
    required this.onBandChanged,
    required this.onPreset,
    required this.onToggleEnabled,
    required this.onReset,
  });

  final EqualizerState eq;
  final ColorScheme colorScheme;
  final VoidCallback onClose;
  final void Function(int bandIndex, double gainDb) onBandChanged;
  final ValueChanged<EqPreset> onPreset;
  final VoidCallback onToggleEnabled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(
        top: CrispySpacing.xxl,
        bottom: CrispySpacing.xxl,
        right: CrispySpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CrispySpacing.md,
              CrispySpacing.md,
              CrispySpacing.xs,
              CrispySpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.equalizer_rounded,
                  color: colorScheme.onSurface,
                  size: 18,
                ),
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Text(
                    'Equalizer',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Enable/disable toggle
                Switch(
                  value: eq.isEnabled,
                  onChanged: (_) => onToggleEnabled(),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurface,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(CrispySpacing.xs),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Preset chips ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    EqPreset.allPresets
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(
                              right: CrispySpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: Text(p.name),
                              selected: eq.activePreset == p.name,
                              onSelected: (_) => onPreset(p),
                              selectedColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    eq.activePreset == p.name
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                fontSize: 11,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.xs,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Band sliders ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(5, (i) {
                return Expanded(
                  child: _BandSlider(
                    label: _kBandLabels[i],
                    gainDb: eq.gains[i],
                    isEnabled: eq.isEnabled,
                    accentColor: colorScheme.primary,
                    onChanged: (v) => onBandChanged(i, v),
                  ),
                );
              }),
            ),
          ),

          // ── Active preset label + reset ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CrispySpacing.md,
              0,
              CrispySpacing.md,
              CrispySpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  eq.activePreset,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Band slider widget (FE-PS-13)
// ─────────────────────────────────────────────────────────────

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.label,
    required this.gainDb,
    required this.isEnabled,
    required this.accentColor,
    required this.onChanged,
  });

  final String label;
  final double gainDb;
  final bool isEnabled;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayGain = gainDb.toStringAsFixed(0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gain label (+6 dB)
        Text(
          '${gainDb >= 0 ? '+' : ''}$displayGain',
          style: textTheme.labelSmall?.copyWith(
            color: isEnabled ? accentColor : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),

        const SizedBox(height: CrispySpacing.xs),

        // Vertical slider (rotated)
        SizedBox(
          height: 140,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: isEnabled ? accentColor : Colors.white38,
                inactiveTrackColor: Colors.white12,
                thumbColor: isEnabled ? accentColor : Colors.white38,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: gainDb.clamp(-12.0, 12.0),
                min: -12.0,
                max: 12.0,
                onChanged: isEnabled ? onChanged : null,
              ),
            ),
          ),
        ),

        const SizedBox(height: CrispySpacing.xs),

        // Frequency label
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white54,
            fontSize: 9,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  OSD EQ button (FE-PS-13)
// ─────────────────────────────────────────────────────────────

/// OSD icon button that toggles the EQ panel.
///
/// Shows the EQ icon highlighted when EQ is enabled.
/// Add to the OSD overflow menu or settings panel.
class OsdEqButton extends ConsumerWidget {
  const OsdEqButton({this.order, super.key});

  final double? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(equalizerProvider.select((s) => s.isVisible));
    final isEnabled = ref.watch(equalizerProvider.select((s) => s.isEnabled));
    final colorScheme = Theme.of(context).colorScheme;

    Widget button = Tooltip(
      message: 'Equalizer',
      child: IconButton(
        onPressed: () {
          ref.read(equalizerProvider.notifier).toggleVisibility();
          ref.read(osdStateProvider.notifier).show();
        },
        icon: Icon(
          Icons.equalizer_rounded,
          color: isVisible || isEnabled ? colorScheme.primary : Colors.white,
          size: 22,
        ),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: Colors.white, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
    );

    if (order != null) {
      button = FocusTraversalOrder(
        order: NumericFocusOrder(order!),
        child: button,
      );
    }

    return button;
  }
}
