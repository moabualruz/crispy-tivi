import 'package:crispy_tivi/features/shell/data/runtime_shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'runtime bootstrap consumes rust-owned runtime bundle without flutter fallback hydration',
    () async {
      final _FakeSourceRegistryRepository fakeRegistry =
          _FakeSourceRegistryRepository(_sourceRegistry);
      final _FakeRustShellRuntimeBridge fakeBridge =
          _FakeRustShellRuntimeBridge(
            hydratedRuntimeBundleJson: _runtimeBundleJson,
          );

      final RuntimeShellBootstrapRepository repository =
          RuntimeShellBootstrapRepository(
            contractRepository: _FakeContractRepository(_contract),
            sourceRegistryRepository: fakeRegistry,
            shellRuntimeBridge: fakeBridge,
          );

      final bootstrap = await repository.load();

      expect(bootstrap.liveTvRuntime.channels, isNotEmpty);
      expect(fakeBridge.lastHydrateSourceRegistryJson, isNotNull);
      expect(fakeBridge.loadDiagnosticsCalls, 1);
      expect(bootstrap.sourceRegistry.configuredProviders, isNotEmpty);
      expect(
        bootstrap.sourceRegistry.configuredProviders.single.kind,
        SourceProviderKind.xtream,
      );
      expect(
        bootstrap.sourceRegistry.configuredProviders.single.family,
        'portal',
      );
      expect(
        bootstrap.sourceRegistry.configuredProviders.single.connectionMode,
        'portal_account',
      );
      expect(bootstrap.mediaRuntime.movieCollections, isNotEmpty);
      expect(bootstrap.searchRuntime.groups, isNotEmpty);
      expect(bootstrap.personalizationRuntime.continueWatching, isNotEmpty);
      expect(bootstrap.diagnosticsRuntime.reports, isNotEmpty);
      expect(bootstrap.liveTvRuntime.provider.providerType, 'Xtream');
      expect(bootstrap.liveTvRuntime.provider.sourceName, 'Portal Demo');
      expect(bootstrap.liveTvRuntime.channels.first.playbackSource, isNotNull);
      expect(
        bootstrap.liveTvRuntime.channels.first.playbackSource!.sourceLabel,
        isNotEmpty,
      );
      expect(
        bootstrap.mediaRuntime.movieCollections.first.items.first.title,
        isNotEmpty,
      );
      expect(
        bootstrap.mediaRuntime.movieHero.title.contains('failed to load'),
        isFalse,
      );
    },
  );
}

class _FakeRustShellRuntimeBridge implements ShellRuntimeBridge {
  _FakeRustShellRuntimeBridge({required this.hydratedRuntimeBundleJson});

  final String hydratedRuntimeBundleJson;
  String? lastHydrateSourceRegistryJson;
  int loadDiagnosticsCalls = 0;

  @override
  Future<String> loadSourceRegistryJson() async =>
      _sourceRegistry.toJsonString();

  @override
  Future<String> updateSourceSetupJson({
    required String sourceRegistryJson,
    required String action,
    String? selectedProviderType,
    int? selectedSourceIndex,
    String? targetStep,
    String? fieldKey,
    String? fieldValue,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> hydrateRuntimeBundleJson({String? sourceRegistryJson}) async {
    lastHydrateSourceRegistryJson = sourceRegistryJson;
    return hydratedRuntimeBundleJson;
  }

  @override
  Future<String> loadPlaybackRuntimeJson({String? sourceRegistryJson}) async {
    throw UnimplementedError();
  }

  @override
  Future<String> loadPlaybackSessionRuntimeJsonFromStreamJson({
    required String playbackStreamJson,
    int? sourceIndex,
    int? qualityIndex,
    int? audioIndex,
    int? subtitleIndex,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> commitSourceSetupJson({
    required String sourceRegistryJson,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> loadDiagnosticsRuntimeJson() async {
    loadDiagnosticsCalls += 1;
    return _diagnosticsRuntimeJson;
  }
}

const String _diagnosticsRuntimeJson = '''
{
  "title": "CrispyTivi Diagnostics Runtime",
  "version": "1",
  "validation_summary": "Diagnostics from Rust.",
  "ffprobe_available": false,
  "ffmpeg_available": false,
  "reports": [
    {
      "source_name": "Portal Demo",
      "stream_title": "Crispy One",
      "category": "healthy",
      "status_code": 200,
      "response_time_ms": 182,
      "url_hash": "hash-1",
      "resume_hash": "resume-1",
      "resolution_label": "1080p",
      "probe_backend": "metadata-only",
      "mismatch_warnings": [],
      "detail_lines": ["Diagnostics come from Rust."]
    }
  ],
  "notes": ["Rust diagnostics seam"]
}
''';

class _FakeSourceRegistryRepository extends SourceRegistryRepository {
  _FakeSourceRegistryRepository(this.snapshot);

  final SourceRegistrySnapshot snapshot;

  @override
  Future<SourceRegistrySnapshot> load() async => snapshot;

  @override
  Future<void> save(SourceRegistrySnapshot snapshot) async {}
}

class _FakeContractRepository extends ShellContractRepository {
  const _FakeContractRepository(this.contract);

  final ShellContractSupport contract;

  @override
  Future<ShellContractSupport> load() async => contract;
}

const String _runtimeBundleJson = '''
{
  "source_registry": {
    "title": "Source registry",
    "version": "1",
    "selected_provider_kind": "M3U URL",
    "active_wizard_step": "Source Type",
    "provider_types": [
      {
        "provider_key": "xtream",
        "provider_type": "Xtream",
        "display_name": "Portal Demo",
        "family": "portal",
        "connection_mode": "portal_account",
        "summary": "Catalog-backed provider.",
        "endpoint_label": "portal.example.test",
        "capabilities": [
          {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
          {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
          {"id": "series", "title": "Series", "summary": "Series lane", "supported": true}
        ],
        "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
        "auth": {
          "status": "Needs auth",
          "progress": "0%",
          "summary": "Credentials required.",
          "primary_action": "Verify access",
          "secondary_action": "Back",
          "field_labels": ["Server URL", "Username", "Password"],
          "helper_lines": ["Portal credentials."]
        },
        "import": {"status": "Blocked", "progress": "0%", "summary": "Import blocked", "primary_action": "Continue", "secondary_action": "Review"},
        "onboarding_hint": "Authenticate first."
      }
    ],
    "configured_providers": [
      {
        "provider_key": "xtream",
        "provider_type": "Xtream",
        "display_name": "Portal Demo",
        "family": "portal",
        "connection_mode": "portal_account",
        "summary": "Configured provider.",
        "endpoint_label": "portal.example.test",
        "capabilities": [
          {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
          {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
          {"id": "series", "title": "Series", "summary": "Series lane", "supported": true}
        ],
        "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
        "auth": {
          "status": "Complete",
          "progress": "100%",
          "summary": "Credentials saved.",
          "primary_action": "Refresh credentials",
          "secondary_action": "Back",
          "field_labels": ["Server URL", "Username", "Password"],
          "helper_lines": ["Portal credentials."]
        },
        "import": {"status": "Ready", "progress": "Ready", "summary": "Ready to import.", "primary_action": "Start import", "secondary_action": "Review"},
        "onboarding_hint": "Authenticate first."
      }
    ],
    "onboarding": {
      "selected_provider_type": "Xtream",
      "active_step": "Source Type",
      "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
      "steps": [
        {
          "step": "Source Type",
          "title": "Choose source type",
          "summary": "Pick provider family.",
          "primary_action": "Continue",
          "secondary_action": "Back",
          "field_labels": ["Source type", "Display name"],
          "helper_lines": ["Ordered wizard."]
        }
      ],
      "provider_copy": []
    },
    "registry_notes": []
  },
  "runtime": {
    "live_tv": {
      "title": "CrispyTivi Live TV Runtime",
      "version": "1",
      "provider": {
        "provider_key": "xtream",
        "provider_type": "Xtream",
        "family": "portal",
        "connection_mode": "portal_account",
        "source_name": "Portal Demo",
        "status": "Healthy",
        "summary": "Catalog-backed provider.",
        "last_sync": "now",
        "guide_health": "Guide available"
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
            "summary": "All available live channels",
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
          "state": "ready",
          "live_edge": true,
          "catch_up": true,
          "archive": true,
          "playback_source": {
            "kind": "live_channel",
            "source_key": "xtream",
            "content_key": "101",
            "source_label": "Portal Demo",
            "handoff_label": "Watch live"
          },
          "playback_stream": {
            "uri": "https://stream.crispy-tivi.test/live/101.m3u8",
            "transport": "hls",
            "live": true,
            "seekable": true,
            "resume_position_seconds": 0,
            "source_options": [],
            "quality_options": [],
            "audio_options": [],
            "subtitle_options": []
          },
          "current": {
            "title": "Midnight Bulletin",
            "summary": "Late-night national news.",
            "start": "21:00",
            "end": "22:00",
            "progress_percent": 54
          },
          "next": {
            "title": "Market Close",
            "summary": "Closing bell recap.",
            "start": "22:00",
            "end": "22:30",
            "progress_percent": 0
          }
        }
      ],
      "guide": {
        "title": "Live TV Guide",
        "window_start": "21:00",
        "window_end": "22:30",
        "time_slots": ["Now", "21:30"],
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
          "progress_percent": 54
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
        "detail_lines": ["Hydrated in Rust."]
      },
      "notes": ["Rust-owned runtime bundle."]
    },
    "media": {
      "title": "CrispyTivi Media Runtime",
      "version": "1",
      "active_panel": "Movies",
      "active_scope": "Featured",
      "movie_hero": {
        "kicker": "Featured film",
        "title": "The Last Harbor",
        "summary": "A cinematic detail state.",
        "primary_action": "Play trailer",
        "secondary_action": "Add to watchlist",
        "artwork": {"kind": "asset", "value": "assets/mocks/media-movie-hero-shell.jpg"}
      },
      "series_hero": {
        "kicker": "Series spotlight",
        "title": "Shadow Signals",
        "summary": "Episode-driven browsing.",
        "primary_action": "Resume",
        "secondary_action": "Browse episodes",
        "artwork": {"kind": "asset", "value": "assets/mocks/media-series-hero-shell.jpg"}
      },
      "movie_collections": [
        {
          "title": "Top films",
          "summary": "Featured films",
          "items": [
            {
              "title": "The Last Harbor",
              "caption": "Thriller",
              "rank": 1,
              "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"}
            }
          ]
        }
      ],
      "series_collections": [
        {
          "title": "Top series",
          "summary": "Featured series",
          "items": [
            {
              "title": "Shadow Signals",
              "caption": "New episode",
              "rank": 1,
              "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-5.jpg"}
            }
          ]
        }
      ],
      "series_detail": {
        "summary_title": "Season and episode handoff",
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
      "notes": ["Rust-owned runtime bundle."]
    },
    "search": {
      "title": "CrispyTivi Search Runtime",
      "version": "1",
      "query": "",
      "active_group_title": "Live TV",
      "groups": [
        {
          "title": "Live TV",
          "summary": "Live TV results",
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
      "notes": ["Rust-owned runtime bundle."]
    },
    "personalization": {
      "title": "CrispyTivi Personalization Runtime",
      "version": "1",
      "startup_route": "Home",
      "continue_watching": [
        {
          "kind": "movie",
          "content_key": "the-last-harbor",
          "channel_number": null,
          "title": "The Last Harbor",
          "caption": "42 min left",
          "summary": "Resume directly into the film.",
          "progress_label": "01:24 / 02:11 · Resume",
          "progress_value": 0.64,
          "resume_position_seconds": 5040,
          "last_viewed_at": "2026-04-13T00:00:00Z",
          "detail_lines": ["Feature playback keeps shell chrome out of the way."],
          "artwork": {"kind": "asset", "value": "assets/mocks/poster-shell-1.jpg"},
          "playback_source": {
            "kind": "movie",
            "source_key": "media_library",
            "content_key": "the-last-harbor",
            "source_label": "Media Library",
            "handoff_label": "Play movie"
          },
          "playback_stream": {
            "uri": "https://stream.crispy-tivi.test/media/the-last-harbor.m3u8",
            "transport": "hls",
            "live": false,
            "seekable": true,
            "resume_position_seconds": 5040,
            "source_options": [],
            "quality_options": [],
            "audio_options": [],
            "subtitle_options": []
          }
        }
      ],
      "recently_viewed": [],
      "favorite_media_keys": ["the-last-harbor"],
      "favorite_channel_numbers": []
    }
  }
}
''';

final ShellContractSupport _contract = ShellContractSupport.fromContract(
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

final SourceRegistrySnapshot _sourceRegistry =
    SourceRegistrySnapshot.fromJsonString('''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Catalog-backed provider.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
        {"id": "series", "title": "Series", "summary": "Series lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {
        "status": "Needs auth",
        "progress": "0%",
        "summary": "Credentials required.",
        "primary_action": "Verify access",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Portal credentials."]
      },
      "import": {"status": "Blocked", "progress": "0%", "summary": "Import blocked", "primary_action": "Continue", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "configured_providers": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "display_name": "Portal Demo",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Configured provider.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true},
        {"id": "series", "title": "Series", "summary": "Series lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {
        "status": "Complete",
        "progress": "100%",
        "summary": "Credentials saved.",
        "primary_action": "Refresh credentials",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Portal credentials."]
      },
      "import": {"status": "Ready", "progress": "Ready", "summary": "Ready to import.", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [
      {"step": "Source Type", "title": "Choose source type", "summary": "Pick provider family.", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Source type", "Display name"], "helper_lines": ["Ordered wizard."]}
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
''');
