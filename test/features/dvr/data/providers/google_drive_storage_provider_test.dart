import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/dvr/data/providers/google_drive_storage_provider.dart';
import 'package:crispy_tivi/features/cloud_sync/data/google_auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class MockGoogleAuthService implements GoogleAuthService {
  @override
  Future<http.Client?> getAuthenticatedClient() async {
    // Return null to simulate not signed in
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async => null;

  @override
  Future<void> signOut() async {}

  @override
  bool get isSignedIn => false;

  @override
  GoogleSignInAccount? get currentUser => null;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> refreshAuth() async => true;

  @override
  Future<GoogleSignInAccount?> tryRestoreSession() async => null;
}

void main() {
  group('GoogleDriveStorageProvider Tests', () {
    late GoogleDriveStorageProvider provider;
    late MockGoogleAuthService authService;

    setUp(() {
      authService = MockGoogleAuthService();
      provider = GoogleDriveStorageProvider(authService: authService);
    });

    test(
      'initializes and testConnection fails gracefully when not signed in',
      () async {
        await provider.initialize({'folderId': 'my_folder'});

        final isConnected = await provider.testConnection();
        expect(isConnected, isFalse);
      },
    );
  });
}
