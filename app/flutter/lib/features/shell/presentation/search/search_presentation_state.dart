import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';

final class SearchPresentationState {
  const SearchPresentationState({
    required this.query,
    required this.groups,
    required this.activeGroupTitle,
  });

  const SearchPresentationState.empty()
    : query = '',
      groups = const <SearchResultGroup>[],
      activeGroupTitle = '';

  factory SearchPresentationState.fromRuntime(SearchRuntimeSnapshot runtime) {
    return SearchPresentationState(
      query: runtime.query,
      activeGroupTitle: runtime.activeGroupTitle,
      groups: runtime.groups
          .map(
            (SearchRuntimeGroupSnapshot group) => SearchResultGroup(
              title: group.title,
              results: group.results
                  .map(
                    (SearchRuntimeResultSnapshot result) => ShelfItem(
                      title: result.title,
                      caption: result.caption,
                      artwork: result.artwork,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  final String query;
  final List<SearchResultGroup> groups;
  final String activeGroupTitle;

  bool get hasGroups => groups.isNotEmpty;
}
