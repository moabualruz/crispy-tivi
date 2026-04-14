import 'package:crispy_tivi/features/shell/domain/shell_content.dart';

abstract class ShellContentRepository {
  const ShellContentRepository();

  Future<ShellContentSnapshot> load();
}
