import 'dart:async';

import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/shell_runtime_bundle.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_source_setup_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_state/source_provider_registry.dart';

final class ShellSourceWorkflowCoordinator {
  ShellSourceWorkflowCoordinator({
    required SourceRegistrySnapshot sourceRegistry,
    required SourceRegistryRepository sourceRegistryRepository,
    ShellSourceSetupCoordinator? sourceSetupCoordinator,
    ShellRuntimeBridge? shellRuntimeBridge,
    required bool Function() isDisposed,
    required void Function(ShellRuntimeBundle bundle) applyRuntimeBundle,
    required void Function() notifyChanged,
  }) : _sourceRegistrySnapshot = sourceRegistry,
       _sourceSetupCoordinator =
           sourceSetupCoordinator ??
           ShellSourceSetupCoordinator(
             sourceRegistryRepository: sourceRegistryRepository,
             shellRuntimeBridge: shellRuntimeBridge,
           ),
       _isDisposed = isDisposed,
       _applyRuntimeBundle = applyRuntimeBundle,
       _notifyChanged = notifyChanged;

  final ShellSourceSetupCoordinator _sourceSetupCoordinator;
  final bool Function() _isDisposed;
  final void Function(ShellRuntimeBundle bundle) _applyRuntimeBundle;
  final void Function() _notifyChanged;

  SourceRegistrySnapshot _sourceRegistrySnapshot;

  SourceRegistrySnapshot get sourceRegistrySnapshot => _sourceRegistrySnapshot;
  int get selectedSourceIndex => _sourceRegistrySnapshot.selectedSourceIndex;
  bool get sourceWizardActive => _sourceRegistrySnapshot.wizardActive;
  SourceWizardStep get sourceWizardStep =>
      _sourceRegistrySnapshot.activeWizardStep;
  Map<String, String> get sourceWizardFieldValues =>
      Map<String, String>.unmodifiable(_sourceRegistrySnapshot.fieldValues);

  void applySourceRegistrySnapshot(SourceRegistrySnapshot snapshot) {
    _sourceRegistrySnapshot = snapshot;
  }

  void selectSourceIndex(int index) {
    if (selectedSourceIndex == index && !sourceWizardActive) {
      return;
    }
    unawaited(
      _applySourceSetupAction(
        action: 'select_source',
        selectedSourceIndex: index,
      ),
    );
  }

  void startAddSourceWizard() {
    unawaited(_applySourceSetupAction(action: 'start_add'));
    _notifyChanged();
  }

  void startEditSourceWizard() {
    unawaited(
      _applySourceSetupAction(
        action: 'start_edit',
        selectedSourceIndex: selectedSourceIndex,
      ),
    );
    _notifyChanged();
  }

  void startReconnectWizard() {
    unawaited(
      _applySourceSetupAction(
        action: 'start_reconnect',
        selectedSourceIndex: selectedSourceIndex,
      ),
    );
    _notifyChanged();
  }

  void startImportWizard() {
    unawaited(
      _applySourceSetupAction(
        action: 'start_import',
        selectedSourceIndex: selectedSourceIndex,
      ),
    );
    _notifyChanged();
  }

  void updateSourceWizardField(String fieldLabel, String value) {
    if (_sourceRegistrySnapshot.fieldValues[fieldLabel] == value) {
      return;
    }
    unawaited(
      _applySourceSetupAction(
        action: 'update_field',
        fieldKey: fieldLabel,
        fieldValue: value,
      ),
    );
  }

  void selectSourceProviderType(SourceProviderKind kind) {
    if (_sourceRegistrySnapshot.selectedProviderKind.label == kind.label) {
      return;
    }
    unawaited(
      _applySourceSetupAction(
        action: 'select_provider_type',
        selectedProviderType: kind.label,
      ),
    );
  }

  void selectSourceWizardStep(SourceWizardStep step) {
    if (!sourceWizardActive || sourceWizardStep == step) {
      return;
    }
    unawaited(
      _applySourceSetupAction(
        action: 'select_wizard_step',
        targetStep: step.label,
      ),
    );
  }

  Future<void> advanceSourceWizard() async {
    if (!sourceWizardActive) {
      return;
    }
    final SourceSetupAdvanceResult result = await _sourceSetupCoordinator
        .advance(sourceRegistry: _sourceRegistrySnapshot);
    if (_isDisposed()) {
      return;
    }
    if (result.runtimeBundle case final ShellRuntimeBundle bundle) {
      _sourceRegistrySnapshot = bundle.sourceRegistry;
      _applyRuntimeBundle(bundle);
      _notifyChanged();
      return;
    }
    if (result.sourceRegistry case final SourceRegistrySnapshot snapshot) {
      _sourceRegistrySnapshot = snapshot;
      _notifyChanged();
    }
  }

  void retreatSourceWizard() {
    if (!sourceWizardActive) {
      return;
    }
    unawaited(_applySourceSetupAction(action: 'retreat_wizard'));
  }

  Future<void> clearSourceWizardState() async {
    await _applySourceSetupAction(action: 'clear_wizard');
  }

  Future<void> _applySourceSetupAction({
    required String action,
    String? selectedProviderType,
    int? selectedSourceIndex,
    String? targetStep,
    String? fieldKey,
    String? fieldValue,
  }) async {
    final SourceRegistrySnapshot updatedRegistry = await _sourceSetupCoordinator
        .applyAction(
          sourceRegistry: _sourceRegistrySnapshot,
          action: action,
          selectedProviderType: selectedProviderType,
          selectedSourceIndex: selectedSourceIndex,
          targetStep: targetStep,
          fieldKey: fieldKey,
          fieldValue: fieldValue,
        );
    if (_isDisposed()) {
      return;
    }
    _sourceRegistrySnapshot = updatedRegistry;
    _notifyChanged();
  }
}
