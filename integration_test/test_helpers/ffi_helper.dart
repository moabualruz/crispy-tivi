import 'package:crispy_tivi/src/rust/frb_generated.dart';

/// Idempotent helper to initialize Rust backend state via FFI.
/// Ensures that `RustLib.init()` is safely called only once across modular test suites.
abstract class FfiTestHelper {
  static bool _hasInitialized = false;

  /// Ensure the Rust backend is initialized.
  static Future<void> ensureRustInitialized() async {
    if (!_hasInitialized) {
      await RustLib.init();
      _hasInitialized = true;
    }
  }

  /// Mock state preparation that simulates setting up local SQLite databases.
  /// Replace/augment with actual mock FFI calls if needed for your environment.
  static Future<void> setupGuestProfileBackendState() async {
    await ensureRustInitialized();
    // Simulate FFI backend creation of a guest profile.
    // e.g. await RustLib.api.createGuestProfile();
  }

  static Future<void> setupSettingsBackendState() async {
    await ensureRustInitialized();
  }

  static Future<void> setupNavigationBackendState() async {
    await ensureRustInitialized();
  }
}
