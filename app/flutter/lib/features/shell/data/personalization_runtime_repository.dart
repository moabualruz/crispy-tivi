import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';

abstract class PersonalizationRuntimeRepository {
  const PersonalizationRuntimeRepository();

  Future<PersonalizationRuntimeSnapshot> load();

  Future<void> save(PersonalizationRuntimeSnapshot snapshot);
}

final class NoopPersonalizationRuntimeRepository
    extends PersonalizationRuntimeRepository {
  const NoopPersonalizationRuntimeRepository();

  @override
  Future<PersonalizationRuntimeSnapshot> load() async {
    return const PersonalizationRuntimeSnapshot.empty();
  }

  @override
  Future<void> save(PersonalizationRuntimeSnapshot snapshot) async {}
}
