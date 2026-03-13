import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/utils/debounce_throttle.dart';
import '../../../../core/utils/device_form_factor.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/widgets/alpha_jump_bar.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../application/duplicate_detection_service.dart';
import '../../application/playlist_sync_service.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_providers.dart';
import '../../../../core/widgets/source_selector_bar.dart';
import '../widgets/channel_genre_chips_sliver.dart';
import '../widgets/channel_grid_sliver.dart';
import '../widgets/channel_group_row.dart';
import '../widgets/channel_list_helpers.dart';
import '../widgets/channel_recent_strip.dart';
import '../widgets/channel_resume_banner.dart';
import '../widgets/channel_search_bar_sliver.dart';
import '../widgets/channel_sync_utils.dart';
import '../widgets/channel_sliver.dart';
import '../widgets/channel_sort_menu.dart';
import '../../../../core/utils/focus_restoration_service.dart';
import '../widgets/channel_tv_layout.dart';

/// Live TV channel list screen per
/// `.ai/docs/project-specs/ui_ux_spec.md §3.4`.
class ChannelListScreen extends ConsumerStatefulWidget {
  const ChannelListScreen({super.key});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  final _searchController = TextEditingController();
  final _searchDebouncer = Debouncer(duration: CrispyAnimation.normal);
  final _channelScrollController = ScrollController();
  static const _routePath = 'channel_list';
  bool _showSearchBar = false;
  String? _lastKnownRoute;
  bool _autoResumeRan = false;
  bool _focusRestored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(channelListProvider, (prev, next) {
        if (prev?.isLoading == true && !next.isLoading && !_autoResumeRan) {
          _maybeAutoResume();
        }
      });
      syncHiddenGroups(ref);
      syncLastWatched(ref);
      loadSavedSortMode(ref, () => mounted);
      _maybeAutoResume();
      _loadEpgWindow();
    });
  }

  @override
  void deactivate() {
    saveFocusKey(ref, _routePath);
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_focusRestored) {
      _focusRestored = true;
      restoreFocus(ref, _routePath, context);
    }
    // GoRouterState is absent in golden/unit tests that use
    // plain MaterialApp — guard with try/catch.
    String? route;
    try {
      route = GoRouterState.of(context).uri.path;
    } catch (_) {
      return;
    }
    final wasOnTv = _lastKnownRoute == AppRoutes.tv;
    _lastKnownRoute = route;
    // Only re-trigger on return navigation (not first mount —
    // initState handles that).
    if (route == AppRoutes.tv && !wasOnTv && _autoResumeRan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoResume());
    }
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    _channelScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingGroups = ref.watch(
      channelListProvider.select((s) => s.showingGroupsView),
    );
    return Scaffold(
      key: TestKeys.channelListScreen,
      body: ScreenTemplate(
        focusRestorationKey: 'channel_list',
        compactBody: PopScope(
          canPop: showingGroups,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              ref.read(channelListProvider.notifier).setShowGroupsView(true);
            }
          },
          child: Consumer(
            builder: (context, ref, _) {
              final s = ref.watch(channelListProvider);
              return s.showingGroupsView && s.displayGroups.isNotEmpty
                  ? _groupsView(s)
                  : _channelView(s);
            },
          ),
        ),
        largeBody: Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(channelListProvider);
            final hiddenCount = ref.watch(
              settingsNotifierProvider.select(
                (a) => a.value?.hiddenChannelIds.length ?? 0,
              ),
            );
            return ChannelTvLayout(
              state: s,
              showSearchBar: _showSearchBar,
              searchController: _searchController,
              duplicateCount: ref.watch(duplicateCountProvider),
              hiddenChannelCount: hiddenCount,
              onSearchChanged: _onSearchChanged,
              onSearchClose: _toggleSearch,
              onSearchToggle: _toggleSearch,
              onChannelTap: _onChannelTap,
              onReorder: _onReorder,
              onSortSelected: _onSortSelected,
            );
          },
        ),
      ),
    );
  }

  // -- Mobile layouts --

  Widget _groupsView(ChannelListState s) {
    final tt = Theme.of(context).textTheme;
    return _wrapRefresh(
      CustomScrollView(
        key: const PageStorageKey('channel_groups'),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text('Live TV', style: tt.headlineSmall),
            actions: [
              IconButton(
                icon: const Icon(Icons.grid_view),
                onPressed: () => context.push(AppRoutes.multiview),
                tooltip: context.l10n.iptvMultiView,
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () => context.push(AppRoutes.epg),
                tooltip: context.l10n.iptvTvGuide,
              ),
              _searchBtn(),
              IconButton(
                key: TestKeys.channelListFavoriteButton,
                icon: const Icon(Icons.favorite_border_rounded),
                tooltip: context.l10n.commonFavorites,
                onPressed: () => context.push(AppRoutes.favorites),
              ),
            ],
          ),
          ..._searchAndResume(s),
          if (s.isLoading)
            const ChannelSkeletonSliver()
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final g = s.displayGroups[i];
                return ChannelGroupRow(
                  group: g,
                  channelCount:
                      g == ChannelListState.favoritesGroup
                          ? s.favoriteCount
                          : s.groupCounts[g] ?? 0,
                  onTap:
                      () =>
                          ref.read(channelListProvider.notifier).selectGroup(g),
                );
              }, childCount: s.displayGroups.length),
            ),
        ],
      ),
    );
  }

  Widget _channelView(ChannelListState s) {
    final tt = Theme.of(context).textTheme;
    final viewMode = ref.watch(
      settingsNotifierProvider.select(
        (async) => async.value?.channelViewMode ?? ChannelViewMode.list,
      ),
    );
    final hiddenCount = ref.watch(
      settingsNotifierProvider.select(
        (a) => a.value?.hiddenChannelIds.length ?? 0,
      ),
    );
    final isFiltered = _showSearchBar || s.effectiveGroup != null;

    // FE-TV-05: use EPG-aware list when search is active so channels
    // currently airing a matching program are also included.
    final displayChannels =
        _showSearchBar && s.searchQuery.isNotEmpty
            ? ref.watch(epgAwareChannelListProvider)
            : s.filteredChannels;

    final names = displayChannels.map((c) => c.name).toList();
    final indexOffsets = AlphaJumpBar.computeIndexOffsets(names);

    return Stack(
      children: [
        _wrapRefresh(
          CustomScrollView(
            key: const PageStorageKey('channel_list'),
            controller: _channelScrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                leading:
                    s.displayGroups.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed:
                              () => ref
                                  .read(channelListProvider.notifier)
                                  .setShowGroupsView(true),
                          tooltip: context.l10n.iptvBackToGroups,
                        )
                        : null,
                title: Text(
                  s.effectiveGroup ?? 'All Channels',
                  style: tt.headlineSmall,
                ),
                actions: [
                  _viewModeBtn(viewMode),
                  _searchBtn(),
                  if (displayChannels.isNotEmpty)
                    ChannelSortMenu(
                      state: s,
                      duplicateCount: ref.watch(duplicateCountProvider),
                      hiddenChannelCount: hiddenCount,
                      onSelected: _onSortSelected,
                    ),
                ],
              ),
              ..._searchAndResume(s),
              // Source filter bar (hidden when ≤1 source).
              const SliverToBoxAdapter(child: SourceSelectorBar()),
              // FE-TV-09: genre filter chips — hidden while search bar is open.
              if (!_showSearchBar) const ChannelGenreChipsSliver(),
              // Recent channels strip — only in default (unfiltered) mode.
              if (!isFiltered) RecentChannelsStrip(onChannelTap: _onChannelTap),
              channelStateSliver(
                    isLoading: s.isLoading,
                    error: s.error,
                    isEmpty: displayChannels.isEmpty,
                    onRetry: () => ref.invalidate(channelListProvider),
                  ) ??
                  switch (viewMode) {
                    ChannelViewMode.grid => ChannelGridSliver(
                      channels: displayChannels,
                      onTap: _onChannelTap,
                    ),
                    ChannelViewMode.list ||
                    ChannelViewMode.compact => _channelSliver(displayChannels),
                  },
            ],
          ),
        ),
        // Alpha jump bar — right edge, proportional scrolling.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _AlphaJumpBarAdapter(
            scrollController: _channelScrollController,
            indexOffsets: indexOffsets,
            totalItemCount: displayChannels.length,
          ),
        ),
      ],
    );
  }

  // -- Shared helpers --

  List<Widget> _searchAndResume(ChannelListState s) => [
    ChannelSearchBarSliver(
      visible: _showSearchBar,
      controller: _searchController,
      onChanged: _onSearchChanged,
      onClose: _toggleSearch,
    ),
    ChannelResumeBanner(state: s, onResume: _onChannelTap),
  ];

  Widget _channelSliver(List<Channel> chs) =>
      ChannelSliver(channels: chs, onTap: _onChannelTap, onReorder: _onReorder);

  Widget _searchBtn() => IconButton(
    icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
    onPressed: _toggleSearch,
    tooltip: context.l10n.iptvSearchChannels,
  );

  /// Cycles through list → grid → compact view modes.
  Widget _viewModeBtn(ChannelViewMode current) {
    final icon = switch (current) {
      ChannelViewMode.list => Icons.view_list,
      ChannelViewMode.grid => Icons.grid_view_rounded,
      ChannelViewMode.compact => Icons.density_small,
    };
    return IconButton(
      icon: Icon(icon),
      tooltip: current.next.label,
      onPressed: () {
        ref
            .read(settingsNotifierProvider.notifier)
            .setChannelViewMode(current.next);
      },
    );
  }

  /// Wraps [child] in [RefreshIndicator] on mobile/tablet.
  Widget _wrapRefresh(Widget child) {
    if (!DeviceFormFactorService.current.isMobile) return child;
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(playlistSyncServiceProvider).syncAll();
      },
      child: child,
    );
  }

  // -- Auto-resume & EPG preload --

  Future<void> _maybeAutoResume() async {
    if (!mounted) return;
    final settings = ref.read(settingsNotifierProvider).value;
    if (settings == null) return;
    if (!settings.autoResumeChannel) {
      _autoResumeRan = true;
      return;
    }

    final channelState = ref.read(channelListProvider);
    if (channelState.isLoading) {
      // Channels not loaded yet, don't mark as ran, let the listener catch it
      return;
    }

    _autoResumeRan = true;

    final notifier = ref.read(settingsNotifierProvider.notifier);
    final lastChannelId = await notifier.getLastChannelId();
    final lastGroupName = await notifier.getLastGroupName();
    if (!mounted) return;

    if (lastChannelId == null) return;

    // Select the last group first.
    if (lastGroupName != null) {
      ref.read(channelListProvider.notifier).selectGroup(lastGroupName);
      // Wait one frame for state to propagate.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }

    // Find the channel in the filtered list.
    final chs = ref.read(channelListProvider).filteredChannels;
    final ch = chs.firstWhereOrNull((c) => c.id == lastChannelId);
    if (ch != null) {
      _onChannelTap(ch);
    } else {
      // Exit fullscreen if channel not found to avoid stuck state.
      final mode = ref.read(playerModeProvider);
      if (mode.mode == PlayerMode.fullscreen) {
        ref.read(playerModeProvider.notifier).setIdle();
      }
    }
  }

  Future<void> _loadEpgWindow() async {
    if (!mounted) return;
    final epgState = ref.read(epgProvider);
    if (epgState.entries.isNotEmpty) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(hours: 4));
    ref.read(epgProvider.notifier).fetchEpgWindow(start, end);
  }

  // -- Callbacks --

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchDebouncer.cancel();
        _searchController.clear();
        ref.read(channelListProvider.notifier).search('');
      }
    });
  }

  void _onSearchChanged(String q) {
    _searchDebouncer.run(
      () => ref.read(channelListProvider.notifier).search(q),
    );
  }

  void _onChannelTap(Channel ch) {
    final chs = ref.read(channelListProvider).filteredChannels;
    final idx = chs.indexWhere((c) => c.id == ch.id);
    ref
        .read(playbackSessionProvider.notifier)
        .startPlayback(
          streamUrl: ch.streamUrl,
          isLive: true,
          channelName: ch.name,
          channelLogoUrl: ch.logoUrl,
          channelList: chs,
          channelIndex: idx >= 0 ? idx : 0,
          headers: ch.userAgent != null ? {'User-Agent': ch.userAgent!} : null,
        );
    // Navigate to fullscreen player immediately per requirements.
    if (context.mounted) {
      if (kDebugMode) {
        debugPrint('[Channel] Entering fullscreen mode.');
      }
      ref
          .read(playerModeProvider.notifier)
          .enterFullscreen(hostRoute: AppRoutes.tv);
      ref.read(playerServiceProvider).forceStateEmit();
    }

    // Persist for auto-resume.
    final groupName = ref.read(channelListProvider).effectiveGroup;
    ref
        .read(settingsNotifierProvider.notifier)
        .setLastChannel(ch.id, groupName);
  }

  void _onReorder(int o, int n) =>
      ref.read(channelListProvider.notifier).reorderChannel(o, n);

  void _onSortSelected(ChannelSortAction action) {
    final n = ref.read(channelListProvider.notifier);
    switch (action) {
      case ChannelSortAction.sortDefault:
        n.setSortMode(ChannelSortMode.defaultOrder);
        saveSortMode(ref, ChannelSortMode.defaultOrder);
      case ChannelSortAction.sortName:
        n.setSortMode(ChannelSortMode.byName);
        saveSortMode(ref, ChannelSortMode.byName);
      case ChannelSortAction.sortDateAdded:
        n.setSortMode(ChannelSortMode.byDateAdded);
        saveSortMode(ref, ChannelSortMode.byDateAdded);
      case ChannelSortAction.sortWatchTime:
        syncLastWatched(ref);
        n.setSortMode(ChannelSortMode.byWatchTime);
        saveSortMode(ref, ChannelSortMode.byWatchTime);
      case ChannelSortAction.sortManual:
        n.setSortMode(ChannelSortMode.manual);
        saveSortMode(ref, ChannelSortMode.manual);
      case ChannelSortAction.done:
        n.setReorderMode(false);
      case ChannelSortAction.reset:
        showResetOrderDialog(context, ref);
      case ChannelSortAction.toggleDuplicates:
        final s = ref.read(channelListProvider);
        n.setHideDuplicates(!s.hideDuplicates);
      case ChannelSortAction.groupCategory:
        n.setGroupMode(ChannelGroupMode.byCategory);
      case ChannelSortAction.groupPlaylist:
        n.setGroupMode(ChannelGroupMode.byPlaylist);
      // FE-TV-04: toggle hidden channel visibility.
      case ChannelSortAction.toggleShowHidden:
        final s = ref.read(channelListProvider);
        n.setShowHiddenChannels(!s.showHiddenChannels);
    }
  }
}

/// Adapter that converts index-based offsets to pixel offsets
/// once the scroll controller's max extent is known.
class _AlphaJumpBarAdapter extends StatefulWidget {
  final ScrollController scrollController;
  final Map<String, double> indexOffsets;
  final int totalItemCount;

  const _AlphaJumpBarAdapter({
    required this.scrollController,
    required this.indexOffsets,
    required this.totalItemCount,
  });

  @override
  State<_AlphaJumpBarAdapter> createState() => _AlphaJumpBarAdapterState();
}

class _AlphaJumpBarAdapterState extends State<_AlphaJumpBarAdapter> {
  Map<String, double> _pixelOffsets = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_AlphaJumpBarAdapter old) {
    super.didUpdateWidget(old);
    if (old.indexOffsets != widget.indexOffsets ||
        old.totalItemCount != widget.totalItemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  bool _extentReady = false;

  void _onScroll() {
    if (!_extentReady && widget.scrollController.hasClients) {
      _update();
    }
  }

  void _update() {
    if (!widget.scrollController.hasClients) return;
    final maxExtent = widget.scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    _extentReady = true;
    final scaled = AlphaJumpBar.scaleOffsets(
      widget.indexOffsets,
      maxExtent,
      widget.totalItemCount,
    );
    if (mounted) setState(() => _pixelOffsets = scaled);
  }

  @override
  Widget build(BuildContext context) {
    return AlphaJumpBar(
      controller: widget.scrollController,
      sectionOffsets: _pixelOffsets,
      totalItemCount: widget.totalItemCount,
    );
  }
}
