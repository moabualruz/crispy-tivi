import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/utils/url_utils.dart';
import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import '../providers/jellyfin_providers.dart';
import 'jellyfin_quick_connect_screen.dart';

// ── Server info probe (FE-JF-03) ─────────────────────────────────────────

/// Result of probing a Jellyfin server before login.
class _JellyfinServerProbe {
  const _JellyfinServerProbe({
    required this.serverName,
    required this.version,
    required this.connectionType,
    required this.latencyMs,
  });

  /// Human-readable server name (e.g. "My Jellyfin Server").
  final String serverName;

  /// Server version string (e.g. "10.9.7").
  final String version;

  /// `'HTTPS'` or `'HTTP'` depending on the URL scheme.
  final String connectionType;

  /// Round-trip latency in milliseconds for the `/System/Info/Public` call.
  final int latencyMs;
}

/// Probes a Jellyfin server at [url] (already normalized) and returns
/// connection info including latency.
///
/// Uses [autoDispose] + [family] so each URL gets its own cached result,
/// and stale results are cleaned up when no longer watched.
final _jellyfinServerProbeProvider = FutureProvider.autoDispose
    .family<_JellyfinServerProbe, String>((ref, url) async {
      if (url.isEmpty) throw StateError('empty url');

      final connectionType = url.startsWith('https') ? 'HTTPS' : 'HTTP';
      final dio = Dio(
        BaseOptions(baseUrl: url, connectTimeout: const Duration(seconds: 5)),
      );

      final sw = Stopwatch()..start();
      final client = MediaServerApiClient(dio, baseUrl: url);
      final info = await client.getPublicSystemInfo();
      sw.stop();

      return _JellyfinServerProbe(
        serverName: info.serverName,
        version: info.version,
        connectionType: connectionType,
        latencyMs: sw.elapsedMilliseconds,
      );
    });

// ── Screen ────────────────────────────────────────────────────────────────

/// Jellyfin login screen.
///
/// Extends [MediaServerLoginScreen] with:
/// - FE-JF-02: public-user picker (avatar tiles populated after URL entry).
/// - FE-JF-03: server info panel (name, version, connection type, latency)
///   shown as a card immediately after the server responds to the URL probe.
class JellyfinLoginScreen extends ConsumerStatefulWidget {
  const JellyfinLoginScreen({super.key});

  static Future<PlaylistSource> _authenticate(
    Dio dio,
    String url,
    String username,
    String password,
  ) => authenticateMediaServer(
    dio,
    url,
    username,
    password,
    PlaylistSourceType.jellyfin,
  );

  @override
  ConsumerState<JellyfinLoginScreen> createState() =>
      _JellyfinLoginScreenState();
}

class _JellyfinLoginScreenState extends ConsumerState<JellyfinLoginScreen> {
  /// Normalized URL used to fetch public users and server info.
  String _resolvedUrl = '';

  /// External username controller so the picker can fill it.
  final _userCtrl = TextEditingController();

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  void _onUrlChanged(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      if (_resolvedUrl.isNotEmpty) setState(() => _resolvedUrl = '');
      return;
    }
    try {
      final normalized = normalizeServerUrl(trimmed);
      if (normalized != _resolvedUrl) {
        setState(() => _resolvedUrl = normalized);
      }
    } catch (_) {
      // Not yet a valid URL — ignore until the user finishes typing.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaServerLoginScreen(
      serverName: 'Jellyfin',
      authenticate: JellyfinLoginScreen._authenticate,
      onUrlChanged: _onUrlChanged,
      externalUsernameController: _userCtrl,
      bodyFooter:
          _resolvedUrl.isNotEmpty
              ? (context) => _JellyfinBodyFooter(
                serverUrl: _resolvedUrl,
                onUserSelected: (name) => _userCtrl.text = name,
              )
              : null,
    );
  }
}

// ── Combined body footer: server info panel + user picker ─────────────────

/// Renders the server info panel (FE-JF-03), the public-user picker
/// (FE-JF-02), and the Quick Connect button (JF-FE-01) stacked vertically
/// below the login form.
class _JellyfinBodyFooter extends ConsumerWidget {
  const _JellyfinBodyFooter({
    required this.serverUrl,
    required this.onUserSelected,
  });

  final String serverUrl;
  final ValueChanged<String> onUserSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JellyfinServerInfoPanel(serverUrl: serverUrl),
        _JellyfinUserPicker(
          serverUrl: serverUrl,
          onUserSelected: onUserSelected,
        ),
        _QuickConnectRow(serverUrl: serverUrl),
      ],
    );
  }
}

// ── Server info panel (FE-JF-03) ─────────────────────────────────────────

/// Displays server name, version, connection type, and response latency
/// in a compact card after the user enters a valid Jellyfin URL.
///
/// Shows a loading indicator while the probe is in progress, nothing on
/// error (the test-connection button already shows errors inline).
class _JellyfinServerInfoPanel extends ConsumerWidget {
  const _JellyfinServerInfoPanel({required this.serverUrl});

  final String serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probeAsync = ref.watch(_jellyfinServerProbeProvider(serverUrl));

    return probeAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: CrispySpacing.lg,
              vertical: CrispySpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: CrispySpacing.sm),
                Text('Probing server…'),
              ],
            ),
          ),
      error: (_, _) => const SizedBox.shrink(),
      data: (probe) => _ServerInfoCard(probe: probe),
    );
  }
}

class _ServerInfoCard extends StatelessWidget {
  const _ServerInfoCard({required this.probe});

  final _JellyfinServerProbe probe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isHttps = probe.connectionType == 'HTTPS';
    final connColor = isHttps ? cs.primary : cs.error;
    final connIcon = isHttps ? Icons.lock_outlined : Icons.lock_open_outlined;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.lg,
        0,
        CrispySpacing.lg,
        CrispySpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(CrispySpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.all(
            Radius.circular(CrispyRadius.tv),
          ),
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Server name + version
            Row(
              children: [
                Icon(Icons.dns_outlined, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: CrispySpacing.xs),
                Expanded(
                  child: Text(
                    probe.serverName,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'v${probe.version}',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.xs),
            // Connection type + latency
            Row(
              children: [
                Icon(connIcon, size: 14, color: connColor),
                const SizedBox(width: CrispySpacing.xs),
                Text(
                  probe.connectionType,
                  style: tt.labelSmall?.copyWith(color: connColor),
                ),
                const SizedBox(width: CrispySpacing.md),
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: CrispySpacing.xs),
                Text(
                  '${probe.latencyMs} ms',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Public-user picker (FE-JF-02) ────────────────────────────────────────

/// Horizontal row of Jellyfin public-user avatar tiles.
///
/// Appears on the login screen after a valid server URL is entered.
/// Tapping a tile auto-fills the username field.
class _JellyfinUserPicker extends ConsumerWidget {
  const _JellyfinUserPicker({
    required this.serverUrl,
    required this.onUserSelected,
  });

  final String serverUrl;
  final ValueChanged<String> onUserSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(jellyfinPublicUsersProvider(serverUrl));

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return _UserPickerRow(
          users: users,
          serverUrl: serverUrl,
          onUserSelected: onUserSelected,
        );
      },
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: CrispySpacing.sm),
            child: Center(child: CircularProgressIndicator()),
          ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _UserPickerRow extends StatelessWidget {
  const _UserPickerRow({
    required this.users,
    required this.serverUrl,
    required this.onUserSelected,
  });

  final List<MediaServerUser> users;
  final String serverUrl;
  final ValueChanged<String> onUserSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.lg,
        0,
        CrispySpacing.lg,
        CrispySpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select user',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.sm),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              separatorBuilder:
                  (_, _) => const SizedBox(width: CrispySpacing.sm),
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserAvatarTile(
                  user: user,
                  serverUrl: serverUrl,
                  onTap: () => onUserSelected(user.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatarTile extends StatelessWidget {
  const _UserAvatarTile({
    required this.user,
    required this.serverUrl,
    required this.onTap,
  });

  final MediaServerUser user;
  final String serverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build avatar image URL if a primaryImageTag is present.
    final imageUrl =
        user.primaryImageTag != null
            ? '$serverUrl/Users/${user.id}/Images/Primary'
                '?tag=${user.primaryImageTag}&height=80'
            : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CrispyRadius.tv),
      child: SizedBox(
        width: 72,
        child: Padding(
          padding: const EdgeInsets.all(CrispySpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.primaryContainer,
                backgroundImage:
                    imageUrl != null ? NetworkImage(imageUrl) : null,
                child:
                    imageUrl == null
                        ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : null,
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                user.name,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── JF-FE-01: Quick Connect row ───────────────────────────────────────────

/// Divider + "Use Quick Connect" button shown when a valid server URL is set.
///
/// Tapping the button navigates to [JellyfinQuickConnectScreen] with the
/// current server URL.
class _QuickConnectRow extends StatelessWidget {
  const _QuickConnectRow({required this.serverUrl});

  final String serverUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.lg,
        0,
        CrispySpacing.lg,
        CrispySpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Divider(color: cs.outline.withValues(alpha: 0.5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                ),
                child: Text(
                  'or',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Divider(color: cs.outline.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: CrispySpacing.sm),
          FocusWrapper(
            onSelect: () => _goToQuickConnect(context),
            child: OutlinedButton.icon(
              onPressed: () => _goToQuickConnect(context),
              icon: const Icon(Icons.cast_connected, size: 18),
              label: const Text('Use Quick Connect'),
            ),
          ),
        ],
      ),
    );
  }

  void _goToQuickConnect(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JellyfinQuickConnectScreen(serverUrl: serverUrl),
      ),
    );
  }
}
