import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/generated_placeholder.dart';
import 'package:crispy_tivi/core/widgets/smart_image.dart';

void main() {
  group('SmartImage', () {
    testWidgets('shows GeneratedPlaceholder when no URL and poster kind', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: SmartImage(title: 'Test Movie', imageKind: 'poster'),
          ),
        ),
      );

      expect(find.byType(GeneratedPlaceholder), findsOneWidget);
    });

    testWidgets('shows GeneratedPlaceholder for empty URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: SmartImage(title: 'Test', imageUrl: ''),
          ),
        ),
      );

      expect(find.byType(GeneratedPlaceholder), findsOneWidget);
    });

    testWidgets('shows GeneratedPlaceholder for whitespace URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: SmartImage(title: 'Test', imageUrl: '   '),
          ),
        ),
      );

      expect(find.byType(GeneratedPlaceholder), findsOneWidget);
    });

    testWidgets('shows GeneratedPlaceholder for invalid protocol', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: SmartImage(
              title: 'Test',
              imageUrl: 'sftp://evil.com/img.png',
            ),
          ),
        ),
      );

      expect(find.byType(GeneratedPlaceholder), findsOneWidget);
    });

    testWidgets('renders base64 data URI as Image.memory', (tester) async {
      // Minimal 1×1 transparent PNG as data URI.
      const png1x1 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lE'
          'QVQIHWNgAAIABQABNjN9GQAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAA'
          'BJRU5ErkJggg==';
      const dataUri = 'data:image/png;base64,$png1x1';

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: SmartImage(title: 'Test', imageUrl: dataUri),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('accepts blurHash parameter', (tester) async {
      // The blurHash won't decode in widget test (no FFI), so
      // it should gracefully fall back to GeneratedPlaceholder.
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: SmartImage(
              title: 'Test',
              blurHash: 'LGF5]+Yk^6#M@-5c,1J5@[or[Q6.',
            ),
          ),
        ),
      );

      // Without FFI, blurHash decode fails silently → placeholder.
      expect(find.byType(GeneratedPlaceholder), findsOneWidget);
    });

    testWidgets('accepts all constructor parameters', (tester) async {
      // Verify all parameters can be passed without error.
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: SmartImage(
              itemId: 'item-1',
              title: 'Test Title',
              imageUrl: null,
              imageKind: 'poster',
              fit: BoxFit.contain,
              icon: Icons.movie,
              blurHash: null,
              placeholderAspectRatio: 16 / 9,
              memCacheWidth: 200,
              memCacheHeight: 300,
            ),
          ),
        ),
      );

      expect(find.byType(GeneratedPlaceholder), findsOneWidget);
    });

    testWidgets('renders s:1: pseudo-URI as Image.memory', (tester) async {
      // Create a minimal 1x1 PNG and encode as URL-safe base64.
      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lE'
        'QVQIHWNgAAIABQABNjN9GQAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAA'
        'BJRU5ErkJggg==',
      );
      final urlSafe = base64Url.encode(pngBytes).replaceAll('=', '');
      final pseudoUri = 's:1:/images/$urlSafe';

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: SmartImage(title: 'Test', imageUrl: pseudoUri),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });
}
