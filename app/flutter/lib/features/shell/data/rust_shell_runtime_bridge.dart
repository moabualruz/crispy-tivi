import 'dart:async';

import 'package:crispy_tivi/src/rust/api.dart' as rust_api;
import 'package:crispy_tivi/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

abstract class ShellRuntimeBridge {
  Future<String> loadSourceRegistryJson();

  Future<String> updateSourceSetupJson({
    required String sourceRegistryJson,
    required String action,
    String? selectedProviderType,
    int? selectedSourceIndex,
    String? targetStep,
    String? fieldKey,
    String? fieldValue,
  });

  Future<String> hydrateRuntimeBundleJson({String? sourceRegistryJson});

  Future<String> loadPlaybackRuntimeJson({String? sourceRegistryJson});

  Future<String> loadPlaybackSessionRuntimeJsonFromStreamJson({
    required String playbackStreamJson,
    int? sourceIndex,
    int? qualityIndex,
    int? audioIndex,
    int? subtitleIndex,
  });

  Future<String> commitSourceSetupJson({required String sourceRegistryJson});

  Future<String> loadDiagnosticsRuntimeJson();
}

ShellRuntimeBridge createShellRuntimeBridge() => const RustShellRuntimeBridge();

class RustShellRuntimeBridge implements ShellRuntimeBridge {
  const RustShellRuntimeBridge();

  static Future<void>? _initFuture;

  static Future<void> ensureInitialized({
    ExternalLibrary? externalLibrary,
    bool forceSameCodegenVersion = true,
  }) {
    return _initFuture ??= RustLib.init(
      externalLibrary: externalLibrary,
      forceSameCodegenVersion: forceSameCodegenVersion,
    );
  }

  static Future<void> initializeMock({required RustLibApi api}) {
    if (_initFuture != null) {
      return _initFuture!;
    }
    RustLib.initMock(api: api);
    _initFuture = Future<void>.value();
    return _initFuture!;
  }

  Future<void> _ensureInitialized() {
    return ensureInitialized();
  }

  @override
  Future<String> loadSourceRegistryJson() async {
    await _ensureInitialized();
    return rust_api.sourceRegistryJson();
  }

  @override
  Future<String> hydrateRuntimeBundleJson({String? sourceRegistryJson}) async {
    await _ensureInitialized();
    return rust_api.hydrateRuntimeBundleJson(
      sourceRegistryJson: sourceRegistryJson,
    );
  }

  @override
  Future<String> loadPlaybackRuntimeJson({String? sourceRegistryJson}) async {
    await _ensureInitialized();
    return rust_api.playbackRuntimeJson(
      sourceRegistryJson: sourceRegistryJson,
    );
  }

  @override
  Future<String> loadPlaybackSessionRuntimeJsonFromStreamJson({
    required String playbackStreamJson,
    int? sourceIndex,
    int? qualityIndex,
    int? audioIndex,
    int? subtitleIndex,
  }) async {
    await _ensureInitialized();
    return rust_api.playbackSessionRuntimeJsonFromStreamJson(
      playbackStreamJson: playbackStreamJson,
      sourceIndex: sourceIndex,
      qualityIndex: qualityIndex,
      audioIndex: audioIndex,
      subtitleIndex: subtitleIndex,
    );
  }

  @override
  Future<String> updateSourceSetupJson({
    required String sourceRegistryJson,
    required String action,
    String? selectedProviderType,
    int? selectedSourceIndex,
    String? targetStep,
    String? fieldKey,
    String? fieldValue,
  }) async {
    await _ensureInitialized();
    return rust_api.updateSourceSetupJson(
      sourceRegistryJson: sourceRegistryJson,
      action: action,
      selectedProviderType: selectedProviderType,
      selectedSourceIndex: selectedSourceIndex,
      targetStep: targetStep,
      fieldKey: fieldKey,
      fieldValue: fieldValue,
    );
  }

  @override
  Future<String> commitSourceSetupJson({
    required String sourceRegistryJson,
  }) async {
    await _ensureInitialized();
    return rust_api.commitSourceSetupJson(
      sourceRegistryJson: sourceRegistryJson,
    );
  }

  @override
  Future<String> loadDiagnosticsRuntimeJson() async {
    await _ensureInitialized();
    return rust_api.diagnosticsRuntimeJson();
  }
}
