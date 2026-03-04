import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper for enforcing Visual Assertions (Gap 3 from .ai/docs/ai-tracking/autonomous_qa_execution.md)
/// Converts subjective "Verify layout changes" into explicit exact pixel requirements and goldens.
class VisualMatcher {
  static Future<void> verifyLayoutConstraint(
    WidgetTester tester,
    Finder finder, {
    required double expectedWidth,
    required double expectedHeight,
  }) async {
    final Rect rect = tester.getRect(finder);
    expect(
      rect.width,
      expectedWidth,
      reason:
          'Visual match failed: expected width $expectedWidth but got ${rect.width}',
    );
    expect(
      rect.height,
      expectedHeight,
      reason:
          'Visual match failed: expected height $expectedHeight but got ${rect.height}',
    );
  }

  static Future<void> matchGolden(
    WidgetTester tester,
    Finder finder,
    String goldenFileName,
  ) async {
    // In a real run, this matches a generated .png inside integration_test/goldens/
    await expectLater(finder, matchesGoldenFile('goldens/$goldenFileName'));
  }
}
