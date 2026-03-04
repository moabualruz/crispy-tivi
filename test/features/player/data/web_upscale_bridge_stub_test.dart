import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/data/'
    'web_upscale_bridge_stub.dart';

void main() {
  group('web_upscale_bridge_stub', () {
    test('initWebUpscaler returns false', () async {
      final result = await initWebUpscaler();
      expect(result, isFalse);
    });

    test('applyWebUpscaling returns false', () async {
      final result = await applyWebUpscaling(
        scaleFactor: 2.0,
        quality: 'balanced',
      );
      expect(result, isFalse);
    });

    test('removeWebUpscaling completes without error', () async {
      await expectLater(removeWebUpscaling(), completes);
    });

    test('isWebGpuAvailable returns false', () {
      expect(isWebGpuAvailable(), isFalse);
    });

    test('isWebGl2Available returns false', () {
      expect(isWebGl2Available(), isFalse);
    });

    test('activeWebMethod returns null', () {
      expect(activeWebMethod(), isNull);
    });

    test('disposeWebUpscaler completes without error', () async {
      await expectLater(disposeWebUpscaler(), completes);
    });

    test('applyWebUpscaling with various params '
        'always returns false', () async {
      final r1 = await applyWebUpscaling(
        scaleFactor: 1.0,
        quality: 'performance',
      );
      final r2 = await applyWebUpscaling(scaleFactor: 4.0, quality: 'maximum');
      expect(r1, isFalse);
      expect(r2, isFalse);
    });

    test('multiple calls to removeWebUpscaling '
        'complete without error', () async {
      await removeWebUpscaling();
      await removeWebUpscaling();
    });
  });
}
