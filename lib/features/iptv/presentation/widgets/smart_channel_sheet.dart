import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../providers/smart_group_providers.dart';

/// Shows the smart channel group management sheet.
///
/// Tab 1: "My Groups" — existing groups with edit actions.
/// Tab 2: "Suggestions" — auto-detected candidates.
Future<void> showSmartChannelSheet({
  required BuildContext context,
  required WidgetRef ref,
  String? preselectedChannelId,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder:
        (_) => SmartChannelSheet(preselectedChannelId: preselectedChannelId),
  );
}

/// Bottom sheet for managing smart channel groups.
class SmartChannelSheet extends ConsumerStatefulWidget {
  const SmartChannelSheet({super.key, this.preselectedChannelId});

  final String? preselectedChannelId;

  @override
  ConsumerState<SmartChannelSheet> createState() => _SmartChannelSheetState();
}

class _SmartChannelSheetState extends ConsumerState<SmartChannelSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final crispyColors = theme.crispyColors;

    return GlassSurface(
      borderRadius: CrispyRadius.md,
      blurSigma: crispyColors.glassBlur,
      tintColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
              ),
            ),
            // ── Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: colorScheme.primary),
                  const SizedBox(width: CrispySpacing.sm),
                  Text(
                    'Smart Channel Groups',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Create group',
                    onPressed: () => _createGroup(context),
                  ),
                ],
              ),
            ),
            // ── Tabs ─────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'My Groups'), Tab(text: 'Suggestions')],
            ),
            const Divider(height: 1),
            // ── Tab content ──────────────────────────────
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _GroupsTab(preselectedChannelId: widget.preselectedChannelId),
                  const _SuggestionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(BuildContext context) async {
    final name = await _showNameDialog(context, title: 'Create Smart Group');
    if (name == null || name.isEmpty) return;
    final cache = ref.read(cacheServiceProvider);
    await cache.createSmartGroup(name);
    ref.invalidate(smartGroupsProvider);
    ref.invalidate(smartGroupChannelIdsProvider);
  }
}

/// Tab showing existing smart groups.
class _GroupsTab extends ConsumerWidget {
  const _GroupsTab({this.preselectedChannelId});

  final String? preselectedChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(smartGroupsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(CrispySpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    size: 48,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: CrispySpacing.md),
                  Text(
                    'No smart groups yet',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.xs),
                  Text(
                    'Create a group to link the same channel\nacross providers for automatic failover.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + CrispySpacing.sm,
          ),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final group = groups[i];
            return _SmartGroupTile(group: group);
          },
        );
      },
    );
  }
}

/// A single smart group row with expand/collapse.
class _SmartGroupTile extends ConsumerStatefulWidget {
  const _SmartGroupTile({required this.group});

  final SmartGroup group;

  @override
  ConsumerState<_SmartGroupTile> createState() => _SmartGroupTileState();
}

class _SmartGroupTileState extends ConsumerState<_SmartGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final group = widget.group;

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.bolt, color: colorScheme.primary),
          title: Text(
            group.name,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${group.members.length} channel${group.members.length == 1 ? '' : 's'}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Rename',
                onPressed: () => _rename(context),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: colorScheme.error,
                ),
                tooltip: 'Delete group',
                onPressed: () => _delete(context),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: CrispySpacing.xl),
            child: Column(
              children: [
                for (final member in group.members)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      child: Text(
                        '${member.priority + 1}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      member.channelId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Source: ${member.sourceId}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      tooltip: 'Remove from group',
                      onPressed: () => _removeMember(member.channelId),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = await _showNameDialog(
      context,
      title: 'Rename Group',
      initialValue: widget.group.name,
    );
    if (name == null || name.isEmpty) return;
    final cache = ref.read(cacheServiceProvider);
    await cache.renameSmartGroup(widget.group.id, name);
    ref.invalidate(smartGroupsProvider);
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Smart Group?'),
            content: Text('Delete "${widget.group.name}" and all its members?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    final cache = ref.read(cacheServiceProvider);
    await cache.deleteSmartGroup(widget.group.id);
    ref.invalidate(smartGroupsProvider);
    ref.invalidate(smartGroupChannelIdsProvider);
  }

  Future<void> _removeMember(String channelId) async {
    final cache = ref.read(cacheServiceProvider);
    await cache.removeSmartGroupMember(widget.group.id, channelId);
    ref.invalidate(smartGroupsProvider);
    ref.invalidate(smartGroupChannelIdsProvider);
  }
}

/// Tab showing auto-detected candidates.
class _SuggestionsTab extends ConsumerWidget {
  const _SuggestionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(smartGroupCandidatesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return candidatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (candidates) {
        if (candidates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(CrispySpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 48,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: CrispySpacing.md),
                  Text(
                    'No suggestions',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.xs),
                  Text(
                    'Add multiple sources with overlapping\nchannels to see suggestions here.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + CrispySpacing.sm,
          ),
          itemCount: candidates.length,
          itemBuilder: (context, i) {
            final candidate = candidates[i];
            return _CandidateTile(candidate: candidate);
          },
        );
      },
    );
  }
}

/// A single candidate suggestion row.
class _CandidateTile extends ConsumerWidget {
  const _CandidateTile({required this.candidate});

  final SmartGroupCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(Icons.lightbulb_outline, color: colorScheme.tertiary),
      title: Text(
        candidate.suggestedName,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${candidate.members.length} channels from different sources',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: FilledButton.tonal(
        onPressed: () => _createFromCandidate(context, ref),
        child: const Text('Create'),
      ),
    );
  }

  Future<void> _createFromCandidate(BuildContext context, WidgetRef ref) async {
    final cache = ref.read(cacheServiceProvider);
    final groupId = await cache.createSmartGroup(candidate.suggestedName);
    for (var i = 0; i < candidate.members.length; i++) {
      final m = candidate.members[i];
      await cache.addSmartGroupMember(groupId, m.channelId, m.sourceId, i);
    }
    ref.invalidate(smartGroupsProvider);
    ref.invalidate(smartGroupChannelIdsProvider);
    ref.invalidate(smartGroupCandidatesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created "${candidate.suggestedName}" group')),
      );
    }
  }
}

/// Shows a dialog to input a group name.
Future<String?> _showNameDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g. ESPN, CNN, BBC',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
  );
}
