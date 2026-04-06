import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/entities/media_item.dart';
import '../../../../core/domain/entities/media_type.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/widgets/tv_color_button_legend.dart';
import '../../../epg/presentation/providers/epg_providers.dart';
import '../../../iptv/domain/entities/epg_entry.dart';
import '../../domain/entities/search_history_entry.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../vod/domain/entities/vod_item.dart';
import '../../../vod/presentation/providers/vod_providers.dart';
import '../../../voice_search/presentation/widgets/voice_search_button.dart';
import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../domain/constants/search_source_key.dart';
import '../providers/search_providers.dart';
import '../widgets/search_body.dart';
import '../widgets/search_filter_sheet.dart';
// TvSearchPanel removed — desktop/TV uses same SearchBody as compact.

// ── UI dimension constants ────────────────────────────────────────────────────

/// Diameter of the active-filter indicator dot on the filter icon.
const double _kFilterDotSize = 8.0;

/// Inset of the active-filter dot from the top-right corner of the icon button.
const double _kFilterDotInset = 8.0;

/// Duration for brief informational snackbars (e.g. favorite toggled).
const Duration _kSnackBarShort = CrispyAnimation.snackBarDuration;

/// Enhanced search screen with filtering, grouped results, and history.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Defer provider modifications to avoid "modified during build" errors.
    // Clearing stale state and populating deep-link queries both happen
    // in a single post-frame callback after the widget tree is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Clear stale search state from previous session, cancel dangling
      // timers, and bump generation to discard any in-flight results.
      ref.read(searchControllerProvider.notifier).resetForNewSession();

      // S-010: pre-populate from the deep-link ?q= query parameter.
      // GoRouterState.of throws when no GoRouter is in the tree (e.g. tests
      // using plain MaterialApp). Guard with try-catch to stay resilient.
      try {
        final deepLinkQuery =
            GoRouterState.of(context).uri.queryParameters['q'] ?? '';
        if (deepLinkQuery.isNotEmpty) {
          _searchController.text = deepLinkQuery;
          ref.read(searchControllerProvider.notifier).search(deepLinkQuery);
        }
      } on Object catch (_) {
        // No GoRouter ancestor — deep-link query unavailable.
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // S-18: cancellation is handled inside SearchNotifier.search()
    // via Timer debounce — a new call cancels the pending timer.
    ref.read(searchControllerProvider.notifier).search(query);
  }

  /// S-012: Enter key submits immediately, bypassing the debounce timer.
  void _onSearchSubmitted(String query) {
    ref.read(searchControllerProvider.notifier).search(query);
  }

  /// S-012: Escape clears the field when it has content, otherwise pops.
  void _onEscape() {
    if (_searchController.text.isNotEmpty) {
      _clearSearch();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchControllerProvider.notifier).clearSearch();
    _focusNode.requestFocus();
  }

  void _showFilterSheet() {
    final state = ref.read(searchControllerProvider);
    showSearchFilterSheet(
      context: context,
      filter: state.filter,
      categories: state.availableCategories,
      onApply: (filter) {
        ref.read(searchControllerProvider.notifier).updateFilter(filter);
      },
      onClear: () {
        ref.read(searchControllerProvider.notifier).clearFilters();
      },
    );
  }

  void _onVoiceResult(String text) {
    if (text.isNotEmpty) {
      _searchController.text = text;
      ref.read(searchControllerProvider.notifier).search(text);
    }
  }

  void _onVoicePartialResult(String text) {
    // Update text field with partial results for visual feedback.
    if (text.isNotEmpty) {
      _searchController.text = text;
    }
  }

  void _onItemFavorite(MediaItem item) {
    final channel = item.metadata['channel'];
    if (channel is Channel) {
      ref.read(favoritesControllerProvider.notifier).toggleFavorite(channel);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toggled favorite: ${item.name}'),
          duration: _kSnackBarShort,
        ),
      );
    }
  }

  void _onItemDetails(MediaItem item) {
    final vodItem = item.metadata['vodItem'];
    if (vodItem is VodItem) {
      context.push(AppRoutes.vodDetails, extra: {'item': vodItem});
    }
  }

  /// FE-SR-09: navigate to the EPG timeline, select the matched
  /// channel and scroll to the programme's airing time slot.
  void _navigateToEpgEntry(MediaItem item) {
    final entry = item.metadata['epgEntry'];
    final channel = item.metadata['channel'];
    if (entry == null) {
      // Fall back to EPG screen root when entry is missing.
      context.push(AppRoutes.epg);
      return;
    }

    // Pre-select channel + focus time in the EPG provider so the
    // screen auto-scrolls to the right position on mount.
    final epgNotifier = ref.read(epgProvider.notifier);
    if (channel != null) {
      epgNotifier.selectChannel((channel as dynamic).id as String);
    }
    epgNotifier.setFocusedTime((entry as dynamic).startTime as DateTime);
    if (entry != null) {
      epgNotifier.selectEntry(entry as EpgEntry?);
    }
    context.push(AppRoutes.epg);
  }

  Future<void> _onItemTap(MediaItem item) async {
    final sourceKey = item.metadata['source'] as String? ?? '';

    // FE-SR-09: EPG results navigate to the timeline, not the player.
    if (sourceKey == SearchSourceKey.iptvEpg) {
      _navigateToEpgEntry(item);
      return;
    }

    // IPTV / Local VOD — play directly
    if (sourceKey.startsWith(SearchSourceKey.iptv)) {
      ref
          .read(playbackSessionProvider.notifier)
          .startPlayback(
            streamUrl: item.streamUrl ?? '',
            channelName: item.name,
            channelLogoUrl: item.logoUrl,
            isLive: item.type == MediaType.channel,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // S-012: Escape key shortcut — handled at the scaffold level so it fires
    // regardless of which child widget holds focus.
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _onEscape();
              return null;
            },
          ),
        },
        child: Scaffold(
          key: TestKeys.searchScreen,
          appBar: AppBar(
            title: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              style: textTheme.titleMedium,
              decoration: InputDecoration(
                // S-009: labelText removed — hintText alone guides the user.
                hintText: context.l10n.searchHint,
                border: InputBorder.none,
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                suffixIcon:
                    state.query.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                        )
                        : null,
              ),
              onChanged: _onSearchChanged,
              // S-012: Enter key triggers an immediate search.
              onSubmitted: _onSearchSubmitted,
            ),
            actions: [
              // Voice search button.
              VoiceSearchButton(
                onResult: _onVoiceResult,
                onPartialResult: _onVoicePartialResult,
              ),
              // Filter button with badge if filters are active.
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: _showFilterSheet,
                    tooltip: 'Advanced filters',
                  ),
                  if (state.filter.hasActiveFilters)
                    Positioned(
                      right: _kFilterDotInset,
                      top: _kFilterDotInset,
                      child: Container(
                        width: _kFilterDotSize,
                        height: _kFilterDotSize,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // S-07: body content extracted to SearchBody
          body: ScreenTemplate(
            focusRestorationKey: 'search',
            colorButtonMap: {
              TvColorButton.red: ColorButtonAction(
                label: 'Clear',
                onPressed: _clearSearch,
              ),
              TvColorButton.yellow: ColorButtonAction(
                label: 'Filter',
                onPressed: _showFilterSheet,
              ),
            },
            compactBody: SearchBody(
              state: state,
              isContentLoaded:
                  ref.watch(
                    channelListProvider.select((s) => s.channels.isNotEmpty),
                  ) ||
                  ref.watch(vodProvider.select((s) => s.items.isNotEmpty)),
              onToggleContentType: (type) {
                ref
                    .read(searchControllerProvider.notifier)
                    .toggleContentType(type);
              },
              onClearFilters: () {
                ref.read(searchControllerProvider.notifier).clearFilters();
              },
              onSelectRecent: (entry) {
                _searchController.text = (entry as SearchHistoryEntry).query;
                ref
                    .read(searchControllerProvider.notifier)
                    .selectRecentSearch(entry);
              },
              onRemoveRecent: (id) {
                ref
                    .read(searchControllerProvider.notifier)
                    .removeFromHistory(id);
              },
              onClearHistory: () {
                ref.read(searchControllerProvider.notifier).clearHistory();
              },
              onItemTap: _onItemTap,
              onItemFavorite: _onItemFavorite,
              onItemDetails: _onItemDetails,
            ),
            // Desktop/TV: same layout as compact — physical keyboards
            // exist on desktops, and TVs use OS-level on-screen keyboard.
            // The on-screen QWERTY panel was redundant and hid the
            // content type/source filter chips.
            largeBody: SearchBody(
              state: state,
              isContentLoaded:
                  ref.watch(
                    channelListProvider.select((s) => s.channels.isNotEmpty),
                  ) ||
                  ref.watch(vodProvider.select((s) => s.items.isNotEmpty)),
              onToggleContentType: (type) {
                ref
                    .read(searchControllerProvider.notifier)
                    .toggleContentType(type);
              },
              onClearFilters: () {
                ref.read(searchControllerProvider.notifier).clearFilters();
              },
              onSelectRecent: (entry) {
                _searchController.text = (entry as SearchHistoryEntry).query;
                ref
                    .read(searchControllerProvider.notifier)
                    .selectRecentSearch(entry);
              },
              onRemoveRecent: (id) {
                ref
                    .read(searchControllerProvider.notifier)
                    .removeFromHistory(id);
              },
              onClearHistory: () {
                ref.read(searchControllerProvider.notifier).clearHistory();
              },
              onItemTap: _onItemTap,
              onItemFavorite: _onItemFavorite,
              onItemDetails: _onItemDetails,
            ),
          ),
        ),
      ),
    );
  }
}
