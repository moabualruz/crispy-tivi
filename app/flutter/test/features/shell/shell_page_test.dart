import 'package:crispy_tivi/app/app.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ShellContractSupport contract = ShellContractSupport.fromContract(
    ShellContract.fromJsonString('''
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
'''),
  );
  final ShellContentSnapshot content = ShellContentSnapshot.fromJsonString('''
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
  "series_detail": {
    "summary_title": "Season and episode handoff",
    "summary_body": "Season choice stays above episode choice and the launch action remains explicit.",
    "handoff_label": "Mock player handoff",
    "seasons": [
      {
        "label": "Season 1",
        "summary": "Episode-first season with the core story arc.",
        "episodes": [
          {"code": "S1:E1", "title": "Cold Open", "summary": "Series premiere and setup.", "duration_label": "45 min", "handoff_label": "Launch player handoff"},
          {"code": "S1:E2", "title": "Cross Signal", "summary": "The plot tightens around the central handoff.", "duration_label": "44 min", "handoff_label": "Launch player handoff"}
        ]
      },
      {
        "label": "Season 2",
        "summary": "Continuation season with stronger episode continuity.",
        "episodes": [
          {"code": "S2:E1", "title": "Return Path", "summary": "The series resets with a longer-form arc.", "duration_label": "45 min", "handoff_label": "Launch player handoff"},
          {"code": "S2:E2", "title": "Signal Drift", "summary": "Season continuity stays explicit.", "duration_label": "44 min", "handoff_label": "Launch player handoff"}
        ]
      }
    ]
  },
  "top_films": [
    {"title": "The Last Harbor", "caption": "Thriller", "rank": 1, "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"}}
  ],
  "top_series": [
    {"title": "Shadow Signals", "caption": "New episode", "rank": 1, "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}}
  ],
  "live_tv_channels": [
    {"number": "101", "name": "Crispy One", "program": "Midnight Bulletin", "time_range": "21:00 - 22:00"},
    {"number": "118", "name": "Arena Live", "program": "Championship Replay", "time_range": "21:30 - 23:30"},
    {"number": "205", "name": "Cinema Vault", "program": "Coastal Drive", "time_range": "20:45 - 22:35"},
    {"number": "311", "name": "Nature Atlas", "program": "Winter Oceans", "time_range": "21:15 - 22:15"}
  ],
  "guide_rows": [
    ["Now", "21:30", "22:00"],
    ["Crispy One", "Bulletin", "Market Close"]
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
      },
      {
        "number": "118",
        "brand": "Arena Live",
        "title": "Championship Replay",
        "summary": "Replay block with studio analysis.",
        "now_label": "Now · Championship Replay",
        "next_label": "Next · Locker Room at 23:30",
        "quick_play_label": "Resume replay",
        "metadata_badges": ["Sports", "4K", "Catch-up"],
        "supports_catchup": true,
        "supports_archive": false,
        "archive_hint": "Replay supports catch-up but not full archive."
      },
      {
        "number": "205",
        "brand": "Cinema Vault",
        "title": "Coastal Drive",
        "summary": "Feature film lane with title-safe artwork.",
        "now_label": "Now · Coastal Drive",
        "next_label": "Next · Studio Cut at 22:35",
        "quick_play_label": "Play from live edge",
        "metadata_badges": ["Movies", "Dolby", "Start over"],
        "supports_catchup": true,
        "supports_archive": true,
        "archive_hint": "Movie start-over and archive window available."
      },
      {
        "number": "311",
        "brand": "Nature Atlas",
        "title": "Winter Oceans",
        "summary": "Documentary lane with live-only rights.",
        "now_label": "Now · Winter Oceans",
        "next_label": "Next · Arctic Voices at 22:15",
        "quick_play_label": "Join live",
        "metadata_badges": ["Docs", "HD"],
        "supports_catchup": false,
        "supports_archive": false,
        "archive_hint": "Live-only on the current source."
      }
    ]
  },
  "live_tv_guide": {
    "summary_title": "Guide matrix with live-edge context",
    "summary_body": "Guide browsing keeps compact matrix context and no retune until activation.",
    "time_slots": ["21:30", "22:00"],
    "selected_channel_number": "101",
    "focused_slot": "22:00",
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
          },
          {
            "slot": "22:00",
            "title": "Market Close",
            "summary": "Closing bell recap.",
            "duration_label": "30 min",
            "supports_catchup": true,
            "supports_archive": true,
            "live_edge_label": "Starts at 22:00"
          }
        ]
      },
      {
        "channel_number": "118",
        "channel_name": "Arena Live",
        "programs": [
          {
            "slot": "21:30",
            "title": "Championship Replay",
            "summary": "Full replay with multi-angle chapters.",
            "duration_label": "120 min",
            "supports_catchup": true,
            "supports_archive": false,
            "live_edge_label": "In progress"
          },
          {
            "slot": "22:00",
            "title": "Analysis",
            "summary": "Studio wrap and tactical breakdown.",
            "duration_label": "30 min",
            "supports_catchup": true,
            "supports_archive": false,
            "live_edge_label": "Queued"
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
    },
    {
      "name": "Travel Archive",
      "status": "Needs auth",
      "summary": "Reconnect credentials to resume sync.",
      "source_type": "Xtream Codes",
      "endpoint": "travel.example.com / xtream",
      "last_sync": "Sync blocked",
      "capabilities": ["Live TV", "Movies", "Series"],
      "primary_action": "Reconnect"
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
    },
    {
      "step": "Connection",
      "title": "Add connection details",
      "summary": "Capture the endpoint and source-specific path before auth or validation runs.",
      "primary_action": "Validate connection",
      "secondary_action": "Back",
      "field_labels": ["Connection endpoint", "Headers"],
      "helper_lines": ["Connection validation should fail here instead of later import screens.", "Temporary connection state must not auto-restore into an unsafe stale step."]
    },
    {
      "step": "Credentials",
      "title": "Authenticate source",
      "summary": "Sensitive credentials stay in the wizard and should never auto-restore into the middle of the secret-bearing step.",
      "primary_action": "Verify access",
      "secondary_action": "Back",
      "field_labels": ["Username", "Password"],
      "helper_lines": ["Auth can be entered for new sources or reconnect flows on existing sources.", "Back from this step returns safely to connection rather than leaving the user in a broken state."]
    },
    {
      "step": "Import",
      "title": "Choose import scope",
      "summary": "Review what the source will bring in and confirm the validation result before final import begins.",
      "primary_action": "Start import",
      "secondary_action": "Back",
      "field_labels": ["Import scope", "Validation result"],
      "helper_lines": ["Import confirmation is a dedicated step, not a hidden side effect of auth.", "Failures here should unwind cleanly back through the wizard."]
    },
    {
      "step": "Finish",
      "title": "Finish setup",
      "summary": "Complete the source handoff and return to source overview with health and capability status visible.",
      "primary_action": "Return to sources",
      "secondary_action": "Back",
      "field_labels": ["Validation result", "Import scope"],
      "helper_lines": ["Success returns to the Settings-owned source overview, not to a detached source domain.", "The next domain phases can rely on this onboarding lane being complete."]
    }
  ]
}
''');

  testWidgets('global navigation excludes Sources and Player', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sources'), findsNothing);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets('sources live under settings', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('General'), findsWidgets);
    expect(find.byKey(const Key('settings-sidebar-Sources')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('settings-sidebar-Sources')),
    );
    await tester.tap(find.byKey(const Key('settings-sidebar-Sources')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('source-item-Home Fiber IPTV')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sources-add-button')), findsOneWidget);
  });

  testWidgets('settings top-level groups navigate through the owned panels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final List<(String key, String leafMarker)> panels = <(String, String)>[
      ('settings-sidebar-General', 'Startup target'),
      ('settings-sidebar-Playback', 'Quick play confirmation'),
      ('settings-sidebar-Sources', 'Connected sources'),
      ('settings-sidebar-Appearance', 'Focus intensity'),
      ('settings-sidebar-System', 'Storage'),
    ];

    for (final (String key, String leafMarker) in panels) {
      final Finder panelFinder = find.byKey(Key(key));
      await tester.ensureVisible(panelFinder);
      await tester.tap(panelFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(Key(key)), findsOneWidget);
      expect(find.text(leafMarker), findsWidgets);
    }
  });

  testWidgets('source wizard enters from settings and unwinds safely', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sidebar-Sources')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sources-add-button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose source type'), findsOneWidget);
    expect(
      find.byKey(const Key('source-wizard-step-Source Type')),
      findsOneWidget,
    );

    final Finder connectionStep = find.byKey(
      const Key('source-wizard-step-Connection'),
    );
    await tester.ensureVisible(connectionStep);
    await tester.tap(connectionStep);
    await tester.pumpAndSettle();
    expect(find.text('Add connection details'), findsOneWidget);
  });

  testWidgets('settings deep leaf opens exact source detail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sidebar-Sources')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'travel',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-search-hit-0')));
    await tester.pumpAndSettle();

    expect(find.text('travel.example.com / xtream'), findsOneWidget);
    expect(find.text('Search opened: Travel Archive.'), findsOneWidget);
    expect(find.text('Sources'), findsWidgets);
  });

  testWidgets(
    'settings search activates exact leaf inside settings hierarchy',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        CrispyTiviApp(initialContract: contract, initialContent: content),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        'storage',
      );
      await tester.pumpAndSettle();

      expect(find.text('Search results'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-search-hit-0')));
      await tester.pumpAndSettle();

      expect(find.text('Search opened: Storage.'), findsOneWidget);
      expect(find.byKey(const Key('settings-sidebar-System')), findsOneWidget);
      expect(find.text('Storage'), findsWidgets);
    },
  );

  testWidgets('live tv sidebar owns only subviews, groups live in content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live TV'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-tv-sidebar-Channels')), findsOneWidget);
    expect(find.byKey(const Key('live-tv-sidebar-Guide')), findsOneWidget);
    expect(find.byKey(const Key('live-tv-sidebar-All')), findsNothing);
    expect(find.byKey(const Key('live-tv-group-allChannels')), findsOneWidget);
  });

  testWidgets(
    'live tv focus updates detail but explicit action changes playback',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        CrispyTiviApp(initialContract: contract, initialContent: content),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live TV'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('live-tv-playing-channel-label')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Start over and last 24 hours'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('live-tv-channel-118')));
      await tester.pumpAndSettle();

      expect(find.text('Championship Replay'), findsWidgets);
      expect(find.text('Preview only'), findsOneWidget);
      expect(find.textContaining('Replay supports catch-up'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('live-tv-tune-action')));
      await tester.tap(find.byKey(const Key('live-tv-tune-action')));
      await tester.pumpAndSettle();

      expect(find.text('Playing now'), findsOneWidget);
      expect(find.text('Playing 118'), findsOneWidget);
    },
  );

  testWidgets('live tv guide keeps detail overlays and no tune action', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live TV'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('live-tv-sidebar-Guide')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-tv-group-allChannels')), findsOneWidget);
    expect(find.byKey(const Key('live-tv-tune-action')), findsNothing);
    expect(find.text('Market Close'), findsWidgets);
    expect(
      find.byKey(const Key('live-tv-guide-live-edge-label')),
      findsOneWidget,
    );
    expect(find.text('Starts at 22:00'), findsWidgets);

    await tester.tap(find.byKey(const Key('live-tv-group-sports')));
    await tester.pumpAndSettle();

    expect(find.text('Analysis'), findsWidgets);
    expect(find.text('Queued'), findsWidgets);
  });

  testWidgets('media sidebar owns subviews while scope lives in content', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-sidebar-Movies')), findsOneWidget);
    expect(find.byKey(const Key('media-sidebar-Series')), findsOneWidget);
    expect(find.byKey(const Key('media-scope-featured')), findsOneWidget);
    expect(find.byKey(const Key('media-scope-library')), findsOneWidget);
  });

  testWidgets('series browsing emphasizes season and episode handoff', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CrispyTiviApp(initialContract: contract, initialContent: content),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media-sidebar-Series')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('series-season-0')), findsOneWidget);
    expect(find.byKey(const Key('series-season-1')), findsOneWidget);
    expect(find.byKey(const Key('series-episode-0-0')), findsOneWidget);
    expect(find.byKey(const Key('series-handoff-state')), findsOneWidget);
    expect(find.textContaining('Ready to launch S1:E1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('series-season-1')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('media-list-view')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('series-episode-1-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('series-episode-1-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('series-launch-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ready to launch S2:E2'), findsOneWidget);
    expect(find.textContaining('Launch player handoff'), findsWidgets);

    await tester.tap(find.byKey(const Key('series-launch-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Launched S2:E2'), findsOneWidget);
    expect(find.textContaining('Launched'), findsWidgets);
  });
}
