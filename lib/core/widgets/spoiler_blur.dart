import 'dart:ui';

import 'package:flutter/material.dart';

/// Overlays a Gaussian blur over [child] to hide spoiler content until the
/// user deliberately taps to reveal it.
///
/// The blur is only applied when **all** of the following are true:
/// - [enabled] is `true`
/// - [isWatched] is `false` (already-watched content needs no spoiler guard)
/// - The user has not yet tapped to reveal
///
/// Once revealed the blur is permanently removed for the lifetime of the
/// widget. Wrap in a keyed parent to reset the reveal state when the item
/// changes.
///
/// ```dart
/// SpoilerBlur(
///   isWatched: entry.isWatched,
///   child: EpisodeThumbnail(entry: entry),
/// )
/// ```
class SpoilerBlur extends StatefulWidget {
  /// Creates a [SpoilerBlur].
  const SpoilerBlur({
    super.key,
    required this.isWatched,
    required this.child,
    this.enabled = true,
  });

  /// When `true` the item has already been seen — no blur is applied.
  final bool isWatched;

  /// Master switch for the blur effect. Set to `false` to disable globally
  /// (e.g. when the user turns off spoiler protection in settings).
  final bool enabled;

  /// The content to potentially blur.
  final Widget child;

  @override
  State<SpoilerBlur> createState() => _SpoilerBlurState();
}

class _SpoilerBlurState extends State<SpoilerBlur> {
  /// Whether the user has manually revealed the blurred content.
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    // Skip the blur overlay entirely when not needed.
    if (!widget.enabled || widget.isWatched || _isRevealed) {
      return widget.child;
    }

    return GestureDetector(
      onTap: () => setState(() => _isRevealed = true),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred content layer.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: widget.child,
          ),
          // Reveal hint overlay.
          Positioned.fill(
            child: Semantics(
              label: 'Spoiler hidden. Tap to reveal.',
              button: true,
              child: Container(
                color: Colors.black26,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.visibility_off,
                  color: Colors.white54,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
