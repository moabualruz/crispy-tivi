import 'package:crispy_tivi/features/shell/data/shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:flutter/services.dart';

class AssetShellContentRepository extends ShellContentRepository {
  const AssetShellContentRepository();

  static const String assetPath = 'assets/contracts/asset_shell_content.json';

  @override
  Future<ShellContentSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return ShellContentSnapshot.fromJsonString(source);
  }
}
