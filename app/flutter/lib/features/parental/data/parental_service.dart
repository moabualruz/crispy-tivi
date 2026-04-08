import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/data/crispy_backend.dart';
import '../../profiles/domain/entities/user_profile.dart';
import '../domain/content_rating.dart';

/// Settings key for master parental PIN.
const _masterPinKey = 'parental_master_pin';

/// State for parental controls.
class ParentalState {
  const ParentalState({this.hasMasterPin = false, this.isUnlocked = false});

  /// Whether a master PIN has been set.
  final bool hasMasterPin;

  /// Whether parental controls are currently unlocked for this session.
  final bool isUnlocked;

  ParentalState copyWith({bool? hasMasterPin, bool? isUnlocked}) {
    return ParentalState(
      hasMasterPin: hasMasterPin ?? this.hasMasterPin,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

/// Manages master parental PIN and content access controls.
class ParentalService extends AsyncNotifier<ParentalState> {
  late CacheService _cache;
  late CrispyBackend _backend;

  @override
  Future<ParentalState> build() async {
    _cache = ref.read(cacheServiceProvider);
    _backend = ref.read(crispyBackendProvider);
    final storedPin = await _cache.getSetting(_masterPinKey);
    return ParentalState(
      hasMasterPin: storedPin != null && storedPin.isNotEmpty,
    );
  }

  /// Sets or updates the master parental PIN.
  Future<void> setMasterPin(String pin) async {
    final hashed = await _backend.hashPin(pin);
    await _cache.setSetting(_masterPinKey, hashed);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(hasMasterPin: true, isUnlocked: true));
  }

  /// Verifies the master PIN.
  Future<bool> verifyMasterPin(String pin) async {
    final storedHash = await _cache.getSetting(_masterPinKey);
    if (storedHash == null || storedHash.isEmpty) return false;

    final isValid = await _backend.verifyPin(pin, storedHash);
    if (isValid) {
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(isUnlocked: true));
      }
    }
    return isValid;
  }

  /// Clears the master PIN (requires current PIN verification first).
  Future<bool> clearMasterPin(String currentPin) async {
    final isValid = await verifyMasterPin(currentPin);
    if (!isValid) return false;

    await _cache.removeSetting(_masterPinKey);
    final current = state.value;
    if (current == null) return true;
    state = AsyncData(current.copyWith(hasMasterPin: false, isUnlocked: false));
    return true;
  }

  /// Locks parental controls (requires re-authentication).
  void lock() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(isUnlocked: false));
  }

  /// Checks if content with the given rating is allowed for a profile.
  bool isContentAllowed(String? rating, UserProfile profile) {
    if (!profile.isRestricted) return true;

    final contentRating = ContentRatingLevel.fromString(rating);
    return contentRating.isAllowedFor(profile.ratingLevel);
  }

  /// Checks if content with a numeric rating value is allowed.
  bool isRatingValueAllowed(int ratingValue, UserProfile profile) {
    if (!profile.isRestricted) return true;
    return ratingValue <= profile.maxAllowedRating;
  }
}

/// Global parental service provider.
final parentalServiceProvider =
    AsyncNotifierProvider<ParentalService, ParentalState>(ParentalService.new);
