import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';

final class ShellRuntimeBundle {
  const ShellRuntimeBundle({
    required this.sourceRegistry,
    required this.liveTvRuntime,
    required this.mediaRuntime,
    required this.searchRuntime,
    required this.personalizationRuntime,
  });

  factory ShellRuntimeBundle.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('shell runtime bundle must be a JSON object');
    }
    return ShellRuntimeBundle.fromJson(decoded);
  }

  factory ShellRuntimeBundle.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> runtime = _readObject(json, 'runtime');
    return ShellRuntimeBundle(
      sourceRegistry: SourceRegistrySnapshot.fromJson(
        _readObject(json, 'source_registry'),
      ),
      liveTvRuntime: LiveTvRuntimeSnapshot.fromJson(
        _readObject(runtime, 'live_tv'),
      ),
      mediaRuntime: MediaRuntimeSnapshot.fromJson(_readObject(runtime, 'media')),
      searchRuntime: SearchRuntimeSnapshot.fromJson(
        _readObject(runtime, 'search'),
      ),
      personalizationRuntime: PersonalizationRuntimeSnapshot.fromJson(
        _readObject(runtime, 'personalization'),
      ),
    );
  }

  final SourceRegistrySnapshot sourceRegistry;
  final LiveTvRuntimeSnapshot liveTvRuntime;
  final MediaRuntimeSnapshot mediaRuntime;
  final SearchRuntimeSnapshot searchRuntime;
  final PersonalizationRuntimeSnapshot personalizationRuntime;
}

Map<String, dynamic> _readObject(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return value;
}
