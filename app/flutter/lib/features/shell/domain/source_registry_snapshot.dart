import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart';

final class SourceRegistrySnapshot {
  const SourceRegistrySnapshot({
    required this.title,
    required this.version,
    required this.selectedProviderKind,
    required this.activeWizardStep,
    required this.wizardActive,
    required this.wizardMode,
    required this.selectedSourceIndex,
    required this.fieldValues,
    required this.providerTypes,
    required this.configuredProviders,
    required this.wizardSteps,
    required this.providerCopy,
    required this.registryNotes,
  });

  const SourceRegistrySnapshot.empty()
    : title = 'Source registry',
      version = '0',
      selectedProviderKind = SourceProviderKind.m3uUrl,
      activeWizardStep = SourceWizardStep.sourceType,
      wizardActive = true,
      wizardMode = 'add',
      selectedSourceIndex = 0,
      fieldValues = const <String, String>{},
      providerTypes = const <SourceProviderEntry>[],
      configuredProviders = const <SourceProviderEntry>[],
      wizardSteps = const <SourceWizardStepDescriptor>[],
      providerCopy = const <SourceProviderWizardCopy>[],
      registryNotes = const <String>[];

  factory SourceRegistrySnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('source registry must be a JSON object');
    }
    return SourceRegistrySnapshot.fromJson(decoded);
  }

  factory SourceRegistrySnapshot.fromJson(Map<String, dynamic> json) {
    final List<SourceProviderEntry> providerTypes = _readProviders(
      json,
      'provider_types',
    );
    final Map<String, dynamic> onboarding = _readObject(json, 'onboarding');
    final SourceProviderKind selectedProviderKind = _readProviderKind(
      onboarding,
      'selected_provider_type',
    );
    if (providerTypes.isNotEmpty &&
        !providerTypes.any(
          (SourceProviderEntry provider) =>
              provider.kind == selectedProviderKind,
        )) {
      throw const FormatException(
        'selected onboarding provider must exist in provider_types',
      );
    }
    final List<SourceWizardStepDescriptor> wizardSteps = _readWizardSteps(
      onboarding,
      'steps',
    );
    final SourceWizardStep activeWizardStep = _readWizardStep(
      onboarding,
      'active_step',
    );
    if (wizardSteps.isNotEmpty &&
        !wizardSteps.any(
          (SourceWizardStepDescriptor item) => item.step == activeWizardStep,
        )) {
      throw const FormatException(
        'active onboarding step must exist in onboarding steps',
      );
    }
    return SourceRegistrySnapshot(
      title: _readString(json, 'title'),
      version: _readString(json, 'version'),
      selectedProviderKind: selectedProviderKind,
      activeWizardStep: activeWizardStep,
      wizardActive:
          _readOptionalBool(onboarding, 'wizard_active') ??
          _readConfiguredProviders(
            json,
            'configured_providers',
            fallbackProviderTypes: providerTypes,
          ).isEmpty,
      wizardMode: _readOptionalString(onboarding, 'wizard_mode') ?? 'idle',
      selectedSourceIndex:
          _readOptionalInt(onboarding, 'selected_source_index') ?? 0,
      fieldValues: _readOptionalStringMap(onboarding, 'field_values'),
      providerTypes: providerTypes,
      configuredProviders: _readConfiguredProviders(
        json,
        'configured_providers',
        fallbackProviderTypes: providerTypes,
      ),
      wizardSteps: wizardSteps,
      providerCopy: _readProviderCopy(onboarding, 'provider_copy'),
      registryNotes: _readOptionalStringList(json, 'registry_notes'),
    );
  }

  final String title;
  final String version;
  final SourceProviderKind selectedProviderKind;
  final SourceWizardStep activeWizardStep;
  final bool wizardActive;
  final String wizardMode;
  final int selectedSourceIndex;
  final Map<String, String> fieldValues;
  final List<SourceProviderEntry> providerTypes;
  final List<SourceProviderEntry> configuredProviders;
  final List<SourceWizardStepDescriptor> wizardSteps;
  final List<SourceProviderWizardCopy> providerCopy;
  final List<String> registryNotes;

  SourceProviderEntry get selectedProviderType =>
      providerType(selectedProviderKind);

  List<SourceProviderEntry> get providers => configuredProviders;

  SourceProviderEntry get selectedProvider => selectedProviderType;

  int get selectedProviderIndex {
    return providerTypes.indexWhere(
      (SourceProviderEntry provider) => provider.kind == selectedProviderKind,
    );
  }

  SourceProviderEntry providerType(SourceProviderKind kind) {
    return providerTypes.firstWhere(
      (SourceProviderEntry provider) => provider.kind == kind,
      orElse: () => throw StateError('missing source provider $kind'),
    );
  }

  SourceProviderEntry provider(SourceProviderKind kind) => providerType(kind);

  SourceProviderWizardCopy? copyFor(SourceProviderKind kind) {
    for (final SourceProviderWizardCopy item in providerCopy) {
      if (item.kind == kind) {
        return item;
      }
    }
    return null;
  }

  List<SourceProviderEntry> providersSupporting(SourceCapability capability) {
    return List<SourceProviderEntry>.unmodifiable(
      providerTypes
          .where(
            (SourceProviderEntry provider) => provider.supports(capability),
          )
          .toList(growable: false),
    );
  }

  SourceRegistrySnapshot copyWith({
    SourceProviderKind? selectedProviderKind,
    SourceWizardStep? activeWizardStep,
    List<SourceProviderEntry>? providerTypes,
    List<SourceProviderEntry>? configuredProviders,
  }) {
    return SourceRegistrySnapshot(
      title: title,
      version: version,
      selectedProviderKind: selectedProviderKind ?? this.selectedProviderKind,
      activeWizardStep: activeWizardStep ?? this.activeWizardStep,
      wizardActive: wizardActive,
      wizardMode: wizardMode,
      selectedSourceIndex: selectedSourceIndex,
      fieldValues: fieldValues,
      providerTypes: providerTypes ?? this.providerTypes,
      configuredProviders: configuredProviders ?? this.configuredProviders,
      wizardSteps: wizardSteps,
      providerCopy: providerCopy,
      registryNotes: registryNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'version': version,
      'provider_types': providerTypes
          .map((SourceProviderEntry provider) => provider.toJson())
          .toList(growable: false),
      'configured_providers': configuredProviders
          .map((SourceProviderEntry provider) => provider.toJson())
          .toList(growable: false),
      'onboarding': <String, dynamic>{
        'selected_provider_type': selectedProviderKind.label,
        'active_step': activeWizardStep.label,
        'wizard_active': wizardActive,
        'wizard_mode': wizardMode,
        'selected_source_index': selectedSourceIndex,
        'field_values': fieldValues,
        'step_order': wizardSteps
            .map((SourceWizardStepDescriptor step) => step.step.label)
            .toList(growable: false),
        'steps': wizardSteps
            .map((SourceWizardStepDescriptor step) => step.toJson())
            .toList(growable: false),
        'provider_copy': providerCopy
            .map((SourceProviderWizardCopy copy) => copy.toJson())
            .toList(growable: false),
      },
      'registry_notes': registryNotes,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

List<SourceProviderEntry> _readProviders(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  if (value.isEmpty) {
    return const <SourceProviderEntry>[];
  }
  final Set<SourceProviderKind> seenKinds = <SourceProviderKind>{};
  final List<SourceProviderEntry> providers = value
      .map<SourceProviderEntry>((Object? item) {
        if (item is! Map<String, dynamic>) {
          throw FormatException('$key must contain only objects');
        }
        final SourceProviderKind kind = _readProviderKind(item, 'provider_type');
        if (!seenKinds.add(kind)) {
          throw FormatException(
            '$key must not contain duplicate provider types',
          );
        }
        return _readProviderEntry(item);
      })
      .toList(growable: false);
  return List<SourceProviderEntry>.unmodifiable(providers);
}

List<SourceProviderEntry> _readConfiguredProviders(
  Map<String, dynamic> json,
  String key, {
  required List<SourceProviderEntry> fallbackProviderTypes,
}) {
  final Object? value = json[key];
  if (value == null) {
    return fallbackProviderTypes;
  }
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  if (value.isEmpty) {
    return const <SourceProviderEntry>[];
  }
  return List<SourceProviderEntry>.unmodifiable(
    value.map((Object? item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$key must contain only objects');
      }
      return _readProviderEntry(item);
    }).toList(growable: false),
  );
}

SourceProviderEntry _readProviderEntry(Map<String, dynamic> item) {
  final SourceProviderKind kind = _readProviderKind(item, 'provider_type');
  final Map<String, dynamic> health = _readObject(item, 'health');
  final Map<String, dynamic> auth = _readObject(item, 'auth');
  final Map<String, dynamic> import = _readObject(item, 'import');
  return SourceProviderEntry(
    kind: kind,
    providerKey: _readString(item, 'provider_key'),
    displayName:
        item['display_name'] is String &&
                (item['display_name'] as String).trim().isNotEmpty
            ? item['display_name'] as String
            : _readString(item, 'provider_type'),
    family: _readString(item, 'family'),
    connectionMode: _readString(item, 'connection_mode'),
    summary: _readString(item, 'summary'),
    endpointLabel:
        item['endpoint_label'] is String &&
                (item['endpoint_label'] as String).trim().isNotEmpty
            ? item['endpoint_label'] as String
            : _endpointLabelFor(kind, auth),
    capabilities: _readCapabilities(item, 'capabilities'),
    status: SourceProviderStatus(
      healthStatus: _readWorkflowState(health, 'status'),
      authStatus: _readWorkflowState(auth, 'status'),
      importStatus: _readWorkflowState(import, 'status'),
      refreshStatus: _refreshStatusFor(health, import),
      healthSummary: _readString(health, 'summary'),
      lastChecked: _readString(health, 'last_checked'),
      lastSync: _readString(health, 'last_sync'),
      errorTitle: _errorTitleFor(health, auth, import),
      errorSummary: _errorSummaryFor(health, auth, import),
    ),
    auth: SourceAuthDetails(
      status: _readWorkflowState(auth, 'status'),
      progress: _readString(auth, 'progress'),
      summary: _readString(auth, 'summary'),
      primaryAction: _readString(auth, 'primary_action'),
      secondaryAction: _readString(auth, 'secondary_action'),
      fieldLabels: _readStringList(auth, 'field_labels'),
      helperLines: _readStringList(auth, 'helper_lines'),
    ),
    importDetails: SourceImportDetails(
      status: _readWorkflowState(import, 'status'),
      progress: _readString(import, 'progress'),
      summary: _readString(import, 'summary'),
      primaryAction: _readString(import, 'primary_action'),
      secondaryAction: _readString(import, 'secondary_action'),
    ),
    onboardingHint: _readString(item, 'onboarding_hint'),
    runtimeConfig: _readOptionalStringMap(item, 'runtime_config'),
  );
}

List<SourceCapabilitySupport> _readCapabilities(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw FormatException('$key must be a non-empty array');
  }
  return List<SourceCapabilitySupport>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SourceCapabilitySupport(
            capability: _readCapability(item, 'id'),
            title: _readString(item, 'title'),
            summary: _readString(item, 'summary'),
            supported: _readBool(item, 'supported'),
          );
        })
        .toList(growable: false),
  );
}

List<SourceWizardStepDescriptor> _readWizardSteps(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  if (value.isEmpty) {
    return const <SourceWizardStepDescriptor>[];
  }
  return List<SourceWizardStepDescriptor>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SourceWizardStepDescriptor(
            step: _readWizardStep(item, 'step'),
            title: _readString(item, 'title'),
            summary: _readString(item, 'summary'),
            primaryAction: _readString(item, 'primary_action'),
            secondaryAction: _readString(item, 'secondary_action'),
            fieldLabels: _readStringList(item, 'field_labels'),
            helperLines: _readStringList(item, 'helper_lines'),
          );
        })
        .toList(growable: false),
  );
}

List<SourceProviderWizardCopy> _readProviderCopy(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  return List<SourceProviderWizardCopy>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! Map<String, dynamic>) {
            throw FormatException('$key must contain only objects');
          }
          return SourceProviderWizardCopy(
            kind: _readProviderKind(item, 'provider_type'),
            title: _readString(item, 'title'),
            summary: _readString(item, 'summary'),
            helperLines: _readStringList(item, 'helper_lines'),
          );
        })
        .toList(growable: false),
  );
}

SourceProviderKind _readProviderKind(Map<String, dynamic> json, String key) {
  final String label = _readString(json, key);
  return _mapLabel(
    label: label,
    values: SourceProviderKind.values,
    labelOf: (SourceProviderKind kind) => kind.label,
    fieldName: key,
  );
}

SourceCapability _readCapability(Map<String, dynamic> json, String key) {
  final String id = _readString(json, key);
  return switch (id) {
    'live_tv' => SourceCapability.live,
    'guide' => SourceCapability.guide,
    'movies' => SourceCapability.movies,
    'series' => SourceCapability.series,
    'catch_up' => SourceCapability.catchup,
    'archive_playback' => SourceCapability.archive,
    'search' => SourceCapability.search,
    'subtitles' => SourceCapability.subtitles,
    'tracks' => SourceCapability.tracks,
    'local_playlist' => SourceCapability.localPlaylist,
    _ => throw FormatException('unknown capability id "$id"'),
  };
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a string when present');
  }
  return value;
}

bool? _readOptionalBool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw FormatException('$key must be a bool when present');
  }
  return value;
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('$key must be an int when present');
  }
  return value;
}

Map<String, String> _readOptionalStringMap(
  Map<String, dynamic> json,
  String key,
) {
  final Object? value = json[key];
  if (value == null) {
    return const <String, String>{};
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object when present');
  }
  return Map<String, String>.unmodifiable(
    value.map((Object? mapKey, Object? mapValue) {
      if (mapKey is! String || mapValue is! String) {
        throw FormatException('$key must contain only string pairs');
      }
      return MapEntry<String, String>(mapKey, mapValue);
    }),
  );
}

SourceWizardStep _readWizardStep(Map<String, dynamic> json, String key) {
  final String label = _readString(json, key);
  return _mapLabel(
    label: label,
    values: SourceWizardStep.values,
    labelOf: (SourceWizardStep step) => step.label,
    fieldName: key,
  );
}

SourceWorkflowState _readWorkflowState(Map<String, dynamic> json, String key) {
  final String label = _readString(json, key);
  return _mapLabel(
    label: label,
    values: SourceWorkflowState.values,
    labelOf: (SourceWorkflowState state) => state.label,
    fieldName: key,
  );
}

Map<String, dynamic> _readObject(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$key must be an object');
}

String _readString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-empty string');
}

bool _readBool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean');
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  return List<String>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! String || item.isEmpty) {
            throw FormatException('$key must contain only non-empty strings');
          }
          return item;
        })
        .toList(growable: false),
  );
}

List<String> _readOptionalStringList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array when present');
  }
  return List<String>.unmodifiable(
    value
        .map((Object? item) {
          if (item is! String || item.isEmpty) {
            throw FormatException('$key must contain only non-empty strings');
          }
          return item;
        })
        .toList(growable: false),
  );
}

String _endpointLabelFor(SourceProviderKind kind, Map<String, dynamic> auth) {
  final List<String> fields = _readStringList(auth, 'field_labels');
  if (fields.isEmpty) {
    return kind.label;
  }
  return fields.join(' • ');
}

SourceWorkflowState _refreshStatusFor(
  Map<String, dynamic> health,
  Map<String, dynamic> import,
) {
  final SourceWorkflowState healthStatus = _readWorkflowState(health, 'status');
  final SourceWorkflowState importStatus = _readWorkflowState(import, 'status');
  if (healthStatus == SourceWorkflowState.healthy ||
      healthStatus == SourceWorkflowState.complete) {
    return SourceWorkflowState.ready;
  }
  if (healthStatus == SourceWorkflowState.needsAuth ||
      importStatus == SourceWorkflowState.blocked) {
    return SourceWorkflowState.failed;
  }
  if (importStatus == SourceWorkflowState.ready ||
      importStatus == SourceWorkflowState.complete) {
    return SourceWorkflowState.ready;
  }
  return healthStatus;
}

String? _errorTitleFor(
  Map<String, dynamic> health,
  Map<String, dynamic> auth,
  Map<String, dynamic> import,
) {
  final SourceWorkflowState healthStatus = _readWorkflowState(health, 'status');
  final SourceWorkflowState authStatus = _readWorkflowState(auth, 'status');
  final SourceWorkflowState importStatus = _readWorkflowState(import, 'status');
  if (authStatus == SourceWorkflowState.needsAuth) {
    return 'Auth required';
  }
  if (healthStatus == SourceWorkflowState.failed ||
      importStatus == SourceWorkflowState.failed) {
    return 'Source requires attention';
  }
  return null;
}

String? _errorSummaryFor(
  Map<String, dynamic> health,
  Map<String, dynamic> auth,
  Map<String, dynamic> import,
) {
  final SourceWorkflowState authStatus = _readWorkflowState(auth, 'status');
  final SourceWorkflowState healthStatus = _readWorkflowState(health, 'status');
  final SourceWorkflowState importStatus = _readWorkflowState(import, 'status');
  if (authStatus == SourceWorkflowState.needsAuth) {
    return _readString(auth, 'summary');
  }
  if (healthStatus == SourceWorkflowState.failed) {
    return _readString(health, 'summary');
  }
  if (importStatus == SourceWorkflowState.failed ||
      importStatus == SourceWorkflowState.blocked) {
    return _readString(import, 'summary');
  }
  return null;
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
