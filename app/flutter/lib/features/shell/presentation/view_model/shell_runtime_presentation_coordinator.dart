import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/data/shell_runtime_bundle.dart';

final class ShellRuntimePresentationCoordinator {
  ShellRuntimePresentationCoordinator({
    required LiveTvRuntimeSnapshot liveTvRuntime,
    required MediaRuntimeSnapshot mediaRuntime,
    required SearchRuntimeSnapshot searchRuntime,
    required DiagnosticsRuntimeSnapshot diagnosticsRuntime,
    required PersonalizationRuntimeSnapshot personalizationRuntime,
  }) : _liveTvRuntime = liveTvRuntime,
       _mediaRuntime = mediaRuntime,
       _searchRuntime = searchRuntime,
       _diagnosticsRuntime = diagnosticsRuntime,
       _personalizationRuntime = personalizationRuntime;

  LiveTvRuntimeSnapshot _liveTvRuntime;
  MediaRuntimeSnapshot _mediaRuntime;
  SearchRuntimeSnapshot _searchRuntime;
  final DiagnosticsRuntimeSnapshot _diagnosticsRuntime;
  PersonalizationRuntimeSnapshot _personalizationRuntime;

  LiveTvRuntimeSnapshot get liveTvRuntime => _liveTvRuntime;
  MediaRuntimeSnapshot get mediaRuntime => _mediaRuntime;
  SearchRuntimeSnapshot get searchRuntime => _searchRuntime;
  DiagnosticsRuntimeSnapshot get diagnosticsRuntime => _diagnosticsRuntime;
  PersonalizationRuntimeSnapshot get personalizationRuntime =>
      _personalizationRuntime;

  void applyRuntimeBundle(ShellRuntimeBundle bundle) {
    _liveTvRuntime = bundle.liveTvRuntime;
    _mediaRuntime = bundle.mediaRuntime;
    _searchRuntime = bundle.searchRuntime;
    _personalizationRuntime = bundle.personalizationRuntime;
  }

  void setPersonalizationRuntime(PersonalizationRuntimeSnapshot snapshot) {
    _personalizationRuntime = snapshot;
  }
}
