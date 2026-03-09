import 'package:crispy_tivi/features/player/data/shader_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShaderPresetType', () {
    test('has 3 values', () {
      expect(ShaderPresetType.values, hasLength(3));
    });

    test('values are none, nvscaler, anime4k', () {
      expect(ShaderPresetType.values.map((v) => v.name), [
        'none',
        'nvscaler',
        'anime4k',
      ]);
    });
  });

  group('Anime4KQuality', () {
    test('has 2 values', () {
      expect(Anime4KQuality.values, hasLength(2));
    });
  });

  group('Anime4KMode', () {
    test('has 6 values', () {
      expect(Anime4KMode.values, hasLength(6));
    });
  });

  group('ShaderPreset', () {
    test('none preset is off', () {
      expect(ShaderPreset.none.id, 'none');
      expect(ShaderPreset.none.name, 'Off');
      expect(ShaderPreset.none.type, ShaderPresetType.none);
      expect(ShaderPreset.none.isEnabled, false);
    });

    test('nvscaler preset has auto HDR skip', () {
      expect(ShaderPreset.nvscaler.id, 'nvscaler');
      expect(ShaderPreset.nvscaler.name, 'NVScaler');
      expect(ShaderPreset.nvscaler.type, ShaderPresetType.nvscaler);
      expect(ShaderPreset.nvscaler.autoHdrSkip, true);
      expect(ShaderPreset.nvscaler.isEnabled, true);
    });

    test('anime4k factory creates correct preset', () {
      final preset = ShaderPreset.anime4k(Anime4KQuality.hq, Anime4KMode.modeA);
      expect(preset.id, 'anime4k_hq_modeA');
      expect(preset.name, 'Anime4K HQ A');
      expect(preset.type, ShaderPresetType.anime4k);
      expect(preset.anime4kQuality, Anime4KQuality.hq);
      expect(preset.anime4kMode, Anime4KMode.modeA);
    });

    test('anime4k fast quality uses Fast label', () {
      final preset = ShaderPreset.anime4k(
        Anime4KQuality.fast,
        Anime4KMode.modeB,
      );
      expect(preset.name, 'Anime4K Fast B');
    });

    test('anime4k compound modes have correct labels', () {
      expect(
        ShaderPreset.anime4k(Anime4KQuality.fast, Anime4KMode.modeAA).name,
        'Anime4K Fast A+A',
      );
      expect(
        ShaderPreset.anime4k(Anime4KQuality.hq, Anime4KMode.modeBB).name,
        'Anime4K HQ B+B',
      );
      expect(
        ShaderPreset.anime4k(Anime4KQuality.fast, Anime4KMode.modeCA).name,
        'Anime4K Fast C+A',
      );
    });

    test('allPresets has 14 entries', () {
      final presets = ShaderPreset.allPresets;
      expect(presets, hasLength(14));
      // Off + NVScaler + 2 qualities × 6 modes = 14
    });

    test('allPresets starts with none then nvscaler', () {
      final presets = ShaderPreset.allPresets;
      expect(presets[0].id, 'none');
      expect(presets[1].id, 'nvscaler');
    });

    test('allPresets has unique IDs', () {
      final ids = ShaderPreset.allPresets.map((p) => p.id).toSet();
      expect(ids, hasLength(14));
    });

    test('fromId returns correct preset', () {
      expect(ShaderPreset.fromId('none'), ShaderPreset.none);
      expect(ShaderPreset.fromId('nvscaler'), ShaderPreset.nvscaler);
      expect(ShaderPreset.fromId('anime4k_fast_modeA')?.name, 'Anime4K Fast A');
    });

    test('fromId returns null for unknown ID', () {
      expect(ShaderPreset.fromId('nonexistent'), isNull);
    });

    test('equality is by ID', () {
      final a = ShaderPreset.anime4k(Anime4KQuality.fast, Anime4KMode.modeA);
      final b = ShaderPreset.anime4k(Anime4KQuality.fast, Anime4KMode.modeA);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different IDs are not equal', () {
      expect(ShaderPreset.none, isNot(equals(ShaderPreset.nvscaler)));
    });
  });

  group('kShaderPresetKey', () {
    test('is namespaced', () {
      expect(kShaderPresetKey, startsWith('crispy_'));
    });
  });

  group('Shader preset cycling', () {
    test('cycling wraps around', () {
      final presets = ShaderPreset.allPresets;
      // Last preset cycles to first
      final lastIdx = presets.length - 1;
      final nextIdx = (lastIdx + 1) % presets.length;
      expect(nextIdx, 0);
    });

    test('cycling from none goes to nvscaler', () {
      final presets = ShaderPreset.allPresets;
      final idx = presets.indexWhere((p) => p.id == 'none');
      final next = presets[(idx + 1) % presets.length];
      expect(next.id, 'nvscaler');
    });
  });
}
