import 'dart:convert';

import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_source_setup_coordinator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applyAction consumes the Rust setup seam for wizard transitions', () async {
    final _MemorySourceRegistryRepository repository =
        _MemorySourceRegistryRepository();
    final _CoordinatorRustBridge bridge = _CoordinatorRustBridge();
    final ShellSourceSetupCoordinator coordinator =
        ShellSourceSetupCoordinator(
          sourceRegistryRepository: repository,
          shellRuntimeBridge: bridge,
        );

    final SourceRegistrySnapshot initial = SourceRegistrySnapshot.fromJsonString(
      _initialSourceRegistryJson,
    );

    final SourceRegistrySnapshot updated = await coordinator.applyAction(
      sourceRegistry: initial,
      action: 'start_reconnect',
      selectedSourceIndex: 0,
    );

    expect(updated.wizardActive, isTrue);
    expect(updated.wizardMode, 'reconnect');
    expect(updated.activeWizardStep, SourceWizardStep.credentials);
    expect(updated.selectedSourceIndex, 0);
    expect(bridge.updateCalls, 1);
  });

  test('advance commits the final step through Rust and persists the bundle registry', () async {
    final _MemorySourceRegistryRepository repository =
        _MemorySourceRegistryRepository();
    final _CoordinatorRustBridge bridge = _CoordinatorRustBridge();
    final ShellSourceSetupCoordinator coordinator =
        ShellSourceSetupCoordinator(
          sourceRegistryRepository: repository,
          shellRuntimeBridge: bridge,
        );

    final SourceRegistrySnapshot finalStep = SourceRegistrySnapshot.fromJsonString(
      _finalStepSourceRegistryJson,
    );

    final SourceSetupAdvanceResult result = await coordinator.advance(
      sourceRegistry: finalStep,
    );

    expect(result.runtimeBundle, isNotNull);
    expect(result.sourceRegistry, isNull);
    expect(bridge.commitCalls, 1);
    expect(repository.saved, isNotNull);
    expect(repository.saved!.configuredProviders, isNotEmpty);
  });
}

final class _MemorySourceRegistryRepository extends SourceRegistryRepository {
  SourceRegistrySnapshot? saved;

  @override
  Future<SourceRegistrySnapshot> load() async {
    return saved ?? const SourceRegistrySnapshot.empty();
  }

  @override
  Future<void> save(SourceRegistrySnapshot snapshot) async {
    saved = snapshot;
  }
}

final class _CoordinatorRustBridge implements ShellRuntimeBridge {
  int updateCalls = 0;
  int commitCalls = 0;

  @override
  Future<String> loadSourceRegistryJson() async => _initialSourceRegistryJson;

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
    if (action == 'start_reconnect') {
      onboarding['wizard_active'] = true;
      onboarding['wizard_mode'] = 'reconnect';
      onboarding['active_step'] = 'Credentials';
      onboarding['selected_source_index'] = selectedSourceIndex ?? 0;
    }
    registry['onboarding'] = onboarding;
    return jsonEncode(registry);
  }

  @override
  Future<String> hydrateRuntimeBundleJson({String? sourceRegistryJson}) async {
    throw UnimplementedError();
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
    final String liveTvJson = await rootBundle.loadString(
      'assets/contracts/asset_live_tv_runtime.json',
    );
    final String mediaJson = await rootBundle.loadString(
      'assets/contracts/asset_media_runtime.json',
    );
    final String searchJson = await rootBundle.loadString(
      'assets/contracts/asset_search_runtime.json',
    );
    return jsonEncode(<String, dynamic>{
      'source_registry': jsonDecode(sourceRegistryJson),
      'runtime': <String, dynamic>{
        'live_tv': jsonDecode(liveTvJson),
        'media': jsonDecode(mediaJson),
        'search': jsonDecode(searchJson),
        'personalization': <String, dynamic>{
          'title': 'Personalization Runtime',
          'version': '1',
          'startup_route': 'Settings',
          'continue_watching': <dynamic>[],
          'recently_viewed': <dynamic>[],
          'favorite_media_keys': <dynamic>[],
          'favorite_channel_numbers': <dynamic>[],
          'notes': <dynamic>[],
        },
      },
    });
  }

  @override
  Future<String> loadDiagnosticsRuntimeJson() async {
    throw UnimplementedError();
  }
}

const String _initialSourceRegistryJson = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "ott",
      "connection_mode": "portal",
      "summary": "Xtream provider",
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live", "supported": true}],
      "health": {"status": "Healthy", "summary": "Healthy", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Ready", "progress": "100%", "summary": "Connected", "primary_action": "Reconnect", "secondary_action": "Import", "field_labels": ["Username", "Password"], "helper_lines": ["Use credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Use Xtream credentials."
    }
  ],
  "configured_providers": [
    {
      "provider_key": "xtream-main",
      "provider_type": "Xtream",
      "family": "ott",
      "connection_mode": "portal",
      "display_name": "Xtream",
      "summary": "Configured Xtream provider",
      "endpoint_label": "http://provider.example.com",
      "last_sync": "now",
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live", "supported": true}],
      "health": {"status": "Healthy", "summary": "Healthy", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Ready", "progress": "100%", "summary": "Connected", "primary_action": "Reconnect", "secondary_action": "Import", "field_labels": ["Username", "Password"], "helper_lines": ["Use credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Use Xtream credentials."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "wizard_active": false,
    "wizard_mode": "idle",
    "selected_source_index": 0,
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [
      {"step": "Source Type", "title": "Choose source type", "summary": "Pick provider family.", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Source type", "Display name"], "helper_lines": ["Ordered wizard."]},
      {"step": "Connection", "title": "Add connection details", "summary": "Connection first.", "primary_action": "Validate connection", "secondary_action": "Back", "field_labels": ["Connection endpoint"], "helper_lines": ["Validate first."]},
      {"step": "Credentials", "title": "Authenticate source", "summary": "Credentials second.", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Username", "Password"], "helper_lines": ["Safe unwind."]},
      {"step": "Import", "title": "Choose import scope", "summary": "Pick lanes.", "primary_action": "Start import", "secondary_action": "Back", "field_labels": ["Import scope", "Validation result"], "helper_lines": ["Explicit import."]},
      {"step": "Finish", "title": "Finish setup", "summary": "Return to sources.", "primary_action": "Return to sources", "secondary_action": "Back", "field_labels": ["Validation result", "Import scope"], "helper_lines": ["Done."]}
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
''';

const String _finalStepSourceRegistryJson = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "family": "ott",
      "connection_mode": "portal",
      "summary": "Xtream provider",
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live", "supported": true}],
      "health": {"status": "Healthy", "summary": "Healthy", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Ready", "progress": "100%", "summary": "Connected", "primary_action": "Reconnect", "secondary_action": "Import", "field_labels": ["Username", "Password"], "helper_lines": ["Use credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Use Xtream credentials."
    }
  ],
  "configured_providers": [
    {
      "provider_key": "xtream-main",
      "provider_type": "Xtream",
      "family": "ott",
      "connection_mode": "portal",
      "display_name": "Xtream",
      "summary": "Configured Xtream provider",
      "endpoint_label": "http://provider.example.com",
      "last_sync": "now",
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live", "supported": true}],
      "health": {"status": "Healthy", "summary": "Healthy", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Ready", "progress": "100%", "summary": "Connected", "primary_action": "Reconnect", "secondary_action": "Import", "field_labels": ["Username", "Password"], "helper_lines": ["Use credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Use Xtream credentials."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Finish",
    "wizard_active": true,
    "wizard_mode": "add",
    "selected_source_index": 0,
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [
      {"step": "Source Type", "title": "Choose source type", "summary": "Pick provider family.", "primary_action": "Continue", "secondary_action": "Back", "field_labels": ["Source type", "Display name"], "helper_lines": ["Ordered wizard."]},
      {"step": "Connection", "title": "Add connection details", "summary": "Connection first.", "primary_action": "Validate connection", "secondary_action": "Back", "field_labels": ["Connection endpoint"], "helper_lines": ["Validate first."]},
      {"step": "Credentials", "title": "Authenticate source", "summary": "Credentials second.", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Username", "Password"], "helper_lines": ["Safe unwind."]},
      {"step": "Import", "title": "Choose import scope", "summary": "Pick lanes.", "primary_action": "Start import", "secondary_action": "Back", "field_labels": ["Import scope", "Validation result"], "helper_lines": ["Explicit import."]},
      {"step": "Finish", "title": "Finish setup", "summary": "Return to sources.", "primary_action": "Return to sources", "secondary_action": "Back", "field_labels": ["Validation result", "Import scope"], "helper_lines": ["Done."]}
    ],
    "provider_copy": []
  },
  "registry_notes": []
}
''';
