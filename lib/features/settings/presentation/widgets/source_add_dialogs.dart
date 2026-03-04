import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import 'source_form_fields.dart';

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
          content: M3uFormFields(nameCtrl: nameCtrl, urlCtrl: urlCtrl),
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
                  id: PlaylistSource.generateId(),
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
                try {
                  final result = await ref
                      .read(playlistSyncServiceProvider)
                      .syncSource(source);
                  if (!isMounted()) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Loaded ${result.totalChannels} channels '
                        'from "$name"',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!isMounted()) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Sync failed for "$name": $e')),
                  );
                }
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
            child: XtreamFormFields(
              nameCtrl: nameCtrl,
              urlCtrl: urlCtrl,
              userCtrl: userCtrl,
              passCtrl: passCtrl,
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

                final source = PlaylistSource(
                  id: PlaylistSource.generateId(),
                  name: name,
                  url: url,
                  type: PlaylistSourceType.xtream,
                  username: user,
                  password: pass,
                  epgUrl: PlaylistSource.buildXtreamEpgUrl(url, user, pass),
                );
                ref.read(settingsNotifierProvider.notifier).addSource(source);
                if (context.mounted) Navigator.pop(ctx);

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Source added \u2014 syncing\u2026'),
                  ),
                );

                // Trigger channel sync.
                try {
                  final result = await ref
                      .read(playlistSyncServiceProvider)
                      .syncSource(source);
                  if (!isMounted()) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Loaded ${result.totalChannels} channels '
                        'from "$name"',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!isMounted()) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Sync failed for "$name": $e')),
                  );
                }
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
