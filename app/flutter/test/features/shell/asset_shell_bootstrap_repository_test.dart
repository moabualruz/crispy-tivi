import 'package:crispy_tivi/features/shell/data/asset_live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_bootstrap_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bootstrap repository resolves contract and content together', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetShellContractRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "startup_route": "Home",
  "top_level_routes": ["Home", "Live TV", "Media", "Search", "Settings"],
  "settings_groups": ["General", "Playback", "Sources", "Appearance", "System"],
  "live_tv_panels": ["Channels", "Guide"],
  "live_tv_groups": ["All", "Favorites", "News", "Sports", "Movies", "Kids"],
  "media_panels": ["Movies", "Series"],
  "media_scopes": ["Featured", "Trending", "Recent", "Library"],
  "home_quick_access": ["Search", "Settings", "Series", "Live TV Guide"],
  "source_wizard_steps": ["Source Type", "Connection", "Credentials", "Import", "Finish"]
}
''');
      }
      if (key == AssetShellContentRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "home_hero": {
    "kicker": "Tonight on CrispyTivi",
    "title": "City Lights at Midnight",
    "summary": "A dramatic featured rail with quiet chrome, clear hierarchy, and room-readable action placement.",
    "primary_action": "Resume watching",
    "secondary_action": "Open details",
    "artwork": {"kind": "asset", "value": "assets/mocks/home-hero-shell.jpg"}
  },
  "continue_watching": [
    {"title": "Neon District", "caption": "42 min left", "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"}}
  ],
  "live_now": [
    {"title": "World Report", "caption": "Newsroom", "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}}
  ],
  "movie_hero": {
    "kicker": "Featured film",
    "title": "The Last Harbor",
    "summary": "A cinematic detail state with clear action hierarchy, restrained metadata, and content-first framing.",
    "primary_action": "Play trailer",
    "secondary_action": "Add to watchlist",
    "artwork": {"kind": "asset", "value": "assets/mocks/media-movie-hero-shell.jpg"}
  },
  "series_hero": {
    "kicker": "Series spotlight",
    "title": "Shadow Signals",
    "summary": "Season-driven browsing stays inside the media domain with episode context and tight focus separation.",
    "primary_action": "Resume S1:E6",
    "secondary_action": "Browse episodes",
    "artwork": {"kind": "asset", "value": "assets/mocks/media-series-hero-shell.jpg"}
  },
  "top_films": [
    {"title": "The Last Harbor", "caption": "Thriller", "rank": 1, "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"}}
  ],
  "top_series": [
    {"title": "Shadow Signals", "caption": "New episode", "rank": 1, "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}}
  ],
  "live_tv_channels": [
    {"number": "101", "name": "Crispy One", "program": "Midnight Bulletin", "time_range": "21:00 - 22:00"}
  ],
  "guide_rows": [
    ["Now", "21:30"],
    ["Crispy One", "Bulletin"]
  ],
  "live_tv_browse": {
    "summary_title": "Quick tune with dense context",
    "summary_body": "Live TV browsing keeps the rail dense and playback on explicit action only.",
    "quick_play_label": "Play selected channel",
    "quick_play_hint": "Tune changes only on explicit activation.",
    "selected_channel_number": "101",
    "channel_details": [
      {
        "number": "101",
        "brand": "Crispy One",
        "title": "Midnight Bulletin",
        "summary": "Late-night national news.",
        "now_label": "Now · Midnight Bulletin",
        "next_label": "Next · Market Close at 22:00",
        "quick_play_label": "Play live",
        "metadata_badges": ["News", "HD", "Archive 24h"],
        "supports_catchup": true,
        "supports_archive": true,
        "archive_hint": "Start over and last 24 hours available."
      }
    ]
  },
  "live_tv_guide": {
    "summary_title": "Guide matrix with live-edge context",
    "summary_body": "Guide browsing keeps compact matrix context and no retune until activation.",
    "time_slots": ["21:30"],
    "selected_channel_number": "101",
    "focused_slot": "21:30",
    "rows": [
      {
        "channel_number": "101",
        "channel_name": "Crispy One",
        "programs": [
          {
            "slot": "21:30",
            "title": "Midnight Bulletin",
            "summary": "Top national stories.",
            "duration_label": "30 min",
            "supports_catchup": true,
            "supports_archive": true,
            "live_edge_label": "Live edge"
          }
        ]
      }
    ]
  },
  "search_groups": [
    {"title": "Live TV", "results": [{"title": "Arena Live", "caption": "Channel 118"}]}
  ],
  "general_settings": [
    {"title": "Startup target", "summary": "Choose the first screen after launch.", "value": "Home"}
  ],
  "playback_settings": [
    {"title": "Quick play confirmation", "summary": "Require explicit play confirmation for channel tune.", "value": "On"}
  ],
  "appearance_settings": [
    {"title": "Focus intensity", "summary": "Boost focus glow for brighter rooms.", "value": "Balanced"}
  ],
  "system_settings": [
    {"title": "Storage", "summary": "Inspect cache and offline data.", "value": "4.2 GB"}
  ],
  "source_health_items": [
    {
      "name": "Home Fiber IPTV",
      "status": "Healthy",
      "summary": "Live, guide, and catch-up verified 2 min ago.",
      "source_type": "M3U + XMLTV",
      "endpoint": "fiber.local / lineup-primary",
      "last_sync": "2 minutes ago",
      "capabilities": ["Live TV", "Guide", "Catch-up"],
      "primary_action": "Re-import source"
    }
  ],
  "source_wizard_steps": [
    {
      "step": "Source Type",
      "title": "Choose source type",
      "summary": "Pick the provider integration first so connection, auth, and import rules stay accurate for the rest of the wizard.",
      "primary_action": "Continue",
      "secondary_action": "Back",
      "field_labels": ["Source type", "Display name"],
      "helper_lines": ["Keep provider-specific flow inside Settings.", "Wizard steps stay ordered and safe to unwind."]
    }
  ]
}
''');
      }
      if (key == AssetSourceRegistryRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login with live, VOD, and EPG lanes.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true}
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
        "status": "Blocked",
        "progress": "0%",
        "summary": "Import is paused until auth succeeds.",
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
        "step": "Credentials",
        "title": "Verify access",
        "summary": "Credentials gate import.",
        "primary_action": "Continue",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Validation should happen before import."]
      }
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
''');
      }
      if (key == AssetLiveTvRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "title": "CrispyTivi Live TV Runtime",
  "version": "1",
  "provider": {
    "provider_key": "home_fiber_iptv",
    "provider_type": "M3U + XMLTV",
    "family": "playlist",
    "connection_mode": "remote_url",
    "source_name": "Home Fiber IPTV",
    "status": "Healthy",
    "summary": "Live channels and guide data are synchronized for browse and playback.",
    "last_sync": "2 minutes ago",
    "guide_health": "EPG verified"
  },
  "browsing": {
    "active_panel": "Channels",
    "selected_group": "All",
    "selected_channel": "101 Crispy One",
    "group_order": ["All"],
    "groups": [
      {
        "id": "all",
        "title": "All",
        "summary": "Every available live channel",
        "channel_count": 1,
        "selected": true
      }
    ]
  },
  "channels": [
    {
      "number": "101",
      "name": "Crispy One",
      "group": "News",
      "state": "selected",
      "live_edge": true,
      "catch_up": true,
      "archive": true,
      "current": {
        "title": "Midnight Bulletin",
        "summary": "Top stories, business close, and late headlines.",
        "start": "21:00",
        "end": "22:00",
        "progress_percent": 55
      },
      "next": {
        "title": "Market Close",
        "summary": "Wrap-up analysis and overnight context.",
        "start": "22:00",
        "end": "22:30",
        "progress_percent": 0
      }
    }
  ],
  "guide": {
    "title": "Live TV Guide",
    "window_start": "21:00",
    "window_end": "23:00",
    "time_slots": ["Now"],
    "rows": [
      {
        "channel_number": "101",
        "channel_name": "Crispy One",
        "slots": [
          {
            "start": "21:00",
            "end": "22:00",
            "title": "Midnight Bulletin",
            "state": "current"
          }
        ]
      }
    ]
  },
  "selection": {
    "channel_number": "101",
    "channel_name": "Crispy One",
    "status": "Live",
    "live_edge": true,
    "catch_up": true,
    "archive": true,
    "now": {
      "title": "Midnight Bulletin",
      "summary": "Top national stories.",
      "start": "21:00",
      "end": "22:00",
      "progress_percent": 55
    },
    "next": {
      "title": "Market Close",
      "summary": "Closing bell recap.",
      "start": "22:00",
      "end": "22:30",
      "progress_percent": 0
    },
    "primary_action": "Watch live",
    "secondary_action": "Start over",
    "badges": ["Live", "News"],
    "detail_lines": ["Selected detail stays in the right lane."]
  },
  "notes": ["Rust-owned runtime snapshot."]
}
''');
      }
      if (key == AssetMediaRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "title": "CrispyTivi Media Runtime",
  "version": "1",
  "active_panel": "Movies",
  "active_scope": "Featured",
  "movie_hero": {
    "kicker": "Featured film",
    "title": "The Last Harbor",
    "summary": "Cinematic detail state.",
    "primary_action": "Play trailer",
    "secondary_action": "Add to watchlist"
  },
  "series_hero": {
    "kicker": "Series spotlight",
    "title": "Shadow Signals",
    "summary": "Season-driven browsing.",
    "primary_action": "Resume S1:E6",
    "secondary_action": "Browse episodes"
  },
  "movie_collections": [
    {
      "title": "Featured Films",
      "summary": "Featured runtime films.",
      "items": [
        {"title": "The Last Harbor", "caption": "Thriller", "rank": 1}
      ]
    }
  ],
  "series_collections": [
    {
      "title": "Featured Series",
      "summary": "Featured runtime series.",
      "items": [
        {"title": "Shadow Signals", "caption": "Sci-fi drama", "rank": 1}
      ]
    }
  ],
  "series_detail": {
    "summary_title": "Season and episode playback",
    "summary_body": "Season choice stays above episode choice.",
    "handoff_label": "Play episode",
    "seasons": [
      {
        "label": "Season 1",
        "summary": "Episode-first season.",
        "episodes": [
          {
            "code": "S1:E1",
            "title": "Cold Open",
            "summary": "Series premiere and setup.",
            "duration_label": "45 min",
            "handoff_label": "Play episode"
          }
        ]
      }
    ]
  },
  "notes": ["Asset-backed media runtime snapshot."]
}
''');
      }
      if (key == AssetSearchRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "title": "CrispyTivi Search Runtime",
  "version": "1",
  "query": "",
  "active_group_title": "Live TV",
  "groups": [
    {
      "title": "Live TV",
      "summary": "Live channels and guide-linked results.",
      "selected": true,
      "results": [
        {
          "title": "Arena Live",
          "caption": "Channel 118",
          "source_label": "Live TV",
          "handoff_label": "Open channel"
        }
      ]
    }
  ],
  "notes": ["Asset-backed search runtime snapshot."]
}
''');
      }
      if (key == AssetDiagnosticsRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage('''
{
  "title": "CrispyTivi Diagnostics Runtime",
  "version": "1",
  "validation_summary": "Runtime validation and media diagnostics are available for source QA and release support.",
  "ffprobe_available": false,
  "ffmpeg_available": false,
  "reports": [],
  "notes": ["Asset-backed diagnostics snapshot."]
}
''');
      }
      if (key == AssetPersonalizationRuntimeRepository().assetPath) {
        return const StringCodec().encodeMessage('''
{
  "title": "CrispyTivi Personalization Runtime",
  "version": "1",
  "startup_route": "Home",
  "continue_watching": [],
  "recently_viewed": [],
  "favorite_media_keys": [],
  "favorite_channel_numbers": [],
  "notes": ["Asset-backed personalization defaults."]
}
''');
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    final AssetShellBootstrapRepository repository =
        AssetShellBootstrapRepository(
          personalizationRuntimeRepository:
              AssetPersonalizationRuntimeRepository(),
        );
    final ShellBootstrap bootstrap = await repository.load();

    expect(bootstrap.contract.homeQuickAccess.first, 'Search');
    expect(bootstrap.content.homeHero.title, 'City Lights at Midnight');
    expect(bootstrap.content.generalSettings.first.title, 'Startup target');
    expect(bootstrap.contract.sourceWizardSteps.first.label, 'Source Type');
    expect(bootstrap.sourceRegistry.selectedProvider.kind.label, 'Xtream');
    expect(bootstrap.liveTvRuntime.provider.sourceName, 'Home Fiber IPTV');
    expect(bootstrap.mediaRuntime.movieHero.title, 'The Last Harbor');
    expect(bootstrap.searchRuntime.groups.single.title, 'Live TV');
    expect(bootstrap.diagnosticsRuntime.version, '1');
    expect(bootstrap.personalizationRuntime.startupRoute, 'Home');
  });
}
