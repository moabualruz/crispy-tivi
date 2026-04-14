import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/shell_runtime_bundle.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart' as raw;
import 'package:flutter/foundation.dart';

final class SourceSetupAdvanceResult {
  const SourceSetupAdvanceResult({
    this.sourceRegistry,
    this.runtimeBundle,
  });

  final SourceRegistrySnapshot? sourceRegistry;
  final ShellRuntimeBundle? runtimeBundle;
}

final class ShellSourceSetupCoordinator {
  const ShellSourceSetupCoordinator({
    required SourceRegistryRepository sourceRegistryRepository,
    ShellRuntimeBridge? shellRuntimeBridge,
  }) : _sourceRegistryRepository = sourceRegistryRepository,
       _shellRuntimeBridge = shellRuntimeBridge;

  final SourceRegistryRepository _sourceRegistryRepository;
  final ShellRuntimeBridge? _shellRuntimeBridge;

  bool get available => !kIsWeb && _shellRuntimeBridge != null;

  Future<SourceRegistrySnapshot> applyAction({
    required SourceRegistrySnapshot sourceRegistry,
    required String action,
    String? selectedProviderType,
    int? selectedSourceIndex,
    String? targetStep,
    String? fieldKey,
    String? fieldValue,
  }) async {
    if (!available) {
      return sourceRegistry;
    }
    final String updatedRegistryJson = await _shellRuntimeBridge!
        .updateSourceSetupJson(
          sourceRegistryJson: sourceRegistry.toJsonString(),
          action: action,
          selectedProviderType: selectedProviderType,
          selectedSourceIndex: selectedSourceIndex,
          targetStep: targetStep,
          fieldKey: fieldKey,
          fieldValue: fieldValue,
        );
    return SourceRegistrySnapshot.fromJsonString(updatedRegistryJson);
  }

  Future<SourceSetupAdvanceResult> advance({
    required SourceRegistrySnapshot sourceRegistry,
  }) async {
    if (!available) {
      return SourceSetupAdvanceResult(sourceRegistry: _nextWizardSnapshot(sourceRegistry));
    }
    if (_isFinalWizardStep(sourceRegistry)) {
      final String bundleJson = await _shellRuntimeBridge!.commitSourceSetupJson(
        sourceRegistryJson: sourceRegistry.toJsonString(),
      );
      final ShellRuntimeBundle bundle = ShellRuntimeBundle.fromJsonString(
        bundleJson,
      );
      await _sourceRegistryRepository.save(bundle.sourceRegistry);
      return SourceSetupAdvanceResult(runtimeBundle: bundle);
    }
    return SourceSetupAdvanceResult(
      sourceRegistry: await applyAction(
        sourceRegistry: sourceRegistry,
        action: 'advance_wizard',
      ),
    );
  }

  Future<SourceRegistrySnapshot> clear({
    required SourceRegistrySnapshot sourceRegistry,
  }) {
    return applyAction(sourceRegistry: sourceRegistry, action: 'clear_wizard');
  }

  static bool _isFinalWizardStep(SourceRegistrySnapshot sourceRegistry) {
    if (sourceRegistry.wizardSteps.isEmpty) {
      return false;
    }
    return sourceRegistry.activeWizardStep ==
        sourceRegistry.wizardSteps.last.step;
  }

  static SourceRegistrySnapshot _nextWizardSnapshot(
    SourceRegistrySnapshot sourceRegistry,
  ) {
    final int currentIndex = sourceRegistry.wizardSteps.indexWhere(
      (raw.SourceWizardStepDescriptor item) =>
          item.step == sourceRegistry.activeWizardStep,
    );
    if (currentIndex == -1 ||
        currentIndex + 1 >= sourceRegistry.wizardSteps.length) {
      return sourceRegistry;
    }
    return sourceRegistry.copyWith(
      activeWizardStep: sourceRegistry.wizardSteps[currentIndex + 1].step,
    );
  }
}
