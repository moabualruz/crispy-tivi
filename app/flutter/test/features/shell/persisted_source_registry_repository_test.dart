import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/persisted_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_store.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persisted source registry merges saved configured providers with asset catalog', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetSourceRegistryRepository.assetPath) {
        return const StringCodec().encodeMessage(_assetRegistryJson);
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    final _MemorySourceRegistryStore store = _MemorySourceRegistryStore();
    final PersistedSourceRegistryRepository repository =
        PersistedSourceRegistryRepository(store: store);

    final SourceRegistrySnapshot initial = await repository.load();
    expect(initial.providerTypes, hasLength(1));
    expect(initial.configuredProviders, isEmpty);

    final SourceRegistrySnapshot saved = initial.copyWith(
      configuredProviders: initial.providerTypes,
    );
    await repository.save(saved);

    final SourceRegistrySnapshot reloaded = await repository.load();
    expect(reloaded.providerTypes, hasLength(1));
    expect(reloaded.configuredProviders, hasLength(1));
    expect(reloaded.configuredProviders.single.displayName, 'Xtream');
    expect(reloaded.configuredProviders.single.endpointLabel, 'Server URL • Username • Password');
  });
}

class _MemorySourceRegistryStore extends SourceRegistryStore {
  String? source;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String source) async {
    this.source = source;
  }
}

const String _assetRegistryJson = '''
{
  "title": "Source registry",
  "version": "1",
  "provider_types": [
    {
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
      "auth": {
        "status": "Needs auth",
        "progress": "0%",
        "summary": "Credentials required.",
        "primary_action": "Verify access",
        "secondary_action": "Back",
        "field_labels": ["Server URL", "Username", "Password"],
        "helper_lines": ["Portal access uses credentials."]
      },
      "import": {"status": "Blocked", "progress": "0%", "summary": "Blocked", "primary_action": "Start import", "secondary_action": "Review"},
      "onboarding_hint": "Authenticate first."
    }
  ],
  "configured_providers": [],
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
''';
