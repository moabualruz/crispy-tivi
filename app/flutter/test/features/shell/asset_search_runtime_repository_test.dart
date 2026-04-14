import 'package:crispy_tivi/features/shell/data/asset_search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset search runtime repository implements the retained interface', () {
    expect(
      const AssetSearchRuntimeRepository(),
      isA<SearchRuntimeRepository>(),
    );
  });

  test('repository loads the search runtime asset', () async {
    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;
    const String assetJson = '''
{
  "title": "CrispyTivi Search Runtime",
  "version": "1",
  "query": "",
  "active_group_title": "Live TV",
  "groups": [
    {
      "title": "Live TV",
      "summary": "Live channels and guide-linked results.",
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
  "notes": ["Asset-backed search runtime snapshot."]
}
''';

    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetSearchRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage(assetJson);
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    const AssetSearchRuntimeRepository repository =
        AssetSearchRuntimeRepository();
    final SearchRuntimeSnapshot snapshot = await repository.load();

    expect(snapshot.title, 'CrispyTivi Search Runtime');
    expect(snapshot.activeGroupTitle, 'Live TV');
    expect(snapshot.groups.single.results.single.caption, 'Channel 118');
  });
}
