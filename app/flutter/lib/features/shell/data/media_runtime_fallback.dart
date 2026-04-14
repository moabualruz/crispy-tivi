import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';

MediaRuntimeSnapshot resolveMediaRuntime({
  MediaRuntimeSnapshot? runtime,
  ShellContentSnapshot? fallbackContent,
}) {
  return runtime ?? const MediaRuntimeSnapshot.empty();
}
