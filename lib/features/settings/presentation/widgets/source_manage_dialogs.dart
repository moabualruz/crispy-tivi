import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/presentation/providers/duplicate_detection_service.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import 'source_add_dialogs.dart' show syncSourceAndNotify;

/// Shows a dialog listing duplicate channel groups.
void showDuplicatesDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  final groups = ref.read(duplicateGroupsProvider);

  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Duplicate Channels'),
          content: SizedBox(
            width: 400,
            child:
                groups.isEmpty
                    ? const Text('No duplicate channels found.')
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: CrispySpacing.sm,
                          ),
                          child: ListTile(
                            title: Text(
                              '${group.count} channels '
                              'share same stream',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              group.streamUrl.length > 50
                                  ? '${group.streamUrl.substring(0, 50)}...'
                                  : group.streamUrl,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.sm,
                                vertical: CrispySpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                '${group.count}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}

/// Shows the dialog to open the "Add Xtream"
/// dialog.
///
/// Used by [SettingsScreen] when navigated with
/// `extra: {'action': 'addXtream'}`.
void showAddXtreamDialogFromScreen(BuildContext context, WidgetRef ref) {
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
                      '$epgBase/xmltv.php?'
                      'username=$user'
                      '&password=$pass',
                );
                ref.read(settingsNotifierProvider.notifier).addSource(source);
                if (context.mounted) {
                  Navigator.pop(ctx);
                }

                // Trigger channel sync.
                await syncSourceAndNotify(
                  ref: ref,
                  messenger: messenger,
                  source: source,
                  name: name,
                  isMounted: () => context.mounted,
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
