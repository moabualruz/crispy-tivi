import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  "top_films": [
    {"title": "The Last Harbor", "caption": "Thriller", "rank": 1, "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"}}
  ],
  "top_series": [
    {"title": "Shadow Signals", "caption": "New episode", "rank": 1, "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}}
  ],
  "live_tv_channels": [
    {"number": "118", "name": "Arena Live", "program": "Championship Replay", "time_range": "21:30 - 23:30"}
  ],
  "guide_rows": [
    ["Now", "21:30"],
    ["Arena Live", "Replay"]
  ],
  "live_tv_browse": {
    "summary_title": "Quick tune with dense context",
    "summary_body": "Live TV browsing keeps the rail dense and playback on explicit action only.",
    "quick_play_label": "Play selected channel",
    "quick_play_hint": "Tune changes only on explicit activation.",
    "selected_channel_number": "118",
    "channel_details": [
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
      }
    ]
  },
  "live_tv_guide": {
    "summary_title": "Guide matrix with live-edge context",
    "summary_body": "Guide browsing keeps compact matrix context and no retune until activation.",
    "time_slots": ["21:30"],
    "selected_channel_number": "118",
    "focused_slot": "21:30",
    "rows": [
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
          }
        ]
      }
    ]
  },
  "search_groups": [
    {
      "title": "Live TV",
      "results": [
        {
          "title": "Arena Live",
          "caption": "Channel 118",
          "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}
        }
      ]
    },
    {
      "title": "Movies",
      "results": [
        {
          "title": "The Last Harbor",
          "caption": "Thriller",
          "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"}
        }
      ]
    },
    {
      "title": "Series",
      "results": [
        {
          "title": "Shadow Signals",
          "caption": "Sci-fi drama",
          "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}
        }
      ]
    }
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

  testWidgets('search route shows live tv handoff by default', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchView(content: content))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Domain: Live TV'), findsOneWidget);
    expect(find.text('Selected result: Arena Live'), findsOneWidget);
    expect(find.text('Action: Tune live channel'), findsOneWidget);
  });

  testWidgets('search result selection updates canonical handoff detail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ShellContentSnapshot moviesContent = await _moviesFocusedContent();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SearchView(content: moviesContent))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Domain: Movies'), findsOneWidget);
    expect(find.text('Selected result: The Last Harbor'), findsOneWidget);
    expect(find.text('Selected target: Thriller'), findsOneWidget);
    expect(find.text('Action: Open movie detail'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-result-0-1')));
    await tester.pumpAndSettle();

    expect(find.text('Selected result: Atlas Run'), findsOneWidget);
    expect(find.text('Selected target: Action'), findsOneWidget);
    expect(find.text('Action: Open movie detail'), findsOneWidget);
  });
}

Future<ShellContentSnapshot> _moviesFocusedContent() async {
  final String source = await rootBundle.loadString(
    'assets/contracts/asset_shell_content.json',
  );
  final Map<String, dynamic> json = jsonDecode(source) as Map<String, dynamic>;
  json['search_groups'] = <Map<String, dynamic>>[
    <String, dynamic>{
      'title': 'Movies',
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'The Last Harbor',
          'caption': 'Thriller',
          'artwork': <String, dynamic>{
            'kind': 'asset',
            'value': 'assets/mocks/poster-shell-1.jpg',
          },
        },
        <String, dynamic>{
          'title': 'Atlas Run',
          'caption': 'Action',
          'artwork': <String, dynamic>{
            'kind': 'asset',
            'value': 'assets/mocks/poster-shell-3.jpg',
          },
        },
      ],
    },
  ];
  return ShellContentSnapshot.fromJson(json);
}
