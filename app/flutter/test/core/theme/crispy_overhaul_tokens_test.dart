import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overhaul tokens stay pinned to installed design values', () {
    expect(CrispyOverhaulTokens.surfaceVoid.toARGB32(), 0xFF0E0E10);
    expect(CrispyOverhaulTokens.accentBrand.toARGB32(), 0xFF8DA4C7);
    expect(CrispyOverhaulTokens.medium, 18);
    expect(CrispyOverhaulTokens.radiusSheet, 10);
  });
}
