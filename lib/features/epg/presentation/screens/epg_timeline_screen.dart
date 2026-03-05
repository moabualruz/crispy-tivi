import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/group_sidebar.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../iptv/application/playlist_sync_service.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../../dvr/data/dvr_service.dart';
import '../../../dvr/domain/entities/recording.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/epg_providers.dart';
import '../widgets/epg_actions_mixin.dart';
import '../widgets/epg_app_bar.dart';
import '../widgets/epg_channel_row.dart';
import '../widgets/epg_mobile_video_overlay.dart';
import '../widgets/epg_program_block.dart';
import '../widgets/epg_program_info_panel.dart';
import '../widgets/epg_state_helpers.dart';
import '../../../../core/widgets/video_preview_widget.dart';
import '../widgets/epg_whats_on_now_row.dart';
import '../widgets/virtual_epg_grid.dart';

/// EPG timeline screen per `.ai/docs/project-specs/ui_ux_spec.md §3.3`.
///
/// Layout:
/// - Left column: channel names/logos (fixed width)
/// - Right area: horizontally scrollable 30-min
///   block timeline
/// - Red "now" line indicating current time
/// - Time axis header showing hours
class EpgTimelineScreen extends ConsumerStatefulWidget {
  const EpgTimelineScreen({super.key});

  @override
  ConsumerState<EpgTimelineScreen> createState() => _EpgTimelineScreenState();
}

class _EpgTimelineScreenState extends ConsumerState<EpgTimelineScreen>
    with EpgActionsMixin {
  late final ScrollController _horizontalScroll;
  late final ScrollController _gridScroll;

  late DateTime _selectedDate;

  // FE-EPG-08: active time-slot preset (null = none selected).
  EpgTimePreset? _selectedTimePreset;

  // FE-EPG-06: continuous auto-scroll ("Live" mode) state.
  bool _autoScrollActive = false;
  Timer? _autoScrollTimer;

  @override
  ScrollController get epgGridScroll => _gridScroll;

  @override
  ScrollController? get epgHorizontalScroll => _horizontalScroll;

  DateTime Function() get _clock => ref.read(epgClockProvider);

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
    _gridScroll = ScrollController();
    _selectedDate = ref.read(epgClockProvider)();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNow();
      _fetchCurrentWindow();

      final state = ref.read(epgProvider);
      if (state.selectedChannel == null && state.filteredChannels.isNotEmpty) {
        previewChannel(state.filteredChannels.first);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _horizontalScroll.dispose();
    _gridScroll.dispose();
    super.dispose();
  }

  void _scrollToNow({bool animate = true}) {
    if (!_horizontalScroll.hasClients) return;

    final viewMode = ref.read(epgProvider).viewMode;
    final ppm = getEpgPixelsPerMinute(viewMode);
    final (startDate, _) = getEpgDateRange(viewMode, _selectedDate);
    final now = _clock();

    if (viewMode == EpgViewMode.day && !isSameDay(now, _selectedDate)) {
      return;
    }

    final minutesFromStart = now.difference(startDate).inMinutes;
    if (minutesFromStart < 0) return;

    final offset = (minutesFromStart * ppm) - 200;
    final target = offset.clamp(
      0.0,
      _horizontalScroll.position.maxScrollExtent,
    );

    if (animate) {
      _horizontalScroll.animateTo(
        target,
        duration: CrispyAnimation.normal,
        curve: Curves.easeOut,
      );
    } else {
      // Silent jump used by auto-scroll timer — avoids
      // scroll animation piling up every second.
      _horizontalScroll.jumpTo(target);
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = date);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isSameDay(date, _clock())) {
        _scrollToNow();
      } else {
        if (_horizontalScroll.hasClients) {
          _horizontalScroll.jumpTo(0);
        }
      }
      _fetchCurrentWindow();
    });
  }

  void _onWeekChanged(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta * 7));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalScroll.hasClients) {
        _horizontalScroll.jumpTo(0);
      }
      _fetchCurrentWindow();
    });
  }

  void _fetchCurrentWindow() {
    final viewMode = ref.read(epgProvider).viewMode;
    final (start, end) = getEpgDateRange(viewMode, _selectedDate);
    ref.read(epgProvider.notifier).fetchEpgWindow(start, end);
  }

  void _triggerRefresh() {
    ref.read(playlistSyncServiceProvider).refreshEpg();
  }

  void _scrollTimeForward() {
    if (!_horizontalScroll.hasClients) return;
    final viewMode = ref.read(epgProvider).viewMode;
    final ppm = getEpgPixelsPerMinute(viewMode);
    final maxScroll = _horizontalScroll.position.maxScrollExtent;
    final offset = _horizontalScroll.offset + (120 * ppm);
    _horizontalScroll.animateTo(
      offset > maxScroll ? maxScroll : offset,
      duration: CrispyAnimation.normal,
      curve: Curves.easeInOut,
    );
  }

  void _scrollTimeBackward() {
    if (!_horizontalScroll.hasClients) return;
    final viewMode = ref.read(epgProvider).viewMode;
    final ppm = getEpgPixelsPerMinute(viewMode);
    final offset = _horizontalScroll.offset - (120 * ppm);
    _horizontalScroll.animateTo(
      offset < 0 ? 0 : offset,
      duration: CrispyAnimation.normal,
      curve: Curves.easeInOut,
    );
  }

  // FE-EPG-06: auto-scroll ("Live" mode) ──────────────────

  /// Toggles the "Live" auto-scroll mode.
  ///
  /// When active, a [Timer.periodic] fires every second and
  /// nudges the timeline so the "now" line stays centred.
  /// Manual user scrolling calls [_pauseAutoScroll] to pause
  /// the timer. The "Live" pill re-enables it.
  void _toggleAutoScroll() {
    setState(() => _autoScrollActive = !_autoScrollActive);
    if (_autoScrollActive) {
      _startAutoScrollTimer();
      // Snap to now immediately.
      _scrollToNow();
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  /// Starts (or restarts) the auto-scroll timer.
  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    // Tick every second — calculates absolute offset so no drift
    // accumulates over time.
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_autoScrollActive) return;
      _scrollToNow(animate: false);
    });
  }

  /// Called when the user manually scrolls the timeline.
  ///
  /// Pauses auto-scroll so the live marker doesn't fight the
  /// user's scroll position.
  void _pauseAutoScroll() {
    if (!_autoScrollActive) return;
    setState(() => _autoScrollActive = false);
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  // FE-EPG-10: scroll the vertical grid to the row for [channel].
  void _scrollToChannel(Channel channel) {
    final state = ref.read(epgProvider);
    final index = state.filteredChannels.indexWhere((c) => c.id == channel.id);
    if (index < 0 || !_gridScroll.hasClients) return;
    const rowHeight = 64.0; // kEpgRowHeight
    _gridScroll.animateTo(
      (index * rowHeight).clamp(0.0, _gridScroll.position.maxScrollExtent),
      duration: CrispyAnimation.normal,
      curve: Curves.easeOut,
    );
    // Also scroll horizontally to now so the live programme is visible.
    _scrollToNow();
  }

  // FE-EPG-08: scroll the EPG timeline to the start hour of a preset.
  void _onTimePresetSelected(EpgTimePreset? preset) {
    setState(() => _selectedTimePreset = preset);
    if (preset == null || !_horizontalScroll.hasClients) return;

    final viewMode = ref.read(epgProvider).viewMode;
    final ppm = getEpgPixelsPerMinute(viewMode);
    final (startDate, _) = getEpgDateRange(viewMode, _selectedDate);

    // Build a DateTime at the preset's start hour on the selected date.
    final presetStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      preset.startHour,
    );

    final minutesFromStart = presetStart.difference(startDate).inMinutes;
    if (minutesFromStart < 0) return;

    final offset = (minutesFromStart * ppm).clamp(
      0.0,
      _horizontalScroll.position.maxScrollExtent,
    );

    _horizontalScroll.animateTo(
      offset,
      duration: CrispyAnimation.normal,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(epgProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<EpgState>(epgProvider, (previous, next) {
      final wasEmpty = previous == null || previous.filteredChannels.isEmpty;
      if (wasEmpty &&
          next.filteredChannels.isNotEmpty &&
          next.selectedChannel == null) {
        previewChannel(next.filteredChannels.first);
      }
    });

    listenForFetchResults();

    final isEmpty =
        state.channels.isEmpty ||
        (state.showEpgOnly && state.filteredChannels.isEmpty);

    if (state.isLoading && isEmpty) {
      return _buildLoading();
    }

    if (state.error != null && isEmpty) {
      return _buildError(state.error!, colorScheme);
    }

    if (isEmpty) {
      return _buildEmpty(colorScheme);
    }

    // Fullscreen is handled by AppShell's PlayerOsdLayer.
    // EPG layout is always guide mode — grid stays mounted
    // to preserve scroll position.

    return Scaffold(
      key: TestKeys.epgScreen,
      body: ResponsiveLayout(
        compactBody: _buildMobileLayout(state),
        largeBody: _buildTvLayout(state),
      ),
    );
  }

  // ── Mobile layout ─────────────────────────────

  Widget _buildMobileLayout(EpgState state) {
    final (startDate, endDate) = getEpgDateRange(state.viewMode, _selectedDate);
    final ppm = getEpgPixelsPerMinute(state.viewMode);
    final appBar = _buildAppBar(state, showGroupDropdown: true);

    return Column(
      children: [
        SizedBox(height: appBar.preferredSize.height, child: appBar),
        // FE-EPG-10: "What's On Now" summary row (day view only).
        if (state.viewMode == EpgViewMode.day)
          EpgWhatsOnNowRow(onChannelTap: _scrollToChannel),
        Expanded(
          child: FocusTraversalGroup(
            child: Stack(
              children: [
                _buildEpgGrid(state, startDate, endDate, ppm),
                EpgMobileVideoOverlay(onTap: expandPlayer),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TV/Desktop layout ─────────────────────────

  Widget _buildTvLayout(EpgState state) {
    final textTheme = Theme.of(context).textTheme;
    final timezone = ref.watch(epgTimezoneProvider);
    final (startDate, endDate) = getEpgDateRange(state.viewMode, _selectedDate);
    final ppm = getEpgPixelsPerMinute(state.viewMode);

    return Row(
      children: [
        // ── Group Sidebar ──
        GroupSidebar(
          groups: state.groups,
          selectedGroup: state.selectedGroup,
          onGroupSelected: (group) {
            ref.read(epgProvider.notifier).selectGroup(group);
          },
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
            child: Text(
              'Groups',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // ── EPG Content Area ──
        Expanded(
          child: FocusTraversalGroup(
            child: Builder(
              builder: (context) {
                final appBar = _buildAppBar(state, showGroupDropdown: false);
                return Column(
                  children: [
                    SizedBox(
                      height: appBar.preferredSize.height,
                      child: appBar,
                    ),
                    // ── Top: Info + Video
                    // Info panel (Expanded) absorbs sidebar width
                    // changes; video stays anchored on the right
                    // so the Platform View doesn't need to move
                    // during sidebar animation.
                    SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: EpgProgramInfoPanel(
                              entry: state.selectedEntry,
                              channels: state.channels,
                              timezone: timezone,
                              onWatch: playSelectedEntry,
                              onRecord: recordSelectedEntry,
                            ),
                          ),
                          VideoPreviewWidget(onTap: expandPlayer),
                        ],
                      ),
                    ),
                    // FE-EPG-10: "What's On Now" row (day view only).
                    if (state.viewMode == EpgViewMode.day)
                      EpgWhatsOnNowRow(onChannelTap: _scrollToChannel),
                    // ── EPG Grid ──
                    Expanded(
                      child: _buildEpgGrid(state, startDate, endDate, ppm),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── App bar ───────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    EpgState state, {
    required bool showGroupDropdown,
  }) {
    return EpgAppBar(
      state: state,
      selectedDate: _selectedDate,
      showGroupDropdown: showGroupDropdown,
      onDateSelected: _onDateSelected,
      onWeekChanged: _onWeekChanged,
      onSearch: () => showEpgSearch(state),
      onJumpToNow: () => _onDateSelected(_clock()),
      onRefresh: _triggerRefresh,
      onScrollTimeBackward: _scrollTimeBackward,
      onScrollTimeForward: _scrollTimeForward,
      // FE-EPG-08: time-slot preset wiring.
      selectedTimePreset: _selectedTimePreset,
      onTimePresetSelected: _onTimePresetSelected,
      // FE-EPG-06: live auto-scroll wiring.
      autoScrollActive: _autoScrollActive,
      onToggleAutoScroll: _toggleAutoScroll,
    );
  }

  // ── EPG grid ──────────────────────────────────

  /// Wraps the grid in a [NotificationListener] so that any
  /// user-initiated drag pauses the FE-EPG-06 auto-scroll timer.
  Widget _buildEpgGrid(
    EpgState state,
    DateTime startDate,
    DateTime endDate,
    double pixelsPerMinute,
  ) {
    final timezone = ref.watch(epgTimezoneProvider);

    final effectiveEntries = <String, List<EpgEntry>>{...state.entries};
    for (final entry in state.epgOverrides.entries) {
      final target = state.entries[entry.value];
      if (target != null) {
        effectiveEntries[entry.key] = target;
      }
    }

    final clock = ref.watch(epgClockProvider);
    final playingUrl = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl),
    );
    final dvrRecordings = ref.watch(dvrServiceProvider).value?.recordings;
    final recordingKeys = <String>{};
    if (dvrRecordings != null) {
      for (final r in dvrRecordings) {
        if (r.status == RecordingStatus.scheduled ||
            r.status == RecordingStatus.recording) {
          recordingKeys.add('${r.channelId}_${r.startTime}');
        }
      }
    }

    // FE-EPG-06: detect user-initiated drags and pause auto-scroll.
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _pauseAutoScroll();
        return false; // bubble up
      },
      child: VirtualEpgGrid(
        channels: state.filteredChannels,
        epgEntries: effectiveEntries,
        startDate: startDate,
        endDate: endDate,
        pixelsPerMinute: pixelsPerMinute,
        viewMode: state.viewMode,
        timezone: timezone,
        clock: clock,
        horizontalScrollController: _horizontalScroll,
        verticalScrollController: _gridScroll,
        channelBuilder: (context, channel) {
          final nowPlaying = state.getNowPlaying(channel.id, now: clock());
          final isPlaying =
              channel.streamUrl.isNotEmpty && channel.streamUrl == playingUrl;

          return EpgChannelRow(
            channel: channel,
            nowPlaying: nowPlaying,
            isSelected: channel.id == state.selectedChannel,
            isPlaying: isPlaying,
            onTap: () => previewChannel(channel),
            onLongPress: () => showChannelContextMenu(channel, nowPlaying),
          );
        },
        programBuilder: (context, entry, w, h) {
          final isRecording = recordingKeys.contains(
            '${entry.channelId}_${entry.startTime}',
          );
          // Look up the channel to pass catch-up support to the block.
          final entryChannel = state.filteredChannels.firstWhere(
            (c) => c.id == entry.channelId || c.tvgId == entry.channelId,
            orElse: () => Channel(id: entry.channelId, name: '', streamUrl: ''),
          );

          return EpgProgramBlock(
            entry: entry,
            pixelsPerMinute: pixelsPerMinute,
            isRecording: isRecording,
            hasCatchup: entryChannel.hasCatchup,
            onTap: () {
              ref.read(epgProvider.notifier).selectEntry(entry);
              if (entry.isLive) {
                final ch = state.filteredChannels.firstWhere(
                  (c) => c.id == entry.channelId || c.tvgId == entry.channelId,
                  orElse:
                      () => Channel(
                        id: entry.channelId,
                        name: 'Unknown',
                        streamUrl: '',
                      ),
                );
                if (ch.streamUrl.isNotEmpty) previewChannel(ch);
              }
              showProgramDetail(entry);
            },
          );
        },
        cornerBuilder:
            (context) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    epgTodayLabel(_selectedDate),
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: CrispySpacing.xxs),
                IconButton(
                  icon: const Icon(Icons.my_location, size: 16),
                  onPressed: () => _onDateSelected(_clock()),
                  tooltip: 'Jump to now',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // ── Scaffold wrappers ─────────────────────────

  Widget _buildLoading() {
    return Scaffold(
      appBar: AppBar(title: const Text('Program Guide')),
      body: const LoadingStateWidget(),
    );
  }

  Widget _buildError(String error, ColorScheme colorScheme) {
    return Scaffold(
      appBar: AppBar(title: const Text('Program Guide')),
      body: ErrorStateWidget(message: 'Error: $error'),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Scaffold(
      appBar: AppBar(title: const Text('Program Guide')),
      body: EmptyStateWidget(
        icon: Icons.calendar_month,
        title: 'No channels found',
        description: 'Add a playlist source in Settings',
        showSettingsButton: true,
        onRefresh: _triggerRefresh,
      ),
    );
  }
}
