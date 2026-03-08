import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/utils/debounce_throttle.dart';
import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/group_sidebar.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';
import 'channel_epg_overlay.dart';
import 'channel_genre_chips_sliver.dart';
import 'channel_list_helpers.dart';
import 'channel_preview_mixin.dart';
import 'channel_resume_banner.dart';
import 'channel_search_bar_sliver.dart';
import 'channel_sliver.dart';
import 'channel_sort_menu.dart';
import '../../../../core/widgets/video_preview_widget.dart';

/// TV/desktop two-panel layout for the channel list.
///
/// Left: group sidebar. Right: video preview with EPG
/// overlay at the top, then app bar, search, resume
/// banner, and channel list below.
class ChannelTvLayout extends ConsumerStatefulWidget {
  const ChannelTvLayout({
    super.key,
    required this.state,
    required this.showSearchBar,
    required this.searchController,
    required this.duplicateCount,
    required this.onSearchChanged,
    required this.onSearchClose,
    required this.onSearchToggle,
    required this.onChannelTap,
    required this.onReorder,
    required this.onSortSelected,
    this.hiddenChannelCount = 0,
  });

  final ChannelListState state;
  final bool showSearchBar;
  final TextEditingController searchController;
  final int duplicateCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClose;
  final VoidCallback onSearchToggle;

  /// Number of individually hidden channels.
  ///
  /// Passed to [ChannelSortMenu] to show the
  /// "Show / Hide Hidden Channels" menu item (FE-TV-04).
  final int hiddenChannelCount;

  /// Called for fullscreen entry (double-tap or middle-click).
  final void Function(Channel) onChannelTap;
  final void Function(int, int) onReorder;
  final ValueChanged<ChannelSortAction> onSortSelected;

  @override
  ConsumerState<ChannelTvLayout> createState() => _ChannelTvLayoutState();
}

/// Duration of inactivity before the direct-dial HUD commits
/// the entered channel number and hides the overlay.
const Duration _kDialTimeout = Duration(seconds: 2);

class _ChannelTvLayoutState extends ConsumerState<ChannelTvLayout>
    with ChannelPreviewMixin {
  final _previewDebouncer = Debouncer(duration: CrispyAnimation.normal);

  // ── Sidebar collapse state ───────────────────────────────────
  bool _isGroupsCollapsed = false;

  // ── Direct-dial state ───────────────────────────────────────
  late final FocusNode _focusNode;
  String _dialDigits = '';
  Timer? _dialTimer;
  final ScrollController _channelScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Ensure the root keyboard listener can capture digit keys
    // even if no child has focus yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasPrimaryFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _previewDebouncer.dispose();
    _dialTimer?.cancel();
    _focusNode.dispose();
    _channelScrollController.dispose();
    super.dispose();
  }

  /// Restore keyboard focus to the root node after interactions
  /// that may steal it (navigation, dialogs, etc.).
  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasPrimaryFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  // ── Direct-dial helpers ─────────────────────────────────────

  /// Handles a numeric key press. Accumulates digits and
  /// restarts the 2-second commit timer.
  void _onDigitKey(String digit) {
    setState(() => _dialDigits += digit);
    _dialTimer?.cancel();
    _dialTimer = Timer(_kDialTimeout, _commitDial);
  }

  /// Called after [_kDialTimeout] of inactivity. Matches
  /// [_dialDigits] against [Channel.number] and selects the
  /// channel, or shows "Channel not found" if no match.
  void _commitDial() {
    final digits = _dialDigits;
    setState(() {
      _dialDigits = '';
      _dialTimer = null;
    });

    if (digits.isEmpty) return;
    final target = int.tryParse(digits);
    if (target == null) return;

    final channels = widget.state.filteredChannels;
    final match = channels.firstWhere(
      (c) => c.number == target,
      orElse: () => _sentinel,
    );

    if (identical(match, _sentinel)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Channel $digits not found'),
            duration: CrispyAnimation.snackBarDuration,
          ),
        );
      }
      return;
    }

    // Scroll to the matched channel and preview it.
    final idx = channels.indexOf(match);
    if (idx >= 0 && _channelScrollController.hasClients) {
      // Each channel row is approximately 72 px tall.
      const rowHeight = 72.0;
      final offset = (idx * rowHeight).clamp(
        0.0,
        _channelScrollController.position.maxScrollExtent,
      );
      _channelScrollController.animateTo(
        offset,
        duration: CrispyAnimation.normal,
        curve: CrispyAnimation.scrollCurve,
      );
    }
    previewChannel(match);
  }

  /// Sentinel instance used as a "not found" marker in
  /// [List.firstWhere] so that [Channel.==] never returns it
  /// as a real match.
  static final _sentinel = Channel(id: '__sentinel__', name: '', streamUrl: '');

  /// Returns the first channel in the filtered list.
  Channel? get _firstChannel {
    final chs = widget.state.filteredChannels;
    return chs.isNotEmpty ? chs.first : null;
  }

  /// Returns the currently-live EPG entry for the previewed
  /// channel (or the first channel if none is previewed).
  EpgEntry? _currentEpgEntry(EpgState epgState) {
    final ch = previewedChannel ?? _firstChannel;
    if (ch == null) return null;
    return epgState.getNowPlaying(ch.id);
  }

  /// Returns up to 2 upcoming EPG entries for the previewed
  /// channel (or the first channel if none is previewed).
  List<EpgEntry> _upcomingEpgEntries(EpgState epgState) {
    final ch = previewedChannel ?? _firstChannel;
    if (ch == null) return const [];
    return epgState.getUpcomingPrograms(ch.id, count: 2);
  }

  /// Debounced preview on D-pad focus change (300 ms).
  void _onChannelFocused(Channel ch) {
    _previewDebouncer.run(() {
      if (mounted) previewChannel(ch);
    });
  }

  /// Single tap → preview in the preview area.
  void _onChannelTapped(Channel ch) {
    previewChannel(ch);
  }

  /// Middle-click / explicit fullscreen request.
  void _onChannelFullscreen(Channel ch) {
    widget.onChannelTap(ch);
  }

  @override
  Widget build(BuildContext context) {
    // Sync previewed channel when returning from fullscreen
    // after the user zapped to a different channel.
    listenForChannelSync();

    // Restore keyboard focus when exiting fullscreen so
    // direct-dial digit keys work immediately.
    ref.listen(playerModeProvider.select((s) => s.mode), (prev, mode) {
      if (prev == PlayerMode.fullscreen && mode != PlayerMode.fullscreen) {
        _restoreFocus();
      }
    });

    final tt = Theme.of(context).textTheme;
    final epgState = ref.watch(epgProvider); // reactive — updates EPG overlay
    final displayChannel = previewedChannel ?? _firstChannel;

    final layout = Row(
      children: [
        FocusTraversalGroup(
          child: GroupSidebar(
            groups: widget.state.displayGroups,
            selectedGroup: widget.state.effectiveGroup,
            onGroupSelected:
                (g) => ref.read(channelListProvider.notifier).selectGroup(g),
            isCollapsed: _isGroupsCollapsed,
            onCollapseToggle:
                () => setState(() => _isGroupsCollapsed = !_isGroupsCollapsed),
            header: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
              child: Text(
                'Groups',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        Expanded(
          child: FocusTraversalGroup(
            child: Column(
              children: [
                // ── Top: Video Preview with EPG overlay ──
                // Flexible(flex: 2) gives ~40 % of column height.
                // ConstrainedBox inside ensures the preview never
                // collapses below 180 dp on very small windows.
                Flexible(
                  flex: 2,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 180.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPreviewWidget(onTap: expandPlayer),
                        if (displayChannel != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: expandPlayer,
                                child: ChannelEpgOverlay(
                                  channel: displayChannel,
                                  entry: _currentEpgEntry(epgState),
                                  upcomingPrograms: _upcomingEpgEntries(
                                    epgState,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // ── Bottom: App bar + search + channel list ──
                Expanded(
                  child: ClipRect(
                    child: CustomScrollView(
                      controller: _channelScrollController,
                      slivers: [
                        SliverAppBar(
                          floating: true,
                          snap: true,
                          title: Text('Live TV', style: tt.headlineSmall),
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.grid_view),
                              onPressed:
                                  () => context.push(AppRoutes.multiview),
                              tooltip: 'Multi-View',
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: () => context.push(AppRoutes.epg),
                              tooltip: 'TV Guide',
                            ),
                            IconButton(
                              icon: Icon(
                                widget.showSearchBar
                                    ? Icons.search_off
                                    : Icons.search,
                              ),
                              onPressed: widget.onSearchToggle,
                              tooltip: 'Search channels',
                            ),
                            if (widget.state.filteredChannels.isNotEmpty ||
                                (widget.showSearchBar &&
                                    widget.state.searchQuery.isNotEmpty))
                              ChannelSortMenu(
                                state: widget.state,
                                duplicateCount: widget.duplicateCount,
                                hiddenChannelCount: widget.hiddenChannelCount,
                                onSelected: widget.onSortSelected,
                              ),
                          ],
                        ),
                        ChannelSearchBarSliver(
                          visible: widget.showSearchBar,
                          controller: widget.searchController,
                          onChanged: widget.onSearchChanged,
                          onClose: widget.onSearchClose,
                        ),
                        // FE-TV-09: genre filter chips — hidden while
                        // search bar is open.
                        if (!widget.showSearchBar)
                          const ChannelGenreChipsSliver(),
                        ChannelResumeBanner(
                          state: widget.state,
                          onResume: widget.onChannelTap,
                        ),
                        // FE-TV-05: use EPG-aware list when searching so
                        // channels currently airing a matching program are
                        // also included.
                        Builder(
                          builder: (context) {
                            final displayChannels =
                                widget.showSearchBar &&
                                        widget.state.searchQuery.isNotEmpty
                                    ? ref.watch(epgAwareChannelListProvider)
                                    : widget.state.filteredChannels;
                            return channelStateSliver(
                                  isLoading: widget.state.isLoading,
                                  error: widget.state.error,
                                  isEmpty: displayChannels.isEmpty,
                                ) ??
                                ChannelSliver(
                                  channels: displayChannels,
                                  onTap: _onChannelTapped,
                                  onDoubleTap: _onChannelFullscreen,
                                  onFocus: _onChannelFocused,
                                  onMiddleClick: _onChannelFullscreen,
                                  onReorder: widget.onReorder,
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // Wrap in a keyboard listener for direct-dial channel number
    // entry. The FocusScope ensures the widget can capture key
    // events even when child widgets have focus.
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final label = event.logicalKey.keyLabel;
        // Accept digits 0–9 from number row and numpad.
        if (label.length == 1 &&
            label.codeUnits.first >= 48 &&
            label.codeUnits.first <= 57) {
          _onDigitKey(label);
        }
      },
      child: Stack(
        children: [
          layout,
          // ── Direct-dial HUD overlay ──────────────────────
          if (_dialDigits.isNotEmpty)
            Positioned(
              top: CrispySpacing.xl,
              right: CrispySpacing.xl,
              child: _DialHud(digits: _dialDigits),
            ),
        ],
      ),
    );
  }
}

/// Glassmorphic overlay displaying the accumulated dial digits.
///
/// Renders in the top-right corner during direct-dial input and
/// disappears automatically when [_commitDial] clears [digits].
class _DialHud extends StatelessWidget {
  const _DialHud({required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    final crispyColors = Theme.of(context).crispyColors;
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(CrispyRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: crispyColors.glassBlur,
          sigmaY: crispyColors.glassBlur,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.xl,
            vertical: CrispySpacing.lg,
          ),
          decoration: BoxDecoration(
            color: crispyColors.glassTint,
            borderRadius: BorderRadius.circular(CrispyRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Text(
            digits,
            style: tt.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
        ),
      ),
    );
  }
}
