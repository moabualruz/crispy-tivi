import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../providers/voice_search_service_providers.dart';
import '../../domain/entities/voice_search_state.dart';

/// Voice search button with animated recording indicator.
///
/// Shows a microphone icon that pulses when listening, with a visual
/// sound level indicator. Handles the full voice search flow.
class VoiceSearchButton extends ConsumerStatefulWidget {
  /// Callback when speech is recognized.
  final void Function(String text) onResult;

  /// Optional callback for partial results during listening.
  final void Function(String text)? onPartialResult;

  /// Size of the button icon.
  final double iconSize;

  const VoiceSearchButton({
    required this.onResult,
    this.onPartialResult,
    this.iconSize = 24.0,
    super.key,
  });

  @override
  ConsumerState<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends ConsumerState<VoiceSearchButton> {
  @override
  void initState() {
    super.initState();
    // Initialize speech service on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceSearchServiceProvider.notifier).initialize();
    });
  }

  Future<void> _toggleListening() async {
    final service = ref.read(voiceSearchServiceProvider.notifier);
    final state = ref.read(voiceSearchServiceProvider);

    if (state.isListening) {
      await service.stopListening();
    } else {
      await service.startListening(
        onResult: (text, isFinal) {
          if (isFinal && text.isNotEmpty) {
            widget.onResult(text);
          } else if (!isFinal) {
            widget.onPartialResult?.call(text);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceSearchServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Don't show button if speech not supported.
    if (!ref.read(voiceSearchServiceProvider.notifier).isSupported) {
      return const SizedBox.shrink();
    }

    return _VoiceButton(
      state: state,
      iconSize: widget.iconSize,
      colorScheme: colorScheme,
      onPressed:
          state.status == VoiceSearchStatus.initializing
              ? null
              : _toggleListening,
    );
  }
}

class _VoiceButton extends StatelessWidget {
  final VoiceSearchState state;
  final double iconSize;
  final ColorScheme colorScheme;
  final VoidCallback? onPressed;

  const _VoiceButton({
    required this.state,
    required this.iconSize,
    required this.colorScheme,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isListening = state.isListening;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Sound level indicator ring.
        if (isListening)
          AnimatedContainer(
            duration: CrispyAnimation.fast,
            width: iconSize * 2 + (state.soundLevel * 16),
            height: iconSize * 2 + (state.soundLevel * 16),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 2 + (state.soundLevel * 2),
              ),
            ),
          ),

        // Main button.
        IconButton(
              onPressed: onPressed,
              icon: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                size: iconSize,
                color: isListening ? colorScheme.primary : null,
              ),
              tooltip: isListening ? 'Stop listening' : 'Voice search',
            )
            .animate(target: isListening ? 1.0 : 0.0)
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.1, 1.1),
              duration: CrispyAnimation.normal,
              curve: CrispyAnimation.enterCurve,
            ),
      ],
    );
  }
}

/// Full-screen voice search overlay with visual feedback.
///
/// Shows a modal dialog with animated listening indicator,
/// recognized text preview, and cancel/submit controls.
class VoiceSearchOverlay extends ConsumerWidget {
  /// Callback when speech is finalized.
  final void Function(String text) onResult;

  /// Callback when overlay is dismissed.
  final VoidCallback onDismiss;

  const VoiceSearchOverlay({
    required this.onResult,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceSearchServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap through.
            child: Container(
              margin: const EdgeInsets.all(CrispySpacing.xl),
              padding: const EdgeInsets.all(CrispySpacing.xl),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated microphone indicator.
                  _ListeningIndicator(
                    isListening: state.isListening,
                    soundLevel: state.soundLevel,
                    colorScheme: colorScheme,
                  ),

                  const SizedBox(height: CrispySpacing.lg),

                  // Status text.
                  Text(
                    _getStatusText(state),
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: CrispySpacing.md),

                  // Recognized text preview.
                  if (state.hasText)
                    Container(
                      padding: const EdgeInsets.all(CrispySpacing.md),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        '"${state.recognizedText}"',
                        style: textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: CrispySpacing.lg),

                  // Action buttons.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          ref
                              .read(voiceSearchServiceProvider.notifier)
                              .cancelListening();
                          onDismiss();
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: CrispySpacing.md),
                      if (state.hasText && state.isFinal)
                        FilledButton(
                          onPressed: () {
                            onResult(state.recognizedText);
                            onDismiss();
                          },
                          child: const Text('Search'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText(VoiceSearchState state) {
    switch (state.status) {
      case VoiceSearchStatus.idle:
        return 'Tap to speak';
      case VoiceSearchStatus.initializing:
        return 'Initializing...';
      case VoiceSearchStatus.listening:
        return 'Listening...';
      case VoiceSearchStatus.processing:
        return 'Processing...';
      case VoiceSearchStatus.unavailable:
        return 'Voice search unavailable';
      case VoiceSearchStatus.error:
        return state.errorMessage ?? 'An error occurred';
    }
  }
}

class _ListeningIndicator extends StatelessWidget {
  final bool isListening;
  final double soundLevel;
  final ColorScheme colorScheme;

  const _ListeningIndicator({
    required this.isListening,
    required this.soundLevel,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring.
          if (isListening)
            AnimatedContainer(
              duration: CrispyAnimation.fast,
              width: 80 + (soundLevel * 40),
              height: 80 + (soundLevel * 40),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),

          // Inner circle.
          Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  color:
                      isListening
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  size: 32,
                  color:
                      isListening
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                ),
              )
              .animate(target: isListening ? 1.0 : 0.0)
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.05, 1.05),
                duration: CrispyAnimation.normal,
              ),
        ],
      ),
    );
  }
}
