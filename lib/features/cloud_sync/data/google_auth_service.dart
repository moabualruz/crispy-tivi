import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;

/// OAuth scopes required for Google Drive app data access.
class CloudSyncScopes {
  /// Access to app-specific folder only.
  ///
  /// Files stored here are NOT visible to the user in their Drive.
  /// Files are automatically deleted when the app is uninstalled.
  static const driveAppData = 'https://www.googleapis.com/auth/drive.appdata';

  /// List of all required scopes.
  static const all = [driveAppData];
}

/// Service for handling Google OAuth 2.0 authentication.
///
/// Wraps [GoogleSignIn] and provides authenticated HTTP clients
/// for Google Drive API access.
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: CloudSyncScopes.all);

  final GoogleSignIn _googleSignIn;

  /// Currently signed-in account.
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Whether a user is currently signed in.
  bool get isSignedIn => currentUser != null;

  /// Signs in the user with Google.
  ///
  /// Returns the signed-in account, or null if cancelled.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      // Check if already signed in silently.
      final existingUser = await _googleSignIn.signInSilently();
      if (existingUser != null) {
        debugPrint('CloudSync: Restored existing session');
        return existingUser;
      }

      // Prompt interactive sign-in.
      final user = await _googleSignIn.signIn();
      if (user != null) {
        debugPrint('CloudSync: Signed in as ${user.email}');
      }
      return user;
    } catch (e) {
      debugPrint('CloudSync: Sign-in error: $e');
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('CloudSync: Signed out');
    } catch (e) {
      debugPrint('CloudSync: Sign-out error: $e');
      rethrow;
    }
  }

  /// Disconnects the user and revokes access.
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      debugPrint('CloudSync: Disconnected and revoked access');
    } catch (e) {
      debugPrint('CloudSync: Disconnect error: $e');
      rethrow;
    }
  }

  /// Gets an authenticated HTTP client for Google API calls.
  ///
  /// Returns null if not signed in.
  Future<http.Client?> getAuthenticatedClient() async {
    final account = currentUser;
    if (account == null) {
      debugPrint('CloudSync: Cannot get client - not signed in');
      return null;
    }

    try {
      final auth = await account.authentication;
      if (auth.accessToken == null) {
        debugPrint('CloudSync: No access token available');
        return null;
      }

      // Create credentials from the access token.
      final credentials = gauth.AccessCredentials(
        gauth.AccessToken(
          'Bearer',
          auth.accessToken!,
          // Token expiry - Google tokens typically expire in 1 hour.
          // The client will handle refresh automatically.
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null, // No refresh token needed - GoogleSignIn handles refresh
        CloudSyncScopes.all,
      );

      return gauth.authenticatedClient(http.Client(), credentials);
    } catch (e) {
      debugPrint('CloudSync: Error getting authenticated client: $e');
      return null;
    }
  }

  /// Refreshes the authentication if needed.
  Future<bool> refreshAuth() async {
    try {
      final account = currentUser;
      if (account == null) return false;

      // Request new authentication tokens.
      await account.authentication;
      return true;
    } catch (e) {
      debugPrint('CloudSync: Auth refresh error: $e');
      return false;
    }
  }

  /// Attempts to restore a previous session silently.
  Future<GoogleSignInAccount?> tryRestoreSession() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('CloudSync: Silent sign-in failed: $e');
      return null;
    }
  }
}
