import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artwork source supports asset and network providers', () {
    final ArtworkSource asset = ArtworkSource.asset(
      'assets/mocks/poster-shell-1.jpg',
    );
    final ArtworkSource network = ArtworkSource.network(
      'https://example.com/poster.jpg',
    );

    expect(asset.provider(), isA<AssetImage>());
    expect(network.provider(), isA<NetworkImage>());
  });
}
