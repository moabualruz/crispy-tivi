import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';

abstract class SearchRuntimeRepository {
  const SearchRuntimeRepository();

  Future<SearchRuntimeSnapshot> load();
}
