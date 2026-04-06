import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../domain/entities/active_stream.dart';

/// A lightweight video player for Multi-View slots.
///
/// Creates an independent [Player] per multiview slot. This
/// intentionally bypasses the [CrispyPlayer] singleton because
/// multiview IS multi-play by design — each slot decodes its own
/// stream. Only the `isAudioActive == true` slot has audible
/// output; others play at volume 0.
///
/// Hardware decoder limits: most devices support 2–4 simultaneous
/// hardware decoders. Exceeding this falls back to software
/// decoding which increases CPU usage significantly.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({
    super.key,
    required this.stream,
    required this.isAudioActive,
  });

  final ActiveStream stream;
  final bool isAudioActive;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  late final Player _player;
  late final VideoController _controller;

  /// Duration for audio fade in/out transition.
  static const _audioFadeDuration = CrispyAnimation.normal;

  /// Whether a fade animation is currently in progress.
  bool _isFading = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.open(Media(widget.stream.url), play: true);
    await _player.setVolume(widget.isAudioActive ? 100.0 : 0.0);
  }

  /// Smoothly fades volume to target level.
  Future<void> _fadeVolume(bool active) async {
    if (_isFading) return; // Prevent overlapping fades
    _isFading = true;

    final startVol = active ? 0.0 : 100.0;
    final endVol = active ? 100.0 : 0.0;

    const steps = 10;
    final stepDuration = _audioFadeDuration ~/ steps;
    final volumeStep = (endVol - startVol) / steps;

    for (var i = 0; i <= steps; i++) {
      if (!mounted) break;
      await _player.setVolume(startVol + (volumeStep * i));
      if (i < steps) {
        await Future<void>.delayed(stepDuration);
      }
    }

    _isFading = false;
  }

  @override
  void didUpdateWidget(MiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAudioActive != oldWidget.isAudioActive) {
      _fadeVolume(widget.isAudioActive);
    }
    if (widget.stream.url != oldWidget.stream.url) {
      _player.open(Media(widget.stream.url));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _controller,
      fit: BoxFit.contain,
      controls: NoVideoControls as VideoControlsBuilder?,  // NoVideoControls == null
    );
  }
}
