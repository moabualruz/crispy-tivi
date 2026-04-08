import 'package:crispy_tivi/features/player/presentation/providers/player_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeDeinterlaceNotifier', () {
    test('initial state defaults to off', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(runtimeDeinterlaceProvider), 'off');
    });

    test('cycle rotates auto → off → on → auto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(runtimeDeinterlaceProvider.notifier);

      // Default is 'off' (from deinterlaceModeProvider fallback).
      expect(container.read(runtimeDeinterlaceProvider), 'off');

      // off → on
      notifier.cycle();
      expect(container.read(runtimeDeinterlaceProvider), 'on');

      // on → auto
      notifier.cycle();
      expect(container.read(runtimeDeinterlaceProvider), 'auto');

      // auto → off
      notifier.cycle();
      expect(container.read(runtimeDeinterlaceProvider), 'off');
    });

    test('cycle wraps from on back to auto', () {
      final container = ProviderContainer(
        overrides: [
          // Start with 'on' mode.
          deinterlaceModeProvider.overrideWithValue('on'),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(runtimeDeinterlaceProvider), 'on');

      // on → auto
      container.read(runtimeDeinterlaceProvider.notifier).cycle();
      expect(container.read(runtimeDeinterlaceProvider), 'auto');
    });

    test('initializes from deinterlaceModeProvider value', () {
      final container = ProviderContainer(
        overrides: [deinterlaceModeProvider.overrideWithValue('auto')],
      );
      addTearDown(container.dispose);

      expect(container.read(runtimeDeinterlaceProvider), 'auto');
    });
  });
}
