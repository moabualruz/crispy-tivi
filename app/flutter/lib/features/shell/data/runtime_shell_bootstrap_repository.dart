import 'package:crispy_tivi/features/shell/data/asset_shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/persisted_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_runtime_bundle.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';

class RuntimeShellBootstrapRepository extends ShellBootstrapRepository {
  RuntimeShellBootstrapRepository({
    this.contractRepository = const AssetShellContractRepository(),
    SourceRegistryRepository? sourceRegistryRepository,
    DiagnosticsRuntimeRepository? diagnosticsRuntimeRepository,
    PersonalizationRuntimeRepository? personalizationRuntimeRepository,
    ShellRuntimeBridge? shellRuntimeBridge,
  }) : sourceRegistryRepository =
           sourceRegistryRepository ?? RustSourceRegistryRepository(),
       diagnosticsRuntimeRepository =
           diagnosticsRuntimeRepository ??
           RustDiagnosticsRuntimeRepository(
             shellRuntimeBridge: shellRuntimeBridge,
           ),
       personalizationRuntimeRepository =
           personalizationRuntimeRepository ??
           PersistedPersonalizationRuntimeRepository(),
       shellRuntimeBridge = shellRuntimeBridge ?? createShellRuntimeBridge();

  final ShellContractRepository contractRepository;
  final SourceRegistryRepository sourceRegistryRepository;
  final DiagnosticsRuntimeRepository diagnosticsRuntimeRepository;
  final PersonalizationRuntimeRepository personalizationRuntimeRepository;
  final ShellRuntimeBridge shellRuntimeBridge;

  @override
  Future<ShellBootstrap> load() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      contractRepository.load(),
      sourceRegistryRepository.load(),
      diagnosticsRuntimeRepository.load(),
      personalizationRuntimeRepository.load(),
    ]);

    final ShellContractSupport contract = loaded[0] as ShellContractSupport;
    final SourceRegistrySnapshot sourceRegistry =
        loaded[1] as SourceRegistrySnapshot;
    final DiagnosticsRuntimeSnapshot diagnosticsRuntime =
        loaded[2] as DiagnosticsRuntimeSnapshot;
    final String bundleJson = await shellRuntimeBridge.hydrateRuntimeBundleJson(
      sourceRegistryJson: sourceRegistry.toJsonString(),
    );
    final ShellRuntimeBundle runtimeBundle = ShellRuntimeBundle.fromJsonString(
      bundleJson,
    );

    return ShellBootstrap(
      contract: contract,
      content: const ShellContentSnapshot.empty(),
      sourceRegistry: runtimeBundle.sourceRegistry,
      liveTvRuntime: runtimeBundle.liveTvRuntime,
      mediaRuntime: runtimeBundle.mediaRuntime,
      searchRuntime: runtimeBundle.searchRuntime,
      diagnosticsRuntime: diagnosticsRuntime,
      personalizationRuntime: runtimeBundle.personalizationRuntime,
    );
  }
}
