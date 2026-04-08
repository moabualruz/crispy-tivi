import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [ProviderObserver] that counts per-provider rebuild/update events.
///
/// Useful in performance tests to assert that key providers stay below
/// rebuild thresholds during common user flows. Guarded by [kDebugMode]
/// so it has zero overhead in release builds.
///
/// ```dart
/// final observer = RebuildCountObserver();
/// final container = ProviderContainer(observers: [observer]);
/// // ... exercise providers ...
/// expect(observer.countFor('channelList'), lessThan(10));
/// ```
final class RebuildCountObserver extends ProviderObserver {
  final Map<String, int> _counts = {};

  /// Returns the update count for the provider identified by [name].
  ///
  /// Returns 0 if the provider has not been tracked yet.
  int countFor(String name) => _counts[name] ?? 0;

  /// Total number of updates across all tracked providers.
  int get totalUpdates => _counts.values.fold(0, (sum, count) => sum + count);

  /// Clears all recorded counts.
  void reset() => _counts.clear();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (!kDebugMode) return;
    final provider = context.provider;
    final key = provider.name ?? provider.runtimeType.toString();
    _counts[key] = (_counts[key] ?? 0) + 1;
  }
}
