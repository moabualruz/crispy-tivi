import 'package:flutter/material.dart';

/// Stub implementation of WebHlsVideo for non-web
/// platforms. This widget should never be instantiated
/// on native because the caller guards with `kIsWeb`.
class WebHlsVideo extends StatelessWidget {
  const WebHlsVideo({
    required this.streamUrl,
    this.onError,
    this.onStatsUpdate,
    this.onVideoIdReady,
    this.startPosition,
    super.key,
  });

  final String streamUrl;
  final void Function(String message)? onError;
  final void Function(Map<String, String> stats)? onStatsUpdate;
  final void Function(String videoId)? onVideoIdReady;
  final Duration? startPosition;

  @override
  Widget build(BuildContext context) {
    // This should never be reached on non-web platforms.
    return const Center(
      child: Text(
        'Web player not available on this platform.',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
