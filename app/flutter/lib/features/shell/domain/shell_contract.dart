import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

class ShellContract {
  const ShellContract({
    required this.startupRoute,
    required this.topLevelRoutes,
    required this.settingsGroups,
    required this.liveTvPanels,
    required this.liveTvGroups,
    required this.mediaPanels,
    required this.mediaScopes,
    required this.homeQuickAccess,
    required this.sourceWizardSteps,
  });

  factory ShellContract.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('shell contract must be a JSON object');
    }
    return ShellContract.fromJson(decoded);
  }

  factory ShellContract.fromJson(Map<String, dynamic> json) {
    return ShellContract(
      startupRoute: _readString(json, 'startup_route'),
      topLevelRoutes: _readStringList(json, 'top_level_routes'),
      settingsGroups: _readStringList(json, 'settings_groups'),
      liveTvPanels: _readStringList(json, 'live_tv_panels'),
      liveTvGroups: _readStringList(json, 'live_tv_groups'),
      mediaPanels: _readStringList(json, 'media_panels'),
      mediaScopes: _readStringList(json, 'media_scopes'),
      homeQuickAccess: _readStringList(json, 'home_quick_access'),
      sourceWizardSteps: _readStringList(json, 'source_wizard_steps'),
    );
  }

  final String startupRoute;
  final List<String> topLevelRoutes;
  final List<String> settingsGroups;
  final List<String> liveTvPanels;
  final List<String> liveTvGroups;
  final List<String> mediaPanels;
  final List<String> mediaScopes;
  final List<String> homeQuickAccess;
  final List<String> sourceWizardSteps;
}

class ShellContractSupport {
  const ShellContractSupport._({
    required this.startupRoute,
    required this.topLevelRoutes,
    required this.settingsPanels,
    required this.liveTvPanels,
    required this.liveTvGroups,
    required this.mediaPanels,
    required this.mediaScopes,
    required this.homeQuickAccess,
    required this.sourceWizardSteps,
  });

  factory ShellContractSupport.fromContract(ShellContract contract) {
    final List<ShellRoute> topLevelRoutes = _mapLabels(
      labels: contract.topLevelRoutes,
      values: ShellRoute.values,
      labelOf: (ShellRoute route) => route.label,
      fieldName: 'top_level_routes',
    );
    final ShellRoute startupRoute = _mapLabel(
      label: contract.startupRoute,
      values: ShellRoute.values,
      labelOf: (ShellRoute route) => route.label,
      fieldName: 'startup_route',
    );
    final List<SettingsPanel> settingsPanels = _mapLabels(
      labels: contract.settingsGroups,
      values: SettingsPanel.values,
      labelOf: (SettingsPanel panel) => panel.label,
      fieldName: 'settings_groups',
    );
    final List<LiveTvPanel> liveTvPanels = _mapLabels(
      labels: contract.liveTvPanels,
      values: LiveTvPanel.values,
      labelOf: (LiveTvPanel panel) => panel.label,
      fieldName: 'live_tv_panels',
    );
    final List<LiveTvGroup> liveTvGroups = _mapLabels(
      labels: contract.liveTvGroups,
      values: LiveTvGroup.values,
      labelOf: (LiveTvGroup group) => group.label,
      fieldName: 'live_tv_groups',
    );
    final List<MediaPanel> mediaPanels = _mapLabels(
      labels: contract.mediaPanels,
      values: MediaPanel.values,
      labelOf: (MediaPanel panel) => panel.label,
      fieldName: 'media_panels',
    );
    final List<MediaScope> mediaScopes = _mapLabels(
      labels: contract.mediaScopes,
      values: MediaScope.values,
      labelOf: (MediaScope scope) => scope.label,
      fieldName: 'media_scopes',
    );
    final List<SourceWizardStep> sourceWizardSteps = _mapLabels(
      labels: contract.sourceWizardSteps,
      values: SourceWizardStep.values,
      labelOf: (SourceWizardStep step) => step.label,
      fieldName: 'source_wizard_steps',
    );

    if (topLevelRoutes.contains(ShellRoute.settings)) {
      final List<ShellRoute> mainDomainRoutes = topLevelRoutes
          .where((ShellRoute route) => route != ShellRoute.settings)
          .toList(growable: false);
      return ShellContractSupport._(
        startupRoute: startupRoute,
        topLevelRoutes: mainDomainRoutes,
        settingsPanels: settingsPanels,
        liveTvPanels: liveTvPanels,
        liveTvGroups: liveTvGroups,
        mediaPanels: mediaPanels,
        mediaScopes: mediaScopes,
        homeQuickAccess: List<String>.unmodifiable(contract.homeQuickAccess),
        sourceWizardSteps: sourceWizardSteps,
      );
    }

    throw const FormatException(
      'top_level_routes must include Settings for the utility cluster',
    );
  }

  final ShellRoute startupRoute;
  final List<ShellRoute> topLevelRoutes;
  final List<SettingsPanel> settingsPanels;
  final List<LiveTvPanel> liveTvPanels;
  final List<LiveTvGroup> liveTvGroups;
  final List<MediaPanel> mediaPanels;
  final List<MediaScope> mediaScopes;
  final List<String> homeQuickAccess;
  final List<SourceWizardStep> sourceWizardSteps;
}

T _mapLabel<T>({
  required String label,
  required List<T> values,
  required String Function(T value) labelOf,
  required String fieldName,
}) {
  for (final T value in values) {
    if (labelOf(value) == label) {
      return value;
    }
  }
  throw FormatException('unknown label "$label" in $fieldName');
}

List<T> _mapLabels<T>({
  required List<String> labels,
  required List<T> values,
  required String Function(T value) labelOf,
  required String fieldName,
}) {
  return List<T>.unmodifiable(
    labels
        .map(
          (String label) => _mapLabel(
            label: label,
            values: values,
            labelOf: labelOf,
            fieldName: fieldName,
          ),
        )
        .toList(growable: false),
  );
}

String _readString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-empty string');
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  final List<String> items = value
      .map((Object? item) {
        if (item is! String || item.isEmpty) {
          throw FormatException('$key must contain only non-empty strings');
        }
        return item;
      })
      .toList(growable: false);
  return List<String>.unmodifiable(items);
}
