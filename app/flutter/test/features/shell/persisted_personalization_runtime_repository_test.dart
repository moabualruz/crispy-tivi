import 'package:crispy_tivi/features/shell/data/asset_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/persisted_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_store.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persisted personalization repository prefers stored snapshot',
    () async {
      final TestDefaultBinaryMessengerBinding binding =
          TestDefaultBinaryMessengerBinding.instance;

      binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
        ByteData? message,
      ) async {
        final String key = const StringCodec().decodeMessage(message)!;
        if (key == 'assets/contracts/asset_personalization_runtime.json') {
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

      final PersistedPersonalizationRuntimeRepository repository =
          PersistedPersonalizationRuntimeRepository(
            defaultsRepository: AssetPersonalizationRuntimeRepository(),
            store: _MemoryPersonalizationStore(
              initialValue: '''
{
  "title": "CrispyTivi Personalization Runtime",
  "version": "1",
  "startup_route": "Search",
  "continue_watching": [],
  "recently_viewed": [],
  "favorite_media_keys": ["the-last-harbor"],
  "favorite_channel_numbers": ["118"],
  "notes": ["Persisted snapshot."]
}
''',
            ),
          );

      final PersonalizationRuntimeSnapshot snapshot = await repository.load();

      expect(snapshot.startupRoute, 'Search');
      expect(snapshot.isFavoriteMediaKey('the-last-harbor'), isTrue);
      expect(snapshot.favoriteChannelNumbers, <String>['118']);
    },
  );
}

final class _MemoryPersonalizationStore extends PersonalizationRuntimeStore {
  const _MemoryPersonalizationStore({this.initialValue});

  final String? initialValue;

  @override
  Future<String?> load() async => initialValue;

  @override
  Future<void> save(String source) async {}
}
