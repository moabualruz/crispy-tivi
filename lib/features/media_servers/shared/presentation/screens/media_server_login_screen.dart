import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/widgets/async_filled_button.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/widgets/sync_progress_dialog.dart';
import 'package:crispy_tivi/core/widgets/safe_focus_scope.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/error_sanitizer.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';

/// Result of a server connectivity test.
///
/// Returned by [TestConnectionCallback] on success. Carries the
/// server name and version string to display to the user.
class ServerConnectionInfo {
  const ServerConnectionInfo({required this.serverName, required this.version});

  /// Human-readable server name (e.g. "My Emby Server").
  final String serverName;

  /// Server version string (e.g. "4.8.7.0").
  final String version;
}

/// Callback that probes the server at [url] without authenticating.
///
/// Returns [ServerConnectionInfo] on success, or throws on failure.
typedef TestConnectionCallback =
    Future<ServerConnectionInfo> Function(String url);

/// Visual state of the test-connection indicator.
enum _TestState { idle, loading, success, failure }

/// Shared authentication logic for Emby and Jellyfin servers.
///
/// Both servers expose an identical wire protocol — this function
/// handles the common authenticate-by-name flow. Callers supply the
/// [type] to distinguish the resulting [PlaylistSource].
///
/// Used by [EmbyLoginScreen] and [JellyfinLoginScreen] to avoid
/// duplicating the same 15-line authenticate body in each file.
Future<PlaylistSource> authenticateMediaServer(
  Dio dio,
  String url,
  String username,
  String password,
  PlaylistSourceType type,
) async {
  final client = MediaServerApiClient(dio, baseUrl: url);
  final systemInfo = await client.getPublicSystemInfo();
  final authResult = await client.authenticateByName({
    'Username': username,
    'Pw': password,
  });
  return PlaylistSource(
    id: systemInfo.id,
    name: systemInfo.serverName,
    url: url,
    type: type,
    username: authResult.user.name,
    userId: authResult.user.id,
    accessToken: authResult.accessToken,
    deviceId: MediaServerLoginScreen.kDeviceId,
  );
}

/// Callback that performs server-specific authentication.
///
/// Receives a pre-configured [Dio] instance (base URL + auth header set)
/// and raw field values. Must return a [PlaylistSource] on success or
/// throw on failure.
///
/// When [MediaServerLoginScreen.showUsernameField] is `false`, [username]
/// is always an empty string.
typedef MediaServerAuthenticate =
    Future<PlaylistSource> Function(
      Dio dio,
      String url,
      String username,
      String password,
    );

/// Maximum width of the login form.
const double kLoginFormMaxWidth = 400;

/// Shared login form for Emby, Jellyfin, Plex, and any future media server.
///
/// Handles URL normalization, form validation, loading state, error
/// display, and source persistence. Server-specific logic is injected
/// via [authenticate].
///
/// For token-based servers (e.g. Plex), set [showUsernameField] to `false`
/// and customize [credentialLabel], [credentialHint], [credentialHelperText],
/// and [obscureCredential] for the single credential field.
class MediaServerLoginScreen extends ConsumerStatefulWidget {
  const MediaServerLoginScreen({
    super.key,
    required this.serverName,
    required this.authenticate,
    this.urlHint = 'http://192.168.1.5:8096',
    this.showUsernameField = true,
    this.credentialLabel = 'Password',
    this.credentialHint,
    this.credentialHelperText,
    this.credentialIcon = Icons.lock,
    this.obscureCredential = true,
    this.testConnection,
    this.onUrlChanged,
    this.externalUsernameController,
    this.bodyFooter,
  });

  /// Device identifier sent in the MediaBrowser auth header and stored
  /// in [PlaylistSource.deviceId].
  ///
  /// Varies by platform so the media server can distinguish clients
  /// (e.g. Android TV vs. web browser vs. Windows desktop).
  static String get kDeviceId {
    if (kIsWeb) return 'crispy_tivi_web';
    if (Platform.isAndroid) return 'crispy_tivi_android';
    if (Platform.isIOS) return 'crispy_tivi_ios';
    if (Platform.isWindows) return 'crispy_tivi_windows';
    if (Platform.isLinux) return 'crispy_tivi_linux';
    if (Platform.isMacOS) return 'crispy_tivi_macos';
    return 'crispy_tivi';
  }

  /// Display name shown in the AppBar, e.g. `'Emby'` or `'Jellyfin'`.
  final String serverName;

  /// Server-specific auth logic — creates the API client, verifies the
  /// server, authenticates, and returns a ready-to-save [PlaylistSource].
  final MediaServerAuthenticate authenticate;

  /// Hint text for the Server URL field.
  final String urlHint;

  /// Whether to show the Username field.
  ///
  /// Set to `false` for token-based servers (e.g. Plex). When hidden,
  /// the [authenticate] callback receives an empty string for [username].
  final bool showUsernameField;

  /// Label for the credential field (Password or Token).
  final String credentialLabel;

  /// Optional hint text for the credential field.
  final String? credentialHint;

  /// Optional helper text shown below the credential field.
  final String? credentialHelperText;

  /// Icon for the credential field.
  final IconData credentialIcon;

  /// Whether to obscure the credential field text.
  final bool obscureCredential;

  /// Optional callback to test server reachability before login.
  ///
  /// When provided, a "Test Connection" button is shown below the
  /// Server URL field. On success the server name and version are
  /// displayed. On failure an inline error is shown.
  ///
  /// Set this for servers that expose an unauthenticated health
  /// endpoint (e.g. Emby/Jellyfin `/System/Info/Public`).
  final TestConnectionCallback? testConnection;

  /// Optional callback invoked whenever the Server URL field changes.
  ///
  /// Used by [JellyfinLoginScreen] to trigger the public-user list
  /// fetch (FE-JF-02) as the user types the server URL.
  final ValueChanged<String>? onUrlChanged;

  /// Optional external controller for the Username field.
  ///
  /// When provided, this controller is used instead of the internal one.
  /// Allows the parent widget to programmatically fill the username
  /// (e.g. by tapping a user avatar in the public-user picker).
  final TextEditingController? externalUsernameController;

  /// Optional widget displayed below the login form (inside the scroll
  /// body but outside the max-width container).
  ///
  /// Used by [JellyfinLoginScreen] to inject the public-user picker row
  /// (FE-JF-02) below the form without duplicating form logic.
  final WidgetBuilder? bodyFooter;

  @override
  ConsumerState<MediaServerLoginScreen> createState() =>
      _MediaServerLoginScreenState();
}

class _MediaServerLoginScreenState
    extends ConsumerState<MediaServerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  late final TextEditingController _userCtrl;
  final _credCtrl = TextEditingController();

  /// Whether [_userCtrl] was provided externally (not owned by this state).
  bool _externalUserCtrl = false;

  bool _isLoading = false;
  String? _error;

  // ── Test-connection state ──────────────────────────────────
  _TestState _testState = _TestState.idle;
  ServerConnectionInfo? _serverInfo;
  String? _testError;

  @override
  void initState() {
    super.initState();
    if (widget.externalUsernameController != null) {
      _userCtrl = widget.externalUsernameController!;
      _externalUserCtrl = true;
    } else {
      _userCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    // Only dispose the username controller if we created it.
    if (!_externalUserCtrl) _userCtrl.dispose();
    _credCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnectionTap() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testState = _TestState.failure;
        _testError = 'Enter the server URL first.';
        _serverInfo = null;
      });
      return;
    }

    setState(() {
      _testState = _TestState.loading;
      _testError = null;
      _serverInfo = null;
    });

    try {
      final normalized = ref
          .read(crispyBackendProvider)
          .normalizeServerUrl(url);
      final info = await widget.testConnection!(normalized);
      if (mounted) {
        setState(() {
          _testState = _TestState.success;
          _serverInfo = info;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testState = _TestState.failure;
          _testError = sanitizeError(e);
        });
      }
    }
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = ref
          .read(crispyBackendProvider)
          .normalizeServerUrl(_urlCtrl.text);

      final dio = Dio(BaseOptions(baseUrl: url));
      dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(
        MediaServerLoginScreen.kDeviceId,
      );

      final source = await widget.authenticate(
        dio,
        url,
        widget.showUsernameField ? _userCtrl.text.trim() : '',
        _credCtrl.text.trim(),
      );

      if (mounted) {
        ref.read(settingsNotifierProvider.notifier).addSource(source);
        // Show sync progress dialog — awaits completion or user cancel.
        final success = await SyncProgressDialog.show(context, source);
        if (mounted) {
          context.pop();
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connected to ${source.name}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = sanitizeError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: TestKeys.mediaServerLoginScreen,
      appBar: AppBar(title: Text('Connect ${widget.serverName}')),
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: SafeFocusScope(
          restorationKey: 'media_server_login',
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: kLoginFormMaxWidth,
                    ),
                    padding: const EdgeInsets.all(CrispySpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(CrispySpacing.sm),
                              margin: const EdgeInsets.only(
                                bottom: CrispySpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          TextFormField(
                            controller: _urlCtrl,
                            decoration: InputDecoration(
                              labelText: 'Server URL',
                              hintText: widget.urlHint,
                              prefixIcon: const Icon(Icons.dns),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            onChanged: (value) {
                              // Reset test-connection indicator when URL changes.
                              if (widget.testConnection != null &&
                                  _testState != _TestState.idle) {
                                setState(() => _testState = _TestState.idle);
                              }
                              // Notify parent of URL change (e.g. for user picker).
                              widget.onUrlChanged?.call(value);
                            },
                            validator:
                                (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                          ),
                          if (widget.testConnection != null) ...[
                            const SizedBox(height: CrispySpacing.sm),
                            _TestConnectionButton(
                              state: _testState,
                              serverInfo: _serverInfo,
                              testError: _testError,
                              onTest: _testConnectionTap,
                            ),
                          ],
                          if (widget.showUsernameField) ...[
                            const SizedBox(height: CrispySpacing.md),
                            TextFormField(
                              controller: _userCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              validator:
                                  (v) =>
                                      v == null || v.isEmpty
                                          ? 'Required'
                                          : null,
                            ),
                          ],
                          const SizedBox(height: CrispySpacing.md),
                          TextFormField(
                            controller: _credCtrl,
                            decoration: InputDecoration(
                              labelText: widget.credentialLabel,
                              hintText: widget.credentialHint,
                              helperText: widget.credentialHelperText,
                              prefixIcon: Icon(widget.credentialIcon),
                              border: const OutlineInputBorder(),
                            ),
                            obscureText: widget.obscureCredential,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _connect(),
                            validator:
                                (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: CrispySpacing.lg),
                          AsyncFilledButton(
                            isLoading: _isLoading,
                            label: 'Connect',
                            onPressed: _connect,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Optional slot for server-specific content below the form.
                if (widget.bodyFooter != null) widget.bodyFooter!(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Test-connection UI ────────────────────────────────────────────────────

/// Inline "Test Connection" button and status indicator.
///
/// Shows a text button when idle, a progress indicator while loading,
/// a green success chip with server name + version, or a red error chip.
class _TestConnectionButton extends StatelessWidget {
  const _TestConnectionButton({
    required this.state,
    required this.onTest,
    this.serverInfo,
    this.testError,
  });

  final _TestState state;
  final VoidCallback onTest;
  final ServerConnectionInfo? serverInfo;
  final String? testError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return switch (state) {
      _TestState.idle => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.wifi_tethering, size: 18),
          label: const Text('Test Connection'),
          onPressed: onTest,
        ),
      ),
      _TestState.loading => const Padding(
        padding: EdgeInsets.symmetric(vertical: CrispySpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: CrispySpacing.sm),
            Text('Testing connection…'),
          ],
        ),
      ),
      _TestState.success => _StatusChip(
        icon: Icons.check_circle_outline,
        iconColor: cs.primary,
        backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
        label: '${serverInfo!.serverName}  •  v${serverInfo!.version}',
        labelColor: cs.onPrimaryContainer,
        trailing: TextButton(onPressed: onTest, child: const Text('Re-test')),
      ),
      _TestState.failure => _StatusChip(
        icon: Icons.cancel_outlined,
        iconColor: cs.error,
        backgroundColor: cs.errorContainer.withValues(alpha: 0.35),
        label: testError ?? 'Connection failed.',
        labelColor: cs.onErrorContainer,
        trailing: TextButton(onPressed: onTest, child: const Text('Retry')),
      ),
    };
  }
}

/// Compact status row used by [_TestConnectionButton].
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.labelColor,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final Color labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: CrispySpacing.xs),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
