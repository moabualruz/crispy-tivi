import 'package:crispy_tivi/features/shell/data/asset_shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/persisted_personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/media_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_bootstrap_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/data/shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/search_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';

class AssetShellBootstrapRepository extends ShellBootstrapRepository {
  AssetShellBootstrapRepository({
    this.contractRepository = const AssetShellContractRepository(),
    this.contentRepository = const AssetShellContentRepository(),
    this.sourceRegistryRepository = const AssetSourceRegistryRepository(),
    this.liveTvRuntimeRepository = const AssetLiveTvRuntimeRepository(),
    this.mediaRuntimeRepository = const AssetMediaRuntimeRepository(),
    this.searchRuntimeRepository = const AssetSearchRuntimeRepository(),
    this.diagnosticsRuntimeRepository =
        const AssetDiagnosticsRuntimeRepository(),
    PersonalizationRuntimeRepository? personalizationRuntimeRepository,
  }) : personalizationRuntimeRepository =
           personalizationRuntimeRepository ??
           PersistedPersonalizationRuntimeRepository();

  final ShellContractRepository contractRepository;
  final ShellContentRepository contentRepository;
  final SourceRegistryRepository sourceRegistryRepository;
  final LiveTvRuntimeRepository liveTvRuntimeRepository;
  final MediaRuntimeRepository mediaRuntimeRepository;
  final SearchRuntimeRepository searchRuntimeRepository;
  final DiagnosticsRuntimeRepository diagnosticsRuntimeRepository;
  final PersonalizationRuntimeRepository personalizationRuntimeRepository;

  @override
  Future<ShellBootstrap> load() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      contractRepository.load(),
      contentRepository.load(),
      sourceRegistryRepository.load(),
      liveTvRuntimeRepository.load(),
      mediaRuntimeRepository.load(),
      searchRuntimeRepository.load(),
      diagnosticsRuntimeRepository.load(),
      personalizationRuntimeRepository.load(),
    ]);
    return ShellBootstrap(
      contract: loaded[0] as ShellContractSupport,
      content: loaded[1] as ShellContentSnapshot,
      sourceRegistry: loaded[2] as SourceRegistrySnapshot,
      liveTvRuntime: loaded[3] as LiveTvRuntimeSnapshot,
      mediaRuntime: loaded[4] as MediaRuntimeSnapshot,
      searchRuntime: loaded[5] as SearchRuntimeSnapshot,
      diagnosticsRuntime: loaded[6] as DiagnosticsRuntimeSnapshot,
      personalizationRuntime: loaded[7] as PersonalizationRuntimeSnapshot,
    );
  }
}
