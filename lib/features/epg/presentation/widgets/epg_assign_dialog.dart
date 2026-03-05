import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../providers/epg_providers.dart';

/// Dialog for manually assigning EPG data to a channel.
///
/// Shows a searchable list of all channels that have EPG
/// entries. The user picks a source channel whose EPG data
/// will be used for the target channel.
class EpgAssignDialog extends ConsumerStatefulWidget {
  const EpgAssignDialog({required this.channel, super.key});

  /// The channel to assign EPG data to.
  final Channel channel;

  @override
  ConsumerState<EpgAssignDialog> createState() => _EpgAssignDialogState();
}

class _EpgAssignDialogState extends ConsumerState<EpgAssignDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final epgState = ref.watch(epgProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Current override (if any).
    final settings = ref.watch(settingsNotifierProvider).value;
    final currentOverride = settings?.epgOverrides[widget.channel.id];

    // Channels that have EPG entries.
    final channelsWithEpg =
        epgState.channels
            .where(
              (c) =>
                  epgState.entries.containsKey(c.id) &&
                  (epgState.entries[c.id]?.isNotEmpty ?? false),
            )
            .toList();

    // Filter by search.
    final filtered =
        _search.isEmpty
            ? channelsWithEpg
            : channelsWithEpg
                .where(
                  (c) => c.name.toLowerCase().contains(_search.toLowerCase()),
                )
                .toList();

    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.85).clamp(300.0, 480.0);
    final dialogHeight = (screenSize.height * 0.65).clamp(300.0, 520.0);

    return AlertDialog(
      title: Text(
        'Assign EPG — ${widget.channel.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current assignment info.
            if (currentOverride != null) ...[
              Container(
                padding: const EdgeInsets.all(CrispySpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: colorScheme.primary),
                    const SizedBox(width: CrispySpacing.sm),
                    Expanded(
                      child: Text(
                        'Linked to: '
                        '${_channelName(channelsWithEpg, currentOverride)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(settingsNotifierProvider.notifier)
                            .clearEpgOverride(widget.channel.id);
                        // Update EPG provider.
                        final updated =
                            ref
                                .read(settingsNotifierProvider)
                                .value
                                ?.epgOverrides ??
                            {};
                        ref.read(epgProvider.notifier).setEpgOverrides(updated);
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CrispySpacing.sm),
            ],

            // Search field.
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search channels...',
                labelText: 'Search channels',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: CrispySpacing.sm),

            // Channel list.
            Expanded(
              child:
                  filtered.isEmpty
                      ? Center(
                        child: Text(
                          'No channels with EPG data',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final ch = filtered[index];
                          final isLinked = currentOverride == ch.id;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isLinked ? Icons.link : Icons.tv,
                              color:
                                  isLinked
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                            ),
                            title: Text(ch.name),
                            subtitle: ch.group != null ? Text(ch.group!) : null,
                            selected: isLinked,
                            onTap: () => _assign(ch.id),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _assign(String targetChannelId) async {
    await ref
        .read(settingsNotifierProvider.notifier)
        .setEpgOverride(widget.channel.id, targetChannelId);
    // Update EPG provider.
    final updated =
        ref.read(settingsNotifierProvider).value?.epgOverrides ?? {};
    ref.read(epgProvider.notifier).setEpgOverrides(updated);
    if (mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    }
  }

  String _channelName(List<Channel> channels, String channelId) {
    final ch = channels.where((c) => c.id == channelId);
    return ch.isNotEmpty ? ch.first.name : channelId;
  }
}
