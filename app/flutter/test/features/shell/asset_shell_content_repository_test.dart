import 'package:crispy_tivi/features/shell/data/asset_shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('content snapshot parses approved home and media content', () {
    const String source = '''
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
''';

    final ShellContentSnapshot content =
        ShellContentSnapshot.fromJsonString(source);

    expect(content.homeHero.title, 'City Lights at Midnight');
    expect(content.movieHero.title, 'The Last Harbor');
    expect(content.topFilms.single.rank, 1);
    expect(content.continueWatching.single.artwork, isNotNull);
    expect(content.sourceHealthItems.single.primaryAction, 'Re-import source');
    expect(content.sourceWizardSteps.single.step, SourceWizardStep.sourceType);
  });

  test('repository loads shell content asset', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
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
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    const AssetShellContentRepository repository = AssetShellContentRepository();
    final ShellContentSnapshot content = await repository.load();

    expect(content.homeHero.artwork, isNotNull);
    expect(content.topSeries.single.title, 'Shadow Signals');
    expect(content.sourceWizardSteps.single.title, 'Choose source type');
  });
}
