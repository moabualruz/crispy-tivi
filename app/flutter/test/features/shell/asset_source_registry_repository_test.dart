import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'asset source registry repository implements the retained interface',
    () {
      expect(
        const AssetSourceRegistryRepository(),
        isA<SourceRegistryRepository>(),
      );
    },
  );

  test('repository loads the Rust-owned source registry asset', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;

    const String source = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "m3u_url",
      "provider_type": "M3U URL",
      "family": "playlist",
      "connection_mode": "remote_url",
      "summary": "Remote playlist lane for standard IPTV providers.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
        {"id": "catch_up", "title": "Catch-up", "summary": "Catch-up lane", "supported": true},
        {"id": "search", "title": "Search", "summary": "Search lane", "supported": true}
      ],
      "health": {
        "status": "Healthy",
        "summary": "Playlist reachable.",
        "last_checked": "2 minutes ago",
        "last_sync": "2 minutes ago"
      },
      "auth": {
        "status": "Not required",
        "progress": "0%",
        "summary": "No credentials required.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Playlist URL", "XMLTV URL"],
        "helper_lines": ["Use a direct playlist URL."]
      },
      "import": {
        "status": "Ready",
        "progress": "100%",
        "summary": "Ready to import.",
        "primary_action": "Start import",
        "secondary_action": "Review"
      },
      "onboarding_hint": "Start with a direct playlist URL."
    },
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login with live, VOD, and EPG lanes.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
        {"id": "series", "title": "Series", "summary": "Series lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
        {"id": "catch_up", "title": "Catch-up", "summary": "Catch-up lane", "supported": true},
        {"id": "search", "title": "Search", "summary": "Search lane", "supported": true},
        {"id": "subtitles", "title": "Subtitles", "summary": "Subtitle lane", "supported": true},
        {"id": "tracks", "title": "Tracks", "summary": "Track lane", "supported": true}
      ],
      "health": {
        "status": "Needs auth",
        "summary": "Portal access waiting for credentials.",
        "last_checked": "Sync blocked",
        "last_sync": "Sync blocked"
      },
      "auth": {
        "status": "Needs auth",
        "progress": "0%",
        "summary": "Credentials required.",
        "primary_action": "Verify access",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Supports account-level refresh."]
      },
      "import": {
        "status": "Syncing",
        "progress": "20%",
        "summary": "Import in progress.",
        "primary_action": "Continue",
        "secondary_action": "Review"
      },
      "onboarding_hint": "Authenticate first."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Credentials",
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [
      {
        "step": "Source Type",
        "title": "Choose source type",
        "summary": "Pick the provider type first.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Source type"],
        "helper_lines": ["Keep provider-specific flow inside Settings."]
      },
      {
        "step": "Credentials",
        "title": "Verify access",
        "summary": "Credentials gate import.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Validation should happen before import."]
      }
    ],
    "provider_copy": [
      {
        "provider_key": "xtream",
        "provider_type": "Xtream",
        "title": "Xtream account",
        "summary": "Portal login with live, movies, series, and guide lanes.",
        "helper_lines": ["Supports account-level refresh."]
      }
    ]
  },
  "registry_notes": []
}
''';

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetSourceRegistryRepository.assetPath) {
        return const StringCodec().encodeMessage(source);
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    const AssetSourceRegistryRepository repository =
        AssetSourceRegistryRepository();
    final registry = await repository.load();

    expect(registry.providers.length, 2);
    expect(registry.selectedProvider.kind, SourceProviderKind.xtream);
    expect(registry.activeWizardStep, SourceWizardStep.credentials);
    expect(
      registry.selectedProvider.status.importStatus,
      SourceWorkflowState.syncing,
    );
    expect(
      registry
          .provider(SourceProviderKind.m3uUrl)
          .supports(SourceCapability.search),
      isTrue,
    );
    expect(
      registry.provider(SourceProviderKind.xtream).auth.primaryAction,
      'Verify access',
    );
  });
}
