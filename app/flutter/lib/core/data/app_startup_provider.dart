import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/settings_notifier.dart';
import '../../features/profiles/data/profile_service.dart';

/// Eagerly loads all critical data at app startup.
///
/// Watched by the root widget; while loading, a branded splash
/// screen is shown. Once resolved, [settingsNotifierProvider]
/// and [profileServiceProvider] are guaranteed available via
/// `requireValue` — no loading guards needed in the router.
final appStartupProvider = FutureProvider<void>((ref) async {
  // Load settings and profiles in parallel.
  await Future.wait([
    ref.watch(settingsNotifierProvider.future),
    ref.watch(profileServiceProvider.future),
  ]);
});
