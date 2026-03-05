import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/core/domain/entities/media_item.dart';
import 'package:crispy_tivi/core/domain/entities/media_type.dart';
import 'package:crispy_tivi/core/domain/media_source.dart';
import 'package:crispy_tivi/core/navigation/app_routes.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/theme/crispy_animation.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/widgets/horizontal_scroll_row.dart';
import '../../../shared/presentation/widgets/media_server_item_card.dart';
import '../../../shared/presentation/widgets/media_server_library_card.dart';
import '../../../shared/presentation/widgets/watched_indicator.dart';
import '../providers/plex_providers.dart';
import 'plex_user_switcher_screen.dart';

/// Shared card aspect-ratio constants for Plex screens.
///
/// - [itemPoster]: portrait poster ratio for movie/show cards (library
///   and home screen).
abstract final class PlexCardRatios {
  /// 2:3 — portrait poster for individual items inside a library.
  static const double itemPoster = 2 / 3;
}

/// Height of each poster card in the Watchlist / On Deck rows.
const double _kRowCardHeight = 200;

/// Width of each poster card (2:3 portrait ratio).
const double _kRowCardWidth = _kRowCardHeight * PlexCardRatios.itemPoster;

/// Height of the cinematic hero banner in logical pixels.
// PX-FE-06
const double _kHeroBannerHeight = 420.0;

/// Auto-advance interval for the hero banner carousel.
// PX-FE-06
const Duration _kHeroAdvanceInterval = Duration(seconds: 8);

// ── Home screen ───────────────────────────────────────────────────────

class PlexHomeScreen extends ConsumerWidget {
  const PlexHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(plexSourceProvider);

    // PX-FE-02: check whether managed users are available to show the
    // profile-switcher icon in the AppBar.
    final usersAsync = ref.watch(plexManagedUsersProvider);
    final hasManagedUsers = usersAsync.asData?.value.isNotEmpty ?? false;

    // PX-FE-02: show the active user's name / avatar in the AppBar.
    final activeUser = ref.watch(plexActiveUserProvider);

    return Scaffold(
      key: TestKeys.plexHomeScreen,
      appBar: AppBar(
        title: Text(source?.displayName ?? 'Plex'),
        actions: [
          // PX-FE-02: profile switcher button — shown when Plex Home is enabled.
          if (source != null && hasManagedUsers)
            Padding(
              padding: const EdgeInsets.only(right: CrispySpacing.xs),
              child: IconButton(
                tooltip:
                    activeUser != null
                        ? 'Profile: ${activeUser.name}'
                        : 'Switch profile',
                icon:
                    activeUser?.avatarUrl != null
                        ? CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(activeUser!.avatarUrl!),
                        )
                        : const Icon(Icons.people_outline),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlexUserSwitcherScreen(),
                    ),
                  );
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body:
          source == null
              ? const _PlexNotConnected(serverName: 'Plex')
              : const _PlexLibraryBody(),
    );
  }
}

/// Minimal not-connected fallback for the Plex home screen.
class _PlexNotConnected extends StatelessWidget {
  const _PlexNotConnected({this.serverName = 'Plex'});

  final String serverName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Not connected to $serverName',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Sign in to browse your libraries.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.lg),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.login),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

/// Body that fetches libraries and delegates to [_PlexHomeBody].
class _PlexLibraryBody extends ConsumerWidget {
  const _PlexLibraryBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final librariesAsync = ref.watch(plexLibrariesProvider);

    return librariesAsync.when(
      data: (libraries) {
        if (libraries.isEmpty) {
          return const Center(child: Text('No libraries found'));
        }
        return _PlexHomeBody(libraries: libraries);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Scrollable home body ──────────────────────────────────────────────

/// Scrollable body that renders the hero banner, On Deck row, Watchlist
/// row, and library grid — all scrolling together in one [CustomScrollView].
class _PlexHomeBody extends ConsumerWidget {
  const _PlexHomeBody({required this.libraries});

  final List<MediaItem> libraries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistAsync = ref.watch(plexWatchlistProvider);
    final onDeckAsync = ref.watch(plexOnDeckProvider); // PX-FE-04
    final featuredAsync = ref.watch(plexFeaturedProvider); // PX-FE-06

    return CustomScrollView(
      slivers: [
        // PX-FE-06: Cinematic hero banner (auto-advancing carousel).
        SliverToBoxAdapter(
          child: featuredAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return _PlexHeroBanner(items: items);
            },
          ),
        ),

        // PX-FE-04: On Deck row (in-progress items).
        SliverToBoxAdapter(
          child: onDeckAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return _PlexOnDeckRow(items: items);
            },
          ),
        ),

        // ── Watchlist row ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: watchlistAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return _PlexWatchlistRow(items: items);
            },
          ),
        ),

        // ── Library grid ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.all(CrispySpacing.md),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: PlexCardRatios.itemPoster,
              crossAxisSpacing: CrispySpacing.md,
              mainAxisSpacing: CrispySpacing.md,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final lib = libraries[index];
              return MediaServerLibraryCard(
                library: lib,
                heroPrefix: 'plex',
                routeBase: 'plex',
              );
            }, childCount: libraries.length),
          ),
        ),
      ],
    );
  }
}

// ── PX-FE-06: Cinematic hero banner ──────────────────────────────────

/// [PX-FE-06] Auto-advancing cinematic hero banner carousel.
///
/// Displays the first item's art (backdrop preferred, thumb fallback) as a
/// full-bleed image with a bottom vignette gradient and title overlay.
/// Advances every [_kHeroAdvanceInterval] when multiple items are available.
/// Tapping opens the media details screen.
// PX-FE-06
class _PlexHeroBanner extends ConsumerStatefulWidget {
  const _PlexHeroBanner({required this.items});

  final List<MediaItem> items;

  @override
  ConsumerState<_PlexHeroBanner> createState() => _PlexHeroBannerState();
}

class _PlexHeroBannerState extends ConsumerState<_PlexHeroBanner> {
  // PX-FE-06
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // PX-FE-06: start auto-advance when multiple items are present.
    if (widget.items.length > 1) {
      _timer = Timer.periodic(_kHeroAdvanceInterval, (_) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.items.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap(BuildContext context) {
    // PX-FE-06: tap navigates to media details.
    final item = widget.items[_currentIndex];
    if (item.type == MediaType.folder || item.type == MediaType.series) {
      context.push(AppRoutes.plexChildren(item.id, title: item.name));
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': MediaServerType.plex,
          'getStreamUrl':
              (String id) => ref.read(plexStreamUrlProvider(id).future),
          'heroTag': 'plex_hero_${item.id}',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // PX-FE-06
    final item = widget.items[_currentIndex];
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Prefer backdrop art; fall back to thumb.
    final imageUrl =
        (item.metadata['backdropUrl'] as String?) ??
        (item.metadata['thumbUrl'] as String?) ??
        item.logoUrl;

    return Semantics(
      button: true,
      label: 'View details',
      child: GestureDetector(
        onTap: () => _onTap(context),
        child: SizedBox(
          height: _kHeroBannerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // PX-FE-06: backdrop image.
              AnimatedSwitcher(
                duration: CrispyAnimation.slow,
                child:
                    imageUrl != null
                        ? Image.network(
                          imageUrl,
                          key: ValueKey(imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder:
                              (_, _, _) =>
                                  ColoredBox(color: cs.surfaceContainerHighest),
                        )
                        : ColoredBox(
                          key: const ValueKey('placeholder'),
                          color: cs.surfaceContainerHighest,
                        ),
              ),

              // PX-FE-06: bottom vignette gradient.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x80000000),
                      Color(0xE6000000),
                      Colors.black,
                    ],
                    stops: [0.0, 0.3, 0.6, 0.85, 1.0],
                  ),
                ),
              ),

              // PX-FE-06: title / metadata overlay.
              Positioned(
                left: CrispySpacing.lg,
                right: CrispySpacing.lg,
                bottom: CrispySpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: tt.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.overview != null) ...[
                      const SizedBox(height: CrispySpacing.xs),
                      Text(
                        item.overview!,
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white70,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // PX-FE-06: page indicator dots when multiple items.
                    if (widget.items.length > 1) ...[
                      const SizedBox(height: CrispySpacing.sm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(widget.items.length, (i) {
                          return AnimatedContainer(
                            duration: CrispyAnimation.fast,
                            curve: CrispyAnimation.focusCurve,
                            margin: const EdgeInsets.only(
                              right: CrispySpacing.xs,
                            ),
                            width: i == _currentIndex ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  i == _currentIndex
                                      ? Colors.white
                                      : Colors.white38,
                              borderRadius: BorderRadius.circular(
                                CrispyRadius.tv,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PX-FE-04: On Deck row ─────────────────────────────────────────────

/// [PX-FE-04] Horizontal scroll row showing in-progress items.
///
/// Each card shows the poster / thumb with a [WatchedIndicator] progress bar
/// at the bottom. Tapping an item resumes playback from its [viewOffset].
// PX-FE-04
class _PlexOnDeckRow extends ConsumerWidget {
  const _PlexOnDeckRow({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PX-FE-04
    return HorizontalScrollRow<MediaItem>(
      items: items,
      itemWidth: _kRowCardWidth,
      sectionHeight: _kRowCardHeight,
      headerIcon: Icons.play_circle_outline,
      headerTitle: 'On Deck',
      itemBuilder: (ctx, item, index) {
        return _PlexOnDeckCard(item: item);
      },
    );
  }
}

/// [PX-FE-04] Single On Deck card — poster + progress bar + title label.
// PX-FE-04
class _PlexOnDeckCard extends ConsumerWidget {
  const _PlexOnDeckCard({required this.item});

  final MediaItem item;

  void _onTap(BuildContext context, WidgetRef ref) {
    // PX-FE-04: resume from viewOffset.
    final isFolder =
        item.type == MediaType.folder || item.type == MediaType.series;
    if (isFolder) {
      context.push(AppRoutes.plexChildren(item.id, title: item.name));
    } else {
      context.push(
        AppRoutes.mediaServerDetails,
        extra: {
          'item': item,
          'serverType': MediaServerType.plex,
          'getStreamUrl':
              (String id) => ref.read(plexStreamUrlProvider(id).future),
          'heroTag': 'plex_ondeck_${item.id}',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PX-FE-04
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Resume watching',
      child: GestureDetector(
        onTap: () => _onTap(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.logoUrl != null)
                Image.network(
                  item.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                )
              else
                ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: Icon(Icons.movie, size: 40, color: cs.onSurface),
                  ),
                ),
              // PX-FE-04: progress bar via WatchedIndicator.
              WatchedIndicator(
                isWatched: item.isWatched,
                isInProgress:
                    item.playbackPositionMs != null && !item.isWatched,
                watchProgress: item.watchProgress,
              ),
              // Title overlay at bottom.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ColoredBox(
                  color: cs.surface.withValues(alpha: 0.72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.xs,
                      vertical: CrispySpacing.xxs,
                    ),
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: cs.onSurface),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Watchlist row ─────────────────────────────────────────────────────

/// Horizontal scroll row for the user's Plex Watchlist.
///
/// Displays a poster card for each watchlisted item. Items with
/// folder/series type navigate deeper; playable items open the
/// media details screen.
class _PlexWatchlistRow extends ConsumerWidget {
  const _PlexWatchlistRow({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HorizontalScrollRow<MediaItem>(
      items: items,
      itemWidth: _kRowCardWidth,
      sectionHeight: _kRowCardHeight,
      headerIcon: Icons.bookmark_outline,
      headerTitle: 'Watchlist',
      itemBuilder: (ctx, item, index) {
        return MediaServerItemCard(
          item: item,
          serverType: MediaServerType.plex,
          heroPrefix: 'plex_watchlist',
          getStreamUrl: (id) async {
            final source = ref.read(plexSourceProvider);
            if (source == null) {
              throw StateError('No Plex source connected');
            }
            return source.getStreamUrl(id);
          },
        );
      },
    );
  }
}
