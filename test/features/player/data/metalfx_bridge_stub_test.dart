import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/data/'
    'metalfx_bridge_stub.dart';

void main() {
  group('metalfx_bridge_stub', () {
    test('isMetalFxPlatform returns false', () {
      expect(isMetalFxPlatform, isFalse);
    });

    test('initMetalFx returns false', () async {
      final result = await initMetalFx();
      expect(result, isFalse);
    });

    test('applyMetalFx returns false', () async {
      final result = await applyMetalFx(scaleFactor: 2.0);
      expect(result, isFalse);
    });

    test('removeMetalFx completes without error', () async {
      await expectLater(removeMetalFx(), completes);
    });

    test('disposeMetalFx completes without error', () async {
      await expectLater(disposeMetalFx(), completes);
    });

    test('applyMetalFx with various scale factors '
        'always returns false', () async {
      final r1 = await applyMetalFx(scaleFactor: 1.0);
      final r2 = await applyMetalFx(scaleFactor: 4.0);
      final r3 = await applyMetalFx(scaleFactor: 0.5);
      expect(r1, isFalse);
      expect(r2, isFalse);
      expect(r3, isFalse);
    });

    test('multiple calls to removeMetalFx '
        'complete without error', () async {
      await removeMetalFx();
      await removeMetalFx();
    });

    test('full lifecycle: init, apply, remove, dispose', () async {
      final initOk = await initMetalFx();
      expect(initOk, isFalse);

      final applyOk = await applyMetalFx(scaleFactor: 2.0);
      expect(applyOk, isFalse);

      await removeMetalFx();
      await disposeMetalFx();
    });
  });
}
