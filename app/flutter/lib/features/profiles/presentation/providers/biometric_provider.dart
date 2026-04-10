import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_service_providers.dart';

// FE-PS-05

/// Per-profile biometric authentication preference.
///
/// Stores whether the user has enabled "Use Biometric" for each profile
/// (indexed by profile ID).
final biometricPreferenceProvider =
    AsyncNotifierProvider<BiometricPreferenceNotifier, Map<String, bool>>(
      BiometricPreferenceNotifier.new,
    );

/// Notifier managing per-profile biometric-enable flags.
///
/// FE-PS-05: Key = profile ID, value = whether biometric auth is enabled.
class BiometricPreferenceNotifier extends AsyncNotifier<Map<String, bool>> {
  static const _prefsKey = 'biometric_preferences_v1';
  final _localAuth = LocalAuthentication();

  @override
  Future<Map<String, bool>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return JsonPrefsCodec.readBoolMap(prefs, _prefsKey);
  }

  /// Returns true if biometric auth is enabled for [profileId].
  bool isEnabled(String profileId) => state.value?[profileId] ?? false;

  /// Toggles biometric auth preference for [profileId].
  Future<void> toggle(String profileId) async {
    final currentState = state.value ?? <String, bool>{};
    final currentStatus = currentState[profileId] ?? false;
    await set(profileId, enabled: !currentStatus);
  }

  /// Explicitly sets the biometric preference for [profileId].
  Future<void> set(String profileId, {required bool enabled}) async {
    final currentState = <String, bool>{...?state.value};
    currentState[profileId] = enabled;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await JsonPrefsCodec.writeBoolMap(prefs, _prefsKey, currentState);

    state = AsyncData(currentState);
  }

  /// Attempts to authenticate the user biometrically.
  /// Returns a cryptographic-like token if successful, or null if it fails.
  ///
  /// In a real implementation with token validation cryptography in Rust,
  /// we would pass the biometric success result to Rust to generate
  /// or unlock a secure session token.
  Future<String?> attemptBiometric(String reason) async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) return null;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock profile.',
        biometricOnly: true,
      );

      if (didAuthenticate) {
        // Generate a per-session token from the current timestamp.
        // Deferred security hardening: replace this with a Rust FFI-backed
        // HMAC/session-token flow before treating biometrics as credential
        // material outside this in-process unlock path.
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        return 'bio_session_${timestamp.hashCode.toRadixString(36)}';
      }
    } catch (e) {
      // Error handling for local_auth
      return null;
    }
    return null;
  }
}
