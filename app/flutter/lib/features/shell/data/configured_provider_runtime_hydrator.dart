import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';

LiveTvRuntimeSnapshot resolveLiveTvRuntime({
  LiveTvRuntimeSnapshot? runtime,
  ShellContentSnapshot? fallbackContent,
}) {
  return runtime ?? const LiveTvRuntimeSnapshot.empty();
}
