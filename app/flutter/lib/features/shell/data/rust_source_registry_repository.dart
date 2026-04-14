import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_store.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';

class RustSourceRegistryRepository extends SourceRegistryRepository {
  RustSourceRegistryRepository({
    ShellRuntimeBridge? bridge,
    SourceRegistryStore? store,
    this.demoMode = false,
  }) : bridge = bridge ?? createShellRuntimeBridge(),
       store = store ?? createSourceRegistryStore();

  final ShellRuntimeBridge bridge;
  final SourceRegistryStore store;
  final bool demoMode;

  Future<SourceRegistrySnapshot> _loadDefaultSnapshot() async {
    final String sourceRegistryJson = await bridge.loadSourceRegistryJson();
    final String defaultsJson =
        demoMode
            ? await bridge.updateSourceSetupJson(
              sourceRegistryJson: sourceRegistryJson,
              action: 'seed_demo',
            )
            : sourceRegistryJson;
    return SourceRegistrySnapshot.fromJsonString(defaultsJson);
  }

  @override
  Future<SourceRegistrySnapshot> load() async {
    final SourceRegistrySnapshot defaults = await _loadDefaultSnapshot();
    final String? persisted = await store.load();
    if (persisted == null || persisted.trim().isEmpty) {
      return defaults;
    }
    try {
      final SourceRegistrySnapshot snapshot = SourceRegistrySnapshot.fromJsonString(
        persisted,
      );
      return defaults.copyWith(
        selectedProviderKind: snapshot.selectedProviderKind,
        activeWizardStep: snapshot.activeWizardStep,
        configuredProviders: snapshot.configuredProviders,
      );
    } catch (_) {
      return defaults;
    }
  }

  @override
  Future<void> save(SourceRegistrySnapshot snapshot) {
    return store.save(snapshot.toJsonString());
  }
}
