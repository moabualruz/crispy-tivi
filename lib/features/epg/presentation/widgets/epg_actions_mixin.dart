import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/utils/stream_url_actions.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../dvr/data/dvr_service.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../player/data/external_player_service.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/epg_providers.dart';
import 'epg_assign_dialog.dart';
import 'epg_state_helpers.dart';
import 'epg_channel_context_menu.dart';
import 'epg_program_detail.dart';
import 'epg_search_delegate.dart';

/// Mixin that provides EPG action methods for the
/// timeline screen state.
///
/// Requires [ConsumerStatefulWidget] because it uses
/// `ref` and `context` from the host state.
mixin EpgActionsMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Vertical grid scroll — provided by the host.
  ScrollController get epgGridScroll;

  /// Horizontal timeline scroll — provided by the host.
  ///
  /// Override in the host state to expose the horizontal
  /// scroll controller for time-axis navigation from search
  /// results. Returns null by default (no-op).
  ScrollController? get epgHorizontalScroll => null;

  // ── Channel actions ───────────────────────────

  /// Start playing [channel] in the EPG preview area
  /// without expanding to full screen.
  ///
  /// Enters preview mode via [playerModeProvider] so
  /// [PermanentVideoLayer] positions the video at the
  /// preview rect.
  void previewChannel(Channel channel) {
    final ps = ref.read(playerServiceProvider);
    // Skip re-open if already playing the same URL.
    if (ps.currentUrl != channel.streamUrl) {
      ps.play(
        channel.streamUrl,
        isLive: true,
        channelName: channel.name,
        channelLogoUrl: channel.logoUrl,
        headers:
            channel.userAgent != null
                ? {'User-Agent': channel.userAgent!}
                : null,
      );
    }

    // Keep session provider in sync so OSD actions
    // (external player, copy URL) read the current URL.
    ref
        .read(playbackSessionProvider.notifier)
        .startPreview(
          streamUrl: channel.streamUrl,
          isLive: true,
          channelName: channel.name,
          channelLogoUrl: channel.logoUrl,
          headers:
              channel.userAgent != null
                  ? {'User-Agent': channel.userAgent!}
                  : null,
        );

    // Enter preview mode — always set mode immediately so
    // PermanentVideoLayer knows to show the video once the
    // rect arrives. EpgVideoPreview._reportRect() fires via
    // a post-frame callback and calls updatePreviewRect().
    // The video layer hides until a valid rect is available.
    final modeState = ref.read(playerModeProvider);
    if (modeState.mode != PlayerMode.fullscreen) {
      final rect = modeState.previewRect;
      ref
          .read(playerModeProvider.notifier)
          .enterPreview(rect ?? Rect.zero, hostRoute: AppRoutes.epg);
      ref.read(playerServiceProvider).forceStateEmit();
    }

    ref.read(epgProvider.notifier).selectChannel(channel.id);
    final state = ref.read(epgProvider);
    final nowPlaying = state.getNowPlaying(channel.id);
    if (nowPlaying != null) {
      ref.read(epgProvider.notifier).selectEntry(nowPlaying);
    }
  }

  /// Preview [channel] and expand to full screen.
  void playChannel(Channel channel) {
    previewChannel(channel);
    expandPlayer();
  }

  /// Expand to fullscreen via [playerModeProvider].
  ///
  /// No Navigator.push — the video and OSD are handled
  /// by AppShell's Stack layers.
  void expandPlayer() {
    ref
        .read(playerModeProvider.notifier)
        .enterFullscreen(hostRoute: AppRoutes.epg);
    ref.read(playerServiceProvider).forceStateEmit();
  }

  /// Collapse from fullscreen back to preview.
  void collapsePlayer() {
    ref.read(playerModeProvider.notifier).exitToPreview();
    ref.read(playerServiceProvider).forceStateEmit();
  }

  /// Play the currently selected EPG entry.
  void playSelectedEntry() {
    final state = ref.read(epgProvider);
    final entry = state.selectedEntry;
    if (entry == null) return;

    final channel = _findChannel(state, entry.channelId);
    playChannel(channel);
  }

  /// Record the currently selected EPG entry.
  Future<void> recordSelectedEntry() async {
    final state = ref.read(epgProvider);
    final entry = state.selectedEntry;
    if (entry == null) return;

    final channel = _findChannel(state, entry.channelId);
    await scheduleRecordingFromEpg(entry, channel);
  }

  // ── Recording ─────────────────────────────────

  /// Schedule a DVR recording from an EPG entry.
  Future<void> scheduleRecordingFromEpg(EpgEntry entry, Channel channel) async {
    final dvrNotifier = ref.read(dvrServiceProvider.notifier);

    final result = await dvrNotifier.scheduleRecording(
      channelName: channel.name,
      programName: entry.title,
      startTime: entry.startTime,
      endTime: entry.endTime,
      channelId: channel.id,
      channelLogoUrl: channel.logoUrl,
      streamUrl: channel.streamUrl,
    );

    if (!mounted) return;

    if (result == ScheduleResult.conflict) {
      _showRecordingConflictDialog(entry, channel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording scheduled: ${entry.title}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push(AppRoutes.dvr),
          ),
        ),
      );
    }
  }

  void _showRecordingConflictDialog(EpgEntry entry, Channel channel) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Recording Conflict'),
            content: Text(
              'Another recording is scheduled at this'
              ' time. Record "${entry.title}" anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(dvrServiceProvider.notifier)
                      .forceScheduleRecording(
                        channelName: channel.name,
                        programName: entry.title,
                        startTime: entry.startTime,
                        endTime: entry.endTime,
                        channelId: channel.id,
                        channelLogoUrl: channel.logoUrl,
                        streamUrl: channel.streamUrl,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recording scheduled'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Record Anyway'),
              ),
            ],
          ),
    );
  }

  // ── Program detail sheet ──────────────────────

  /// Show the bottom sheet with program details.
  void showProgramDetail(EpgEntry entry) {
    final channel = ref
        .read(epgProvider)
        .filteredChannels
        .firstWhere(
          (c) => c.id == entry.channelId || c.tvgId == entry.channelId,
          orElse:
              () =>
                  Channel(id: entry.channelId, name: 'Unknown', streamUrl: ''),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(),
      builder:
          (_) => EpgProgramDetailSheet(
            entry: entry,
            channel: channel,
            timezone: ref.read(epgTimezoneProvider),
            onWatch: () {
              Navigator.pop(context);
              playChannel(channel);
            },
            onRecord: () async {
              Navigator.pop(context);
              await scheduleRecordingFromEpg(entry, channel);
            },
            onRemind: () {
              Navigator.pop(context);
              ref
                  .read(notificationServiceProvider.notifier)
                  .addReminder(
                    programName: entry.title,
                    channelName: channel.name,
                    startTime: entry.startTime,
                  );
            },
          ),
    );
  }

  // ── Context menu ──────────────────────────────

  /// Show context menu for a channel row.
  void showChannelContextMenu(Channel channel, EpgEntry? nowPlaying) {
    showEpgChannelContextMenu(
      context: context,
      ref: ref,
      channel: channel,
      nowPlaying: nowPlaying,
      onPlayChannel: () => playChannel(channel),
      onOpenExternal: () => _openInExternalPlayer(channel),
      onRecordNowPlaying: () {
        if (nowPlaying != null) {
          scheduleRecordingFromEpg(nowPlaying, channel);
        }
      },
      onHideChannel: () => hideChannel(channel),
      onBlockChannel: () => blockChannel(channel),
      onAssignEpg: () => showEpgAssignDialog(channel),
      onSearch: () => showEpgSearch(ref.read(epgProvider)),
      hasExternal: hasExternalPlayer(ref),
    );
  }

  // ── External player ───────────────────────────

  Future<void> _openInExternalPlayer(Channel channel) async {
    final settings = ref.read(settingsNotifierProvider).value;
    final playerName =
        settings?.config.player.externalPlayer ?? 'systemDefault';
    final player = ExternalPlayer.values.firstWhere(
      (p) => p.name == playerName,
      orElse: () => ExternalPlayer.systemDefault,
    );
    final service = ref.read(externalPlayerServiceProvider);
    final ok = await service.launch(
      streamUrl: channel.streamUrl,
      player: player,
      title: channel.name,
    );
    if (!ok && mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open external player')),
      );
    }
  }

  // ── Channel visibility ────────────────────────

  /// Hide a channel (from settings).
  void hideChannel(Channel channel) {
    ref.read(settingsNotifierProvider.notifier).hideChannel(channel.id);
    ref
        .read(channelListProvider.notifier)
        .setHiddenChannelIds(
          ref.read(settingsNotifierProvider).value?.allHiddenChannelIds ??
              {channel.id},
        );
  }

  /// Block a channel (from settings).
  void blockChannel(Channel channel) {
    ref.read(settingsNotifierProvider.notifier).blockChannel(channel.id);
    ref
        .read(channelListProvider.notifier)
        .setHiddenChannelIds(
          ref.read(settingsNotifierProvider).value?.allHiddenChannelIds ??
              {channel.id},
        );
  }

  /// Show the EPG assignment dialog.
  void showEpgAssignDialog(Channel channel) {
    showDialog(
      context: context,
      builder: (_) => EpgAssignDialog(channel: channel),
    );
  }

  // ── Search ────────────────────────────────────

  /// Open the EPG search delegate.
  ///
  /// Results wire both vertical (channel row) and horizontal
  /// (time axis) scrolling so program results land on the
  /// correct time slot in the guide.
  void showEpgSearch(EpgState state) {
    final timezone = ref.read(epgTimezoneProvider);
    showSearch(
      context: context,
      delegate: EpgSearchDelegate(
        channels: state.channels,
        entries: state.entries,
        timezone: timezone,
        onChannelSelected: playChannel,
        onScrollToChannel: (channelId) {
          _scrollGridToChannel(state, channelId);
        },
        onScrollToProgram: (channelId, programStart) {
          _scrollGridToChannel(state, channelId);
          _scrollTimelineToStart(programStart);
        },
        onQueryChanged: (q) {
          ref.read(epgProgramSearchProvider.notifier).setQuery(q);
        },
      ),
    );
  }

  // ── Scroll helpers ────────────────────────────

  void _scrollGridToChannel(EpgState state, String channelId) {
    final idx = state.filteredChannels.indexWhere((c) => c.id == channelId);
    if (idx >= 0 && epgGridScroll.hasClients) {
      epgGridScroll.animateTo(
        idx * 60.0,
        duration: CrispyAnimation.normal,
        curve: CrispyAnimation.scrollCurve,
      );
    }
  }

  void _scrollTimelineToStart(DateTime programStart) {
    final hScroll = epgHorizontalScroll;
    if (hScroll == null || !hScroll.hasClients) return;
    final epgState = ref.read(epgProvider);
    final (startDate, _) = getEpgDateRange(epgState.viewMode, programStart);
    final ppm = getEpgPixelsPerMinute(epgState.viewMode);
    final minutesFromStart = programStart.difference(startDate).inMinutes;
    if (minutesFromStart < 0) return;
    final offset = (minutesFromStart * ppm - 50).clamp(
      0.0,
      hScroll.position.maxScrollExtent,
    );
    hScroll.animateTo(
      offset,
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.scrollCurve,
    );
  }

  // ── Snackbar listener ─────────────────────────

  /// Listen for EPG fetch result messages and show
  /// a snackbar.
  void listenForFetchResults() {
    ref.listen(epgProvider.select((s) => s.lastFetchMessage), (_, message) {
      if (message != null) {
        final success = ref.read(epgProvider).lastFetchSuccess ?? true;
        final colorScheme = Theme.of(context).colorScheme;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? null : colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: success ? colorScheme.primary : colorScheme.onError,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        ref.read(epgProvider.notifier).clearFetchMessage();
      }
    });
  }

  // ── Private ───────────────────────────────────

  Channel _findChannel(EpgState state, String channelId) {
    return state.channels.firstWhere(
      (c) => c.id == channelId || c.tvgId == channelId,
      orElse: () => Channel(id: channelId, name: 'Unknown', streamUrl: ''),
    );
  }
}
