import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/live_badge.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../../core/widgets/smart_image.dart';
import '../../../../core/widgets/watch_progress_bar.dart';
import '../../../dvr/data/dvr_service.dart';
import '../../../iptv/data/services/catchup_url_builder.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/epg_providers.dart';

/// Detailed program info bottom sheet with
/// Watch/Record/Remind actions.
///
/// Pass [channel] if the caller has already resolved the
/// channel entity (e.g. from [EpgActionsMixin.showProgramDetail]).
/// When [channel] is null, the widget resolves it internally
/// from [channelListProvider] via [EpgEntry.channelId].
class EpgProgramDetailSheet extends ConsumerWidget {
  const EpgProgramDetailSheet({
    required this.entry,
    required this.timezone,
    this.channel,
    this.onWatch,
    this.onRecord,
    this.onRemind,
    super.key,
  });

  final EpgEntry entry;

  /// Pre-resolved channel, or null to resolve from provider.
  final Channel? channel;

  final String timezone;
  final VoidCallback? onWatch;
  final VoidCallback? onRecord;
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final crispyColors = Theme.of(context).crispyColors;
    final now = ref.watch(epgClockProvider)();
    final isLive = entry.isLiveAt(now);
    final isPast = entry.isPastAt(now);

    // Resolve channel: use the provided one, or look up from provider.
    final resolvedChannel =
        channel ??
        ref
            .read(channelListProvider)
            .channels
            .where((c) => c.id == entry.channelId || c.tvgId == entry.channelId)
            .firstOrNull;

    final canCatchup = isPast && (resolvedChannel?.hasCatchup ?? false);

    return Padding(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              if (isLive) ...[
                const LiveBadge(),
                const SizedBox(width: CrispySpacing.sm),
              ],
              Expanded(
                child: Text(
                  entry.title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.commonClose,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // ── Channel name + logo ──
          if (resolvedChannel != null) ...[
            const SizedBox(height: CrispySpacing.xs),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: CrispySpacing.xs),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: SmartImage(
                      itemId: resolvedChannel.id,
                      title: resolvedChannel.name,
                      imageUrl: resolvedChannel.logoUrl,
                      imageKind: 'logo',
                      fit: BoxFit.contain,
                      memCacheWidth: 48,
                      memCacheHeight: 48,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    resolvedChannel.name,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: CrispySpacing.sm),

          // ── Time + duration ──
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: CrispySpacing.xs),
              Expanded(
                child: Text(
                  '${_fmt(entry.startTime)}'
                  ' – ${_fmt(entry.endTime)}'
                  '  (${DurationFormatter.humanShort(entry.duration)})',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // ── Metadata enrichment row (FE-EPG-09) ──
          _ProgrammeMetadataRow(entry: entry, textTheme: textTheme),

          // ── Description (FE-EPG-09: full, not truncated) ──
          if (entry.description != null && entry.description!.isNotEmpty) ...[
            const SizedBox(height: CrispySpacing.md),
            Text(
              entry.description!,
              style: textTheme.bodyMedium,
              // No maxLines — show full description per FE-EPG-09.
            ),
          ],

          // ── Progress bar ──
          if (isLive) ...[
            const SizedBox(height: CrispySpacing.md),
            WatchProgressBar(
              value: entry.progressAt(now),
              height: 4,
              fillColor: crispyColors.liveRed,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ],

          const SizedBox(height: CrispySpacing.lg),

          // ── Action buttons ──
          FocusTraversalGroup(
            child: Wrap(
              spacing: CrispySpacing.sm,
              runSpacing: CrispySpacing.sm,
              children: [
                // Live: Watch button
                if (isLive)
                  FilledButton.icon(
                    autofocus: true,
                    onPressed:
                        onWatch ??
                        (resolvedChannel != null
                            ? () => _watchLive(context, ref, resolvedChannel)
                            : null),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Watch'),
                  ),

                // Past with catch-up: Watch Catch-up button
                if (canCatchup)
                  FilledButton.icon(
                    autofocus: !isLive,
                    onPressed:
                        () => _playCatchup(context, ref, resolvedChannel!),
                    icon: const Icon(Icons.history),
                    label: const Text('Watch Catch-up'),
                  ),

                // Past without catch-up: unavailable indicator
                if (isPast && !canCatchup && !isLive)
                  OutlinedButton.icon(
                    autofocus: true,
                    onPressed: null,
                    icon: const Icon(Icons.history_toggle_off),
                    label: const Text('Catch-up unavailable'),
                  ),

                OutlinedButton.icon(
                  autofocus: !isLive && !isPast,
                  onPressed:
                      onRemind ??
                      () => _addReminder(context, ref, resolvedChannel),
                  icon: const Icon(Icons.alarm),
                  label: Text(context.l10n.epgSetReminder),
                ),
                OutlinedButton.icon(
                  onPressed:
                      onRecord ??
                      (resolvedChannel != null
                          ? () =>
                              _scheduleRecording(context, ref, resolvedChannel)
                          : null),
                  icon: const Icon(Icons.fiber_manual_record),
                  label: Text(context.l10n.epgRecord),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => TimezoneUtils.formatTime(dt, timezone);

  void _watchLive(BuildContext context, WidgetRef ref, Channel ch) {
    Navigator.pop(context);
    ref
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: ch.streamUrl,
          channelName: ch.name,
          channelLogoUrl: ch.logoUrl,
          isLive: true,
          sourceId: ch.sourceId,
        );
  }

  void _addReminder(BuildContext context, WidgetRef ref, Channel? ch) {
    Navigator.pop(context);
    ref
        .read(notificationServiceProvider.notifier)
        .addReminder(
          programName: entry.title,
          channelName: ch?.name ?? 'Channel',
          startTime: entry.startTime,
        );
  }

  Future<void> _scheduleRecording(
    BuildContext context,
    WidgetRef ref,
    Channel channel,
  ) async {
    Navigator.pop(context);

    // For past programs with catch-up, build the archive URL.
    String? streamUrl = channel.streamUrl;
    if (entry.isPast && channel.hasCatchup) {
      final backend = ref.read(crispyBackendProvider);
      final builder = CatchupUrlBuilder(backend);
      final info = await builder.buildCatchup(channel: channel, entry: entry);
      if (info != null) {
        streamUrl = info.archiveUrl;
      }
    }

    ref
        .read(dvrServiceProvider.notifier)
        .scheduleRecording(
          channelId: channel.id,
          channelName: channel.name,
          channelLogoUrl: channel.logoUrl,
          programName: entry.title,
          streamUrl: streamUrl,
          startTime: entry.startTime,
          endTime: entry.endTime,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entry.isPast
                ? 'Recording catch-up: ${entry.title}'
                : 'Scheduled: ${entry.title}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _playCatchup(
    BuildContext context,
    WidgetRef ref,
    Channel channel,
  ) async {
    final backend = ref.read(crispyBackendProvider);
    final builder = CatchupUrlBuilder(backend);

    final info = await builder.buildCatchup(channel: channel, entry: entry);

    if (!context.mounted) return;

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catch-up not available for this programme'),
        ),
      );
      return;
    }

    Navigator.pop(context);

    ref
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: info.archiveUrl,
          isLive: false,
          channelName: '${channel.name} - ${entry.title}',
          channelLogoUrl: channel.logoUrl,
          currentProgram:
              'Catch-up: ${TimezoneUtils.formatTime(entry.startTime, timezone)}',
          headers:
              channel.userAgent != null
                  ? {'User-Agent': channel.userAgent!}
                  : null,
        );
  }
}

// ── FE-EPG-09: Programme metadata enrichment ─────────────────────────────────

/// Displays genre / category chip and any available episode
/// metadata for an [EpgEntry].
///
/// Shows: category chip (if any), icon poster (if any).
/// [EpgEntry] does not carry S/E numbers — if that field is
/// added to the domain model in future, wire it here.
class _ProgrammeMetadataRow extends StatelessWidget {
  const _ProgrammeMetadataRow({required this.entry, required this.textTheme});

  final EpgEntry entry;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCategory = entry.category != null && entry.category!.isNotEmpty;
    final hasPoster = entry.iconUrl != null && entry.iconUrl!.isNotEmpty;

    if (!hasCategory && !hasPoster) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: CrispySpacing.sm),

        // ── Poster thumbnail (if available) ──
        if (hasPoster) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(CrispyRadius.xs),
            child: SmartImage(
              title: entry.title,
              imageUrl: entry.iconUrl,
              fit: BoxFit.cover,
              memCacheHeight: 200,
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
        ],

        // ── Genre / category chip ──
        if (hasCategory)
          Wrap(
            spacing: CrispySpacing.xs,
            children: [
              Chip(
                avatar: Icon(
                  Icons.label_outline,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  entry.category!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
              ),
            ],
          ),
      ],
    );
  }
}
