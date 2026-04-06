import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_providers.dart';

/// Overlay showing real-time playback diagnostics.
///
/// Shows: codec, hwdec status, fps, dropped frames,
/// decoder type (hw/sw), and resolution. Reads mpv
/// properties via [CrispyPlayer.getProperty] — the
/// domain interface — not raw native player handles.
///
/// Refresh every 2 seconds. Not shown in production
/// builds; integrate via OSD or debug settings when needed.
class PlaybackDiagnostics extends ConsumerStatefulWidget {
  const PlaybackDiagnostics({super.key});

  @override
  ConsumerState<PlaybackDiagnostics> createState() =>
      _PlaybackDiagnosticsState();
}

class _PlaybackDiagnosticsState extends ConsumerState<PlaybackDiagnostics> {
  Timer? _timer;
  Map<String, String> _stats = {};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final player = ref.read(playerProvider);

    String prop(String key) => player.getProperty(key) ?? '?';

    final hwdec = prop('hwdec-current');
    final codec = prop('video-codec');
    final width = prop('video-params/w');
    final height = prop('video-params/h');
    final fps = prop('estimated-vf-fps');
    final droppedVo = prop('frame-drop-count');
    final droppedDec = prop('decoder-frame-drop-count');

    final fpsFormatted =
        double.tryParse(fps)?.toStringAsFixed(1) ?? fps;
    final hwdecLabel =
        (hwdec == 'no' || hwdec == '?') ? 'SOFTWARE' : hwdec;

    setState(() {
      _stats = {
        'HW Decoder': hwdecLabel,
        'Codec': codec,
        'Resolution': '${width}x$height',
        'FPS': fpsFormatted,
        'Dropped (VO)': droppedVo,
        'Dropped (Dec)': droppedDec,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Playback Diagnostics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          ..._stats.entries.map(
            (e) => Text(
              '${e.key}: ${e.value}',
              style: TextStyle(
                color: e.value == 'SOFTWARE'
                    ? Colors.red
                    : Colors.greenAccent,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
