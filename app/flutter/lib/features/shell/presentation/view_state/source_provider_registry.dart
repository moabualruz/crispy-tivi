import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry.dart' as raw;
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';

part 'source_provider_registry_projection.dart';

final class SourceProviderRegistry {
  const SourceProviderRegistry({
    required this.title,
    required this.providerTypes,
    required this.configuredProviders,
    required this.selectedProviderKind,
    required this.wizardSteps,
  });

  const SourceProviderRegistry.empty()
    : title = 'Source registry',
      providerTypes = const <SourceProviderEntry>[],
      configuredProviders = const <SourceProviderEntry>[],
      selectedProviderKind = SourceProviderKind.m3uUrl,
      wizardSteps = const <SourceWizardStepContent>[];

  factory SourceProviderRegistry.fromSnapshot(
    SourceRegistrySnapshot? sourceRegistry,
  ) => sourceProviderRegistryFromSnapshot(sourceRegistry);

  final String title;
  final List<SourceProviderEntry> providerTypes;
  final List<SourceProviderEntry> configuredProviders;
  final SourceProviderKind selectedProviderKind;
  final List<SourceWizardStepContent> wizardSteps;

  List<SourceProviderEntry> get providers => configuredProviders;

  SourceProviderEntry configuredProviderAt(int index) =>
      configuredProviders[index];

  SourceProviderEntry providerTypeAt(int index) => providerTypes[index];

  SourceProviderEntry providerType(SourceProviderKind kind) {
    return providerTypes.firstWhere(
      (SourceProviderEntry item) => item.providerKind == kind,
      orElse: () => providerTypes.first,
    );
  }

  SourceWizardStepContent wizardStep(SourceWizardStep step) {
    return wizardSteps.firstWhere(
      (SourceWizardStepContent item) => item.step == step,
      orElse:
          () =>
              throw StateError('missing source wizard step content for $step'),
    );
  }
}

final class SourceProviderEntry {
  const SourceProviderEntry({
    required this.index,
    required this.name,
    required this.summary,
    required this.providerKind,
    required this.healthState,
    required this.authState,
    required this.importState,
    required this.sourceTypeLabel,
    required this.endpointLabel,
    required this.lastSyncLabel,
    required this.capabilities,
    required this.primaryActionLabel,
    required this.secondaryActionLabel,
  });

  SourceProviderEntry copyWith({
    int? index,
    String? name,
    String? summary,
    SourceProviderKind? providerKind,
    SourceHealthState? healthState,
    SourceAuthState? authState,
    SourceImportState? importState,
    String? sourceTypeLabel,
    String? endpointLabel,
    String? lastSyncLabel,
    List<SourceCapabilityDescriptor>? capabilities,
    String? primaryActionLabel,
    String? secondaryActionLabel,
  }) {
    return SourceProviderEntry(
      index: index ?? this.index,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      providerKind: providerKind ?? this.providerKind,
      healthState: healthState ?? this.healthState,
      authState: authState ?? this.authState,
      importState: importState ?? this.importState,
      sourceTypeLabel: sourceTypeLabel ?? this.sourceTypeLabel,
      endpointLabel: endpointLabel ?? this.endpointLabel,
      lastSyncLabel: lastSyncLabel ?? this.lastSyncLabel,
      capabilities: capabilities ?? this.capabilities,
      primaryActionLabel: primaryActionLabel ?? this.primaryActionLabel,
      secondaryActionLabel: secondaryActionLabel ?? this.secondaryActionLabel,
    );
  }

  factory SourceProviderEntry.fromRuntimeProvider({
    required int index,
    required raw.SourceProviderEntry provider,
    required raw.SourceProviderWizardCopy? providerCopy,
  }) => sourceProviderEntryFromRuntimeProvider(
    index: index,
    provider: provider,
    providerCopy: providerCopy,
  );

  final int index;
  final String name;
  final String summary;
  final SourceProviderKind providerKind;
  final SourceHealthState healthState;
  final SourceAuthState authState;
  final SourceImportState importState;
  final String sourceTypeLabel;
  final String endpointLabel;
  final String lastSyncLabel;
  final List<SourceCapabilityDescriptor> capabilities;
  final String primaryActionLabel;
  final String secondaryActionLabel;
}

enum SourceProviderKind { m3uUrl, localM3u, xtream, stalker }

extension SourceProviderKindLabel on SourceProviderKind {
  String get label {
    return switch (this) {
      SourceProviderKind.m3uUrl => 'M3U URL',
      SourceProviderKind.localM3u => 'local M3U',
      SourceProviderKind.xtream => 'Xtream',
      SourceProviderKind.stalker => 'Stalker',
    };
  }
}

enum SourceHealthState { healthy, degraded, needsAuth, unknown }

extension SourceHealthStateLabel on SourceHealthState {
  String get label {
    return switch (this) {
      SourceHealthState.healthy => 'Healthy',
      SourceHealthState.degraded => 'Degraded',
      SourceHealthState.needsAuth => 'Needs auth',
      SourceHealthState.unknown => 'Unknown',
    };
  }
}

enum SourceAuthState { connected, needsAuth, reconnecting, unknown }

extension SourceAuthStateLabel on SourceAuthState {
  String get label {
    return switch (this) {
      SourceAuthState.connected => 'Connected',
      SourceAuthState.needsAuth => 'Needs auth',
      SourceAuthState.reconnecting => 'Reconnecting',
      SourceAuthState.unknown => 'Unknown',
    };
  }
}

enum SourceImportState { ready, pending, blocked, unknown }

extension SourceImportStateLabel on SourceImportState {
  String get label {
    return switch (this) {
      SourceImportState.ready => 'Ready',
      SourceImportState.pending => 'Pending',
      SourceImportState.blocked => 'Blocked',
      SourceImportState.unknown => 'Unknown',
    };
  }
}

enum SourceCapabilityKind {
  liveTv,
  guide,
  catchup,
  archive,
  movies,
  series,
  other,
}

final class SourceCapabilityDescriptor {
  const SourceCapabilityDescriptor({required this.kind, required this.label});

  factory SourceCapabilityDescriptor.fromRuntime(
    raw.SourceCapabilitySupport capability,
  ) {
    return SourceCapabilityDescriptor(
      kind: sourceCapabilityKindFromRuntime(capability.capability),
      label: capability.title,
    );
  }

  final SourceCapabilityKind kind;
  final String label;
}

extension SourceCapabilityKindLabel on SourceCapabilityKind {
  String get label {
    return switch (this) {
      SourceCapabilityKind.liveTv => 'Live TV',
      SourceCapabilityKind.guide => 'Guide',
      SourceCapabilityKind.catchup => 'Catch-up',
      SourceCapabilityKind.archive => 'Archive',
      SourceCapabilityKind.movies => 'Movies',
      SourceCapabilityKind.series => 'Series',
      SourceCapabilityKind.other => 'Other',
    };
  }
}
