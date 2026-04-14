import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';

SearchRuntimeSnapshot resolveSearchRuntime({
  SearchRuntimeSnapshot? runtime,
  ShellContentSnapshot? fallbackContent,
}) {
  return runtime ?? const SearchRuntimeSnapshot.empty();
}
