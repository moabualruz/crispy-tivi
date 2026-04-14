import 'package:crispy_tivi/features/shell/data/persisted_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/runtime_shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';

enum AppRuntimeMode { real, demo }

final class AppRuntimeProfile {
  const AppRuntimeProfile._({
    required this.mode,
    required this.bootstrapRepositoryFactory,
    required this.sourceRegistryRepositoryFactory,
    required this.personalizationRepositoryFactory,
  });

  const AppRuntimeProfile.real()
    : this._(
        mode: AppRuntimeMode.real,
        bootstrapRepositoryFactory: _createRealBootstrapRepository,
        sourceRegistryRepositoryFactory: _createRealSourceRegistryRepository,
        personalizationRepositoryFactory: _createRealPersonalizationRepository,
      );

  const AppRuntimeProfile.demo()
    : this._(
        mode: AppRuntimeMode.demo,
        bootstrapRepositoryFactory: _createDemoBootstrapRepository,
        sourceRegistryRepositoryFactory: _createDemoSourceRegistryRepository,
        personalizationRepositoryFactory: _createDemoPersonalizationRepository,
      );

  final AppRuntimeMode mode;
  final ShellBootstrapRepository Function() bootstrapRepositoryFactory;
  final SourceRegistryRepository Function() sourceRegistryRepositoryFactory;
  final PersonalizationRuntimeRepository Function()
  personalizationRepositoryFactory;

  ShellBootstrapRepository createBootstrapRepository() =>
      bootstrapRepositoryFactory();

  SourceRegistryRepository createSourceRegistryRepository() =>
      sourceRegistryRepositoryFactory();

  PersonalizationRuntimeRepository createPersonalizationRepository() =>
      personalizationRepositoryFactory();
}

final class AppRuntimeConfig {
  const AppRuntimeConfig._();

  static const bool demoMode = bool.fromEnvironment(
    'CRISPY_DEMO_MODE',
    defaultValue: false,
  );

  static AppRuntimeMode get mode =>
      demoMode ? AppRuntimeMode.demo : AppRuntimeMode.real;

  static AppRuntimeProfile get profile =>
      demoMode
          ? const AppRuntimeProfile.demo()
          : const AppRuntimeProfile.real();
}

ShellBootstrapRepository _createRealBootstrapRepository() =>
    RuntimeShellBootstrapRepository();

ShellBootstrapRepository _createDemoBootstrapRepository() =>
    RuntimeShellBootstrapRepository(
      sourceRegistryRepository: RustSourceRegistryRepository(demoMode: true),
    );

PersonalizationRuntimeRepository _createRealPersonalizationRepository() =>
    PersistedPersonalizationRuntimeRepository();

PersonalizationRuntimeRepository _createDemoPersonalizationRepository() =>
    PersistedPersonalizationRuntimeRepository(seedDefaults: true);

SourceRegistryRepository _createRealSourceRegistryRepository() =>
    RustSourceRegistryRepository();

SourceRegistryRepository _createDemoSourceRegistryRepository() =>
    RustSourceRegistryRepository(demoMode: true);
