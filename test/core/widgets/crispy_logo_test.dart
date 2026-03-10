import 'package:crispy_tivi/core/widgets/crispy_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrispyLogo', () {
    testWidgets('renders without error with default params', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CrispyLogo())),
      );

      expect(find.byType(CrispyLogo), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('uses custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CrispyLogo(size: 96))),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.height, 96);
    });

    testWidgets('applies custom color via colorFilter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CrispyLogo(color: Colors.red))),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        svgPicture.colorFilter,
        const ColorFilter.mode(Colors.red, BlendMode.srcIn),
      );
    });

    testWidgets('has accessibility semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CrispyLogo())),
      );

      expect(find.bySemanticsLabel('CrispyTivi logo'), findsOneWidget);
    });

    testWidgets('accepts custom semantic label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CrispyLogo(semanticLabel: 'App brand')),
        ),
      );

      expect(find.bySemanticsLabel('App brand'), findsOneWidget);
    });
  });
}
