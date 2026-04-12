import 'package:crispy_tivi/app/app.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_contract.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final MockShellContractSupport contract =
      MockShellContractSupport.fromContract(
        MockShellContract.fromJsonString('''
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
  final MockShellContentSnapshot content =
      MockShellContentSnapshot.fromJsonString('''
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
    {"number": "101", "name": "Crispy One", "program": "Midnight Bulletin", "time_range": "21:00 - 22:00"},
    {"number": "118", "name": "Arena Live", "program": "Championship Replay", "time_range": "21:30 - 23:30"},
    {"number": "205", "name": "Cinema Vault", "program": "Coastal Drive", "time_range": "20:45 - 22:35"},
    {"number": "311", "name": "Nature Atlas", "program": "Winter Oceans", "time_range": "21:15 - 22:15"}
  ],
  "guide_rows": [
    ["Now", "21:30", "22:00"],
    ["Crispy One", "Bulletin", "Market Close"]
  ],
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

    await tester.tap(find.byKey(const Key('source-wizard-step-Connection')));
    await tester.pumpAndSettle();
    expect(find.text('Add connection details'), findsOneWidget);
  });

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
}
