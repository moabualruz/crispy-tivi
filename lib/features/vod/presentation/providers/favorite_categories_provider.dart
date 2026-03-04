import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../profiles/data/profile_service.dart';

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
  final cache = ref.watch(cacheServiceProvider);
  final pid =
      ref
          .read(profileServiceProvider.notifier)
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          .state
          .value
          ?.activeProfileId;
  if (pid == null) return {};
  final names = await cache.getFavoriteCategories(pid, categoryType);
  return names.toSet();
});

/// Toggle a category's favorite status and invalidate the
/// corresponding [favoriteCategoriesProvider].
Future<void> toggleFavoriteCategory(
  WidgetRef ref,
  String categoryType,
  String categoryName,
) async {
  final cache = ref.read(cacheServiceProvider);
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
    await cache.removeFavoriteCategory(pid, categoryType, categoryName);
  } else {
    await cache.addFavoriteCategory(pid, categoryType, categoryName);
  }
}

/// Returns categories sorted with favorites first.
List<String> sortCategoriesWithFavorites(
  List<String> categories,
  Set<String> favorites,
) {
  final favs = categories.where((c) => favorites.contains(c)).toList()..sort();
  final rest = categories.where((c) => !favorites.contains(c)).toList()..sort();
  return [...favs, ...rest];
}
