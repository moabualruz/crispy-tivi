import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Global loading indicator ──────────────────────────────────────────────────

/// Global loading indicator notifier.
///
/// When state is `true`, [AppShell] shows a thin [LinearProgressIndicator]
/// at the top of the screen. Feature providers can set this to communicate
/// long-running background work to the user.
///
/// Example:
/// ```dart
/// ref.read(globalLoadingProvider.notifier).setLoading(true);
/// await doSomethingAsync();
/// ref.read(globalLoadingProvider.notifier).setLoading(false);
/// ```
final globalLoadingProvider = NotifierProvider<GlobalLoadingNotifier, bool>(
  GlobalLoadingNotifier.new,
);

/// Controls the global loading indicator state.
class GlobalLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Sets the global loading state.
  void setLoading(bool value) => state = value;
}
