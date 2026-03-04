import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Tile showing a saved playlist source with delete
/// action.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, required this.onDelete});

  final PlaylistSource source;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        source.type == PlaylistSourceType.xtream
            ? Icons.api
            : source.type == PlaylistSourceType.stalkerPortal
            ? Icons.router
            : Icons.playlist_play,
      ),
      title: Text(source.name),
      subtitle: Text(
        source.type == PlaylistSourceType.xtream
            ? '${source.url} \u2022 ${source.username}'
            : source.type == PlaylistSourceType.stalkerPortal
            ? '${source.url} \u2022 ${source.macAddress}'
            : source.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Remove Source'),
                  content: Text('Remove "${source.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        onDelete();
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
          );
        },
      ),
    );
  }
}

/// User agent settings section per source.
class UserAgentSettingsSection extends ConsumerWidget {
  const UserAgentSettingsSection({super.key, required this.sources});

  final List<PlaylistSource> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'User Agent',
          icon: Icons.web,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            for (var i = 0; i < sources.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(sources[i].name),
                subtitle: Text(
                  sources[i].userAgent ?? 'Default',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showUserAgentDialog(context, ref, sources[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showUserAgentDialog(
    BuildContext context,
    WidgetRef ref,
    PlaylistSource source,
  ) {
    final ctrl = TextEditingController(text: source.userAgent ?? '');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('User Agent \u2014 ${source.name}'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Custom User Agent',
                hintText: 'Leave empty for default',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = ctrl.text.trim();
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .updateSourceUserAgent(
                        source.id,
                        value.isEmpty ? null : value,
                      );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User agent updated')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}

/// Content filter settings section: hidden categories.
class ContentFilterSettingsSection extends ConsumerWidget {
  const ContentFilterSettingsSection({super.key, required this.hiddenGroups});

  final List<String> hiddenGroups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Content Filter',
          icon: Icons.filter_list,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Hidden Categories'),
              subtitle: Text(
                hiddenGroups.isEmpty
                    ? 'No categories hidden'
                    : '${hiddenGroups.length} hidden',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showGroupFilterDialog(context, ref, hiddenGroups),
            ),
          ],
        ),
      ],
    );
  }

  void _showGroupFilterDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> currentHidden,
  ) async {
    // Load all known categories.
    final cache = ref.read(cacheServiceProvider);
    final catMap = await cache.loadCategories();
    final allGroups = <String>{};
    for (final list in catMap.values) {
      allGroups.addAll(list);
    }
    final sortedGroups = allGroups.toList()..sort();

    if (!context.mounted || sortedGroups.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No categories found. Sync first.')),
      );
      return;
    }

    final selected = Set<String>.from(currentHidden);

    await showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('Hidden Categories'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 400,
                    child: ListView.builder(
                      itemCount: sortedGroups.length,
                      itemBuilder: (_, i) {
                        final group = sortedGroups[i];
                        return CheckboxListTile(
                          title: Text(group),
                          value: selected.contains(group),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selected.add(group);
                              } else {
                                selected.remove(group);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .setHiddenGroups(selected.toList());
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
          ),
    );
  }
}

/// EPG URL settings section per source.
class EpgUrlSettingsSection extends ConsumerWidget {
  const EpgUrlSettingsSection({super.key, required this.sources});

  final List<PlaylistSource> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }

    // Only show for sources that support or commonly use EPG URLs (M3U, Xtream).
    final validSources =
        sources
            .where(
              (s) =>
                  s.type == PlaylistSourceType.xtream ||
                  s.type == PlaylistSourceType.m3u,
            )
            .toList();

    if (validSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Sources EPG URLs',
          icon: Icons.calendar_today,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            for (var i = 0; i < validSources.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(validSources[i].name),
                subtitle: Text(
                  validSources[i].epgUrl?.isNotEmpty == true
                      ? validSources[i].epgUrl!
                      : 'Not Configured',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => _showEpgUrlEditDialog(context, ref, validSources[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showEpgUrlEditDialog(
    BuildContext context,
    WidgetRef ref,
    PlaylistSource source,
  ) {
    final ctrl = TextEditingController(text: source.epgUrl ?? '');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('EPG URL \u2014 ${source.name}'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'XMLTV URL',
                hintText: 'Leave empty for none',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final value = ctrl.text.trim();
                  final updatedSource = source.copyWith(
                    epgUrl: value.isEmpty ? null : value,
                  );
                  await ref
                      .read(settingsNotifierProvider.notifier)
                      .updateSource(updatedSource);

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('EPG URL updated')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
