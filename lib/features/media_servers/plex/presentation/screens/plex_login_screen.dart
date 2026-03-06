import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/utils/date_format_utils.dart' show formatMmss;
import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import 'package:crispy_tivi/core/widgets/or_divider_row.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_api_client.dart';
import 'package:crispy_tivi/features/media_servers/plex/data/datasources/plex_auth_service.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/error_sanitizer.dart';

/// Thin wrapper around [MediaServerLoginScreen] for Plex servers.
///
/// Uses token-based auth (X-Plex-Token) rather than username/password,
/// so the username field is hidden and the credential field is labelled
/// "X-Plex-Token".
///
/// Also exposes a "Sign in with Plex" button that opens the browser for
/// the OAuth PIN flow (PX-FE-01).
class PlexLoginScreen extends ConsumerStatefulWidget {
  const PlexLoginScreen({super.key});

  @override
  ConsumerState<PlexLoginScreen> createState() => _PlexLoginScreenState();
}

class _PlexLoginScreenState extends ConsumerState<PlexLoginScreen> {
  static Future<PlaylistSource> _authenticate(
    // The Dio instance provided by MediaServerLoginScreen is intentionally
    // ignored here. Plex uses token-based auth (X-Plex-Token) and requires
    // a new, unconfigured Dio instance so PlexApiClient can set its own
    // Plex-specific headers (X-Plex-Token, X-Plex-Client-Identifier) without
    // conflicting with the shared Emby/Jellyfin auth headers.
    Dio _,
    String url,
    String username, // unused — no username for Plex (hidden field)
    String token,
  ) async {
    final client = PlexApiClient(dio: Dio());

    final serverInfo = await client.validateServer(
      url: url,
      token: token,
      clientIdentifier: PlexAuthService.clientIdentifier,
    );

    return PlaylistSource(
      id: 'plex_${url.hashCode}',
      name: serverInfo.name,
      url: url,
      type: PlaylistSourceType.plex,
      accessToken: token,
      deviceId: PlexAuthService.clientIdentifier,
    );
  }

  /// Whether the OAuth overlay is showing.
  bool _showOAuth = false;

  void _startOAuth() {
    setState(() => _showOAuth = true);
  }

  void _cancelOAuth() {
    setState(() => _showOAuth = false);
  }

  /// Called by [_PlexOAuthFlow] when authorization succeeds.
  void _onOAuthSuccess(PlaylistSource source) {
    setState(() => _showOAuth = false);
    ref.read(settingsNotifierProvider.notifier).addSource(source);
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Connected to ${source.name}')));
  }

  @override
  Widget build(BuildContext context) {
    if (_showOAuth) {
      return _PlexOAuthScreen(
        onSuccess: _onOAuthSuccess,
        onCancel: _cancelOAuth,
      );
    }

    return MediaServerLoginScreen(
      serverName: 'Plex',
      authenticate: _authenticate,
      urlHint: 'http://192.168.1.10:32400',
      showUsernameField: false,
      credentialLabel: 'X-Plex-Token',
      credentialHelperText: 'Find this in Plex XML or URL parameters',
      credentialIcon: Icons.vpn_key,
      // PX-FE-01: OAuth sign-in button shown below the form.
      bodyFooter: (context) => _PlexOAuthRow(onSignIn: _startOAuth),
    );
  }
}

// ── PX-FE-01: OAuth "Sign in with Plex" row ─────────────────────────────

/// Divider + "Sign in with Plex" button below the manual-token form.
class _PlexOAuthRow extends StatelessWidget {
  const _PlexOAuthRow({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
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
          const OrDividerRow(),
          const SizedBox(height: CrispySpacing.sm),
          FilledButton.icon(
            onPressed: onSignIn,
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('Sign in with Plex'),
          ),
        ],
      ),
    );
  }
}

// ── PX-FE-01: OAuth flow screen ──────────────────────────────────────────

/// Phase of the Plex OAuth PIN flow.
enum _PlexOAuthPhase {
  /// Starting — requesting a PIN from plex.tv.
  starting,

  /// Waiting for the user to approve in the browser.
  waiting,

  /// Fetching available servers.
  fetchingServers,

  /// User must select a server from a list.
  selectServer,

  /// Validating the chosen server connection.
  validating,

  /// Flow failed.
  error,
}

/// Manages the Plex OAuth PIN flow state.
class _PlexOAuthState {
  const _PlexOAuthState({
    required this.phase,
    this.pinCode,
    this.pinId,
    this.oauthState,
    this.servers,
    this.errorMessage,
  });

  final _PlexOAuthPhase phase;
  final String? pinCode;
  final int? pinId;
  final PlexOAuthState? oauthState;
  final List<PlexOAuthServer>? servers;
  final String? errorMessage;
}

/// Full-screen Plex OAuth flow widget.
///
/// 1. Requests a PIN from plex.tv.
/// 2. Opens the browser to `https://app.plex.tv/auth#?…`.
/// 3. Polls until the user approves.
/// 4. Fetches server list and lets the user select one.
/// 5. Calls [onSuccess] with the constructed [PlaylistSource].
class _PlexOAuthScreen extends StatefulWidget {
  const _PlexOAuthScreen({required this.onSuccess, required this.onCancel});

  final void Function(PlaylistSource) onSuccess;
  final VoidCallback onCancel;

  @override
  State<_PlexOAuthScreen> createState() => _PlexOAuthScreenState();
}

class _PlexOAuthScreenState extends State<_PlexOAuthScreen> {
  final _service = PlexAuthService();

  _PlexOAuthState _state = const _PlexOAuthState(
    phase: _PlexOAuthPhase.starting,
  );

  // Keep track of timers so we can cancel on dispose.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Flow ────────────────────────────────────────────────────────────────

  Future<void> _start() async {
    if (!mounted) return;
    setState(
      () => _state = const _PlexOAuthState(phase: _PlexOAuthPhase.starting),
    );

    try {
      final (:pinId, :state) = await _service.initiate();

      if (!mounted || _disposed) return;

      setState(() {
        _state = _PlexOAuthState(
          phase: _PlexOAuthPhase.waiting,
          pinCode: state.pinCode,
          pinId: pinId,
          oauthState: state,
        );
      });

      // Open browser.
      try {
        await _service.openAuthPage(state.pinCode);
      } catch (_) {
        // Non-fatal — user may open manually.
      }

      // Poll.
      final authToken = await _service.pollForAuth(
        pinId: pinId,
        initialState: state,
        onTick: (updated) {
          if (mounted && !_disposed) {
            setState(() {
              _state = _PlexOAuthState(
                phase: _PlexOAuthPhase.waiting,
                pinCode: updated.pinCode,
                pinId: pinId,
                oauthState: updated,
              );
            });
          }
        },
      );

      if (!mounted || _disposed) return;

      setState(
        () =>
            _state = _PlexOAuthState(
              phase: _PlexOAuthPhase.fetchingServers,
              pinCode: _state.pinCode,
              pinId: pinId,
              oauthState: state,
            ),
      );

      final servers = await _service.fetchServers(authToken);

      if (!mounted || _disposed) return;

      if (servers.isEmpty) {
        // No servers found — create a minimal source from plex.tv token.
        final source = PlaylistSource(
          id: 'plex_cloud_${authToken.hashCode}',
          name: 'Plex',
          url: '',
          type: PlaylistSourceType.plex,
          accessToken: authToken,
          deviceId: PlexAuthService.clientIdentifier,
        );
        widget.onSuccess(source);
        return;
      }

      if (servers.length == 1) {
        await _connectServer(servers.first);
        return;
      }

      setState(() {
        _state = _PlexOAuthState(
          phase: _PlexOAuthPhase.selectServer,
          pinCode: _state.pinCode,
          servers: servers,
        );
      });
    } catch (e) {
      if (!mounted || _disposed) return;
      setState(() {
        _state = _PlexOAuthState(
          phase: _PlexOAuthPhase.error,
          errorMessage: sanitizeError(e),
        );
      });
    }
  }

  Future<void> _connectServer(PlexOAuthServer server) async {
    if (!mounted || _disposed) return;
    setState(() => _state = _PlexOAuthState(phase: _PlexOAuthPhase.validating));

    try {
      final source = await _service.buildSource(server);
      if (!mounted || _disposed) return;
      widget.onSuccess(source);
    } catch (e) {
      if (!mounted || _disposed) return;
      setState(() {
        _state = _PlexOAuthState(
          phase: _PlexOAuthPhase.error,
          errorMessage: sanitizeError(e),
        );
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TestKeys.plexLoginScreen,
      appBar: AppBar(
        title: const Text('Sign in with Plex'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Cancel',
          onPressed: widget.onCancel,
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_state.phase) {
      _PlexOAuthPhase.starting => const Center(
        child: CircularProgressIndicator(),
      ),
      _PlexOAuthPhase.waiting => _WaitingBody(
        pinCode: _state.pinCode ?? '...',
        oauthState: _state.oauthState,
        onCancel: widget.onCancel,
        onRestart: _start,
      ),
      _PlexOAuthPhase.fetchingServers => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: CrispySpacing.md),
            Text('Fetching your servers…'),
          ],
        ),
      ),
      _PlexOAuthPhase.selectServer => _ServerSelector(
        servers: _state.servers ?? [],
        onSelect: _connectServer,
        onCancel: widget.onCancel,
      ),
      _PlexOAuthPhase.validating => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: CrispySpacing.md),
            Text('Connecting to server…'),
          ],
        ),
      ),
      _PlexOAuthPhase.error => _ErrorBody(
        message: _state.errorMessage ?? 'An error occurred.',
        onRetry: _start,
        onCancel: widget.onCancel,
      ),
    };
  }
}

// ── Waiting body ─────────────────────────────────────────────────────────

class _WaitingBody extends StatelessWidget {
  const _WaitingBody({
    required this.pinCode,
    required this.oauthState,
    required this.onCancel,
    required this.onRestart,
  });

  final String pinCode;
  final PlexOAuthState? oauthState;
  final VoidCallback onCancel;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final secondsLeft = oauthState?.secondsRemaining ?? 0;
    final timerLabel = formatMmss(secondsLeft);
    final isAlmostExpired = secondsLeft <= 30;
    final timerColor = isAlmostExpired ? cs.error : cs.onSurfaceVariant;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(CrispySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.perm_identity, size: 56, color: cs.primary),
            const SizedBox(height: CrispySpacing.lg),
            Text(
              'Waiting for authorization…',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              'A browser window has opened. Sign in to plex.tv to authorize '
              'CrispyTivi. If the browser did not open, use the PIN code below '
              'at app.plex.tv/auth.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.xl),

            // PIN code card.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.xl,
                vertical: CrispySpacing.lg,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CrispyRadius.tv),
                ),
                border: Border.all(color: cs.primary, width: 2),
              ),
              child: Text(
                pinCode,
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: cs.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: CrispySpacing.lg),

            // Countdown.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 18, color: timerColor),
                const SizedBox(width: CrispySpacing.xs),
                Text(
                  'Expires in $timerLabel',
                  style: tt.bodyMedium?.copyWith(color: timerColor),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.xl),

            // Buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FocusWrapper(
                  onSelect: onCancel,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                FocusWrapper(
                  onSelect: onRestart,
                  child: FilledButton(
                    onPressed: onRestart,
                    child: const Text('New code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Server selector ──────────────────────────────────────────────────────

class _ServerSelector extends StatelessWidget {
  const _ServerSelector({
    required this.servers,
    required this.onSelect,
    required this.onCancel,
  });

  final List<PlexOAuthServer> servers;
  final void Function(PlexOAuthServer) onSelect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(CrispySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select a server',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.lg),
            ...servers.map(
              (server) => Padding(
                padding: const EdgeInsets.only(bottom: CrispySpacing.sm),
                child: FocusWrapper(
                  onSelect: () => onSelect(server),
                  semanticLabel: 'Select server',
                  child: InkWell(
                    onTap: () => onSelect(server),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CrispyRadius.tv),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(CrispySpacing.md),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(CrispyRadius.tv),
                        ),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.dns_outlined, color: cs.primary, size: 24),
                          const SizedBox(width: CrispySpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  server.name,
                                  style: tt.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  server.baseUrl,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (server.owned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.sm,
                                vertical: CrispySpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(CrispyRadius.tv),
                                ),
                              ),
                              child: Text(
                                'Owned',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CrispySpacing.md),
            OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}

// ── Error body ───────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(CrispySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: cs.error),
            const SizedBox(height: CrispySpacing.lg),
            Text(
              'Plex sign-in failed',
              style: tt.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FocusWrapper(
                  onSelect: onCancel,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                FocusWrapper(
                  onSelect: onRetry,
                  child: FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
