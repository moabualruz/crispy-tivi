import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';

/// Shows a dialog to add an M3U playlist source.
void showAddM3uDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  final nameCtrl = TextEditingController();
  final urlCtrl = TextEditingController();

  showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Add M3U Playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My Playlist',
                  prefixIcon: Icon(Icons.label),
                ),
                autofocus: true,
              ),
              const SizedBox(height: CrispySpacing.sm),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Playlist URL',
                  hintText: 'https://example.com/playlist.m3u',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final url = urlCtrl.text.trim();
                if (url.isEmpty) return;
                final name =
                    nameCtrl.text.trim().isEmpty
                        ? 'M3U Playlist'
                        : nameCtrl.text.trim();

                final messenger = ScaffoldMessenger.of(context);

                final source = PlaylistSource(
                  id: 'src_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  url: url,
                  type: PlaylistSourceType.m3u,
                );
                ref.read(settingsNotifierProvider.notifier).addSource(source);
                if (context.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Source added \u2014 syncing\u2026'),
                  ),
                );
                // Trigger channel sync.
                final count = await ref
                    .read(playlistSyncServiceProvider)
                    .syncSource(source);

                if (!isMounted()) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Loaded $count channels '
                      'from "$name"',
                    ),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
  ).then((_) {
    nameCtrl.dispose();
    urlCtrl.dispose();
  });
}

/// Shows a dialog to add an Xtream Codes source.
void showAddXtreamDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  final nameCtrl = TextEditingController();
  final urlCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Add Xtream Codes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'My IPTV Provider',
                    prefixIcon: Icon(Icons.label),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: CrispySpacing.sm),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://provider.com:8080',
                    prefixIcon: Icon(Icons.dns),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: CrispySpacing.sm),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final url = urlCtrl.text.trim();
                final user = userCtrl.text.trim();
                final pass = passCtrl.text.trim();
                if (url.isEmpty || user.isEmpty || pass.isEmpty) {
                  return;
                }
                final name =
                    nameCtrl.text.trim().isEmpty
                        ? 'Xtream Provider'
                        : nameCtrl.text.trim();

                final messenger = ScaffoldMessenger.of(context);

                // Normalize URL for EPG derivation.
                final normalizedUrl = Uri.tryParse(url);
                final epgBase =
                    normalizedUrl != null
                        ? '${normalizedUrl.scheme}://'
                            '${normalizedUrl.host}'
                            '${normalizedUrl.hasPort ? ":${normalizedUrl.port}" : ""}'
                        : url;
                final source = PlaylistSource(
                  id: 'src_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  url: url,
                  type: PlaylistSourceType.xtream,
                  username: user,
                  password: pass,
                  epgUrl:
                      '$epgBase/xmltv.php?username=$user'
                      '&password=$pass',
                );
                ref.read(settingsNotifierProvider.notifier).addSource(source);
                if (context.mounted) Navigator.pop(ctx);

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Source added \u2014 syncing\u2026'),
                  ),
                );

                // Trigger channel sync.
                final count = await ref
                    .read(playlistSyncServiceProvider)
                    .syncSource(source);

                if (!isMounted()) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Loaded $count channels '
                      'from "$name"',
                    ),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
  ).then((_) {
    nameCtrl.dispose();
    urlCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
  });
}
