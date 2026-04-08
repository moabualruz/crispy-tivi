import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profiles/data/profile_service.dart';

/// Derived provider that extracts the active profile ID.
///
/// Returns `'default'` when no profile is selected.
final activeProfileIdProvider = Provider<String>((ref) {
  return ref.watch(profileServiceProvider).value?.activeProfileId ?? 'default';
});
