import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/widgets/error_state_widget.dart';
import 'package:crispy_tivi/core/widgets/loading_state_widget.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';

/// Default grid delegate for media server library poster grids.
///
/// Shared between [PaginatedMediaLibraryScreen] and Jellyfin/Emby home
/// screens to ensure a consistent 2:3 portrait poster layout.
const SliverGridDelegateWithMaxCrossAxisExtent kPosterGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 200,
      childAspectRatio: 2 / 3,
      crossAxisSpacing: CrispySpacing.md,
      mainAxisSpacing: CrispySpacing.md,
    );

/// A generic paginated grid screen for media server library browsing.
///
/// Handles all shared pagination logic — scroll detection, load-more,
/// error state, and the grid layout. Callers provide the initial data
/// via [initialDataProvider], a [loadMoreItems] callback for subsequent
/// pages, and an [itemBuilder] for server-specific card rendering.
///
/// All three media server screens (Emby, Jellyfin, Plex) delegate their
/// shared logic here and remain thin wrappers.
class PaginatedMediaLibraryScreen extends ConsumerStatefulWidget {
  const PaginatedMediaLibraryScreen({
    super.key,
    required this.title,
    required this.initialDataProvider,
    required this.loadMoreItems,
    required this.itemBuilder,
    this.titleWidget,
    this.childAspectRatio = 2 / 3,
    this.maxCrossAxisExtent = 200,
    this.appBarActions = const [],
    // PX-FE-08: optional header widget inserted above the grid.
    this.headerSliver,
  });

  /// AppBar title string.
  final String title;

  /// Optional custom title widget for the AppBar.
  ///
  /// When set, this is used instead of [title] in the AppBar. Useful for
  /// breadcrumb navigation (PX-FE-BREAD) or other rich title layouts.
  final Widget? titleWidget;

  /// Riverpod provider that supplies the first page of results.
  final FutureProvider<PaginatedResult<MediaItem>> initialDataProvider;

  /// Called to fetch the next page; receives the current item count as
  /// [startIndex]. Must return only the newly loaded items — the widget
  /// appends them to the existing list internally.
  final Future<List<MediaItem>> Function(int startIndex) loadMoreItems;

  /// Builds a single grid cell for a [MediaItem].
  final Widget Function(BuildContext context, MediaItem item) itemBuilder;

  /// Aspect ratio for each grid cell.
  ///
  /// Defaults to `2/3` (portrait poster). Pass a different value
  /// (e.g. [PlexCardRatios.itemPoster]) to share a named constant.
  final double childAspectRatio;

  /// Maximum cross-axis extent for each grid cell in logical pixels.
  ///
  /// Controls how many columns fit at a given viewport width.
  /// Defaults to `200` (portrait poster mode). Use a larger value
  /// (e.g. `360`) for landscape thumbnail mode.
  final double maxCrossAxisExtent;

  /// Optional action widgets shown in the AppBar (e.g. grid mode toggle).
  final List<Widget> appBarActions;

  /// [PX-FE-08] Optional widget rendered above the item grid (e.g. a
  /// filter/sort toolbar). Wrapped in a [SliverToBoxAdapter] internally.
  /// Pass null (the default) to show the grid with no header.
  final Widget? headerSliver;

  @override
  ConsumerState<PaginatedMediaLibraryScreen> createState() =>
      _PaginatedMediaLibraryScreenState();
}

class _PaginatedMediaLibraryScreenState
    extends ConsumerState<PaginatedMediaLibraryScreen> {
  final _scrollController = ScrollController();
  final List<MediaItem> _items = [];
  int _totalCount = 0;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;

  bool get _hasMore => _items.length < _totalCount;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newItems = await widget.loadMoreItems(_items.length);
      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _isLoadingMore = false;
          _hasError = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _retryLoadMore() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final initialData = ref.watch(widget.initialDataProvider);

    return Scaffold(
      key: TestKeys.paginatedLibraryScreen,
      appBar: AppBar(
        // PX-FE-BREAD: use titleWidget when provided (breadcrumb titles).
        title: widget.titleWidget ?? Text(widget.title),
        actions: widget.appBarActions,
      ),
      body: initialData.when(
        data: (result) {
          // Seed local state on first load.
          if (_items.isEmpty && result.items.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _items.addAll(result.items);
                  _totalCount = result.totalCount;
                });
              }
            });
            // Render initial items immediately while setState propagates.
            return _buildGrid(result.items);
          }

          if (_items.isEmpty && result.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: CrispySpacing.sm),
                  Text(
                    'No items found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildGrid(_items);
        },
        loading: () => const LoadingStateWidget(),
        error: (e, _) => ErrorStateWidget(message: 'Error: $e'),
      ),
    );
  }

  Widget _buildGrid(List<MediaItem> items) {
    // PX-FE-08: when a headerSliver is provided, use a CustomScrollView
    // so the toolbar scrolls away naturally with the grid content.
    if (widget.headerSliver != null) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: widget.headerSliver!),
          SliverPadding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: widget.maxCrossAxisExtent,
                childAspectRatio: widget.childAspectRatio,
                crossAxisSpacing: CrispySpacing.md,
                mainAxisSpacing: CrispySpacing.md,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => widget.itemBuilder(context, items[index]),
                childCount: items.length,
              ),
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(CrispySpacing.md),
                child: LoadingStateWidget(),
              ),
            ),
          if (_hasError && _errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(CrispySpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _retryLoadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(CrispySpacing.md),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: widget.maxCrossAxisExtent,
              childAspectRatio: widget.childAspectRatio,
              crossAxisSpacing: CrispySpacing.md,
              mainAxisSpacing: CrispySpacing.md,
            ),
            itemCount: items.length,
            itemBuilder:
                (context, index) => widget.itemBuilder(context, items[index]),
          ),
        ),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(CrispySpacing.md),
            child: CircularProgressIndicator(),
          ),
        if (_hasError && _errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(CrispySpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: _retryLoadMore,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
