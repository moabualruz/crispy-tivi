import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/crispy_animation.dart';
import '../theme/crispy_spacing.dart';

// ── Connectivity state ────────────────────────────────────────────────────────

/// The current connectivity status.
enum _ConnectivityStatus {
  /// Device is online.
  online,

  /// Device is offline.
  offline,

  /// Connection just restored (shows "restored" message transiently).
  restored,
}

/// Provider that streams connectivity status changes.
///
/// Uses [connectivity_plus] to monitor network state. Emits
/// [_ConnectivityStatus.offline] when all connections are lost and
/// [_ConnectivityStatus.restored] for 3 seconds when reconnected.
final _connectivityStatusProvider = StreamProvider<_ConnectivityStatus>((
  ref,
) async* {
  final connectivity = Connectivity();

  // Seed with the initial result.
  final initial = await connectivity.checkConnectivity();
  var isOnline = _isConnected(initial);
  yield isOnline ? _ConnectivityStatus.online : _ConnectivityStatus.offline;

  await for (final result in connectivity.onConnectivityChanged) {
    final nowOnline = _isConnected(result);
    if (nowOnline == isOnline) continue;
    isOnline = nowOnline;

    if (nowOnline) {
      // Briefly show "restored" before returning to online (hidden) state.
      yield _ConnectivityStatus.restored;
      await Future<void>.delayed(const Duration(seconds: 3));
      yield _ConnectivityStatus.online;
    } else {
      yield _ConnectivityStatus.offline;
    }
  }
});

bool _isConnected(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

// ── Banner widget ─────────────────────────────────────────────────────────────

/// Slim 28 dp banner shown when the device loses internet connectivity.
///
/// Displays an "offline" message while disconnected, then a transient
/// "Connection restored" confirmation for 3 seconds after reconnecting.
/// The banner is invisible when the device is fully online.
///
/// Place this near the top of the content area — inside [AppShell]'s
/// content column — so it appears beneath the navigation chrome.
class OfflineBanner extends ConsumerWidget {
  /// Creates the offline banner.
  ///
  /// [onReconnect] is called once when connectivity transitions from
  /// offline to restored. Use it to invalidate stale data providers
  /// so screens auto-refresh with fresh data.
  const OfflineBanner({super.key, this.onReconnect});

  /// Called when connectivity is restored after being offline.
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fire onReconnect callback on offline -> restored transition.
    ref.listen(_connectivityStatusProvider, (prev, next) {
      final prevStatus = prev?.whenData((s) => s).value;
      final nextStatus = next.whenData((s) => s).value;
      if (prevStatus == _ConnectivityStatus.offline &&
          nextStatus == _ConnectivityStatus.restored) {
        onReconnect?.call();
      }
    });

    final statusAsync = ref.watch(_connectivityStatusProvider);

    // While the stream initialises assume online to avoid a flash.
    final status = statusAsync.when(
      data: (s) => s,
      loading: () => _ConnectivityStatus.online,
      error: (err, stack) => _ConnectivityStatus.online,
    );

    final isVisible = status != _ConnectivityStatus.online;

    return AnimatedSize(
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
      child:
          isVisible ? _BannerContent(status: status) : const SizedBox.shrink(),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({required this.status});

  final _ConnectivityStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isRestored = status == _ConnectivityStatus.restored;
    final bgColor =
        isRestored
            ? colorScheme.secondaryContainer
            : colorScheme.errorContainer;
    final fgColor =
        isRestored
            ? colorScheme.onSecondaryContainer
            : colorScheme.onErrorContainer;

    return AnimatedContainer(
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
      height: 28,
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isRestored ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 14,
            color: fgColor,
          ),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            isRestored
                ? context.l10n.offlineConnectionRestored
                : context.l10n.offlineNoConnection,
            style: textTheme.labelSmall?.copyWith(color: fgColor),
          ),
        ],
      ),
    );
  }
}
