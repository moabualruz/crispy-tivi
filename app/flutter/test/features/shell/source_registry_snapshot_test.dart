import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'source registry snapshot parses provider lanes and onboarding state',
    () {
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
      "provider_key": "local_m3u",
      "provider_type": "local M3U",
      "family": "playlist",
      "connection_mode": "local_file",
      "summary": "On-device playlist lane.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
        {"id": "local_playlist", "title": "Local file", "summary": "File lane", "supported": true}
      ],
      "health": {
        "status": "Healthy",
        "summary": "Local file loaded.",
        "last_checked": "1 minute ago",
        "last_sync": "1 minute ago"
      },
      "auth": {
        "status": "Not required",
        "progress": "0%",
        "summary": "Local files do not require credentials.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Playlist file", "XMLTV file"],
        "helper_lines": ["Best for file-based source setup."]
      },
      "import": {
        "status": "Complete",
        "progress": "100%",
        "summary": "Local playlist import complete.",
        "primary_action": "Open sources",
        "secondary_action": "Review"
      },
      "onboarding_hint": "Choose a local file first."
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
    },
    {
      "provider_key": "stalker",
      "provider_type": "Stalker",
      "family": "portal",
      "connection_mode": "portal_device",
      "summary": "Portal-style source with live, series, and archive support.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
        {"id": "series", "title": "Series", "summary": "Series lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
        {"id": "catch_up", "title": "Catch-up", "summary": "Catch-up lane", "supported": true},
        {"id": "tracks", "title": "Tracks", "summary": "Track lane", "supported": true}
      ],
      "health": {
        "status": "Needs attention",
        "summary": "Refresh credentials before sync continues.",
        "last_checked": "5 minutes ago",
        "last_sync": "Sync blocked"
      },
      "auth": {
        "status": "Needs attention",
        "progress": "50%",
        "summary": "Refresh credentials before the source can sync again.",
        "primary_action": "Reconnect",
        "secondary_action": "Back",
        "field_labels": ["Portal URL", "MAC Address"],
        "helper_lines": ["Keep portal auth separate from import."]
      },
      "import": {
        "status": "Failed",
        "progress": "0%",
        "summary": "Sync blocked until auth is restored.",
        "primary_action": "Continue",
        "secondary_action": "Review"
      },
      "onboarding_hint": "Device auth first."
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
  "registry_notes": ["Rust-owned provider lanes with explicit auth, import, and refresh surfaces."]
}
''';

      final SourceRegistrySnapshot registry =
          SourceRegistrySnapshot.fromJsonString(source);

      expect(registry.title, 'Source registry');
      expect(registry.selectedProviderKind, SourceProviderKind.xtream);
      expect(registry.selectedProvider.kind, SourceProviderKind.xtream);
      expect(
        registry
            .provider(SourceProviderKind.localM3u)
            .supports(SourceCapability.localPlaylist),
        isTrue,
      );
      expect(
        registry
            .provider(SourceProviderKind.xtream)
            .supports(SourceCapability.subtitles),
        isTrue,
      );
      expect(
        registry
            .provider(SourceProviderKind.xtream)
            .supports(SourceCapability.tracks),
        isTrue,
      );
      expect(registry.providersSupporting(SourceCapability.catchup).length, 3);
      expect(registry.activeWizardStep, SourceWizardStep.credentials);
      expect(registry.wizardSteps.length, 2);
    },
  );

  test('source registry snapshot rejects unknown selected provider', () {
    expect(
      () => SourceRegistrySnapshot.fromJsonString('''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "m3u_url",
      "provider_type": "M3U URL",
      "family": "playlist",
      "connection_mode": "remote_url",
      "summary": "Remote playlist lane.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}
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
        "field_labels": ["Playlist URL"],
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
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "step_order": ["Source Type"],
    "steps": [
      {
        "step": "Source Type",
        "title": "Choose source type",
        "summary": "Pick the provider type first.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Source type"],
        "helper_lines": ["Keep provider-specific flow inside Settings."]
      }
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
'''),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'configured providers allow multiple instances of the same provider type',
    () {
      const String source = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Complete", "progress": "100%", "summary": "Connected", "primary_action": "Edit", "secondary_action": "Back", "field_labels": ["Server URL"], "helper_lines": ["Portal login."]},
      "import": {"status": "Ready", "progress": "Ready", "summary": "Ready", "primary_action": "Import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "configured_providers": [
    {
      "provider_key": "xtream_one",
      "provider_type": "Xtream",
      "display_name": "Provider One",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "First instance.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Complete", "progress": "100%", "summary": "Connected", "primary_action": "Edit", "secondary_action": "Back", "field_labels": ["Server URL"], "helper_lines": ["Portal login."]},
      "import": {"status": "Ready", "progress": "Ready", "summary": "Ready", "primary_action": "Import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    },
    {
      "provider_key": "xtream_two",
      "provider_type": "Xtream",
      "display_name": "Provider Two",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Second instance.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Complete", "progress": "100%", "summary": "Connected", "primary_action": "Edit", "secondary_action": "Back", "field_labels": ["Server URL"], "helper_lines": ["Portal login."]},
      "import": {"status": "Ready", "progress": "Ready", "summary": "Ready", "primary_action": "Import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "step_order": ["Source Type"],
    "steps": [
      {
        "step": "Source Type",
        "title": "Choose source type",
        "summary": "Pick the provider type first.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Source type"],
        "helper_lines": ["Keep provider-specific flow inside Settings."]
      }
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
''';

      final SourceRegistrySnapshot registry =
          SourceRegistrySnapshot.fromJsonString(source);

      expect(registry.configuredProviders, hasLength(2));
      expect(
        registry.configuredProviders.map((item) => item.displayName),
        containsAll(<String>['Provider One', 'Provider Two']),
      );
    },
  );
}
