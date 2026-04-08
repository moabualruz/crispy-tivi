import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/multiview/domain/entities/active_stream.dart';
import 'package:crispy_tivi/features/multiview/domain/entities/multiview_session.dart';
import 'package:crispy_tivi/features/multiview/domain/entities/saved_layout.dart';
import 'package:crispy_tivi/features/multiview/domain/repositories/layout_repository.dart';
import 'package:crispy_tivi/features/multiview/presentation/providers/multiview_providers.dart';

class MockLayoutRepository implements LayoutRepository {
  final Map<String, SavedLayout> _layouts = {};

  @override
  Future<void> delete(String id) async {
    _layouts.remove(id);
  }

  @override
  String generateId() => 'mock_id_${_layouts.length}';

  @override
  Future<SavedLayout?> getById(String id) async {
    return _layouts[id];
  }

  @override
  Future<List<SavedLayout>> getAll() async {
    return _layouts.values.toList();
  }

  @override
  Future<void> save(SavedLayout layout) async {
    _layouts[layout.id] = layout;
  }
}

void main() {
  group('MultiViewNotifier Tests', () {
    late ProviderContainer container;
    late MockLayoutRepository mockRepo;

    setUp(() {
      mockRepo = MockLayoutRepository();
      container = ProviderContainer(
        overrides: [layoutRepositoryProvider.overrideWithValue(mockRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is 2x2 quad', () {
      final state = container.read(multiViewProvider);
      expect(state.layout, MultiViewLayout.twoByTwo);
      expect(state.preset, MultiViewPreset.quad);
      expect(state.slots.length, 4);
      expect(state.slots.every((element) => element == null), isTrue);
      expect(state.audioFocusIndex, 0);
    });

    test('setPreset updates layout and slots count', () {
      final notifier = container.read(multiViewProvider.notifier);

      notifier.setPreset(MultiViewPreset.pictureInPicture);
      var state = container.read(multiViewProvider);

      expect(state.layout, MultiViewLayout.twoByOne);
      expect(state.preset, MultiViewPreset.pictureInPicture);
      expect(state.slots.length, 2); // PiP has 2 active cells
    });

    test('addSlot / removeSlot', () {
      final notifier = container.read(multiViewProvider.notifier);
      final stream = ActiveStream(url: 'http://test.com', channelName: 'Test');

      notifier.addSlot(1, stream);
      var state = container.read(multiViewProvider);

      expect(state.slots[1], isNotNull);
      expect(state.slots[1]!.url, 'http://test.com');

      notifier.removeSlot(1);
      state = container.read(multiViewProvider);
      expect(state.slots[1], isNull);
    });

    test('setAudioFocus clamps correctly', () {
      final notifier = container.read(multiViewProvider.notifier);

      notifier.setAudioFocus(3);
      var state = container.read(multiViewProvider);
      expect(state.audioFocusIndex, 3);

      // Attempt invalid bounds (ignored by implementation bounds check)
      notifier.setAudioFocus(99);
      state = container.read(multiViewProvider);
      expect(state.audioFocusIndex, 3); // retains old value
    });

    test('swapSlots correctly trades streams', () {
      final notifier = container.read(multiViewProvider.notifier);
      final stream1 = ActiveStream(url: 'http://stream1', channelName: '1');
      final stream2 = ActiveStream(url: 'http://stream2', channelName: '2');

      notifier.addSlot(0, stream1);
      notifier.addSlot(1, stream2);

      notifier.swapSlots(0, 1);

      final state = container.read(multiViewProvider);
      expect(state.slots[0]!.url, 'http://stream2');
      expect(state.slots[1]!.url, 'http://stream1');
    });

    test('saveCurrentLayout formats and delegates to repository', () async {
      final notifier = container.read(multiViewProvider.notifier);
      final stream1 = ActiveStream(url: 'id_123', channelName: 'Test 1');
      notifier.addSlot(0, stream1);

      await notifier.saveCurrentLayout('My Layout');

      final layouts = await mockRepo.getAll();
      expect(layouts.length, 1);
      expect(layouts.first.name, 'My Layout');
      expect(layouts.first.streams.first!.channelId, 'id_123');
    });

    test('clearAll wipes streams but retains layout', () {
      final notifier = container.read(multiViewProvider.notifier);
      notifier.addSlot(
        0,
        ActiveStream(url: 'http://test', channelName: 'Test'),
      );

      notifier.clearAll();

      final state = container.read(multiViewProvider);
      expect(state.slots.every((element) => element == null), isTrue);
      expect(state.audioFocusIndex, 0);
    });
  });
}
