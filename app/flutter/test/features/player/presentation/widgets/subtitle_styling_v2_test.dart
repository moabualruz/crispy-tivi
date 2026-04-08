import 'dart:convert';

import 'package:crispy_tivi/config/settings_state.dart';
import 'package:crispy_tivi/features/player/domain/crispy_player.dart';
import 'package:crispy_tivi/features/player/presentation/widgets/player_osd/subtitle_style_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCrispyPlayer extends Mock implements CrispyPlayer {}

void main() {
  // ── SubtitleStyle model tests ─────────────────────────────

  group('SubtitleStyle new fields', () {
    test('defaults include new fields', () {
      const style = SubtitleStyle();
      expect(style.isBold, false);
      expect(style.verticalPosition, 100);
      expect(style.outlineColor, SubtitleOutlineColor.black);
      expect(style.outlineSize, 2.0);
      expect(style.backgroundOpacity, 0.6);
      expect(style.hasShadow, true);
    });

    test('copyWith updates new fields', () {
      const style = SubtitleStyle();
      final updated = style.copyWith(
        isBold: true,
        verticalPosition: 50,
        outlineColor: SubtitleOutlineColor.white,
        outlineSize: 5.0,
        backgroundOpacity: 0.3,
        hasShadow: false,
      );

      expect(updated.isBold, true);
      expect(updated.verticalPosition, 50);
      expect(updated.outlineColor, SubtitleOutlineColor.white);
      expect(updated.outlineSize, 5.0);
      expect(updated.backgroundOpacity, 0.3);
      expect(updated.hasShadow, false);
      // Original fields unchanged.
      expect(updated.fontSize, SubtitleFontSize.medium);
      expect(updated.textColor, SubtitleTextColor.white);
    });

    test('copyWith preserves unset fields', () {
      final style = const SubtitleStyle().copyWith(isBold: true);
      final updated = style.copyWith(outlineSize: 8.0);

      expect(updated.isBold, true); // Preserved.
      expect(updated.outlineSize, 8.0); // Changed.
      expect(updated.verticalPosition, 100); // Default preserved.
    });

    test('equality includes new fields', () {
      const a = SubtitleStyle(isBold: true, outlineSize: 3.0);
      const b = SubtitleStyle(isBold: true, outlineSize: 3.0);
      const c = SubtitleStyle(isBold: false, outlineSize: 3.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SubtitleStyle JSON serialization', () {
    test('toJson includes new fields', () {
      const style = SubtitleStyle(
        isBold: true,
        verticalPosition: 75,
        outlineColor: SubtitleOutlineColor.red,
        outlineSize: 4.5,
        backgroundOpacity: 0.8,
        hasShadow: false,
      );

      final json = style.toJson();
      expect(json['isBold'], true);
      expect(json['verticalPosition'], 75);
      expect(json['outlineColor'], 'red');
      expect(json['outlineSize'], 4.5);
      expect(json['backgroundOpacity'], 0.8);
      expect(json['hasShadow'], false);
    });

    test('fromJson reads new fields', () {
      final json = {
        'fontSize': 'large',
        'textColor': 'yellow',
        'background': 'black',
        'edgeStyle': 'outline',
        'isBold': true,
        'verticalPosition': 60,
        'outlineColor': 'white',
        'outlineSize': 7.0,
        'backgroundOpacity': 0.4,
        'hasShadow': false,
      };

      final style = SubtitleStyle.fromJson(json);
      expect(style.fontSize, SubtitleFontSize.large);
      expect(style.textColor, SubtitleTextColor.yellow);
      expect(style.isBold, true);
      expect(style.verticalPosition, 60);
      expect(style.outlineColor, SubtitleOutlineColor.white);
      expect(style.outlineSize, 7.0);
      expect(style.backgroundOpacity, 0.4);
      expect(style.hasShadow, false);
    });

    test('fromJson uses defaults for missing new fields', () {
      // Legacy JSON without new fields — simulate old stored data.
      final json = {
        'fontSize': 'small',
        'textColor': 'green',
        'background': 'transparent',
        'edgeStyle': 'none',
      };

      final style = SubtitleStyle.fromJson(json);
      expect(style.fontSize, SubtitleFontSize.small);
      expect(style.textColor, SubtitleTextColor.green);
      // New fields get defaults.
      expect(style.isBold, false);
      expect(style.verticalPosition, 100);
      expect(style.outlineColor, SubtitleOutlineColor.black);
      expect(style.outlineSize, 2.0);
      expect(style.backgroundOpacity, 0.6);
      expect(style.hasShadow, true);
    });

    test('round-trip through JSON preserves all fields', () {
      const original = SubtitleStyle(
        fontSize: SubtitleFontSize.extraLarge,
        textColor: SubtitleTextColor.cyan,
        background: SubtitleBackground.black,
        edgeStyle: SubtitleEdgeStyle.raised,
        isBold: true,
        verticalPosition: 30,
        outlineColor: SubtitleOutlineColor.transparent,
        outlineSize: 0.0,
        backgroundOpacity: 1.0,
        hasShadow: false,
      );

      final jsonStr = jsonEncode(original.toJson());
      final restored = SubtitleStyle.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(restored, equals(original));
    });
  });

  // ── SubtitleOutlineColor enum tests ───────────────────────

  group('SubtitleOutlineColor', () {
    test('has 4 values', () {
      expect(SubtitleOutlineColor.values.length, 4);
    });

    test('each has a label', () {
      for (final oc in SubtitleOutlineColor.values) {
        expect(oc.label.isNotEmpty, true);
      }
    });

    test('each has a color', () {
      expect(SubtitleOutlineColor.black.color, const Color(0xFF000000));
      expect(SubtitleOutlineColor.white.color, const Color(0xFFFFFFFF));
      expect(SubtitleOutlineColor.red.color, const Color(0xFFFF0000));
      expect(SubtitleOutlineColor.transparent.color, const Color(0x00000000));
    });
  });

  // ── applySubtitleStyleToPlayer tests ──────────────────────

  group('applySubtitleStyleToPlayer', () {
    late _MockCrispyPlayer player;

    setUp(() {
      player = _MockCrispyPlayer();
      when(() => player.setProperty(any(), any())).thenReturn(null);
    });

    test('sets all mpv properties from default style', () {
      applySubtitleStyleToPlayer(player, const SubtitleStyle());

      verify(() => player.setProperty('sub-font-size', '18.0')).called(1);
      verify(() => player.setProperty('sub-bold', 'no')).called(1);
      verify(() => player.setProperty('sub-pos', '100')).called(1);
      verify(() => player.setProperty('sub-border-size', '2.0')).called(1);
      verify(() => player.setProperty('sub-shadow-offset', '2')).called(1);
      verify(() => player.setProperty('sub-color', any())).called(1);
      verify(() => player.setProperty('sub-border-color', any())).called(1);
      verify(() => player.setProperty('sub-back-color', any())).called(1);
    });

    test('sets bold when isBold is true', () {
      applySubtitleStyleToPlayer(player, const SubtitleStyle(isBold: true));
      verify(() => player.setProperty('sub-bold', 'yes')).called(1);
    });

    test('sets position to custom value', () {
      applySubtitleStyleToPlayer(
        player,
        const SubtitleStyle(verticalPosition: 50),
      );
      verify(() => player.setProperty('sub-pos', '50')).called(1);
    });

    test('disables shadow when hasShadow is false', () {
      applySubtitleStyleToPlayer(player, const SubtitleStyle(hasShadow: false));
      verify(() => player.setProperty('sub-shadow-offset', '0')).called(1);
    });

    test('sets outline size from style', () {
      applySubtitleStyleToPlayer(player, const SubtitleStyle(outlineSize: 8.5));
      verify(() => player.setProperty('sub-border-size', '8.5')).called(1);
    });

    test('sets font size from enum', () {
      applySubtitleStyleToPlayer(
        player,
        const SubtitleStyle(fontSize: SubtitleFontSize.extraLarge),
      );
      verify(() => player.setProperty('sub-font-size', '32.0')).called(1);
    });
  });
}
