import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profiles/data/profile_service.dart';
import 'vod_service_providers.dart';

/// Loads favorite category names for a profile + type.
///
/// Usage:
/// ```dart
/// final favCats = ref.watch(
///   favoriteCategoriesProvider('vod'),
/// );
/// ```
final favoriteCategoriesProvider = FutureProvider.family<Set<String>, String>((
  ref,
  categoryType,
) async {
  final repo = ref.watch(vodRepositoryProvider);
  final pid =
      ref
          .read(profileServiceProvider.notifier)
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          .state
          .value
          ?.activeProfileId;
  if (pid == null) return {};
  final names = await repo.getFavoriteCategories(pid, categoryType);
  return names.toSet();
});

/// Toggle a category's favorite status and invalidate the
/// corresponding [favoriteCategoriesProvider].
Future<void> toggleFavoriteCategory(
  WidgetRef ref,
  String categoryType,
  String categoryName,
) async {
  final repo = ref.read(vodRepositoryProvider);
  final pid =
      ref
          .read(profileServiceProvider.notifier)
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          .state
          .value
          ?.activeProfileId;
  if (pid == null) return;

  final current = ref.read(favoriteCategoriesProvider(categoryType));
  final favs = current.asData?.value ?? {};

  if (favs.contains(categoryName)) {
    await repo.removeFavoriteCategory(pid, categoryType, categoryName);
  } else {
    await repo.addFavoriteCategory(pid, categoryType, categoryName);
  }
}
