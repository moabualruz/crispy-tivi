import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';

class ShellBootstrap {
  const ShellBootstrap({
    required this.contract,
    required this.content,
    this.sourceRegistry = const SourceRegistrySnapshot.empty(),
    this.liveTvRuntime = const LiveTvRuntimeSnapshot.empty(),
    this.mediaRuntime = const MediaRuntimeSnapshot.empty(),
    this.searchRuntime = const SearchRuntimeSnapshot.empty(),
    this.personalizationRuntime = const PersonalizationRuntimeSnapshot.empty(),
    this.diagnosticsRuntime = const DiagnosticsRuntimeSnapshot.empty(),
  });

  final ShellContractSupport contract;
  final ShellContentSnapshot content;
  final SourceRegistrySnapshot sourceRegistry;
  final LiveTvRuntimeSnapshot liveTvRuntime;
  final MediaRuntimeSnapshot mediaRuntime;
  final SearchRuntimeSnapshot searchRuntime;
  final PersonalizationRuntimeSnapshot personalizationRuntime;
  final DiagnosticsRuntimeSnapshot diagnosticsRuntime;
}

abstract class ShellBootstrapRepository {
  const ShellBootstrapRepository();

  Future<ShellBootstrap> load();
}
