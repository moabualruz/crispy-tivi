import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../config/settings_notifier.dart';
import '../../../../../core/domain/entities/playlist_source.dart';
import '../../../../../core/domain/entities/playlist_source_type_ext.dart';
import '../../../../../core/navigation/app_routes.dart';
import '../../../../../core/testing/test_keys.dart';
import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/widgets/focus_wrapper.dart';
import '../../../../../core/widgets/horizontal_scroll_row.dart';
import '../../../../../core/widgets/smart_image.dart';
import '../../data/mdns_discovery_service.dart';
import '../providers/media_server_providers.dart';

// ── MSB-FE-02: Server online/offline status ───────────────────

/// Status of a server connectivity ping.
enum _ServerStatus {
  /// Ping not yet attempted.
  checking,

  /// Server responded within the timeout.
  online,

  /// Server is unreachable or returned an error.
  offline,
}

/// Per-server ping state: status + cache timestamp.
class _ServerPingState {
  const _ServerPingState({required this.status, required this.checkedAt});

  final _ServerStatus status;
  final DateTime checkedAt;

  /// Whether this result is still fresh (< 60 s old).
  bool get isFresh => DateTime.now().difference(checkedAt).inSeconds < 60;
}

/// MSB-FE-02: Manages server reachability pings, one entry per server ID.
///
/// Results are cached for 60 s. On [ping] the notifier issues an HTTP HEAD
/// to the server's base URL with a 3-second timeout and updates state.
class _ServerStatusNotifier extends Notifier<Map<String, _ServerPingState>> {
  @override
  Map<String, _ServerPingState> build() => {};

  /// Pings [server] if the cached result is stale or missing.
  Future<void> ping(PlaylistSource server) async {
    final cached = state[server.id];
    if (cached != null && cached.isFresh) return;

    // Set to checking immediately so the dot animates.
    state = {
      ...state,
      server.id: _ServerPingState(
        status: _ServerStatus.checking,
        checkedAt: DateTime.now(),
      ),
    };

    _ServerStatus result;
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          sendTimeout: const Duration(seconds: 3),
        ),
      );
      final response = await dio.head<void>(server.url);
      result =
          response.statusCode != null && response.statusCode! < 500
              ? _ServerStatus.online
              : _ServerStatus.offline;
    } catch (_) {
      result = _ServerStatus.offline;
    }

    state = {
      ...state,
      server.id: _ServerPingState(status: result, checkedAt: DateTime.now()),
    };
  }
}

/// Global provider for [_ServerStatusNotifier].
// MSB-FE-02
final _serverStatusProvider =
    NotifierProvider<_ServerStatusNotifier, Map<String, _ServerPingState>>(
      _ServerStatusNotifier.new,
    );

// ── MSB-FE-06: Multiple-accounts per server state ─────────────

/// Per-server account switcher state (scaffold — schema changes needed
/// before real persistence is possible).
///
/// Stores the "selected account index" per server ID so the UI can show
/// which account is active. Actual multi-account data storage requires a
/// settings schema extension (tracked in TODO: MSB-FE-06-persistence).
class _AccountSwitcherNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  /// Sets the active account index for [serverId].
  void setActiveAccount(String serverId, int index) {
    state = {...state, serverId: index};
  }

  /// Returns the active account index for [serverId] (default 0).
  int activeIndex(String serverId) => state[serverId] ?? 0;
}

final _accountSwitcherProvider =
    NotifierProvider<_AccountSwitcherNotifier, Map<String, int>>(
      _AccountSwitcherNotifier.new,
    );

// ─────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────

/// Media server browser screen — lists saved Jellyfin/Emby/Plex servers.
///
/// Sections (top to bottom):
///  1. MSB-FE-03: Discovered Servers (mDNS auto-discovery, auto-hides
///     when empty and scan is done)
///  2. MSB-FE-07: Continue Watching row (all servers, cross-server merge)
///  3. MSB-FE-01: Saved server list (real data from settingsNotifierProvider)
class MediaServerBrowserScreen extends ConsumerWidget {
  const MediaServerBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(savedMediaServersProvider);

    return Scaffold(
      key: TestKeys.mediaServerBrowserScreen,
      appBar: AppBar(
        title: const Text('Media Servers'),
        actions: [
          IconButton(
            onPressed: () => _showAddServerDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Add Server',
          ),
        ],
      ),
      body: FocusTraversalGroup(
        child:
            servers.isEmpty
                ? _EmptyServerState(
                  onAddServer: () => _showAddServerDialog(context, ref),
                )
                : _BrowserBody(
                  servers: servers,
                  onAddServer: () => _showAddServerDialog(context, ref),
                ),
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.dns),
                title: const Text('Jellyfin'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.jellyfinLogin);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Emby'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.embyLogin);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Plex'),
                enabled: true,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.plexLogin);
                },
              ),
              const SizedBox(height: CrispySpacing.lg),
            ],
          ),
    );
  }
}

// ── Body with all sections ─────────────────────────────────────

class _BrowserBody extends ConsumerWidget {
  const _BrowserBody({required this.servers, required this.onAddServer});

  final List<PlaylistSource> servers;
  final VoidCallback onAddServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        // MSB-FE-03: mDNS discovered servers section.
        const SliverToBoxAdapter(child: _MdnsDiscoverySection()),

        // MSB-FE-07: Continue Watching row.
        const SliverToBoxAdapter(child: _ContinueWatchingSection()),

        // MSB-FE-01: Saved server list header.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            CrispySpacing.md,
            CrispySpacing.lg,
            CrispySpacing.md,
            CrispySpacing.xs,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: CrispySpacing.sm),
                Text(
                  'My Servers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAddServer,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
        ),

        // MSB-FE-01: Server cards.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
          sliver: SliverList.builder(
            itemCount: servers.length,
            itemBuilder: (context, index) {
              final server = servers[index];
              return _ServerCard(
                server: server,
                onTap: () => _navigateToServer(context, server),
                onRemove: () => _confirmRemove(context, ref, server),
              );
            },
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: CrispySpacing.xl)),
      ],
    );
  }

  void _navigateToServer(BuildContext context, PlaylistSource server) {
    switch (server.type) {
      case PlaylistSourceType.jellyfin:
        context.push(AppRoutes.jellyfinHome);
      case PlaylistSourceType.emby:
        context.push(AppRoutes.embyHome);
      case PlaylistSourceType.plex:
        context.push(AppRoutes.plexHome);
      default:
        break;
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PlaylistSource server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove Server'),
            content: Text('Remove "${server.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(settingsNotifierProvider.notifier).removeSource(server.id);
    }
  }
}

// ── MSB-FE-03: mDNS Discovery Section ─────────────────────────

/// Shows auto-discovered servers from mDNS/Bonjour.
///
/// Renders a scan button + animated scanning indicator, then a list
/// of discovered servers. The section collapses when scan is done
/// and no servers were found.
class _MdnsDiscoverySection extends ConsumerStatefulWidget {
  const _MdnsDiscoverySection();

  @override
  ConsumerState<_MdnsDiscoverySection> createState() =>
      _MdnsDiscoverySectionState();
}

class _MdnsDiscoverySectionState extends ConsumerState<_MdnsDiscoverySection> {
  @override
  void initState() {
    super.initState();
    // Auto-start scan on first render.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mdnsDiscoveryProvider.notifier).startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(mdnsDiscoveryProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Hide section when done scanning and nothing found.
    if (discovery.status == MdnsDiscoveryStatus.done &&
        discovery.servers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.md,
        CrispySpacing.lg,
        CrispySpacing.md,
        CrispySpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row.
          Row(
            children: [
              Icon(Icons.wifi_find_rounded, size: 18, color: cs.primary),
              const SizedBox(width: CrispySpacing.sm),
              Text(
                'Discovered on Network',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!discovery.isScanning)
                TextButton.icon(
                  onPressed:
                      () =>
                          ref.read(mdnsDiscoveryProvider.notifier).startScan(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Scan'),
                ),
            ],
          ),

          const SizedBox(height: CrispySpacing.sm),

          // Scanning animation.
          if (discovery.isScanning)
            _ScanningIndicator(cs: cs, tt: tt)
          else if (discovery.servers.isNotEmpty)
            // Discovered server chips.
            Wrap(
              spacing: CrispySpacing.sm,
              runSpacing: CrispySpacing.xs,
              children:
                  discovery.servers
                      .map((s) => _DiscoveredServerChip(server: s))
                      .toList(),
            ),

          const Divider(height: CrispySpacing.xl),
        ],
      ),
    );
  }
}

/// Animated "scanning…" row shown while mDNS discovery is in progress.
class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(width: CrispySpacing.sm),
        Text(
          'Scanning for Jellyfin and Emby servers…',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Chip for a single auto-discovered server.
///
/// Tapping it pushes the appropriate login screen.
class _DiscoveredServerChip extends ConsumerWidget {
  const _DiscoveredServerChip({required this.server});

  final DiscoveredServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return FocusWrapper(
      onSelect: () => _addServer(context),
      semanticLabel: 'Discovered server: ${server.name}. Tap to connect.',
      child: ActionChip(
        avatar: Icon(
          server.isJellyfin ? Icons.dns_rounded : Icons.cast_connected_rounded,
          size: 16,
          color: cs.primary,
        ),
        label: Text(server.name),
        onPressed: () => _addServer(context),
        tooltip: 'Connect to ${server.url}',
      ),
    );
  }

  void _addServer(BuildContext context) {
    // Navigate to the appropriate login screen pre-populated with the
    // discovered server URL.
    // TODO(msb-fe-03): Pass server.url as initial value to login screens
    // once the login screens support a pre-filled URL parameter.
    if (server.isJellyfin) {
      context.push(AppRoutes.jellyfinLogin);
    } else if (server.isEmby) {
      context.push(AppRoutes.embyLogin);
    }
  }
}

// ── MSB-FE-07: Continue Watching Section ──────────────────────

/// Horizontal scroll row showing in-progress items from ALL servers.
class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(allServersResumeItemsProvider);

    return resumeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return HorizontalScrollRow<ServerResumeItem>(
          items: items,
          headerIcon: Icons.play_circle_outline_rounded,
          headerTitle: 'Continue Watching',
          itemWidth: 160,
          sectionHeight: 240,
          itemBuilder:
              (ctx, serverItem, _) => _ResumeCard(serverItem: serverItem),
        );
      },
    );
  }
}

/// Card for a single resume item in the Continue Watching row.
///
/// Shows: thumbnail, title, server-type badge, progress bar.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.serverItem});

  final ServerResumeItem serverItem;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = serverItem.item;
    final server = serverItem.server;
    final progress = item.watchProgress;

    return FocusWrapper(
      onSelect: () {
        // TODO(msb-fe-07): Navigate to details/player for this item.
        // Route depends on server type (jellyfin/emby/plex).
      },
      semanticLabel: 'Continue watching ${item.name} on ${server.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with progress bar overlay.
          Expanded(
            child: Stack(
              children: [
                // Poster image.
                ClipRRect(
                  borderRadius: BorderRadius.circular(CrispyRadius.md),
                  child: SmartImage(
                    itemId: item.id,
                    title: item.name,
                    imageUrl: item.logoUrl,
                    fit: BoxFit.cover,
                    icon: Icons.movie_outlined,
                  ),
                ),

                // Server-type badge (top-right corner).
                Positioned(
                  top: CrispySpacing.xs,
                  right: CrispySpacing.xs,
                  child: _ServerBadge(type: server.type),
                ),

                // Progress bar (bottom of thumbnail).
                if (progress != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(CrispyRadius.md),
                        bottomRight: Radius.circular(CrispyRadius.md),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: CrispySpacing.xs),

          // Title.
          Text(
            item.name,
            style: tt.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Server name sub-label.
          Text(
            server.name,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Small server-type badge chip used in resume cards.
class _ServerBadge extends StatelessWidget {
  const _ServerBadge({required this.type});

  final PlaylistSourceType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (icon, label) = switch (type) {
      PlaylistSourceType.jellyfin => (Icons.dns_rounded, 'JF'),
      PlaylistSourceType.emby => (Icons.cast_connected_rounded, 'EM'),
      PlaylistSourceType.plex => (Icons.play_circle_outline_rounded, 'PX'),
      _ => (Icons.storage_rounded, '?'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.inverseSurface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: cs.inversePrimary),
          const SizedBox(width: CrispySpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: cs.inversePrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── MSB-FE-01: Server card ─────────────────────────────────────

/// Card representing a single saved media server.
///
/// MSB-FE-01: Shows server-type icon, display name, URL, server-type label.
/// MSB-FE-02: Shows a colour-coded status dot (green/amber/grey) and
/// auto-pings the server on first render.
/// MSB-FE-05: Long-press opens a bottom-sheet with Rename / Remove /
/// Re-authenticate / Switch User actions.
/// MSB-FE-06: Shows a user-switcher chip when multiple accounts exist
/// (scaffolded — real multi-account data requires settings schema extension).
class _ServerCard extends ConsumerStatefulWidget {
  const _ServerCard({
    required this.server,
    required this.onTap,
    required this.onRemove,
  });

  final PlaylistSource server;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  ConsumerState<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends ConsumerState<_ServerCard> {
  @override
  void initState() {
    super.initState();
    // MSB-FE-02: kick off a ping after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_serverStatusProvider.notifier).ping(widget.server);
    });
  }

  // MSB-FE-05: Long-press context sheet ────────────────────────

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context);
                },
              ),
              // MSB-FE-06: Switch user option.
              ListTile(
                leading: const Icon(Icons.switch_account_outlined),
                title: const Text('Switch User'),
                subtitle: const Text(
                  'Multi-account support — coming soon',
                  style: TextStyle(fontSize: 12),
                ),
                enabled:
                    false, // TODO(msb-fe-06): enable when multi-account schema is ready.
                onTap: () {
                  Navigator.pop(ctx);
                  _showAccountSwitcher(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Re-authenticate'),
                onTap: () {
                  Navigator.pop(ctx);
                  _reAuthenticate(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onRemove();
                },
              ),
              const SizedBox(height: CrispySpacing.lg),
            ],
          ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: widget.server.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rename Server'),
            content: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != widget.server.name) {
        await ref
            .read(settingsNotifierProvider.notifier)
            .updateSource(widget.server.copyWith(name: newName));
      }
    }
    controller.dispose();
  }

  /// MSB-FE-06: Stub account switcher dialog.
  ///
  /// Displays a placeholder until the settings schema supports multiple
  /// accounts per server (TODO: MSB-FE-06-persistence).
  void _showAccountSwitcher(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Switch User'),
            content: const Text(
              'Multiple accounts per server are not yet supported.\n\n'
              'To use a different account, remove this server and '
              'add it again with the new credentials.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _reAuthenticate(BuildContext context) {
    switch (widget.server.type) {
      case PlaylistSourceType.jellyfin:
        context.push(AppRoutes.jellyfinLogin);
      case PlaylistSourceType.emby:
        context.push(AppRoutes.embyLogin);
      case PlaylistSourceType.plex:
        context.push(AppRoutes.plexLogin);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // MSB-FE-02: watch server ping state.
    final pingMap = ref.watch(_serverStatusProvider);
    final ping = pingMap[widget.server.id];
    final pingStatus = ping?.status ?? _ServerStatus.checking;

    // MSB-FE-06: watch account switcher state (scaffold).
    final accountMap = ref.watch(_accountSwitcherProvider);
    final activeAccountIndex = accountMap[widget.server.id] ?? 0;

    // Server type label for MSB-FE-01 display.
    final typeLabel = widget.server.type.serverLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyRadius.md),
      ),
      child: FocusWrapper(
        onSelect: widget.onTap,
        onLongPress: () => _showActionsSheet(context),
        semanticLabel: '${widget.server.name} — $typeLabel server',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Row(
            children: [
              // Server type icon with status dot.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    widget.server.type.icon,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  // MSB-FE-02: status dot.
                  Positioned(
                    bottom: -2,
                    right: -4,
                    child: _StatusDot(status: pingStatus),
                  ),
                ],
              ),

              const SizedBox(width: CrispySpacing.md),

              // Name, URL, type label.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.server.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: CrispySpacing.xxs),
                    Text(
                      widget.server.url,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: CrispySpacing.xxs),
                    // MSB-FE-01: server type chip + MSB-FE-06: active account chip.
                    Row(
                      children: [
                        _TypeChip(label: typeLabel, type: widget.server.type),
                        // MSB-FE-06: account chip (scaffold — shows index only).
                        if (activeAccountIndex > 0) ...[
                          const SizedBox(width: CrispySpacing.xs),
                          _AccountChip(accountIndex: activeAccountIndex),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // More button.
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Server actions',
                onPressed: () => _showActionsSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting small widgets ───────────────────────────────────

/// Small server-type label chip shown under the server name.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.type});

  final String label;
  final PlaylistSourceType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final color = switch (type) {
      PlaylistSourceType.jellyfin => cs.primary,
      PlaylistSourceType.emby => cs.secondary,
      PlaylistSourceType.plex => cs.tertiary,
      _ => cs.outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// MSB-FE-06: Scaffold chip showing active account number.
///
/// Displayed only when [accountIndex] > 0 (i.e. user explicitly switched).
/// Will evolve into a real username chip once multi-account storage lands.
class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.accountIndex});

  final int accountIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
        color: cs.tertiaryContainer,
      ),
      child: Text(
        'Account ${accountIndex + 1}',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: cs.onTertiaryContainer),
      ),
    );
  }
}

// MSB-FE-02: coloured status dot widget ──────────────────────

/// Small dot indicating server reachability.
///
/// Green = online, red = offline, grey = checking.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final _ServerStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final color = switch (status) {
      _ServerStatus.online => cs.primary,
      _ServerStatus.offline => cs.error,
      _ServerStatus.checking => cs.outline,
    };

    final tooltip = switch (status) {
      _ServerStatus.online => 'Online',
      _ServerStatus.offline => 'Offline',
      _ServerStatus.checking => 'Checking…',
    };

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: cs.surface, width: 1.5),
        ),
      ),
    );
  }
}

// MSB-FE-11: Animated onboarding empty state ─────────────────

/// Onboarding flow shown when no media servers are configured.
///
/// Cycles through 3 animated steps with a page indicator, a
/// brief description of each server type, and a prominent CTA.
class _EmptyServerState extends StatefulWidget {
  const _EmptyServerState({required this.onAddServer});

  final VoidCallback onAddServer;

  @override
  State<_EmptyServerState> createState() => _EmptyServerStateState();
}

class _EmptyServerStateState extends State<_EmptyServerState>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  int _currentPage = 0;
  Timer? _autoAdvance;

  static const _steps = [
    _OnboardingStep(
      icon: Icons.add_circle_outline,
      title: 'Add a Server',
      description:
          'Connect to your Jellyfin, Emby, or Plex\n'
          'media server to browse your libraries.',
      serverIcons: [
        Icons.dns_rounded,
        Icons.cast_connected_rounded,
        Icons.play_circle_outline_rounded,
      ],
      serverLabels: ['Jellyfin', 'Emby', 'Plex'],
    ),
    _OnboardingStep(
      icon: Icons.video_library_outlined,
      title: 'Browse Your Libraries',
      description:
          'Explore movies, TV shows, and music\n'
          'organised into your personal libraries.',
      serverIcons: [
        Icons.movie_outlined,
        Icons.live_tv_outlined,
        Icons.music_note_outlined,
      ],
      serverLabels: ['Movies', 'TV Shows', 'Music'],
    ),
    _OnboardingStep(
      icon: Icons.play_arrow_rounded,
      title: 'Start Watching',
      description:
          'Stream content directly to your device\n'
          'with full playback controls and quality options.',
      serverIcons: [
        Icons.hd_outlined,
        Icons.subtitles_outlined,
        Icons.speed_outlined,
      ],
      serverLabels: ['HD Quality', 'Subtitles', 'Speed Control'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    _autoAdvance?.cancel();
    _autoAdvance = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final next = (_currentPage + 1) % _steps.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _autoAdvance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      label:
          'No media servers configured. '
          'Add a Jellyfin, Emby, or Plex server to get started.',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.xl),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Step pages ──
                  SizedBox(
                    height: 260,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        _scheduleAutoAdvance();
                      },
                      itemCount: _steps.length,
                      itemBuilder: (_, i) => _StepPage(step: _steps[i]),
                    ),
                  ),

                  const SizedBox(height: CrispySpacing.md),

                  // ── Page indicator dots ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (i) => AnimatedContainer(
                        duration: CrispyAnimation.normal,
                        margin: const EdgeInsets.symmetric(
                          horizontal: CrispySpacing.xxs,
                        ),
                        width: _currentPage == i ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            CrispyRadius.full,
                          ),
                          color:
                              _currentPage == i
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: CrispySpacing.xl),

                  // ── Server type quick-reference ──
                  Text(
                    'Supported servers',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: CrispySpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ServerTypeChip(
                        icon: Icons.dns_rounded,
                        label: 'Jellyfin',
                        color: cs.primary,
                      ),
                      const SizedBox(width: CrispySpacing.sm),
                      _ServerTypeChip(
                        icon: Icons.cast_connected_rounded,
                        label: 'Emby',
                        color: cs.secondary,
                      ),
                      const SizedBox(width: CrispySpacing.sm),
                      _ServerTypeChip(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Plex',
                        color: cs.tertiary,
                      ),
                    ],
                  ),

                  const SizedBox(height: CrispySpacing.xl),

                  // ── Primary CTA ──
                  FilledButton.icon(
                    onPressed: widget.onAddServer,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Server'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CrispyRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single onboarding step definition.
class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.serverIcons,
    required this.serverLabels,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<IconData> serverIcons;
  final List<String> serverLabels;
}

/// Renders one step in the onboarding page view.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Large step icon.
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primaryContainer,
          ),
          child: Icon(step.icon, size: 40, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: CrispySpacing.md),
        Text(
          step.title,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CrispySpacing.sm),
        Text(
          step.description,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CrispySpacing.md),
        // Feature icons row.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            step.serverIcons.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
              child: Column(
                children: [
                  Icon(step.serverIcons[i], size: 24, color: cs.primary),
                  const SizedBox(height: CrispySpacing.xxs),
                  Text(
                    step.serverLabels[i],
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small chip showing a supported server type.
class _ServerTypeChip extends StatelessWidget {
  const _ServerTypeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CrispyRadius.md),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: CrispySpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
