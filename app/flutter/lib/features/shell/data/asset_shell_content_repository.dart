import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:flutter/services.dart';

class AssetShellContentRepository {
  const AssetShellContentRepository();

  static const String assetPath = 'assets/contracts/asset_shell_content.json';

  Future<ShellContentSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return ShellContentSnapshot.fromJsonString(source);
  }
}
