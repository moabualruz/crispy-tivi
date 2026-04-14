import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';

abstract class SourceRegistryRepository {
  const SourceRegistryRepository();

  Future<SourceRegistrySnapshot> load();

  Future<void> save(SourceRegistrySnapshot snapshot);
}
