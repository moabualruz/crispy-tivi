import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/presentation/search/search_presentation_state.dart';

final class SearchPresentationAdapter {
  const SearchPresentationAdapter();

  static SearchPresentationState build({
    required SearchRuntimeSnapshot runtime,
  }) {
    return SearchPresentationState.fromRuntime(runtime);
  }
}
