import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme uses overhaul surfaces', () {
    final theme = buildCrispyTheme();

    expect(theme.scaffoldBackgroundColor, CrispyOverhaulTokens.surfaceVoid);
    expect(theme.colorScheme.surface, CrispyOverhaulTokens.surfacePanel);
  });
}
