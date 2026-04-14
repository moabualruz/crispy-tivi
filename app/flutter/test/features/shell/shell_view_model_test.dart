import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'source wizard back safety returns to previous step then overview',
    () async {
      final ShellViewModel viewModel = ShellViewModel(
        contract: contract,
        sourceRegistry: SourceRegistrySnapshot.fromJsonString(
          _initialSourceRegistryJson,
        ),
        shellRuntimeBridge: _RecordingRustBridge(),
      );

      viewModel.startAddSourceWizard();
      await _flushAsync();
      expect(viewModel.sourceWizardActive, isTrue);
      expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);

      viewModel.selectSourceWizardStep(SourceWizardStep.connection);
      await _flushAsync();
      expect(viewModel.sourceWizardStep, SourceWizardStep.connection);

      viewModel.retreatSourceWizard();
      await _flushAsync();
      expect(viewModel.sourceWizardActive, isTrue);
      expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);

      viewModel.retreatSourceWizard();
      await _flushAsync();
      expect(viewModel.sourceWizardActive, isFalse);
      expect(viewModel.settingsPanel, SettingsPanel.sources);
    },
  );

  test('reconnect flow starts at credentials step', () async {
    final ShellViewModel viewModel = ShellViewModel(
      contract: contract,
      sourceRegistry: SourceRegistrySnapshot.fromJsonString(
        _initialSourceRegistryJson,
      ),
      shellRuntimeBridge: _RecordingRustBridge(),
    );

    viewModel.startReconnectWizard();
    await _flushAsync();

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.credentials);
  });

  test('settings top-level group navigation keeps sources nested', () async {
    final ShellViewModel viewModel = ShellViewModel(
      contract: contract,
      sourceRegistry: SourceRegistrySnapshot.fromJsonString(
        _initialSourceRegistryJson,
      ),
      shellRuntimeBridge: _RecordingRustBridge(),
    );

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.sourceWizardActive, isTrue);

    viewModel.selectRoute(ShellRoute.settings);
    expect(viewModel.route, ShellRoute.settings);

    viewModel.selectSettingsPanel(SettingsPanel.playback);
    await _flushAsync();
    expect(viewModel.settingsPanel, SettingsPanel.playback);
    expect(viewModel.sourceWizardActive, isFalse);

    viewModel.selectSettingsPanel(SettingsPanel.sources);
    expect(viewModel.settingsPanel, SettingsPanel.sources);

    viewModel.startAddSourceWizard();
    await _flushAsync();
    expect(viewModel.sourceWizardActive, isTrue);
    expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);

    viewModel.selectSettingsPanel(SettingsPanel.appearance);
    await _flushAsync();
    expect(viewModel.settingsPanel, SettingsPanel.appearance);
    expect(viewModel.sourceWizardActive, isFalse);

    viewModel.selectSettingsPanel(SettingsPanel.sources);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.sourceWizardActive, isFalse);
    expect(viewModel.sourceWizardStep, SourceWizardStep.sourceType);
  });

  test(
    'settings search opens exact leaf and clears on manual navigation',
    () async {
      final ShellViewModel viewModel = ShellViewModel(
        contract: contract,
        sourceRegistry: SourceRegistrySnapshot.fromJsonString(
          _initialSourceRegistryJson,
        ),
        shellRuntimeBridge: _RecordingRustBridge(),
      );

      viewModel.selectRoute(ShellRoute.settings);
      viewModel.updateSettingsSearchQuery('storage');
      expect(viewModel.settingsSearchQuery, 'storage');
      expect(viewModel.highlightedSettingsLeaf, isNull);

      viewModel.openSettingsLeaf(
        panel: SettingsPanel.system,
        leafLabel: 'Storage',
      );
      await _flushAsync();

      expect(viewModel.route, ShellRoute.settings);
      expect(viewModel.settingsPanel, SettingsPanel.system);
      expect(viewModel.settingsSearchQuery, 'Storage');
      expect(viewModel.highlightedSettingsLeaf, 'Storage');

      viewModel.selectSettingsPanel(SettingsPanel.general);
      await _flushAsync();
      expect(viewModel.settingsSearchQuery, isEmpty);
      expect(viewModel.highlightedSettingsLeaf, isNull);
    },
  );

  test('settings source search opens exact source detail', () async {
    final ShellViewModel viewModel = ShellViewModel(
      contract: contract,
      sourceRegistry: SourceRegistrySnapshot.fromJsonString(
        _initialSourceRegistryJson,
      ),
      shellRuntimeBridge: _RecordingRustBridge(),
    );

    viewModel.openSettingsLeaf(
      panel: SettingsPanel.sources,
      leafLabel: ShellViewModel.sourcesLeafLabel(1),
      sourceIndex: 1,
    );
    await _flushAsync();

    expect(viewModel.route, ShellRoute.settings);
    expect(viewModel.settingsPanel, SettingsPanel.sources);
    expect(viewModel.selectedSourceIndex, 1);
    expect(viewModel.highlightedSettingsLeaf, 'source:1');
    expect(viewModel.sourceWizardActive, isFalse);
  });

  test('source registry maps typed provider state from runtime registry', () {
    final sourceRegistry = SourceRegistrySnapshot.fromJsonString('''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [{
    "provider_key": "m3u_url",
    "provider_type": "M3U URL",
    "family": "playlist",
    "connection_mode": "remote_url",
    "summary": "Remote playlist lane.",
    "capabilities": [
      {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
      {"id": "guide", "title": "Guide", "summary": "Guide lane", "supported": true},
      {"id": "catch_up", "title": "Catch-up", "summary": "Catch-up lane", "supported": true}
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
  }],
  "onboarding": {
    "selected_provider_type": "M3U URL",
    "active_step": "Source Type",
    "step_order": ["Source Type"],
    "steps": [{
      "step": "Source Type",
      "title": "Choose source type",
      "summary": "Pick the provider integration first.",
      "primary_action": "Continue",
      "secondary_action": "Back",
      "field_labels": ["Source type", "Display name"],
      "helper_lines": ["Keep provider-specific flow inside Settings."]
    }],
    "provider_copy": []
  },
  "registry_notes": []
}
''');
    final ShellViewModel viewModel = ShellViewModel(
      contract: contract,
      sourceRegistry: sourceRegistry,
    );

    expect(viewModel.sourceRegistry.providers, hasLength(1));
    expect(
      viewModel.sourceRegistry.providers.single.providerKind,
      SourceProviderKind.m3uUrl,
    );
    expect(
      viewModel.sourceRegistry.providers.single.healthState,
      SourceHealthState.healthy,
    );
    expect(
      viewModel.sourceRegistry.providers.single.authState,
      SourceAuthState.connected,
    );
    expect(
      viewModel.sourceRegistry.providers.single.importState,
      SourceImportState.ready,
    );
    expect(
      viewModel.sourceRegistry.providers.single.capabilities,
      hasLength(3),
    );
    expect(
      viewModel.sourceRegistry.providers.single.capabilities.first.kind,
      SourceCapabilityKind.liveTv,
    );
    expect(viewModel.sourceRegistry.wizardSteps, hasLength(1));
  });

  test('personalization state persists through the coordinator seam', () async {
    final _RecordingPersonalizationRuntimeRepository fakeRepository =
        _RecordingPersonalizationRuntimeRepository();
    final ShellViewModel viewModel = ShellViewModel(
      contract: contract,
      sourceRegistry: SourceRegistrySnapshot.fromJsonString(
        _initialSourceRegistryJson,
      ),
      personalizationRepository: fakeRepository,
    );

    viewModel.selectRoute(ShellRoute.liveTv);
    await _flushAsync();

    expect(viewModel.personalizationRuntime.startupRoute, 'Live TV');
    expect(fakeRepository.savedSnapshots, isNotEmpty);
    expect(fakeRepository.savedSnapshots.last.startupRoute, 'Live TV');

    viewModel.toggleMediaWatchlist('movie-1');
    await _flushAsync();

    expect(
      viewModel.personalizationRuntime.favoriteMediaKeys,
      contains('movie-1'),
    );
    expect(
      fakeRepository.savedSnapshots.last.favoriteMediaKeys,
      contains('movie-1'),
    );
  });

  test(
    'source setup state is consumed from the rust bridge instead of local controller logic',
    () async {
      final _RecordingRustBridge fakeBridge = _RecordingRustBridge();
      final _RecordingSourceRegistryRepository fakeRepository =
          _RecordingSourceRegistryRepository();
      final ShellViewModel viewModel = ShellViewModel(
        contract: contract,
        sourceRegistry: SourceRegistrySnapshot.fromJsonString(
          _initialSourceRegistryJson,
        ),
        shellRuntimeBridge: fakeBridge,
        sourceRegistryRepository: fakeRepository,
      );

      viewModel.startReconnectWizard();
      await _flushAsync();

      expect(fakeBridge.updateCalls, greaterThan(0));
      expect(viewModel.sourceWizardActive, isTrue);
      expect(viewModel.sourceWizardStep, SourceWizardStep.credentials);
      expect(fakeRepository.savedSnapshots, isEmpty);
    },
  );

  test('media and search presentation derive from retained runtime', () async {
    final String mediaSource = await rootBundle.loadString(
      'assets/contracts/asset_media_runtime.json',
    );
    final String searchSource = await rootBundle.loadString(
      'assets/contracts/asset_search_runtime.json',
    );
    final MediaRuntimeSnapshot mediaRuntime =
        MediaRuntimeSnapshot.fromJsonString(mediaSource);
    final SearchRuntimeSnapshot searchRuntime =
        SearchRuntimeSnapshot.fromJsonString(searchSource);
    final ShellViewModel viewModel = ShellViewModel(
      contract: contract,
      mediaRuntime: mediaRuntime,
      searchRuntime: searchRuntime,
    );

    expect(viewModel.mediaPresentation.movieHero.title, 'The Last Harbor');
    expect(viewModel.mediaPresentation.topFilms, hasLength(2));
    expect(viewModel.searchPresentation.groups, hasLength(3));
    expect(viewModel.searchPresentation.groups.first.title, 'Live TV');
  });

  test(
    'empty retained runtimes do not backfill live tv and search from shell content',
    () async {
      await rootBundle.loadString('assets/contracts/asset_shell_content.json');
      final ShellViewModel viewModel = ShellViewModel(
        contract: contract,
        liveTvRuntime: const LiveTvRuntimeSnapshot.empty(),
        searchRuntime: const SearchRuntimeSnapshot.empty(),
      );

      expect(viewModel.liveTvRuntime.channels, isEmpty);
      expect(viewModel.searchPresentation.groups, isEmpty);
    },
  );

  test(
    'home continue watching stays empty when personalization is empty',
    () async {
      final String mediaSource = await rootBundle.loadString(
        'assets/contracts/asset_media_runtime.json',
      );
      final MediaRuntimeSnapshot mediaRuntime =
          MediaRuntimeSnapshot.fromJsonString(mediaSource);
      final ShellViewModel viewModel = ShellViewModel(
        contract: contract,
        mediaRuntime: mediaRuntime,
        personalizationRuntime: const PersonalizationRuntimeSnapshot.empty(),
      );

      expect(viewModel.homeContinueWatchingItems, isEmpty);
    },
  );

  test('live tv focus updates selection and activation changes playback', () {
    final ShellViewModel viewModel = ShellViewModel(contract: contract);

    expect(viewModel.liveTvFocusedChannelIndex, 0);
    expect(viewModel.liveTvPlayingChannelIndex, 0);

    viewModel.selectLiveTvChannelIndex(1);
    expect(viewModel.liveTvFocusedChannelIndex, 1);
    expect(viewModel.liveTvPlayingChannelIndex, 0);

    viewModel.activateLiveTvFocusedChannel();
    expect(viewModel.liveTvFocusedChannelIndex, 1);
    expect(viewModel.liveTvPlayingChannelIndex, 1);

    viewModel.selectLiveTvGroup('sports');
    expect(viewModel.liveTvFocusedChannelIndex, 0);
    expect(viewModel.liveTvPlayingChannelIndex, 0);
  });

  test('player unwind closes chooser before info before exit', () {
    final ShellViewModel viewModel = ShellViewModel(contract: contract);
    final PlayerSession session = PlayerSession(
      kind: PlayerContentKind.movie,
      originLabel: 'Media · Movies',
      queueLabel: 'Up next',
      queue: const <PlayerQueueItem>[
        PlayerQueueItem(
          eyebrow: 'Featured film',
          title: 'The Last Harbor',
          subtitle: 'Thriller',
          summary: 'Feature playback summary.',
          progressLabel: '00:24 / 02:11',
          progressValue: 0.18,
          badges: <String>['4K'],
          detailLines: <String>['Detail line'],
        ),
      ],
      activeIndex: 0,
      primaryActionLabel: 'Resume playback',
      secondaryActionLabel: 'Watch from start',
      chooserGroups: const <PlayerChooserGroup>[
        PlayerChooserGroup(
          kind: PlayerChooserKind.audio,
          title: 'Audio',
          options: <PlayerChooserOption>[
            PlayerChooserOption(id: 'english', label: 'English'),
          ],
          selectedIndex: 0,
        ),
      ],
      statsLines: <String>['Resolved stream'],
    );

    viewModel.launchPlayer(session);
    viewModel.openPlayerInfo();
    viewModel.openPlayerChooser(PlayerChooserKind.audio);

    expect(viewModel.playerSession, isNotNull);
    expect(viewModel.playerChromeState, PlayerChromeState.expandedInfo);
    expect(viewModel.activePlayerChooser, PlayerChooserKind.audio);

    viewModel.unwindPlayer();
    expect(viewModel.playerSession, isNotNull);
    expect(viewModel.activePlayerChooser, isNull);
    expect(viewModel.playerChromeState, PlayerChromeState.expandedInfo);

    viewModel.unwindPlayer();
    expect(viewModel.playerSession, isNotNull);
    expect(viewModel.playerChromeState, PlayerChromeState.transport);

    viewModel.unwindPlayer();
    expect(viewModel.playerSession, isNull);
  });

  test(
    'player persistence flows through personalization coordinator seam',
    () async {
      final _RecordingPersonalizationRuntimeRepository fakeRepository =
          _RecordingPersonalizationRuntimeRepository();
      final ShellViewModel viewModel = ShellViewModel(
        contract: contract,
        personalizationRepository: fakeRepository,
      );
      final PlayerSession session = PlayerSession(
        kind: PlayerContentKind.movie,
        originLabel: 'Media · Movies',
        queueLabel: 'Up next',
        queue: const <PlayerQueueItem>[
          PlayerQueueItem(
            eyebrow: 'Featured film',
            title: 'The Last Harbor',
            subtitle: 'Thriller',
            summary: 'Feature playback summary.',
            progressLabel: '05:00 / 20:00 · Resume',
            progressValue: 0.25,
            badges: <String>['4K'],
            detailLines: <String>['Detail line'],
            playbackSource: PlaybackSourceSnapshot(
              kind: 'movie',
              sourceKey: 'media_library',
              contentKey: 'the-last-harbor',
              sourceLabel: 'Media Library',
              handoffLabel: 'Play movie',
            ),
            playbackStream: PlaybackStreamSnapshot(
              uri: 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
              transport: 'hls',
              live: false,
              seekable: true,
              resumePositionSeconds: 300,
              sourceOptions: <PlaybackVariantOptionSnapshot>[],
              qualityOptions: <PlaybackVariantOptionSnapshot>[],
              audioOptions: <PlaybackTrackOptionSnapshot>[],
              subtitleOptions: <PlaybackTrackOptionSnapshot>[],
            ),
          ),
        ],
        activeIndex: 0,
        primaryActionLabel: 'Resume playback',
        secondaryActionLabel: 'Watch from start',
        chooserGroups: const <PlayerChooserGroup>[],
        statsLines: <String>['Resolved stream'],
      );

      viewModel.launchPlayer(session);
      viewModel.unwindPlayer();
      await _flushAsync();

      expect(fakeRepository.savedSnapshots, isNotEmpty);
      expect(
        fakeRepository.savedSnapshots.last.continueWatching.first.contentKey,
        'the-last-harbor',
      );
      expect(
        fakeRepository.savedSnapshots.last.continueWatching.first.progressLabel,
        '05:00 / 20:00 · Resume',
      );
    },
  );
}

class _RecordingRustBridge implements ShellRuntimeBridge {
  int commitCalls = 0;
  int updateCalls = 0;

  @override
  Future<String> loadSourceRegistryJson() async => '{}';

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
    updateCalls += 1;
    final Map<String, dynamic> registry =
        jsonDecode(sourceRegistryJson) as Map<String, dynamic>;
    final Map<String, dynamic> onboarding = Map<String, dynamic>.from(
      registry['onboarding'] as Map<String, dynamic>,
    );
    final List<String> stepOrder = List<String>.from(
      onboarding['step_order'] as List<dynamic>? ??
          const <String>[
            'Source Type',
            'Connection',
            'Credentials',
            'Import',
            'Finish',
          ],
    );
    final Map<String, dynamic> fieldValues = Map<String, dynamic>.from(
      onboarding['field_values'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    );

    void clearWizard() {
      onboarding['wizard_active'] = false;
      onboarding['wizard_mode'] = 'idle';
      onboarding['active_step'] = stepOrder.first;
      onboarding['field_values'] = <String, String>{};
    }

    switch (action) {
      case 'start_add':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'add';
        onboarding['active_step'] = stepOrder.first;
        onboarding['field_values'] = <String, String>{};
      case 'start_reconnect':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'reconnect';
        onboarding['active_step'] = 'Credentials';
        onboarding['field_values'] = <String, String>{};
      case 'start_edit':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'edit';
        onboarding['active_step'] = 'Connection';
        onboarding['field_values'] = <String, String>{};
      case 'start_import':
        onboarding['wizard_active'] = true;
        onboarding['wizard_mode'] = 'import';
        onboarding['active_step'] = 'Import';
        onboarding['field_values'] = <String, String>{};
      case 'select_wizard_step':
        onboarding['active_step'] = targetStep;
      case 'select_provider_type':
        onboarding['selected_provider_type'] = selectedProviderType;
        fieldValues['source_type'] = selectedProviderType ?? '';
        onboarding['field_values'] = fieldValues;
      case 'update_field':
        fieldValues[fieldKey ?? ''] = fieldValue ?? '';
        onboarding['field_values'] = fieldValues;
      case 'advance_wizard':
        final String activeStep =
            onboarding['active_step'] as String? ?? stepOrder.first;
        final int index = stepOrder.indexOf(activeStep);
        if (index >= 0 && index + 1 < stepOrder.length) {
          onboarding['active_step'] = stepOrder[index + 1];
        }
      case 'retreat_wizard':
        final String activeStep =
            onboarding['active_step'] as String? ?? stepOrder.first;
        final int index = stepOrder.indexOf(activeStep);
        if (index > 0) {
          onboarding['active_step'] = stepOrder[index - 1];
        } else {
          clearWizard();
        }
      case 'clear_wizard':
        clearWizard();
      case 'select_source':
        onboarding['selected_source_index'] = selectedSourceIndex ?? 0;
        clearWizard();
      default:
        break;
    }

    registry['onboarding'] = onboarding;
    return jsonEncode(registry);
  }

  @override
  Future<String> hydrateRuntimeBundleJson({String? sourceRegistryJson}) async {
    return _runtimeBundleJson;
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
    commitCalls += 1;
    return _runtimeBundleJson;
  }

  @override
  Future<String> loadDiagnosticsRuntimeJson() async {
    throw UnimplementedError();
  }
}

class _RecordingPersonalizationRuntimeRepository
    implements PersonalizationRuntimeRepository {
  final List<PersonalizationRuntimeSnapshot> savedSnapshots =
      <PersonalizationRuntimeSnapshot>[];

  @override
  Future<PersonalizationRuntimeSnapshot> load() async {
    if (savedSnapshots.isEmpty) {
      return const PersonalizationRuntimeSnapshot.empty();
    }
    return savedSnapshots.last;
  }

  @override
  Future<void> save(PersonalizationRuntimeSnapshot snapshot) async {
    savedSnapshots.add(snapshot);
  }
}

Future<void> _flushAsync() => Future<void>.delayed(Duration.zero);

const String _initialSourceRegistryJson = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [{
    "provider_key": "xtream",
    "provider_type": "Xtream",
    "family": "portal",
    "connection_mode": "portal_account",
    "summary": "Xtream provider.",
    "capabilities": [
      {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
      {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true}
    ],
    "health": {"status": "Needs auth", "summary": "Needs credentials.", "last_checked": "never", "last_sync": "never"},
    "auth": {"status": "Needs auth", "progress": "0%", "summary": "Credentials required.", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Server URL", "Username", "Password"], "helper_lines": ["Portal access uses credentials."]},
    "import": {"status": "Blocked", "progress": "0%", "summary": "Blocked", "primary_action": "Start import", "secondary_action": "Review"},
    "onboarding_hint": "Authenticate first."
  }],
  "configured_providers": [],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "wizard_active": true,
    "wizard_mode": "add",
    "selected_source_index": 0,
    "field_values": {},
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [
      {"step": "Source Type", "title": "Choose source type", "summary": "Pick provider family.", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Source type", "Display name"], "helper_lines": ["Ordered wizard."]},
      {"step": "Connection", "title": "Connection", "summary": "Connection", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Connection"], "helper_lines": ["Connection step."]},
      {"step": "Credentials", "title": "Credentials", "summary": "Credentials", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Credentials"], "helper_lines": ["Credentials step."]},
      {"step": "Import", "title": "Import", "summary": "Import", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Import"], "helper_lines": ["Import step."]},
      {"step": "Finish", "title": "Finish", "summary": "Finish", "primary_action": "Return to sources", "secondary_action": "Back", "field_labels": ["Validation result"], "helper_lines": ["Done."]}
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
''';

const String _runtimeBundleJson = '''
{
  "source_registry": {
    "title": "Source registry",
    "version": "1",
    "provider_types": [{
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Xtream provider.",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true}
      ],
      "health": {"status": "Needs auth", "summary": "Needs credentials.", "last_checked": "never", "last_sync": "never"},
      "auth": {"status": "Needs auth", "progress": "0%", "summary": "Credentials required.", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Server URL", "Username", "Password"], "helper_lines": ["Portal access uses credentials."]},
      "import": {"status": "Blocked", "progress": "0%", "summary": "Blocked", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }],
    "configured_providers": [{
      "provider_key": "portal_demo",
      "provider_type": "Xtream",
      "display_name": "Portal Demo",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Configured provider.",
      "endpoint_label": "http://portal.example.test",
      "capabilities": [
        {"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true},
        {"id": "movies", "title": "Movies", "summary": "Movie lane", "supported": true}
      ],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Complete", "progress": "100%", "summary": "Credentials saved.", "primary_action": "Edit provider", "secondary_action": "Back", "field_labels": ["Server URL", "Username", "Password"], "helper_lines": ["Portal access uses credentials."]},
      "import": {"status": "Ready", "progress": "Ready", "summary": "Import ready.", "primary_action": "Run import flow", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }],
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
  },
  "runtime": {
    "live_tv": {
      "title": "Live Runtime",
      "version": "1",
      "provider": {"provider_key": "portal_demo", "provider_type": "Xtream", "family": "portal", "connection_mode": "portal_account", "source_name": "Portal Demo", "status": "Healthy", "summary": "Configured provider", "last_sync": "now", "guide_health": "Good"},
      "browsing": {"active_panel": "Channels", "selected_group": "All", "selected_channel": "101 Crispy One", "group_order": ["All"], "groups": [{"id": "all", "title": "All", "summary": "All channels", "channel_count": 1, "selected": true}]},
      "channels": [{"number": "101", "name": "Crispy One", "group": "All", "state": "selected", "live_edge": true, "catch_up": true, "archive": false, "current": {"title": "Now", "summary": "Current", "start": "21:00", "end": "22:00", "progress_percent": 50}, "next": {"title": "Next", "summary": "Next", "start": "22:00", "end": "23:00", "progress_percent": 0}}],
      "guide": {"title": "Guide", "window_start": "21:00", "window_end": "22:00", "time_slots": ["21:00"], "rows": [{"channel_number": "101", "channel_name": "Crispy One", "slots": [{"start": "21:00", "end": "22:00", "title": "Now", "state": "live"}]}]},
      "selection": {"channel_number": "101", "channel_name": "Crispy One", "status": "Live", "live_edge": true, "catch_up": true, "archive": false, "now": {"title": "Now", "summary": "Current", "start": "21:00", "end": "22:00", "progress_percent": 50}, "next": {"title": "Next", "summary": "Next", "start": "22:00", "end": "23:00", "progress_percent": 0}, "primary_action": "Watch live", "secondary_action": "Restart", "badges": ["HD"], "detail_lines": ["Guide loaded"]},
      "notes": []
    },
    "media": {
      "title": "Media Runtime",
      "version": "1",
      "active_panel": "Movies",
      "active_scope": "Featured",
      "movie_hero": {"kicker": "Featured film", "title": "The Last Harbor", "summary": "Summary", "primary_action": "Resume", "secondary_action": "Details"},
      "series_hero": {"kicker": "Series spotlight", "title": "Signal Point", "summary": "Series summary", "primary_action": "Resume", "secondary_action": "Details"},
      "movie_collections": [{"title": "Featured", "summary": "Summary", "items": [{"title": "The Last Harbor", "caption": "Thriller"}]}],
      "series_collections": [{"title": "Series", "summary": "Summary", "items": [{"title": "Signal Point", "caption": "Drama"}]}],
      "series_detail": {"summary_title": "Signal Point", "summary_body": "Series summary", "handoff_label": "Open series", "seasons": [{"label": "Season 1", "summary": "First season", "episodes": [{"code": "S1:E1", "title": "Pilot", "summary": "Episode summary", "duration_label": "45 min", "handoff_label": "Resume episode"}]}]},
      "notes": []
    },
    "search": {
      "title": "Search Runtime",
      "version": "32",
      "query": "",
      "active_group_title": "Live TV",
      "groups": [{"title": "Live TV", "summary": "Results", "selected": true, "results": [{"title": "Crispy One", "caption": "Channel 101", "source_label": "Portal Demo", "handoff_label": "Open live"}]}],
      "notes": []
    },
    "personalization": {
      "title": "Personalization Runtime",
      "version": "1",
      "startup_route": "Home",
      "continue_watching": [],
      "recently_viewed": [],
      "favorite_media_keys": [],
      "favorite_channel_numbers": [],
      "notes": []
    }
  }
}
''';

class _RecordingSourceRegistryRepository extends SourceRegistryRepository {
  final List<SourceRegistrySnapshot> savedSnapshots =
      <SourceRegistrySnapshot>[];

  @override
  Future<SourceRegistrySnapshot> load() async =>
      const SourceRegistrySnapshot.empty();

  @override
  Future<void> save(SourceRegistrySnapshot snapshot) async {
    savedSnapshots.add(snapshot);
  }
}
