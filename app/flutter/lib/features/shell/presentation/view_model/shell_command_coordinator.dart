import 'dart:async';

import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/presentation/view_state/source_provider_registry.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_navigation_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_player_runtime_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_source_workflow_coordinator.dart';

final class ShellCommandCoordinator {
  ShellCommandCoordinator({
    required ShellNavigationCoordinator navigationCoordinator,
    required ShellSourceWorkflowCoordinator sourceWorkflowCoordinator,
    required ShellPlayerRuntimeCoordinator playerCoordinator,
  }) : _navigationCoordinator = navigationCoordinator,
       _sourceWorkflowCoordinator = sourceWorkflowCoordinator,
       _playerCoordinator = playerCoordinator;

  final ShellNavigationCoordinator _navigationCoordinator;
  final ShellSourceWorkflowCoordinator _sourceWorkflowCoordinator;
  final ShellPlayerRuntimeCoordinator _playerCoordinator;

  void selectRoute(ShellRoute route) {
    _navigationCoordinator.selectRoute(route);
    if (route != ShellRoute.settings) {
      unawaited(_sourceWorkflowCoordinator.clearSourceWizardState());
    }
  }

  void toggleMediaWatchlist(String contentKey) {
    unawaited(_navigationCoordinator.toggleFavoriteMediaKey(contentKey));
  }

  void selectSettingsPanel(SettingsPanel panel) {
    _navigationCoordinator.selectSettingsPanel(panel);
    if (panel != SettingsPanel.sources) {
      unawaited(_sourceWorkflowCoordinator.clearSourceWizardState());
    }
  }

  void selectSourceIndex(int index) {
    _navigationCoordinator.focusSourcesPanel(
      highlightedSettingsLeaf: ShellNavigationCoordinator.sourcesLeafLabel(
        index,
      ),
    );
    _sourceWorkflowCoordinator.selectSourceIndex(index);
  }

  void startAddSourceWizard() {
    _navigationCoordinator.focusSourcesPanel();
    _sourceWorkflowCoordinator.startAddSourceWizard();
  }

  void startEditSourceWizard() {
    _navigationCoordinator.focusSourcesPanel();
    _sourceWorkflowCoordinator.startEditSourceWizard();
  }

  void startReconnectWizard() {
    _navigationCoordinator.focusSourcesPanel();
    _sourceWorkflowCoordinator.startReconnectWizard();
  }

  void startImportWizard() {
    _navigationCoordinator.focusSourcesPanel();
    _sourceWorkflowCoordinator.startImportWizard();
  }

  void updateSourceWizardField(String fieldLabel, String value) {
    _sourceWorkflowCoordinator.updateSourceWizardField(fieldLabel, value);
  }

  void selectSourceProviderType(SourceProviderKind kind) {
    _sourceWorkflowCoordinator.selectSourceProviderType(kind);
  }

  void selectSourceWizardStep(SourceWizardStep step) {
    _sourceWorkflowCoordinator.selectSourceWizardStep(step);
  }

  Future<void> advanceSourceWizard() {
    return _sourceWorkflowCoordinator.advanceSourceWizard();
  }

  void retreatSourceWizard() {
    _sourceWorkflowCoordinator.retreatSourceWizard();
  }

  void updateSettingsSearchQuery(String value) {
    _navigationCoordinator.updateSettingsSearchQuery(value);
  }

  void clearSettingsSearch() {
    _navigationCoordinator.clearSettingsSearch();
  }

  void openSettingsLeaf({
    required SettingsPanel panel,
    required String leafLabel,
    int? sourceIndex,
  }) {
    _navigationCoordinator.openSettingsLeaf(panel: panel, leafLabel: leafLabel);
    if (panel == SettingsPanel.sources && sourceIndex != null) {
      _sourceWorkflowCoordinator.selectSourceIndex(sourceIndex);
    } else {
      unawaited(_sourceWorkflowCoordinator.clearSourceWizardState());
    }
  }

  void launchPlayer(PlayerSession session) {
    _playerCoordinator.launchPlayer(session);
  }

  void openPlayerInfo() {
    _playerCoordinator.openPlayerInfo();
  }

  void openPlayerChooser(PlayerChooserKind kind) {
    _playerCoordinator.openPlayerChooser(kind);
  }

  void closePlayerChooser() {
    _playerCoordinator.closePlayerChooser();
  }

  void unwindPlayer() {
    _playerCoordinator.unwindPlayer();
  }

  void selectPlayerQueueIndex(int index) {
    _playerCoordinator.selectPlayerQueueIndex(index);
  }

  void selectPlayerChooserOption(PlayerChooserKind kind, int optionIndex) {
    _playerCoordinator.selectPlayerChooserOption(kind, optionIndex);
  }

  void dispose() {
    _playerCoordinator.dispose();
  }
}
