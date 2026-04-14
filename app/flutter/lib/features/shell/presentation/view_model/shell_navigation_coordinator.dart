import 'dart:async';

import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_personalization_coordinator.dart';

final class ShellNavigationCoordinator {
  ShellNavigationCoordinator({
    required ShellContractSupport contract,
    required SourceRegistrySnapshot sourceRegistry,
    required PersonalizationRuntimeSnapshot personalizationRuntime,
    required ShellPersonalizationCoordinator personalizationCoordinator,
    required bool Function() isDisposed,
    required void Function(PersonalizationRuntimeSnapshot snapshot)
    setPersonalizationRuntime,
    required void Function() notifyChanged,
  }) : _personalizationRuntime = personalizationRuntime,
       _personalizationCoordinator = personalizationCoordinator,
       _isDisposed = isDisposed,
       _setPersonalizationRuntime = setPersonalizationRuntime,
       _notifyChanged = notifyChanged,
       _route = _resolveShellStartupRoute(
         personalizationRuntime,
         contract,
         sourceRegistry,
       ),
       _settingsPanel =
           (sourceRegistry.configuredProviders.isEmpty &&
                   contract.settingsPanels.contains(SettingsPanel.sources))
               ? SettingsPanel.sources
               : contract.settingsPanels.first;

  final ShellPersonalizationCoordinator _personalizationCoordinator;
  final bool Function() _isDisposed;
  final void Function(PersonalizationRuntimeSnapshot snapshot)
  _setPersonalizationRuntime;
  final void Function() _notifyChanged;

  PersonalizationRuntimeSnapshot _personalizationRuntime;
  ShellRoute _route;
  SettingsPanel _settingsPanel;
  String _settingsSearchQuery = '';
  String? _highlightedSettingsLeaf;

  ShellRoute get route => _route;
  SettingsPanel get settingsPanel => _settingsPanel;
  String get settingsSearchQuery => _settingsSearchQuery;
  String? get highlightedSettingsLeaf => _highlightedSettingsLeaf;

  void setPersonalizationRuntime(PersonalizationRuntimeSnapshot snapshot) {
    _personalizationRuntime = snapshot;
    _setPersonalizationRuntime(snapshot);
  }

  void selectRoute(ShellRoute route) {
    if (_route == route) {
      return;
    }
    _route = route;
    if (route != ShellRoute.settings) {
      _settingsSearchQuery = '';
      _highlightedSettingsLeaf = null;
    }
    unawaited(_updateStartupRoute(route));
    _notifyChanged();
  }

  void selectSettingsPanel(SettingsPanel panel) {
    if (_settingsPanel == panel) {
      return;
    }
    _settingsPanel = panel;
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = null;
    _notifyChanged();
  }

  void focusSourcesPanel({String? highlightedSettingsLeaf}) {
    _route = ShellRoute.settings;
    _settingsPanel = SettingsPanel.sources;
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = highlightedSettingsLeaf;
    _notifyChanged();
  }

  void updateSettingsSearchQuery(String value) {
    if (_settingsSearchQuery == value) {
      return;
    }
    _settingsSearchQuery = value;
    _highlightedSettingsLeaf = null;
    _notifyChanged();
  }

  void clearSettingsSearch() {
    if (_settingsSearchQuery.isEmpty && _highlightedSettingsLeaf == null) {
      return;
    }
    _settingsSearchQuery = '';
    _highlightedSettingsLeaf = null;
    _notifyChanged();
  }

  void openSettingsLeaf({
    required SettingsPanel panel,
    required String leafLabel,
  }) {
    _route = ShellRoute.settings;
    _settingsPanel = panel;
    _settingsSearchQuery = leafLabel;
    _highlightedSettingsLeaf = leafLabel;
    _notifyChanged();
  }

  Future<void> toggleFavoriteMediaKey(String contentKey) async {
    _personalizationRuntime = await _personalizationCoordinator
        .toggleFavoriteMediaKey(
          snapshot: _personalizationRuntime,
          contentKey: contentKey,
        );
    _setPersonalizationRuntime(_personalizationRuntime);
    if (_isDisposed()) {
      return;
    }
    _notifyChanged();
  }

  Future<void> _updateStartupRoute(ShellRoute route) async {
    _personalizationRuntime = await _personalizationCoordinator
        .updateStartupRoute(snapshot: _personalizationRuntime, route: route);
    _setPersonalizationRuntime(_personalizationRuntime);
    if (_isDisposed()) {
      return;
    }
  }

  static String sourcesLeafLabel(int index) => 'source:$index';

  static ShellRoute _resolveShellStartupRoute(
    PersonalizationRuntimeSnapshot personalization,
    ShellContractSupport contract,
    SourceRegistrySnapshot? sourceRegistry,
  ) {
    if (sourceRegistry == null || sourceRegistry.configuredProviders.isEmpty) {
      return ShellRoute.settings;
    }
    for (final ShellRoute route in contract.topLevelRoutes) {
      if (route.label == personalization.startupRoute) {
        return route;
      }
    }
    return contract.startupRoute;
  }
}
