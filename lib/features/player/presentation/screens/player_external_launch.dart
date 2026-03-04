import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../data/external_player_service.dart';

/// Launch the current stream in an external player app.
///
/// Returns silently on success. Shows a [SnackBar] on
/// failure if [context] is still mounted.
Future<void> launchExternalPlayer({
  required WidgetRef ref,
  required BuildContext context,
  required String streamUrl,
  required bool mounted,
  String? title,
  Map<String, String>? headers,
}) async {
  final settings = ref.read(settingsNotifierProvider).value;
  final pName = settings?.config.player.externalPlayer ?? 'systemDefault';
  final ep = ExternalPlayer.values.firstWhere(
    (p) => p.name == pName,
    orElse: () => ExternalPlayer.systemDefault,
  );
  final svc = ref.read(externalPlayerServiceProvider);
  final ok = await svc.launch(
    streamUrl: streamUrl,
    player: ep,
    title: title,
    headers: headers,
  );
  if (!ok && mounted) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open external player')),
    );
  }
}
