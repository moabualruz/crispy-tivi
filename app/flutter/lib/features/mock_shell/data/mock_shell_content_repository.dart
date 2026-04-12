import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:flutter/services.dart';

class MockShellContentRepository {
  const MockShellContentRepository();

  static const String assetPath = 'assets/contracts/mock_shell_content.json';

  Future<MockShellContentSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return MockShellContentSnapshot.fromJsonString(source);
  }
}
