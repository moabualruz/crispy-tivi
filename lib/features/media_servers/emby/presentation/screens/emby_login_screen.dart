import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/iptv/application/playlist_sync_service.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/widgets/media_server_action_row.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/widgets/user_avatar_tile.dart';
import 'package:crispy_tivi/features/media_servers/shared/utils/media_server_auth.dart';
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
///
/// [url] is already normalized by [MediaServerLoginScreen] before
/// this callback is invoked.
Future<ServerConnectionInfo> _testConnection(String url) async {
  final dio = Dio(BaseOptions(baseUrl: url));
  dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(
    MediaServerLoginScreen.kDeviceId,
  );

  final client = MediaServerApiClient(dio, baseUrl: url);
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
    handleMediaServerUrlChanged(
      ref: ref,
      rawUrl: raw,
      currentResolved: _resolvedUrl,
      onChanged: (v) => setState(() => _resolvedUrl = v),
    );
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
      dio.options.headers['X-Emby-Authorization'] = embyAuthHeader(
        MediaServerLoginScreen.kDeviceId,
      );

      final source = await _authenticate(dio, _resolvedUrl, username, pin);

      if (!mounted) return;
      ref.read(settingsNotifierProvider.notifier).addSource(source);
      unawaited(ref.read(playlistSyncServiceProvider).syncSource(source));
      if (!mounted) return;
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
                MediaServerUserPickerRow(
                  serverUrl: _resolvedUrl,
                  onUserSelected: _onPublicUserSelected,
                  showPinBadge: true,
                ),
              // FE-EB-03: PIN login row
              _PinLoginRow(onLoginWithPin: _loginWithPin),
            ],
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
    return MediaServerActionRow(
      child: TextButton.icon(
        onPressed: onLoginWithPin,
        icon: const Icon(Icons.pin_outlined, size: 18),
        label: const Text('Login with PIN'),
      ),
    );
  }
}
