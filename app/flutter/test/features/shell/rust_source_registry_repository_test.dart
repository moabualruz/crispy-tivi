import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/rust_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real mode strips seeded configured providers from Rust defaults', () async {
    final RustSourceRegistryRepository repository = RustSourceRegistryRepository(
      bridge: _FakeShellRuntimeBridge(),
      store: const _MemorySourceRegistryStore(),
    );

    final snapshot = await repository.load();

    expect(snapshot.configuredProviders, isEmpty);
    expect(snapshot.wizardActive, isTrue);
    expect(snapshot.wizardMode, 'add');
  });

  test('demo mode requests seeded providers from Rust action path', () async {
    final _FakeShellRuntimeBridge bridge = _FakeShellRuntimeBridge();
    final RustSourceRegistryRepository repository = RustSourceRegistryRepository(
      bridge: bridge,
      store: const _MemorySourceRegistryStore(),
      demoMode: true,
    );

    final snapshot = await repository.load();

    expect(bridge.lastAction, 'seed_demo');
    expect(snapshot.configuredProviders, isNotEmpty);
    expect(snapshot.wizardActive, isFalse);
    expect(snapshot.wizardMode, 'idle');
  });
}

final class _FakeShellRuntimeBridge implements ShellRuntimeBridge {
  String? lastAction;

  @override
  Future<String> loadSourceRegistryJson() async => '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "display_name": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login.",
      "endpoint_label": "portal.example.test",
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Healthy", "progress": "100%", "summary": "Ready", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Server URL"], "helper_lines": ["Portal credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "configured_providers": [],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "wizard_active": true,
    "wizard_mode": "add",
    "selected_source_index": 0,
    "field_values": {},
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [],
    "provider_copy": []
  },
  "registry_notes": []
}
''';

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
    lastAction = action;
    if (action == 'seed_demo') {
      return '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
      "provider_key": "xtream",
      "provider_type": "Xtream",
      "display_name": "Xtream",
      "family": "portal",
      "connection_mode": "portal_account",
      "summary": "Provider login.",
      "endpoint_label": "portal.example.test",
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Healthy", "progress": "100%", "summary": "Ready", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Server URL"], "helper_lines": ["Portal credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
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
      "capabilities": [{"id": "live_tv", "title": "Live TV", "summary": "Live lane", "supported": true}],
      "health": {"status": "Healthy", "summary": "Ready", "last_checked": "now", "last_sync": "now"},
      "auth": {"status": "Complete", "progress": "100%", "summary": "Ready", "primary_action": "Verify access", "secondary_action": "Back", "field_labels": ["Server URL"], "helper_lines": ["Portal credentials."]},
      "import": {"status": "Ready", "progress": "100%", "summary": "Ready", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "onboarding": {
    "selected_provider_type": "Xtream",
    "active_step": "Source Type",
    "wizard_active": false,
    "wizard_mode": "idle",
    "selected_source_index": 0,
    "field_values": {},
    "step_order": ["Source Type", "Connection", "Credentials", "Import", "Finish"],
    "steps": [],
    "provider_copy": []
  },
  "registry_notes": []
}
''';
    }
    return sourceRegistryJson;
  }

  @override
  Future<String> hydrateRuntimeBundleJson({String? sourceRegistryJson}) async =>
      throw UnimplementedError();

  @override
  Future<String> loadPlaybackRuntimeJson({String? sourceRegistryJson}) async =>
      throw UnimplementedError();

  @override
  Future<String> loadPlaybackSessionRuntimeJsonFromStreamJson({
    required String playbackStreamJson,
    int? sourceIndex,
    int? qualityIndex,
    int? audioIndex,
    int? subtitleIndex,
  }) async => throw UnimplementedError();

  @override
  Future<String> commitSourceSetupJson({
    required String sourceRegistryJson,
  }) async => throw UnimplementedError();

  @override
  Future<String> loadDiagnosticsRuntimeJson() async =>
      throw UnimplementedError();
}

final class _MemorySourceRegistryStore extends SourceRegistryStore {
  const _MemorySourceRegistryStore();

  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String source) async {}
}
