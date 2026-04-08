import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/data/gpu_json_codec.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'gpu_info.dart';

void main() {
  group('GpuVendor.fromString', () {
    test('parses Nvidia', () {
      expect(GpuVendor.fromString('Nvidia'), GpuVendor.nvidia);
    });

    test('parses Amd', () {
      expect(GpuVendor.fromString('Amd'), GpuVendor.amd);
    });

    test('parses Intel', () {
      expect(GpuVendor.fromString('Intel'), GpuVendor.intel);
    });

    test('parses Apple', () {
      expect(GpuVendor.fromString('Apple'), GpuVendor.apple);
    });

    test('parses Qualcomm', () {
      expect(GpuVendor.fromString('Qualcomm'), GpuVendor.qualcomm);
    });

    test('parses Arm', () {
      expect(GpuVendor.fromString('Arm'), GpuVendor.arm);
    });

    test('parses Unknown', () {
      expect(GpuVendor.fromString('Unknown'), GpuVendor.unknown);
    });

    test('garbage string returns unknown', () {
      expect(GpuVendor.fromString('SomeGarbage'), GpuVendor.unknown);
    });

    test('empty string returns unknown', () {
      expect(GpuVendor.fromString(''), GpuVendor.unknown);
    });

    test('lowercase variant returns unknown', () {
      expect(GpuVendor.fromString('nvidia'), GpuVendor.unknown);
    });
  });

  group('VsrMethod.fromString', () {
    test('parses D3d11Nvidia', () {
      expect(VsrMethod.fromString('D3d11Nvidia'), VsrMethod.d3d11Nvidia);
    });

    test('parses D3d11Intel', () {
      expect(VsrMethod.fromString('D3d11Intel'), VsrMethod.d3d11Intel);
    });

    test('parses AmdDriverRsr', () {
      expect(VsrMethod.fromString('AmdDriverRsr'), VsrMethod.amdDriverRsr);
    });

    test('parses MetalFxSpatial', () {
      expect(VsrMethod.fromString('MetalFxSpatial'), VsrMethod.metalFxSpatial);
    });

    test('parses WebGpuCnn', () {
      expect(VsrMethod.fromString('WebGpuCnn'), VsrMethod.webGpuCnn);
    });

    test('parses WebGlFsr', () {
      expect(VsrMethod.fromString('WebGlFsr'), VsrMethod.webGlFsr);
    });

    test('parses SoftwareFsr', () {
      expect(VsrMethod.fromString('SoftwareFsr'), VsrMethod.softwareFsr);
    });

    test('parses SoftwareLanczos', () {
      expect(
        VsrMethod.fromString('SoftwareLanczos'),
        VsrMethod.softwareLanczos,
      );
    });

    test('parses None', () {
      expect(VsrMethod.fromString('None'), VsrMethod.none);
    });

    test('garbage string returns none', () {
      expect(VsrMethod.fromString('SomeGarbage'), VsrMethod.none);
    });

    test('empty string returns none', () {
      expect(VsrMethod.fromString(''), VsrMethod.none);
    });

    test('lowercase variant returns none', () {
      expect(VsrMethod.fromString('d3d11nvidia'), VsrMethod.none);
    });
  });

  group('GpuInfo.fromJson', () {
    test('complete JSON with all fields', () {
      final json = <String, dynamic>{
        'vendor': 'Nvidia',
        'name': 'NVIDIA GeForce RTX 4090',
        'vram_mb': 24576,
        'supports_hw_vsr': true,
        'vsr_method': 'D3d11Nvidia',
      };
      final info = GpuJsonCodec.fromJson(json);

      expect(info.vendor, GpuVendor.nvidia);
      expect(info.name, 'NVIDIA GeForce RTX 4090');
      expect(info.vramMb, 24576);
      expect(info.supportsHwVsr, isTrue);
      expect(info.vsrMethod, VsrMethod.d3d11Nvidia);
    });

    test('missing vram_mb yields null', () {
      final json = <String, dynamic>{
        'vendor': 'Intel',
        'name': 'Intel UHD 770',
        'supports_hw_vsr': true,
        'vsr_method': 'D3d11Intel',
      };
      final info = GpuJsonCodec.fromJson(json);

      expect(info.vendor, GpuVendor.intel);
      expect(info.name, 'Intel UHD 770');
      expect(info.vramMb, isNull);
      expect(info.supportsHwVsr, isTrue);
      expect(info.vsrMethod, VsrMethod.d3d11Intel);
    });

    test('null vram_mb yields null', () {
      final json = <String, dynamic>{
        'vendor': 'Amd',
        'name': 'AMD RX 7900 XTX',
        'vram_mb': null,
        'supports_hw_vsr': false,
        'vsr_method': 'AmdDriverRsr',
      };
      final info = GpuJsonCodec.fromJson(json);

      expect(info.vramMb, isNull);
    });

    test('missing/null fields get defaults', () {
      final json = <String, dynamic>{};
      final info = GpuJsonCodec.fromJson(json);

      expect(info.vendor, GpuVendor.unknown);
      expect(info.name, 'Unknown');
      expect(info.vramMb, isNull);
      expect(info.supportsHwVsr, isFalse);
      expect(info.vsrMethod, VsrMethod.none);
    });

    test('null vendor defaults to unknown', () {
      final json = <String, dynamic>{
        'vendor': null,
        'name': 'Some GPU',
        'supports_hw_vsr': true,
        'vsr_method': 'WebGpuCnn',
      };
      final info = GpuJsonCodec.fromJson(json);

      expect(info.vendor, GpuVendor.unknown);
    });

    test('null supports_hw_vsr defaults to false', () {
      final json = <String, dynamic>{
        'vendor': 'Apple',
        'name': 'M3 Max',
        'supports_hw_vsr': null,
        'vsr_method': 'MetalFxSpatial',
      };
      final info = GpuJsonCodec.fromJson(json);

      expect(info.supportsHwVsr, isFalse);
    });

    test('null vsr_method defaults to none', () {
      final json = <String, dynamic>{
        'vendor': 'Arm',
        'name': 'Mali-G78',
        'supports_hw_vsr': false,
        'vsr_method': null,
      };
      final info = GpuJsonCodec.fromJson(json);

      expect(info.vsrMethod, VsrMethod.none);
    });
  });

  group('GpuInfo.toJson', () {
    test('produces snake_case keys matching Rust', () {
      final info = GpuInfo(
        vendor: GpuVendor.nvidia,
        name: 'RTX 4090',
        vramMb: 24576,
        supportsHwVsr: true,
        vsrMethod: VsrMethod.d3d11Nvidia,
      );
      final json = GpuJsonCodec.toJson(info);

      expect(json.containsKey('vendor'), isTrue);
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('vram_mb'), isTrue);
      expect(json.containsKey('supports_hw_vsr'), isTrue);
      expect(json.containsKey('vsr_method'), isTrue);
      expect(json.keys.length, 5);
    });

    test('serializes all values correctly', () {
      final info = GpuInfo(
        vendor: GpuVendor.amd,
        name: 'RX 7900 XTX',
        vramMb: 24576,
        supportsHwVsr: false,
        vsrMethod: VsrMethod.amdDriverRsr,
      );
      final json = GpuJsonCodec.toJson(info);

      expect(json['vendor'], 'Amd');
      expect(json['name'], 'RX 7900 XTX');
      expect(json['vram_mb'], 24576);
      expect(json['supports_hw_vsr'], isFalse);
      expect(json['vsr_method'], 'AmdDriverRsr');
    });

    test('null vram_mb serializes as null', () {
      final info = GpuInfo(
        vendor: GpuVendor.intel,
        name: 'UHD 770',
        supportsHwVsr: true,
        vsrMethod: VsrMethod.d3d11Intel,
      );
      final json = GpuJsonCodec.toJson(info);

      expect(json['vram_mb'], isNull);
    });
  });

  group('GpuInfo.toJson — roundtrip', () {
    test('Rust JSON roundtrip preserves all fields', () {
      final rustJson = <String, dynamic>{
        'vendor': 'Nvidia',
        'name': 'NVIDIA GeForce RTX 4090',
        'vram_mb': 24576,
        'supports_hw_vsr': true,
        'vsr_method': 'D3d11Nvidia',
      };
      final info = GpuJsonCodec.fromJson(rustJson);

      expect(info.vendor, GpuVendor.nvidia);
      expect(info.name, 'NVIDIA GeForce RTX 4090');
      expect(info.vramMb, 24576);
      expect(info.supportsHwVsr, isTrue);
      expect(info.vsrMethod, VsrMethod.d3d11Nvidia);
    });

    test('Dart toJson → fromJson roundtrip preserves '
        'all fields', () {
      final original = GpuInfo(
        vendor: GpuVendor.nvidia,
        name: 'RTX 4090',
        vramMb: 24576,
        supportsHwVsr: true,
        vsrMethod: VsrMethod.d3d11Nvidia,
      );
      final json = GpuJsonCodec.toJson(original);

      // toRustString emits PascalCase:
      expect(json['vendor'], 'Nvidia');
      expect(json['vsr_method'], 'D3d11Nvidia');

      // Full roundtrip preserves all values:
      final restored = GpuJsonCodec.fromJson(json);
      expect(restored.vendor, GpuVendor.nvidia);
      expect(restored.vsrMethod, VsrMethod.d3d11Nvidia);
      expect(restored.name, 'RTX 4090');
      expect(restored.vramMb, 24576);
      expect(restored.supportsHwVsr, isTrue);
    });

    test('roundtrip with null vram_mb preserves null', () {
      final rustJson = <String, dynamic>{
        'vendor': 'Apple',
        'name': 'M3 Max',
        'vram_mb': null,
        'supports_hw_vsr': true,
        'vsr_method': 'MetalFxSpatial',
      };
      final info = GpuJsonCodec.fromJson(rustJson);

      expect(info.vramMb, isNull);
      expect(info.vendor, GpuVendor.apple);
      expect(info.vsrMethod, VsrMethod.metalFxSpatial);
    });
  });

  group('GpuInfo.unknown', () {
    test('has correct sentinel values', () {
      expect(GpuInfo.unknown.vendor, GpuVendor.unknown);
      expect(GpuInfo.unknown.name, 'Unknown');
      expect(GpuInfo.unknown.vramMb, isNull);
      expect(GpuInfo.unknown.supportsHwVsr, isFalse);
      expect(GpuInfo.unknown.vsrMethod, VsrMethod.none);
    });
  });
}
