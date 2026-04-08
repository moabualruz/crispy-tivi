import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crispy_tivi/core/widgets/glass_surface.dart';
import 'package:crispy_tivi/core/theme/crispy_colors.dart';

void main() {
  testWidgets('BUG-001: GlassSurface respects borderRadius parameter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[CrispyColors.dark()],
          ),
          home: const Scaffold(
            body: GlassSurface(
              borderRadius: 16.0,
              blurSigma: 10.0, // Force a specific value for the test if needed
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    // Using un-blurred fallback Container or BackdropFilter+Container structure
    // Find the ClipRRect (used for BackdropFilter fallback) or AnimatedContainer
    final animatedContainerFinder = find.byType(AnimatedContainer);
    expect(animatedContainerFinder, findsWidgets);

    final AnimatedContainer container = tester.widget(
      animatedContainerFinder.first,
    );
    final BoxDecoration decoration = container.decoration as BoxDecoration;

    // Assert that the border radius equals 16.0
    expect(decoration.borderRadius, BorderRadius.circular(16.0));
  });
}
