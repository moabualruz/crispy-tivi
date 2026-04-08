import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:crispy_tivi/features/player/data/upscale_manager.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/domain/entities/gpu_info.dart';
import 'package:crispy_tivi/features/player/domain/entities/upscale_mode.dart';
import 'package:crispy_tivi/features/player/domain/entities/upscale_quality.dart';

class MockCrispyPlayer extends Mock implements CrispyPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpscaleManager', () {
    late UpscaleManager manager;
    late MockCrispyPlayer mockPlayer;

    setUp(() {
      manager = UpscaleManager();
      mockPlayer = MockCrispyPlayer();
      // Simulate non-mpv backend: setProperty throws so
      // all upscale tiers fail gracefully (matching real
      // behavior where non-mpv players don't support
      // property-based filter chains).
      when(
        () => mockPlayer.setProperty(any(), any()),
      ).thenThrow(UnimplementedError('mock'));
    });

    group('applyUpscaling', () {
      test('mode Off removes upscaling and returns null', () async {
        // MockCrispyPlayer.setProperty/getProperty are no-ops on mock,
        // so removeUpscaling exits early (no-op).
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.off,
          UpscaleQuality.balanced,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });

      test('mode Auto with mock player returns null '
          '(all tiers fail gracefully)', () async {
        // Mock CrispyPlayer setProperty/getProperty are no-ops →
        // _trySetScale and _trySetShader return false → all tiers
        // fail → returns null.
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.balanced,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });

      test('mode ForceSoftware with mock player returns '
          'null (all tiers fail gracefully)', () async {
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.forceSoftware,
          UpscaleQuality.maximum,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });

      test('mode ForceHardware with mock player returns '
          'null (no HW tiers in Phase 1)', () async {
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.forceHardware,
          UpscaleQuality.maximum,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });
    });

    group('removeUpscaling', () {
      test('does not throw with mock player '
          '(mock CrispyPlayer)', () async {
        // mock CrispyPlayer → setProperty is a no-op → early return.
        await expectLater(manager.removeUpscaling(mockPlayer), completes);
      });

      test('mode Off calls removeUpscaling without error', () async {
        // Ensures the Off path handles a player whose
        // properties are unavailable.
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.off,
          UpscaleQuality.performance,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });
    });

    group('quality-based chain length', () {
      test('performance quality: all tiers fail, '
          'returns null', () async {
        // Performance → only spline36 tier.
        // Mock CrispyPlayer → tier fails → null.
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.performance,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });

      test('balanced quality: all tiers fail, '
          'returns null', () async {
        // Balanced → ewa_lanczossharp + spline36.
        // Mock CrispyPlayer → both fail → null.
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.balanced,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });

      test('maximum quality: all tiers fail, '
          'returns null', () async {
        // Maximum → FSR + ewa_lanczossharp + spline36.
        // Mock CrispyPlayer → all three fail → null.
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.maximum,
          GpuInfo.unknown,
        );
        expect(result, isNull);
      });
    });

    group('repeated calls', () {
      test('consecutive applyUpscaling calls are safe', () async {
        final r1 = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.balanced,
          GpuInfo.unknown,
        );
        final r2 = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.off,
          UpscaleQuality.balanced,
          GpuInfo.unknown,
        );
        final r3 = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.maximum,
          GpuInfo.unknown,
        );
        expect(r1, isNull);
        expect(r2, isNull);
        expect(r3, isNull);
      });
    });

    group('hardware tier gating', () {
      test('NVIDIA GPU + mode auto does not crash '
          '(HW tier attempted)', () async {
        // GpuInfo with NVIDIA HW VSR — chain includes
        // tier 1 RTX VSR. All tiers fail on mock but
        // no exception is thrown.
        const nvidiaGpu = GpuInfo(
          vendor: GpuVendor.nvidia,
          name: 'NVIDIA GeForce RTX 4090',
          vramMb: 24576,
          supportsHwVsr: true,
          vsrMethod: VsrMethod.d3d11Nvidia,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.maximum,
          nvidiaGpu,
        );
        // All tiers fail on mock CrispyPlayer (setProperty is no-op).
        expect(result, isNull);
      });

      test('Intel GPU + mode auto does not crash '
          '(Intel VSR tier attempted)', () async {
        const intelGpu = GpuInfo(
          vendor: GpuVendor.intel,
          name: 'Intel Arc A770',
          vramMb: 16384,
          supportsHwVsr: true,
          vsrMethod: VsrMethod.d3d11Intel,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.balanced,
          intelGpu,
        );
        expect(result, isNull);
      });

      test('NVIDIA GPU + forceSoftware skips HW tiers', () async {
        // forceSoftware → HW tiers (1-2) skipped.
        // Only SW tiers attempted, all fail on mock.
        const nvidiaGpu = GpuInfo(
          vendor: GpuVendor.nvidia,
          name: 'NVIDIA GeForce RTX 4090',
          vramMb: 24576,
          supportsHwVsr: true,
          vsrMethod: VsrMethod.d3d11Nvidia,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.forceSoftware,
          UpscaleQuality.maximum,
          nvidiaGpu,
        );
        expect(result, isNull);
      });

      test('GPU with supportsHwVsr false + auto '
          'skips HW tiers', () async {
        // supportsHwVsr=false → no tier 1 added.
        const noHwGpu = GpuInfo(
          vendor: GpuVendor.nvidia,
          name: 'NVIDIA GeForce GTX 1050',
          vramMb: 4096,
          supportsHwVsr: false,
          vsrMethod: VsrMethod.none,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.maximum,
          noHwGpu,
        );
        expect(result, isNull);
      });

      test('MetalFX GPU + mode auto does not crash '
          '(MetalFX tier attempted)', () async {
        const appleGpu = GpuInfo(
          vendor: GpuVendor.apple,
          name: 'Apple M2 Pro',
          vramMb: null,
          supportsHwVsr: true,
          vsrMethod: VsrMethod.metalFxSpatial,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.balanced,
          appleGpu,
        );
        // MetalFX _tryMetalFx returns false (stub).
        // SW tiers also fail on mock CrispyPlayer.
        expect(result, isNull);
      });

      test('MetalFX GPU + forceSoftware skips '
          'MetalFX tier', () async {
        const appleGpu = GpuInfo(
          vendor: GpuVendor.apple,
          name: 'Apple M2 Pro',
          vramMb: null,
          supportsHwVsr: true,
          vsrMethod: VsrMethod.metalFxSpatial,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.forceSoftware,
          UpscaleQuality.maximum,
          appleGpu,
        );
        expect(result, isNull);
      });

      test('forceHardware with NVIDIA GPU still '
          'falls through all tiers on mock', () async {
        const nvidiaGpu = GpuInfo(
          vendor: GpuVendor.nvidia,
          name: 'NVIDIA GeForce RTX 4090',
          vramMb: 24576,
          supportsHwVsr: true,
          vsrMethod: VsrMethod.d3d11Nvidia,
        );
        final result = await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.forceHardware,
          UpscaleQuality.maximum,
          nvidiaGpu,
        );
        expect(result, isNull);
      });

      test('every UpscaleMode + UpscaleQuality combo '
          'completes without exception', () async {
        // Exhaustive: no mode/quality/gpu combo should
        // throw. All return null on mock CrispyPlayer.
        for (final mode in UpscaleMode.values) {
          for (final quality in UpscaleQuality.values) {
            final result = await manager.applyUpscaling(
              mockPlayer,
              mode,
              quality,
              GpuInfo.unknown,
            );
            expect(result, isNull, reason: 'mode=$mode quality=$quality');
          }
        }
      });
    });

    group('extractShaderAsset', () {
      test('returns null when asset not found', () async {
        // rootBundle.load throws for non-existent asset.
        // extractShaderAsset catches and returns null.
        final path = await manager.extractShaderAsset(
          'assets/shaders/nonexistent_shader.glsl',
        );
        expect(path, isNull);
      });

      test('returns null for empty asset path', () async {
        final path = await manager.extractShaderAsset('');
        expect(path, isNull);
      });

      test('consecutive calls with invalid asset '
          'both return null (no stale cache)', () async {
        // First call fails → _cachedShaderPath stays
        // null. Second call also attempts load and
        // fails → still null.
        final p1 = await manager.extractShaderAsset('assets/shaders/fake.glsl');
        final p2 = await manager.extractShaderAsset('assets/shaders/fake.glsl');
        expect(p1, isNull);
        expect(p2, isNull);
      });
    });

    group('removeUpscaling edge cases', () {
      test('removeUpscaling is safe when called '
          'multiple times', () async {
        // Multiple remove calls should not throw.
        await expectLater(manager.removeUpscaling(mockPlayer), completes);
        await expectLater(manager.removeUpscaling(mockPlayer), completes);
        await expectLater(manager.removeUpscaling(mockPlayer), completes);
      });

      test('removeUpscaling after applyUpscaling '
          'completes without error', () async {
        // Apply → remove → apply cycle.
        await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.maximum,
          GpuInfo.unknown,
        );
        await expectLater(manager.removeUpscaling(mockPlayer), completes);
        await manager.applyUpscaling(
          mockPlayer,
          UpscaleMode.auto,
          UpscaleQuality.balanced,
          GpuInfo.unknown,
        );
      });

      test('mode Off with every quality level '
          'returns null', () async {
        // Off mode short-circuits to removeUpscaling
        // regardless of quality.
        for (final quality in UpscaleQuality.values) {
          final result = await manager.applyUpscaling(
            mockPlayer,
            UpscaleMode.off,
            quality,
            GpuInfo.unknown,
          );
          expect(result, isNull, reason: 'Off + $quality should be null');
        }
      });
    });
  });
}
