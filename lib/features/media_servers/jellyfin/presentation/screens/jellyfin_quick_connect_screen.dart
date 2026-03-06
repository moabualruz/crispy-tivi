import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/core/network/network_timeouts.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/utils/date_format_utils.dart' show formatMmss;
import 'package:crispy_tivi/core/widgets/loading_state_widget.dart';
import 'package:crispy_tivi/core/widgets/focus_wrapper.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/media_server_api_client.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/screens/media_server_login_screen.dart';

// ── Quick Connect state ──────────────────────────────────────────────────

/// Phase of the Quick Connect flow.
enum _QcPhase {
  /// Initiating the session — waiting for a code from the server.
  initiating,

  /// Code displayed — polling for authorization.
  polling,

  /// Server confirmed the code was approved; exchanging for a token.
  exchanging,

  /// Flow complete — [PlaylistSource] ready.
  done,

  /// Unrecoverable error.
  error,
}

/// Immutable state for the Quick Connect flow.
class _QcState {
  const _QcState({
    required this.phase,
    this.code,
    this.secret,
    this.source,
    this.errorMessage,
    this.secondsRemaining,
  });

  final _QcPhase phase;

  /// Six-character code displayed to the user (e.g. `'AB12CD'`).
  final String? code;

  /// Secret token used to poll `/QuickConnect/Connect`.
  final String? secret;

  /// Authenticated source — non-null only in [_QcPhase.done].
  final PlaylistSource? source;

  /// Human-readable error message — non-null only in [_QcPhase.error].
  final String? errorMessage;

  /// Countdown seconds remaining (null when not yet started).
  final int? secondsRemaining;

  _QcState copyWith({
    _QcPhase? phase,
    String? code,
    String? secret,
    PlaylistSource? source,
    String? errorMessage,
    int? secondsRemaining,
  }) {
    return _QcState(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      secret: secret ?? this.secret,
      source: source ?? this.source,
      errorMessage: errorMessage ?? this.errorMessage,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
    );
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

/// Time-to-live for a Quick Connect session in seconds.
const int _kQcTtlSeconds = 120;

/// Poll interval in seconds.
const int _kQcPollIntervalSeconds = 3;

/// Notifier for the Jellyfin Quick Connect flow.
///
/// Family parameter: normalized server URL.
///
/// Lifecycle:
/// 1. [_QcPhase.initiating] — POST `/QuickConnect/Initiate` to get code +
///    secret.
/// 2. [_QcPhase.polling] — GET `/QuickConnect/Connect?secret=…` every 3 s.
/// 3. [_QcPhase.exchanging] — POST `/Users/AuthenticateWithQuickConnect` to
///    exchange the approved secret for an auth token.
/// 4. [_QcPhase.done] — [PlaylistSource] is stored and ready.
class _JellyfinQcNotifier extends AsyncNotifier<_QcState> {
  _JellyfinQcNotifier(this._serverUrl);

  /// The normalized server URL passed at construction time.
  final String _serverUrl;

  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsLeft = _kQcTtlSeconds;

  @override
  Future<_QcState> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
    });

    return _initiate();
  }

  // ── Initiation ──────────────────────────────────────────────────────────

  Future<_QcState> _initiate() async {
    final dio = _buildDio();
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$_serverUrl/QuickConnect/Initiate',
      );
      final data = response.data;
      if (data == null) {
        return _errorState('Server returned an empty response.');
      }

      final code = data['Code'] as String?;
      final secret = data['Secret'] as String?;

      if (code == null || secret == null) {
        return _errorState('Invalid Quick Connect response from server.');
      }

      _secondsLeft = _kQcTtlSeconds;
      _startCountdown();
      _startPolling(secret);

      return _QcState(
        phase: _QcPhase.polling,
        code: code,
        secret: secret,
        secondsRemaining: _secondsLeft,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403) {
        return _errorState(
          'Quick Connect is disabled on this Jellyfin server. '
          'Ask your administrator to enable it in the dashboard.',
        );
      }
      return _errorState(
        'Cannot reach the server. Check the URL and your network.',
      );
    } catch (e) {
      return _errorState(e.toString());
    }
  }

  // ── Countdown ───────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsLeft--;
      final current = state.asData?.value;
      if (current != null && current.phase == _QcPhase.polling) {
        state = AsyncData(current.copyWith(secondsRemaining: _secondsLeft));
      }
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        state = AsyncData(
          _errorState(
            'Quick Connect session expired. Tap "Try again" to get a new code.',
          ),
        );
      }
    });
  }

  // ── Polling ─────────────────────────────────────────────────────────────

  void _startPolling(String secret) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: _kQcPollIntervalSeconds),
      (_) => _poll(secret),
    );
  }

  Future<void> _poll(String secret) async {
    final dio = _buildDio();
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$_serverUrl/QuickConnect/Connect',
        queryParameters: {'secret': secret},
      );
      final data = response.data;
      if (data == null) return;

      final authenticated = data['Authenticated'] as bool? ?? false;
      if (!authenticated) return; // Not yet approved — keep polling.

      // Approved — stop timers and exchange for auth token.
      _pollTimer?.cancel();
      _countdownTimer?.cancel();

      state = AsyncData(
        (state.asData?.value ?? const _QcState(phase: _QcPhase.polling))
            .copyWith(phase: _QcPhase.exchanging),
      );

      await _exchange(secret);
    } catch (_) {
      // Non-fatal poll failure — retry on next tick.
    }
  }

  // ── Token exchange ───────────────────────────────────────────────────────

  Future<void> _exchange(String secret) async {
    final dio = _buildDio();
    try {
      // POST /Users/AuthenticateWithQuickConnect
      final authResponse = await dio.post<Map<String, dynamic>>(
        '$_serverUrl/Users/AuthenticateWithQuickConnect',
        data: {'Secret': secret},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final authData = authResponse.data;
      if (authData == null) {
        state = AsyncData(
          _errorState('Token exchange returned an empty response.'),
        );
        return;
      }

      // Build system info for name + id.
      final systemInfo =
          await MediaServerApiClient(
            dio,
            baseUrl: _serverUrl,
          ).getPublicSystemInfo();

      final user = authData['User'] as Map<String, dynamic>?;
      final token = authData['AccessToken'] as String?;

      if (user == null || token == null) {
        state = AsyncData(
          _errorState('Malformed authentication response from server.'),
        );
        return;
      }

      final source = PlaylistSource(
        id: systemInfo.id,
        name: systemInfo.serverName,
        url: _serverUrl,
        type: PlaylistSourceType.jellyfin,
        username: user['Name'] as String?,
        userId: user['Id'] as String?,
        accessToken: token,
        deviceId: MediaServerLoginScreen.kDeviceId,
      );

      state = AsyncData(_QcState(phase: _QcPhase.done, source: source));
    } catch (e) {
      state = AsyncData(
        _errorState('Failed to exchange Quick Connect token: $e'),
      );
    }
  }

  // ── Restart ─────────────────────────────────────────────────────────────

  /// Cancels the current session and starts a new one.
  Future<void> restart() async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    state = const AsyncLoading();
    final next = await _initiate();
    state = AsyncData(next);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Dio _buildDio() {
    return Dio(
      BaseOptions(
        connectTimeout: NetworkTimeouts.fastConnectTimeout,
        receiveTimeout: NetworkTimeouts.fastReceiveTimeout,
      ),
    );
  }

  _QcState _errorState(String message) {
    return _QcState(phase: _QcPhase.error, errorMessage: message);
  }
}

/// Provider for the Jellyfin Quick Connect notifier, keyed by server URL.
///
/// Use [autoDispose] to cancel polling timers when the screen is popped.
final jellyfinQuickConnectProvider = AsyncNotifierProvider.autoDispose
    .family<_JellyfinQcNotifier, _QcState, String>(
      (arg) => _JellyfinQcNotifier(arg),
    );

// ── Screen ────────────────────────────────────────────────────────────────

/// TV-friendly Quick Connect login screen.
///
/// Displays a large 6-character code that the user enters on another
/// Jellyfin client (browser, mobile) to authenticate without typing
/// credentials on a TV remote. Implements JF-FE-01 / MSB-FE-04.
///
/// Navigation: pushed from [JellyfinLoginScreen] via an "Use Quick Connect"
/// button. On success, navigates to `/jellyfin/home`.
class JellyfinQuickConnectScreen extends ConsumerWidget {
  const JellyfinQuickConnectScreen({super.key, required this.serverUrl});

  /// Normalized Jellyfin server URL (e.g. `http://192.168.1.10:8096`).
  final String serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(jellyfinQuickConnectProvider(serverUrl));

    // When done — save source and navigate to home.
    ref.listen(jellyfinQuickConnectProvider(serverUrl), (_, next) {
      final data = next.asData?.value;
      if (data?.phase == _QcPhase.done && data?.source != null) {
        ref.read(settingsNotifierProvider.notifier).addSource(data!.source!);
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${data.source!.name}')),
        );
      }
    });

    return Scaffold(
      key: TestKeys.jellyfinQuickConnectScreen,
      appBar: AppBar(title: const Text('Jellyfin Quick Connect')),
      body: asyncState.when(
        loading: () => const LoadingStateWidget(),
        error:
            (e, _) => _ErrorBody(message: e.toString(), serverUrl: serverUrl),
        data: (qcState) => _QcBody(qcState: qcState, serverUrl: serverUrl),
      ),
    );
  }
}

// ── Body variants ────────────────────────────────────────────────────────

class _QcBody extends ConsumerWidget {
  const _QcBody({required this.qcState, required this.serverUrl});

  final _QcState qcState;
  final String serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (qcState.phase) {
      _QcPhase.initiating => const LoadingStateWidget(),
      _QcPhase.polling => _CodeDisplay(
        code: qcState.code ?? '------',
        secondsRemaining: qcState.secondsRemaining ?? _kQcTtlSeconds,
        serverUrl: serverUrl,
      ),
      _QcPhase.exchanging => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: CrispySpacing.md),
            Text('Authenticating…'),
          ],
        ),
      ),
      _QcPhase.done => const Center(
        child: Icon(Icons.check_circle_outline, size: 72),
      ),
      _QcPhase.error => _ErrorBody(
        message: qcState.errorMessage ?? 'An error occurred.',
        serverUrl: serverUrl,
      ),
    };
  }
}

// ── Code display ─────────────────────────────────────────────────────────

class _CodeDisplay extends ConsumerWidget {
  const _CodeDisplay({
    required this.code,
    required this.secondsRemaining,
    required this.serverUrl,
  });

  final String code;
  final int secondsRemaining;
  final String serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final timeString = formatMmss(secondsRemaining);
    final isAlmostExpired = secondsRemaining <= 30;
    final timerColor = isAlmostExpired ? cs.error : cs.onSurfaceVariant;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(CrispySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon.
            Icon(Icons.cast_connected, size: 56, color: cs.primary),
            const SizedBox(height: CrispySpacing.lg),

            // Instruction.
            Text(
              'Open a Jellyfin client on your phone or browser,\n'
              'go to Settings › Quick Connect, and enter this code:',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.xl),

            // Code display card.
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
                code,
                style: tt.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: cs.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: CrispySpacing.lg),

            // Countdown timer.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 18, color: timerColor),
                const SizedBox(width: CrispySpacing.xs),
                Text(
                  'Expires in $timeString',
                  style: tt.bodyMedium?.copyWith(color: timerColor),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.xl),

            // Cancel / regenerate buttons.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FocusWrapper(
                  onSelect: () => Navigator.of(context).pop(),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                FocusWrapper(
                  onSelect:
                      () =>
                          ref
                              .read(
                                jellyfinQuickConnectProvider(
                                  serverUrl,
                                ).notifier,
                              )
                              .restart(),
                  child: FilledButton(
                    onPressed:
                        () =>
                            ref
                                .read(
                                  jellyfinQuickConnectProvider(
                                    serverUrl,
                                  ).notifier,
                                )
                                .restart(),
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

// ── Error body ───────────────────────────────────────────────────────────

class _ErrorBody extends ConsumerWidget {
  const _ErrorBody({required this.message, required this.serverUrl});

  final String message;
  final String serverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'Quick Connect failed',
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
                  onSelect: () => Navigator.of(context).pop(),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                FocusWrapper(
                  onSelect:
                      () =>
                          ref
                              .read(
                                jellyfinQuickConnectProvider(
                                  serverUrl,
                                ).notifier,
                              )
                              .restart(),
                  child: FilledButton(
                    onPressed:
                        () =>
                            ref
                                .read(
                                  jellyfinQuickConnectProvider(
                                    serverUrl,
                                  ).notifier,
                                )
                                .restart(),
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
