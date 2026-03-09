import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/domain/segment_skip_config.dart';
import 'package:crispy_tivi/features/player/domain/entities/playback_state.dart';
import 'package:crispy_tivi/features/player/domain/utils/skip_segment_utils.dart';

void main() {
  // ── SegmentType ─────────────────────────────────────────
  group('SegmentType', () {
    test('has 5 values', () {
      expect(SegmentType.values.length, 5);
    });

    test('label returns user-facing text', () {
      expect(SegmentType.intro.label, 'Intro');
      expect(SegmentType.outro.label, 'Outro / Credits');
      expect(SegmentType.recap.label, 'Recap');
      expect(SegmentType.commercial.label, 'Commercial');
      expect(SegmentType.preview.label, 'Preview');
    });
  });

  // ── SegmentSkipMode ─────────────────────────────────────
  group('SegmentSkipMode', () {
    test('has 4 values', () {
      expect(SegmentSkipMode.values.length, 4);
    });

    test('label returns user-facing text', () {
      expect(SegmentSkipMode.none.label, 'None');
      expect(SegmentSkipMode.ask.label, 'Ask to Skip');
      expect(SegmentSkipMode.once.label, 'Skip Once');
      expect(SegmentSkipMode.auto.label, 'Always Skip');
    });
  });

  // ── NextUpMode ──────────────────────────────────────────
  group('NextUpMode', () {
    test('has 3 values', () {
      expect(NextUpMode.values.length, 3);
    });

    test('label returns user-facing text', () {
      expect(NextUpMode.off.label, 'Off');
      expect(NextUpMode.static.label, 'Static (32s before end)');
      expect(NextUpMode.smart.label, 'Smart (credits-aware)');
    });
  });

  // ── defaultSegmentSkipConfig ────────────────────────────
  group('defaultSegmentSkipConfig', () {
    test('all types default to ask', () {
      for (final type in SegmentType.values) {
        expect(
          defaultSegmentSkipConfig[type],
          SegmentSkipMode.ask,
          reason: '${type.name} should default to ask',
        );
      }
    });

    test('covers all segment types', () {
      expect(defaultSegmentSkipConfig.keys.toSet(), SegmentType.values.toSet());
    });
  });

  // ── encodeSegmentSkipConfig ─────────────────────────────
  group('encodeSegmentSkipConfig', () {
    test('encodes default config to valid JSON', () {
      final json = encodeSegmentSkipConfig(defaultSegmentSkipConfig);
      expect(() => jsonDecode(json), returnsNormally);
    });

    test('round-trip preserves config', () {
      final config = {
        SegmentType.intro: SegmentSkipMode.auto,
        SegmentType.outro: SegmentSkipMode.none,
        SegmentType.recap: SegmentSkipMode.once,
        SegmentType.commercial: SegmentSkipMode.ask,
        SegmentType.preview: SegmentSkipMode.auto,
      };
      final encoded = encodeSegmentSkipConfig(config);
      final decoded = decodeSegmentSkipConfig(encoded);
      expect(decoded, config);
    });

    test('uses enum name as key/value', () {
      final config = {SegmentType.intro: SegmentSkipMode.auto};
      final json = encodeSegmentSkipConfig(config);
      final map = jsonDecode(json) as Map<String, dynamic>;
      expect(map['intro'], 'auto');
    });
  });

  // ── decodeSegmentSkipConfig ─────────────────────────────
  group('decodeSegmentSkipConfig', () {
    test('null returns defaults', () {
      final result = decodeSegmentSkipConfig(null);
      expect(result, defaultSegmentSkipConfig);
    });

    test('empty string returns defaults', () {
      final result = decodeSegmentSkipConfig('');
      expect(result, defaultSegmentSkipConfig);
    });

    test('invalid JSON returns defaults', () {
      final result = decodeSegmentSkipConfig('not json');
      expect(result, defaultSegmentSkipConfig);
    });

    test('partial config fills missing with defaults', () {
      final json = jsonEncode({'intro': 'auto'});
      final result = decodeSegmentSkipConfig(json);
      expect(result[SegmentType.intro], SegmentSkipMode.auto);
      expect(result[SegmentType.outro], SegmentSkipMode.ask);
      expect(result[SegmentType.recap], SegmentSkipMode.ask);
    });

    test('unknown type names are ignored', () {
      final json = jsonEncode({'intro': 'auto', 'unknown': 'none'});
      final result = decodeSegmentSkipConfig(json);
      expect(result[SegmentType.intro], SegmentSkipMode.auto);
      expect(result.length, SegmentType.values.length);
    });

    test('unknown mode names are ignored', () {
      final json = jsonEncode({'intro': 'invalid_mode'});
      final result = decodeSegmentSkipConfig(json);
      // intro keeps default since mode is unknown
      expect(result[SegmentType.intro], SegmentSkipMode.ask);
    });

    test('returns mutable copy, not shared reference', () {
      final a = decodeSegmentSkipConfig(null);
      final b = decodeSegmentSkipConfig(null);
      a[SegmentType.intro] = SegmentSkipMode.auto;
      expect(b[SegmentType.intro], SegmentSkipMode.ask);
    });
  });

  // ── parseNextUpMode ─────────────────────────────────────
  group('parseNextUpMode', () {
    test('null returns static', () {
      expect(parseNextUpMode(null), NextUpMode.static);
    });

    test('parses valid mode names', () {
      expect(parseNextUpMode('off'), NextUpMode.off);
      expect(parseNextUpMode('static'), NextUpMode.static);
      expect(parseNextUpMode('smart'), NextUpMode.smart);
    });

    test('unknown name returns static', () {
      expect(parseNextUpMode('unknown'), NextUpMode.static);
    });
  });

  // ── inferSegmentType ────────────────────────────────────
  group('inferSegmentType', () {
    const s1 = SkipSegment(
      start: Duration(seconds: 0),
      end: Duration(seconds: 90),
    );
    const s2 = SkipSegment(
      start: Duration(minutes: 5),
      end: Duration(minutes: 6),
    );
    const s3 = SkipSegment(
      start: Duration(minutes: 80),
      end: Duration(minutes: 85),
    );

    test('first segment inferred as intro', () {
      expect(inferSegmentType(s1, [s1, s2, s3]), SegmentType.intro);
    });

    test('last segment inferred as outro', () {
      expect(inferSegmentType(s3, [s1, s2, s3]), SegmentType.outro);
    });

    test('middle segment inferred as recap', () {
      expect(inferSegmentType(s2, [s1, s2, s3]), SegmentType.recap);
    });

    test('single segment inferred as intro', () {
      expect(inferSegmentType(s1, [s1]), SegmentType.intro);
    });

    test('explicit type overrides position heuristic', () {
      const explicitOutro = SkipSegment(
        start: Duration(seconds: 0),
        end: Duration(seconds: 90),
        type: SegmentType.outro,
      );
      // First position would normally be intro, but explicit type wins
      expect(
        inferSegmentType(explicitOutro, [explicitOutro, s2]),
        SegmentType.outro,
      );
    });

    test('explicit commercial type preserved', () {
      const commercial = SkipSegment(
        start: Duration(minutes: 5),
        end: Duration(minutes: 6),
        type: SegmentType.commercial,
      );
      expect(
        inferSegmentType(commercial, [s1, commercial, s3]),
        SegmentType.commercial,
      );
    });
  });

  // ── segmentLabel with types ─────────────────────────────
  group('segmentLabel with explicit types', () {
    test('uses type label for explicitly typed segment', () {
      const commercial = SkipSegment(
        start: Duration(minutes: 5),
        end: Duration(minutes: 6),
        type: SegmentType.commercial,
      );
      expect(segmentLabel(commercial, [commercial]), 'Skip Commercial');
    });

    test('intro label for first untyped segment', () {
      const s = SkipSegment(
        start: Duration(seconds: 0),
        end: Duration(seconds: 60),
      );
      expect(segmentLabel(s, [s]), 'Skip Intro');
    });
  });

  // ── SkipSegment.type field ──────────────────────────────
  group('SkipSegment type field', () {
    test('null type by default', () {
      const seg = SkipSegment(start: Duration.zero, end: Duration(seconds: 30));
      expect(seg.type, isNull);
    });

    test('explicit type preserved', () {
      const seg = SkipSegment(
        start: Duration.zero,
        end: Duration(seconds: 30),
        type: SegmentType.preview,
      );
      expect(seg.type, SegmentType.preview);
    });

    test('equality includes type', () {
      const a = SkipSegment(start: Duration.zero, end: Duration(seconds: 30));
      const b = SkipSegment(
        start: Duration.zero,
        end: Duration(seconds: 30),
        type: SegmentType.intro,
      );
      expect(a, isNot(equals(b)));
    });

    test('same type segments are equal', () {
      const a = SkipSegment(
        start: Duration.zero,
        end: Duration(seconds: 30),
        type: SegmentType.intro,
      );
      const b = SkipSegment(
        start: Duration.zero,
        end: Duration(seconds: 30),
        type: SegmentType.intro,
      );
      expect(a, equals(b));
    });
  });
}
