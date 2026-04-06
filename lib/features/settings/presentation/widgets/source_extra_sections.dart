import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../../core/widgets/playlist_source_type_ext.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../providers/settings_service_providers.dart';
import 'settings_shared_widgets.dart';
import 'tls_toggle_widget.dart';

/// Tile showing a saved playlist source with type icon,
/// type-aware subtitle, optional drag handle, and delete.
class SourceTile extends StatelessWidget {
  const SourceTile({
    super.key,
    required this.source,
    required this.onDelete,
    this.index = 0,
    this.showDragHandle = false,
  });

  final PlaylistSource source;
  final VoidCallback onDelete;

  /// Position of this tile in the list, required when
  /// [showDragHandle] is `true` for [ReorderableDragStartListener].
  final int index;

  /// When `true`, a drag handle is shown on the leading edge so the
  /// parent [ReorderableListView] can reorder items.
  final bool showDragHandle;

  /// Builds the type-aware subtitle string.
  String _subtitle() {
    final label = source.type.serverLabel;
    switch (source.type) {
      case PlaylistSourceType.xtream:
        return '$label \u2022 ${source.url} \u2022 ${source.username ?? ''}';
      case PlaylistSourceType.stalkerPortal:
        return '$label \u2022 ${source.url} \u2022 ${source.macAddress ?? ''}';
      case PlaylistSourceType.m3u:
        return '$label \u2022 ${source.url}';
      case PlaylistSourceType.jellyfin:
      case PlaylistSourceType.emby:
      case PlaylistSourceType.plex:
        return '$label \u2022 ${source.url}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final dragHandle =
        showDragHandle
            ? ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.sm),
                child: Icon(
                  Icons.drag_handle,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
            : null;

    final deleteButton = IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Delete source',
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
                      backgroundColor: colorScheme.error,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ),
        );
      },
    );

    return Row(
      children: [
        if (dragHandle != null) dragHandle,
        Expanded(
          child: ListTile(
            leading: Icon(source.type.icon),
            title: Text(source.name),
            subtitle: Text(
              _subtitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: deleteButton,
          ),
        ),
      ],
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
    final sortedGroups = allGroups.toList()..sort(categoryBucketCompare);

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

/// Per-source TLS certificate settings section.
///
/// Shows a [TlsToggleWidget] for each source, allowing users
/// to enable/disable self-signed certificate acceptance on a
/// per-source basis.
class SourceTlsSettingsSection extends ConsumerWidget {
  /// Creates a per-source TLS settings section.
  const SourceTlsSettingsSection({super.key, required this.sources});

  /// The list of configured playlist sources.
  final List<PlaylistSource> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Source TLS Settings',
          icon: Icons.security,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            for (var i = 0; i < sources.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ExpansionTile(
                leading: Icon(sources[i].type.icon),
                title: Text(sources[i].name),
                subtitle: Text(
                  sources[i].acceptSelfSigned
                      ? 'Self-signed: allowed'
                      : 'Self-signed: rejected',
                  style: TextStyle(
                    color:
                        sources[i].acceptSelfSigned
                            ? Theme.of(context).colorScheme.error
                            : null,
                  ),
                ),
                children: [
                  TlsToggleWidget(
                    value: sources[i].acceptSelfSigned,
                    onChanged: (value) {
                      final updated = sources[i].copyWith(
                        acceptSelfSigned: value,
                      );
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSource(updated);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Displays Stalker portal account/subscription info for each
/// configured Stalker source.
///
/// Shows subscription status, expiry date, max connections, and
/// trial status in an expansion tile per source.
class StalkerAccountInfoSection extends ConsumerStatefulWidget {
  /// Creates a Stalker account info section.
  const StalkerAccountInfoSection({super.key, required this.sources});

  /// All configured playlist sources (filtered to Stalker internally).
  final List<PlaylistSource> sources;

  @override
  ConsumerState<StalkerAccountInfoSection> createState() =>
      _StalkerAccountInfoSectionState();
}

class _StalkerAccountInfoSectionState
    extends ConsumerState<StalkerAccountInfoSection> {
  final Map<String, StalkerAccountInfo?> _infoCache = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  void _fetchAll() {
    for (final source in _stalkerSources) {
      if (_infoCache.containsKey(source.id)) continue;
      _loading.add(source.id);
      fetchStalkerAccountInfoFromRef(ref, source).then((info) {
        if (mounted) {
          setState(() {
            _infoCache[source.id] = info;
            _loading.remove(source.id);
          });
        }
      });
    }
  }

  List<PlaylistSource> get _stalkerSources =>
      widget.sources
          .where((s) => s.type == PlaylistSourceType.stalkerPortal)
          .toList();

  @override
  Widget build(BuildContext context) {
    final stalkerSources = _stalkerSources;
    if (stalkerSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Stalker Account Info',
          icon: Icons.account_circle,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            for (var i = 0; i < stalkerSources.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _StalkerAccountTile(
                source: stalkerSources[i],
                info: _infoCache[stalkerSources[i].id],
                isLoading: _loading.contains(stalkerSources[i].id),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StalkerAccountTile extends StatelessWidget {
  const _StalkerAccountTile({
    required this.source,
    required this.info,
    required this.isLoading,
  });

  final PlaylistSource source;
  final StalkerAccountInfo? info;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return ListTile(
        leading: const Icon(Icons.router),
        title: Text(source.name),
        subtitle: const Text('Loading account info...'),
        trailing: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (info == null) {
      return ListTile(
        leading: const Icon(Icons.router),
        title: Text(source.name),
        subtitle: Text(
          'Account info unavailable',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final details = <String>[];
    if (info!.status != null) details.add('Status: ${info!.status}');
    if (info!.expiryDate != null) details.add('Expires: ${info!.expiryDate}');
    if (info!.maxConnections != null) {
      details.add('Max connections: ${info!.maxConnections}');
    }
    if (info!.isTrial) details.add('Trial account');
    if (info!.tariffPlan != null) details.add('Plan: ${info!.tariffPlan}');

    final isExpired = info!.status?.toLowerCase().contains('expired') ?? false;

    return ListTile(
      leading: Icon(
        Icons.router,
        color: isExpired ? theme.colorScheme.error : null,
      ),
      title: Text(source.name),
      subtitle: Text(
        details.join(' \u2022 '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: isExpired ? theme.colorScheme.error : null),
      ),
    );
  }
}
