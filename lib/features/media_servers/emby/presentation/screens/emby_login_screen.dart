import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/utils/url_utils.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import '../providers/emby_providers.dart';
import '../widgets/emby_pin_login_dialog.dart';

// ── Shared helpers (same authenticate / testConnection as before) ─────────

Future<PlaylistSource> _authenticate(
  Dio dio,
  String url,
  String username,
  String password,
) => authenticateMediaServer(
  dio,
  url,
  username,
  password,
  PlaylistSourceType.emby,
);

/// Pings `/System/Info/Public` and returns server name + version.
///
/// Does not require authentication — Emby exposes this endpoint
/// publicly so the user can verify they have the right URL before
/// entering credentials.
Future<ServerConnectionInfo> _testConnection(String url) async {
  final normalized = normalizeServerUrl(url);
  final dio = Dio(BaseOptions(baseUrl: normalized));
  dio.options.headers['X-Emby-Authorization'] =
      'MediaBrowser Client="CrispyTivi", Device="CrispyTivi", '
      'DeviceId="${MediaServerLoginScreen.kDeviceId}", Version="0.1.0"';

  final client = MediaServerApiClient(dio, baseUrl: normalized);
  final info = await client.getPublicSystemInfo();
  return ServerConnectionInfo(
    serverName: info.serverName,
    version: info.version,
  );
}

/// Emby login screen with standard credential form, PIN login option,
/// and public-user avatar grid (FE-EB-02, FE-EB-03).
///
/// Extends [MediaServerLoginScreen] with:
/// - FE-EB-03: a "Login with PIN" text button that opens
///   [EmbyPinLoginDialog]. After PIN entry the dialog returns the PIN
///   string, which is passed as the password to the standard
///   authenticate flow (Emby accepts PIN as password).
/// - FE-EB-02: avatar tile grid of public users fetched from
///   `/Users/Public` (no auth). Tapping a tile auto-fills the
///   username field. If the user has a configured password a PIN
///   dialog is shown; otherwise login proceeds directly.
class EmbyLoginScreen extends ConsumerStatefulWidget {
  const EmbyLoginScreen({super.key});

  @override
  ConsumerState<EmbyLoginScreen> createState() => _EmbyLoginScreenState();
}

class _EmbyLoginScreenState extends ConsumerState<EmbyLoginScreen> {
  /// External username controller so the PIN flow can read the username.
  final _userCtrl = TextEditingController();

  /// External password controller so the public-user flow can clear it.
  final _passCtrl = TextEditingController();

  /// Normalized server URL, updated via [MediaServerLoginScreen.onUrlChanged].
  String _resolvedUrl = '';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onUrlChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      if (_resolvedUrl.isNotEmpty) setState(() => _resolvedUrl = '');
      return;
    }
    try {
      final normalized = normalizeServerUrl(trimmed);
      if (normalized != _resolvedUrl) setState(() => _resolvedUrl = normalized);
    } catch (_) {
      // Not yet a valid URL — ignore until the user finishes typing.
    }
  }

  /// Opens the PIN numpad dialog and, on confirmation, authenticates
  /// against the Emby server using the PIN as the password.
  ///
  /// Emby accepts the user PIN as the `Pw` field in the
  /// `AuthenticateByName` request — same wire format as a password.
  Future<void> _loginWithPin() async {
    if (!mounted) return;

    if (_resolvedUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the server URL first.')),
      );
      return;
    }

    final username = _userCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your username before using PIN.')),
      );
      return;
    }

    final pin = await showEmbyPinLoginDialog(context);
    if (pin == null || !mounted) return;

    try {
      final dio = Dio(BaseOptions(baseUrl: _resolvedUrl));
      dio.options.headers['X-Emby-Authorization'] =
          'MediaBrowser Client="CrispyTivi", Device="CrispyTivi", '
          'DeviceId="${MediaServerLoginScreen.kDeviceId}", Version="0.1.0"';

      final source = await _authenticate(dio, _resolvedUrl, username, pin);

      if (!mounted) return;
      ref.read(settingsNotifierProvider.notifier).addSource(source);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected to ${source.name}')));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().split('\n').first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// FE-EB-02: Called when the user taps a public-user avatar tile.
  ///
  /// Fills the username field. If the user has a configured password,
  /// opens the PIN dialog and authenticates with the PIN as password.
  /// Otherwise attempts a password-less login (empty password).
  Future<void> _onPublicUserSelected(MediaServerUser user) async {
    // FE-EB-02
    _userCtrl.text = user.name;

    if (!mounted) return;

    if (user.hasConfiguredPassword) {
      // Prompt for PIN / password before logging in.
      final pin = await showEmbyPinLoginDialog(context);
      if (pin == null || !mounted) return;
      _passCtrl.text = pin;
    } else {
      // No password — attempt login with empty password.
      _passCtrl.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaServerLoginScreen(
      serverName: 'Emby',
      authenticate: _authenticate,
      testConnection: _testConnection,
      externalUsernameController: _userCtrl,
      onUrlChanged: _onUrlChanged,
      bodyFooter:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // FE-EB-02: public user avatar grid (shown when URL is valid)
              if (_resolvedUrl.isNotEmpty)
                _EmbyPublicUserPicker(
                  serverUrl: _resolvedUrl,
                  onUserSelected: _onPublicUserSelected,
                ),
              // FE-EB-03: PIN login row
              _PinLoginRow(onLoginWithPin: _loginWithPin),
            ],
          ),
    );
  }
}

// ── FE-EB-02: Public user picker ──────────────────────────────────────────

/// FE-EB-02: Horizontal avatar grid of public Emby users.
///
/// Appears below the login form when a valid server URL is entered.
/// Tapping a tile auto-fills the username field (and optionally opens
/// the PIN dialog when the user has a configured password).
class _EmbyPublicUserPicker extends ConsumerWidget {
  const _EmbyPublicUserPicker({
    required this.serverUrl,
    required this.onUserSelected,
  });

  final String serverUrl;
  final Future<void> Function(MediaServerUser user) onUserSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FE-EB-02
    final usersAsync = ref.watch(embyPublicUsersProvider(serverUrl));

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return _PublicUserRow(
          users: users,
          serverUrl: serverUrl,
          onUserSelected: onUserSelected,
        );
      },
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: CrispySpacing.sm),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PublicUserRow extends StatelessWidget {
  const _PublicUserRow({
    required this.users,
    required this.serverUrl,
    required this.onUserSelected,
  });

  final List<MediaServerUser> users;
  final String serverUrl;
  final Future<void> Function(MediaServerUser user) onUserSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.lg,
        0,
        CrispySpacing.lg,
        CrispySpacing.sm,
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
                  onTap: () => onUserSelected(user),
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
    // FE-EB-02
    final cs = Theme.of(context).colorScheme;

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
              Stack(
                alignment: Alignment.bottomRight,
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
                  // PIN indicator badge when user has a password.
                  if (user.hasConfiguredPassword)
                    Container(
                      padding: const EdgeInsets.all(CrispySpacing.xxs),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.outline, width: 1),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 10,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
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

// ── FE-EB-03: PIN login row ───────────────────────────────────────────────

/// A subtle row shown below the login form offering PIN-based login.
class _PinLoginRow extends StatelessWidget {
  const _PinLoginRow({required this.onLoginWithPin});

  final VoidCallback onLoginWithPin;

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
          TextButton.icon(
            onPressed: onLoginWithPin,
            icon: const Icon(Icons.pin_outlined, size: 18),
            label: const Text('Login with PIN'),
          ),
        ],
      ),
    );
  }
}
