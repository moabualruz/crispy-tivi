import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';

/// Shows a dialog to add a Stalker Portal source.
void showAddStalkerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  final nameCtrl = TextEditingController();
  final urlCtrl = TextEditingController();
  final macCtrl = TextEditingController();

  showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Add Stalker Portal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'My Portal',
                    prefixIcon: Icon(Icons.label),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: CrispySpacing.sm),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Portal URL',
                    hintText: 'http://portal.example.com',
                    prefixIcon: Icon(Icons.dns),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: CrispySpacing.sm),
                TextField(
                  controller: macCtrl,
                  decoration: const InputDecoration(
                    labelText: 'MAC Address',
                    hintText: '00:1A:2B:3C:4D:5E',
                    prefixIcon: Icon(Icons.router),
                    helperText: 'Format: XX:XX:XX:XX:XX:XX',
                  ),
                  textCapitalization: TextCapitalization.characters,
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
                final mac = macCtrl.text.trim().toUpperCase();
                if (url.isEmpty || mac.isEmpty) return;

                // Validate MAC format.
                final macPattern = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$');
                if (!macPattern.hasMatch(mac)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Invalid MAC address format. '
                        'Use XX:XX:XX:XX:XX:XX',
                      ),
                    ),
                  );
                  return;
                }

                final name =
                    nameCtrl.text.trim().isEmpty
                        ? 'Stalker Portal'
                        : nameCtrl.text.trim();

                final messenger = ScaffoldMessenger.of(context);

                final source = PlaylistSource(
                  id: 'src_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  url: url,
                  type: PlaylistSourceType.stalkerPortal,
                  macAddress: mac,
                );
                ref.read(settingsNotifierProvider.notifier).addSource(source);
                if (context.mounted) {
                  Navigator.pop(ctx);
                }

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
    macCtrl.dispose();
  });
}

/// Shows a dialog to set the global EPG URL.
void showEpgUrlDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool Function() isMounted,
}) {
  final controller = TextEditingController();

  // Pre-fill with existing value.
  ref.read(cacheServiceProvider).getSetting(kGlobalEpgUrlKey).then((existing) {
    if (existing != null && existing.isNotEmpty) {
      controller.text = existing;
    }
  });

  showDialog<void>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('EPG URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'XMLTV URL',
              hintText: 'https://example.com/epg.xml',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final url = controller.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(cacheServiceProvider)
                    .setSetting(kGlobalEpgUrlKey, url);
                if (context.mounted) {
                  Navigator.pop(ctx);
                }
                if (isMounted()) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('EPG URL saved')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
  ).then((_) => controller.dispose());
}
