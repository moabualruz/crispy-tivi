import 'dart:async';

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
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/alpha_jump_bar.dart';
import '../../../../core/widgets/app_bar_search_button.dart';
import '../../../../core/widgets/grid_focus_traveler.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../../core/widgets/screen_template.dart';
import '../providers/duplicate_detection_service.dart';
import '../providers/playlist_sync_service.dart';
import '../../domain/entities/channel.dart';
import '../providers/channel_paginated_providers.dart';
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
/// `the project UI/UX specification §3.4`.
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
        if ((prev?.isLoading ?? false) && !next.isLoading && !_autoResumeRan) {
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
    final groupsAsync = ref.watch(channelGroupsPaginatedProvider);
    final favsAsync = ref.watch(favoriteChannelsPaginatedProvider);
    final favCount = favsAsync.valueOrNull?.length ?? 0;
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
              const AppBarSearchButton(),
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
          else if (s.groupMode != ChannelGroupMode.byCategory)
            // TODO: Migrate playlist-group rows once paginated providers support
            // source-name grouping with correct per-source counts.
            _legacyGroupsSliver(s, favCount)
          else
            groupsAsync.when(
              data: (groups) {
                final visibleGroups =
                    groups
                        .where((group) => !s.hiddenGroups.contains(group.name))
                        .toList();
                final itemCount = visibleGroups.length + (favCount > 0 ? 1 : 0);

                return SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    if (favCount > 0 && i == 0) {
                      return ChannelGroupRow(
                        group: ChannelListState.favoritesGroup,
                        channelCount: favCount,
                        onTap:
                            () => ref
                                .read(channelListProvider.notifier)
                                .selectGroup(ChannelListState.favoritesGroup),
                      );
                    }

                    final group = visibleGroups[i - (favCount > 0 ? 1 : 0)];
                    return ChannelGroupRow(
                      group: group.name,
                      channelCount: group.count,
                      onTap:
                          () => ref
                              .read(channelListProvider.notifier)
                              .selectGroup(group.name),
                    );
                  }, childCount: itemCount),
                );
              },
              loading: () => const ChannelSkeletonSliver(),
              error:
                  (_, _) =>
                  // TODO: Replace this fallback once paginated group error
                  // handling gets a dedicated retry/empty state.
                  _legacyGroupsSliver(s, favCount),
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
    final currentSort = _paginatedSortKeyFor(s.sortMode);
    final usePaginatedGrid =
        viewMode == ChannelViewMode.grid &&
        currentSort != null &&
        !_showSearchBar &&
        s.searchQuery.isEmpty &&
        s.groupMode == ChannelGroupMode.byCategory &&
        s.effectiveGroup != ChannelListState.favoritesGroup &&
        s.hiddenChannelIds.isEmpty &&
        !(s.hideDuplicates && s.duplicateIds.isNotEmpty);

    // FE-TV-05: use EPG-aware list when search is active so channels
    // currently airing a matching program are also included.
    final displayChannels =
        _showSearchBar && s.searchQuery.isNotEmpty
            ? ref.watch(epgAwareChannelListProvider)
            : s.filteredChannels;

    final paginatedCountAsync =
        usePaginatedGrid
            ? ref.watch(channelCountPaginatedProvider(s.effectiveGroup))
            : null;
    final paginatedCount = usePaginatedGrid ? paginatedCountAsync : null;

    if (usePaginatedGrid) {
      // Preload stable ordering metadata for playback/zapping follow-up work.
      ref.watch(
        channelIdsPaginatedProvider((
          group: s.effectiveGroup,
          sort: currentSort,
        )),
      );
    }

    final names =
        usePaginatedGrid
            ? const <String>[]
            : displayChannels.map((c) => c.name).toList();
    final indexOffsets = AlphaJumpBar.computeIndexOffsets(names);
    final totalItemCount =
        usePaginatedGrid
            ? paginatedCount?.valueOrNull ?? 0
            : displayChannels.length;
    final paginatedGridStateSliver = paginatedCount?.when<Widget?>(
      data: (count) => count == 0 ? const ChannelEmptySliver() : null,
      loading: () => const ChannelSkeletonSliver(),
      error:
          (error, _) => ChannelErrorSliver(
            error: error.toString(),
            onRetry:
                () => ref.invalidate(
                  channelCountPaginatedProvider(s.effectiveGroup),
                ),
          ),
    );

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
                  const AppBarSearchButton(),
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
              switch (viewMode) {
                ChannelViewMode.grid =>
                  paginatedGridStateSliver ??
                      (usePaginatedGrid
                          ? _paginatedChannelGridSliver(
                            itemCount: paginatedCount?.valueOrNull ?? 0,
                            selectedGroup: s.effectiveGroup,
                            currentSort: currentSort,
                          )
                          : // TODO: Migrate search/favorites/hidden-channel and
                          // unsupported sort paths once paginated providers
                          // can reproduce those legacy screen filters safely.
                          (channelStateSliver(
                                isLoading: s.isLoading,
                                error: s.error,
                                isEmpty: displayChannels.isEmpty,
                                onRetry:
                                    () => ref.invalidate(channelListProvider),
                              ) ??
                              ChannelGridSliver(
                                channels: displayChannels,
                                onTap: _onChannelTap,
                              ))),
                ChannelViewMode.list || ChannelViewMode.compact =>
                  channelStateSliver(
                        isLoading: s.isLoading,
                        error: s.error,
                        isEmpty: displayChannels.isEmpty,
                        onRetry: () => ref.invalidate(channelListProvider),
                      ) ??
                      _channelSliver(displayChannels),
              },
            ],
          ),
        ),
        // Alpha jump bar — right edge, proportional scrolling.
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: AlphaJumpBarAdapter(
            scrollController: _channelScrollController,
            indexOffsets: indexOffsets,
            totalItemCount: totalItemCount,
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

  SliverList _legacyGroupsSliver(ChannelListState s, int favCount) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((_, i) {
        final g = s.displayGroups[i];
        return ChannelGroupRow(
          group: g,
          channelCount:
              g == ChannelListState.favoritesGroup
                  ? favCount
                  : s.groupCounts[g] ?? 0,
          onTap: () => ref.read(channelListProvider.notifier).selectGroup(g),
        );
      }, childCount: s.displayGroups.length),
    );
  }

  Widget _paginatedChannelGridSliver({
    required int itemCount,
    required String? selectedGroup,
    required String currentSort,
  }) {
    ref.watch(epgProvider.select((s) => s.entries));
    final epgState = ref.read(epgProvider);
    final playingUrl = ref.watch(
      playbackSessionProvider.select((s) => s.streamUrl),
    );

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final crossCount =
            width < 360
                ? 2
                : width < 600
                ? 3
                : width < 900
                ? 4
                : 5;
        const itemHeight = 110.0;

        return FocusTraversalGroup(
          policy: GridFocusTravelerPolicy(crossAxisCount: crossCount),
          child: SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.md,
              vertical: CrispySpacing.sm,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisExtent: itemHeight,
                crossAxisSpacing: CrispySpacing.sm,
                mainAxisSpacing: CrispySpacing.sm,
              ),
              delegate: SliverChildBuilderDelegate((ctx, index) {
                final page = index ~/ kChannelPageSize;
                final indexInPage = index % kChannelPageSize;
                final pageRequest = ChannelPageRequest(
                  group: selectedGroup,
                  page: page,
                  sort: currentSort,
                );

                return Consumer(
                  builder: (context, ref, _) {
                    final pageAsync = ref.watch(
                      channelPagePaginatedProvider(pageRequest),
                    );

                    return pageAsync.when(
                      loading: () => const ChannelCardSkeleton(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (channels) {
                        if (indexInPage >= channels.length) {
                          return const SizedBox.shrink();
                        }

                        final channel = channels[indexInPage];
                        final nowPlaying = epgState.getNowPlaying(channel.id);

                        return ChannelCard(
                          channel: channel,
                          currentProgram: nowPlaying?.title,
                          isPlaying: channel.streamUrl == playingUrl,
                          autofocus: index == 0,
                          onTap:
                              () => _onChannelTap(
                                channel,
                                channelList: channels,
                                channelIndex: indexInPage,
                              ),
                        );
                      },
                    );
                  },
                );
              }, childCount: itemCount),
            ),
          ),
        );
      },
    );
  }

  String? _paginatedSortKeyFor(ChannelSortMode mode) {
    switch (mode) {
      case ChannelSortMode.defaultOrder:
        return 'number_asc';
      case ChannelSortMode.byName:
        return 'name_asc';
      case ChannelSortMode.byDateAdded:
        return 'added_desc';
      case ChannelSortMode.byWatchTime:
      case ChannelSortMode.manual:
        return null;
    }
  }

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
      await ref.read(channelListProvider.notifier).selectGroup(lastGroupName);
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
    unawaited(ref.read(epgProvider.notifier).fetchEpgWindow(start, end));
  }

  /// Ensures a minimal EPG window is loaded for the current day so that
  /// EPG-aware search (FE-TV-05) can return program-title matches immediately
  /// when the user opens the search bar — even on first launch where EPG data
  /// may not have been fetched yet.
  ///
  /// Safe to call multiple times — no-ops when entries are already present.
  void _ensureMinimalEpg() {
    if (!mounted) return;
    final epgState = ref.read(epgProvider);
    if (epgState.entries.isNotEmpty) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(hours: 4));
    unawaited(ref.read(epgProvider.notifier).fetchEpgWindow(start, end));
  }

  // -- Callbacks --

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        // Ensure EPG data is available so EPG-aware search (FE-TV-05) can
        // include program-title matches from the first keystroke. Channel name
        // matches from filteredChannels are always immediate; EPG matches
        // appear once the fetch completes and the provider rebuilds.
        _ensureMinimalEpg();
      } else {
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

  void _onChannelTap(
    Channel ch, {
    List<Channel>? channelList,
    int? channelIndex,
  }) {
    final chs = channelList ?? ref.read(channelListProvider).filteredChannels;
    final idx = channelIndex ?? chs.indexWhere((c) => c.id == ch.id);
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
          sourceId: ch.sourceId,
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
