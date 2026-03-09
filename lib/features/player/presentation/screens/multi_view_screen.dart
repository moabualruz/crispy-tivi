import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/domain/entities/channel.dart';

/// Multi-view player — shows 1-9 live streams in a flexible grid.
///
/// Tap a cell to switch audio focus. Number keys 1-9 also switch
/// focus. Escape or the back button exits and disposes all players.
class MultiViewScreen extends StatefulWidget {
  const MultiViewScreen({super.key, required this.channels});

  /// Channels to display (max 9).
  final List<Channel> channels;

  @override
  State<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends State<MultiViewScreen> {
  final List<_StreamCell> _cells = [];
  int _audioFocusIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayers();
  }

  void _initPlayers() {
    final count = widget.channels.length.clamp(0, 9);
    for (var i = 0; i < count; i++) {
      final player = Player();
      _configurePlayer(player);
      final controller = VideoController(player);
      _cells.add(
        _StreamCell(
          player: player,
          controller: controller,
          channel: widget.channels[i],
        ),
      );
      player.setVolume(i == _audioFocusIndex ? 100.0 : 0.0);
      player.open(Media(widget.channels[i].streamUrl));
    }
  }

  /// Apply hardware decoding and buffering optimizations.
  void _configurePlayer(Player player) {
    if (kIsWeb) return;
    final np = player.platform;
    if (np is NativePlayer && Platform.isAndroid) {
      np.setProperty('hwdec', 'mediacodec-copy');
      np.setProperty('vo', 'gpu');
      np.setProperty('framedrop', 'vo');
      np.setProperty('cache', 'yes');
      np.setProperty('cache-secs', '10');
      np.setProperty('demuxer-max-bytes', '50M');
      np.setProperty('demuxer-max-back-bytes', '5M');
    }
  }

  void _setAudioFocus(int index) {
    if (index < 0 || index >= _cells.length) return;
    setState(() => _audioFocusIndex = index);
    for (var i = 0; i < _cells.length; i++) {
      _cells[i].player.setVolume(i == index ? 100.0 : 0.0);
    }
  }

  @override
  void dispose() {
    for (final cell in _cells) {
      cell.player.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cols = gridColumns(_cells.length);
    final rows = (_cells.length / cols).ceil();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
        // Number keys 1-9 switch audio focus.
        for (var i = 0; i < 9; i++)
          SingleActivator(_digitKey(i + 1)): () => _setAudioFocus(i),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Column(
                children: List.generate(rows, (row) {
                  return Expanded(
                    child: Row(
                      children: List.generate(cols, (col) {
                        final index = row * cols + col;
                        if (index >= _cells.length) {
                          return const Expanded(child: SizedBox());
                        }
                        return Expanded(
                          child: _CellView(
                            cell: _cells[index],
                            hasFocus: index == _audioFocusIndex,
                            onTap: () => _setAudioFocus(index),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
              // Back button.
              Positioned(
                top: MediaQuery.paddingOf(context).top + CrispySpacing.sm,
                left: CrispySpacing.sm,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Exit Multi-View',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LogicalKeyboardKey _digitKey(int digit) {
    const keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    return keys[digit - 1];
  }
}

/// Calculates grid column count for the given number of cells.
///
/// Exported for testing.
int gridColumns(int count) {
  if (count <= 1) return 1;
  if (count <= 4) return 2;
  return 3;
}

// ─────────────────────────────────────────────────────────────
//  Cell View
// ─────────────────────────────────────────────────────────────

class _CellView extends StatelessWidget {
  const _CellView({
    required this.cell,
    required this.hasFocus,
    required this.onTap,
  });

  final _StreamCell cell;
  final bool hasFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: hasFocus ? cs.primary : Colors.white10,
            width: hasFocus ? 2 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            Video(controller: cell.controller, controls: NoVideoControls),
            // Channel name label.
            Positioned(
              left: CrispySpacing.xs,
              bottom: CrispySpacing.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(CrispyRadius.xs),
                ),
                child: Text(
                  cell.channel.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
            // Audio focus indicator.
            if (hasFocus)
              Positioned(
                right: CrispySpacing.xs,
                top: CrispySpacing.xs,
                child: Icon(Icons.volume_up, color: cs.primary, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stream Cell Data
// ─────────────────────────────────────────────────────────────

class _StreamCell {
  const _StreamCell({
    required this.player,
    required this.controller,
    required this.channel,
  });

  final Player player;
  final VideoController controller;
  final Channel channel;
}
