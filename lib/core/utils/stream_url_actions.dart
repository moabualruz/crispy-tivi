import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/settings_notifier.dart';
import '../../features/player/data/external_player_service.dart';

/// Normalizes a stream URL for the current platform.
///
/// On web, this handles:
/// - Converting .ts to .m3u8 for HLS.js compatibility.
/// - Appending .m3u8 to extensionless Xtream live URLs.
String normalizeStreamUrl(String url, {bool isWeb = kIsWeb}) {
  if (!isWeb) return url;

  final uri = Uri.parse(url);
  final path = uri.path;

  if (path.endsWith('.ts')) {
    // Replace .ts with .m3u8, preserve query/fragment
    final newPath = '${path.substring(0, path.length - 3)}.m3u8';
    return uri.replace(path: newPath).toString();
  }

  if (path.contains('/live/') &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.last.isNotEmpty &&
      !uri.pathSegments.last.contains('.')) {
    final newPath = '$path.m3u8';
    return uri.replace(path: newPath).toString();
  }

  return url;
}

/// Copy a stream URL to clipboard and show a snackbar.
void copyStreamUrl(BuildContext context, String streamUrl) {
  Clipboard.setData(ClipboardData(text: streamUrl));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Stream URL copied')));
  }
}

/// Launch a stream in the configured external player.
///
/// Reads the user's external player preference from
/// settings and delegates to [ExternalPlayerService].
Future<void> openInExternalPlayer({
  required BuildContext context,
  required WidgetRef ref,
  required String streamUrl,
  String? title,
  Map<String, String>? headers,
}) async {
  final settings = ref.read(settingsNotifierProvider).value;
  final playerName = settings?.config.player.externalPlayer ?? 'systemDefault';
  final player = ExternalPlayer.values.firstWhere(
    (p) => p.name == playerName,
    orElse: () => ExternalPlayer.systemDefault,
  );
  final service = ref.read(externalPlayerServiceProvider);
  final ok = await service.launch(
    streamUrl: streamUrl,
    player: player,
    title: title,
    headers: headers,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open external player')),
    );
  }
}

/// Whether an external player is configured
/// (not 'none').
bool hasExternalPlayer(WidgetRef ref) {
  final settings = ref.read(settingsNotifierProvider).value;
  return settings?.config.player.useExternalPlayer ?? false;
}
