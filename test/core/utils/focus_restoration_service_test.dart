import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/navigation/shell_providers.dart';
import 'package:crispy_tivi/core/utils/focus_restoration_service.dart';

void main() {
  group('FocusRestorationService', () {
    group('focusRestorationProvider', () {
      test('returns null for routes that have not been visited', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final key = container
            .read(focusRestorationProvider.notifier)
            .getKey('/home');
        expect(key, isNull);
      });

      test('stores a Key per route path string', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const testKey = ValueKey('test-item');
        container
            .read(focusRestorationProvider.notifier)
            .setKey('/home', testKey);

        final result = container
            .read(focusRestorationProvider.notifier)
            .getKey('/home');
        expect(result, equals(testKey));
      });

      test('overwrites previous key when set again for same route', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const firstKey = ValueKey('first');
        const secondKey = ValueKey('second');

        final notifier = container.read(focusRestorationProvider.notifier);
        notifier.setKey('/home', firstKey);
        notifier.setKey('/home', secondKey);

        final result = notifier.getKey('/home');
        expect(result, equals(secondKey));
      });

      test('tracks different keys for different routes', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const homeKey = ValueKey('home-item');
        const settingsKey = ValueKey('settings-item');

        final notifier = container.read(focusRestorationProvider.notifier);
        notifier.setKey('/home', homeKey);
        notifier.setKey('/settings', settingsKey);

        expect(notifier.getKey('/home'), equals(homeKey));
        expect(notifier.getKey('/settings'), equals(settingsKey));
      });
    });

    group('saveFocusKey()', () {
      testWidgets('captures ValueKey from current primary focus', (
        tester,
      ) async {
        late WidgetRef widgetRef;
        const itemKey = ValueKey('focused-item');

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  widgetRef = ref;
                  return Container(
                    key: itemKey,
                    child: const Focus(autofocus: true, child: SizedBox()),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        saveFocusKey(widgetRef, '/test');
        // saveFocusKey defers via scheduleMicrotask — pump once
        // to flush the microtask queue.
        await tester.pump();

        final saved = widgetRef
            .read(focusRestorationProvider.notifier)
            .getKey('/test');
        // The saved key should be the ValueKey from the
        // focused element or one of its ancestors.
        expect(saved, isA<ValueKey>());
      });

      testWidgets(
        'uses scheduleMicrotask so mutation fires before next frame',
        (tester) async {
          late WidgetRef widgetRef;
          const itemKey = ValueKey('microtask-item');

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Consumer(
                  builder: (context, ref, _) {
                    widgetRef = ref;
                    return Container(
                      key: itemKey,
                      child: const Focus(autofocus: true, child: SizedBox()),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          saveFocusKey(widgetRef, '/microtask-test');
          // A single pump flushes the microtask queue. If the
          // implementation used addPostFrameCallback instead,
          // this test would fail because post-frame callbacks
          // require scheduleFrame() + pump.
          await tester.pump();

          final saved = widgetRef
              .read(focusRestorationProvider.notifier)
              .getKey('/microtask-test');
          expect(saved, equals(itemKey));
        },
      );
    });
  });

  group('FocusEscalationState', () {
    test('copyWith sets sourceSelectorNode correctly', () {
      final node = FocusNode(debugLabel: 'test-source-selector');
      addTearDown(node.dispose);

      const state = FocusEscalationState();
      final updated = state.copyWith(sourceSelectorNode: node);

      expect(updated.sourceSelectorNode, equals(node));
      expect(updated.railNode, isNull);
      expect(updated.sidebarNode, isNull);
      expect(updated.miniPlayerNode, isNull);
    });

    test('copyWith sets miniPlayerNode correctly', () {
      final node = FocusNode(debugLabel: 'test-mini-player');
      addTearDown(node.dispose);

      const state = FocusEscalationState();
      final updated = state.copyWith(miniPlayerNode: node);

      expect(updated.miniPlayerNode, equals(node));
      expect(updated.railNode, isNull);
      expect(updated.sidebarNode, isNull);
      expect(updated.sourceSelectorNode, isNull);
    });

    test('clearSourceSelector sets sourceSelectorNode to null', () {
      final node = FocusNode(debugLabel: 'test-source-selector');
      addTearDown(node.dispose);

      final state = FocusEscalationState(sourceSelectorNode: node);
      final cleared = state.copyWith(clearSourceSelector: true);

      expect(cleared.sourceSelectorNode, isNull);
    });

    test('clearMiniPlayer sets miniPlayerNode to null', () {
      final node = FocusNode(debugLabel: 'test-mini-player');
      addTearDown(node.dispose);

      final state = FocusEscalationState(miniPlayerNode: node);
      final cleared = state.copyWith(clearMiniPlayer: true);

      expect(cleared.miniPlayerNode, isNull);
    });
  });
}
