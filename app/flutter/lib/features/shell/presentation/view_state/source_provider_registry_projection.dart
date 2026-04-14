part of 'source_provider_registry.dart';

SourceProviderRegistry sourceProviderRegistryFromSnapshot(
  SourceRegistrySnapshot? sourceRegistry,
) {
  if (sourceRegistry == null ||
      sourceRegistry.providerTypes.isEmpty ||
      sourceRegistry.wizardSteps.isEmpty) {
    return const SourceProviderRegistry.empty();
  }
  return SourceProviderRegistry(
    title: sourceRegistry.title,
    providerTypes: List<SourceProviderEntry>.unmodifiable(
      sourceRegistry.providerTypes
          .asMap()
          .entries
          .map((MapEntry<int, raw.SourceProviderEntry> entry) {
            return sourceProviderEntryFromRuntimeProvider(
              index: entry.key,
              provider: entry.value,
              providerCopy: sourceRegistry.copyFor(entry.value.kind),
            );
          })
          .toList(growable: false),
    ),
    configuredProviders: List<SourceProviderEntry>.unmodifiable(
      sourceRegistry.configuredProviders
          .asMap()
          .entries
          .map((MapEntry<int, raw.SourceProviderEntry> entry) {
            return sourceProviderEntryFromRuntimeProvider(
              index: entry.key,
              provider: entry.value,
              providerCopy: sourceRegistry.copyFor(entry.value.kind),
            );
          })
          .toList(growable: false),
    ),
    selectedProviderKind: sourceProviderKindFromRuntime(
      sourceRegistry.selectedProviderKind,
    ),
    wizardSteps: List<SourceWizardStepContent>.unmodifiable(
      sourceRegistry.wizardSteps
          .map((raw.SourceWizardStepDescriptor step) {
            return SourceWizardStepContent(
              step: step.step,
              title: step.title,
              summary: step.summary,
              primaryAction: step.primaryAction,
              secondaryAction: step.secondaryAction,
              fieldLabels: step.fieldLabels,
              helperLines: step.helperLines,
            );
          })
          .toList(growable: false),
    ),
  );
}

SourceProviderEntry sourceProviderEntryFromRuntimeProvider({
  required int index,
  required raw.SourceProviderEntry provider,
  required raw.SourceProviderWizardCopy? providerCopy,
}) {
  return SourceProviderEntry(
    index: index,
    name: provider.displayName,
    summary: providerCopy?.summary ?? provider.summary,
    providerKind: sourceProviderKindFromRuntime(provider.kind),
    healthState: sourceHealthStateFromStatus(provider.status.healthStatus),
    authState: sourceAuthStateFromStatus(provider.status.authStatus),
    importState: sourceImportStateFromStatus(provider.status.importStatus),
    sourceTypeLabel: provider.family,
    endpointLabel: provider.endpointLabel,
    lastSyncLabel: provider.status.lastSync,
    capabilities: provider.capabilities
        .where((raw.SourceCapabilitySupport item) => item.supported)
        .map(SourceCapabilityDescriptor.fromRuntime)
        .toList(growable: false),
    primaryActionLabel: provider.auth.primaryAction,
    secondaryActionLabel: provider.importDetails.primaryAction,
  );
}

SourceHealthState sourceHealthStateFromStatus(raw.SourceWorkflowState status) {
  return switch (status) {
    raw.SourceWorkflowState.healthy ||
    raw.SourceWorkflowState.ready ||
    raw.SourceWorkflowState.complete => SourceHealthState.healthy,
    raw.SourceWorkflowState.needsAuth ||
    raw.SourceWorkflowState.reauthRequired => SourceHealthState.needsAuth,
    raw.SourceWorkflowState.failed ||
    raw.SourceWorkflowState.degraded ||
    raw.SourceWorkflowState.needsAttention => SourceHealthState.degraded,
    _ => SourceHealthState.unknown,
  };
}

SourceProviderKind sourceProviderKindFromRuntime(raw.SourceProviderKind kind) {
  return switch (kind) {
    raw.SourceProviderKind.m3uUrl => SourceProviderKind.m3uUrl,
    raw.SourceProviderKind.localM3u => SourceProviderKind.localM3u,
    raw.SourceProviderKind.xtream => SourceProviderKind.xtream,
    raw.SourceProviderKind.stalker => SourceProviderKind.stalker,
  };
}

SourceAuthState sourceAuthStateFromStatus(raw.SourceWorkflowState state) {
  return switch (state) {
    raw.SourceWorkflowState.healthy ||
    raw.SourceWorkflowState.ready ||
    raw.SourceWorkflowState.complete ||
    raw.SourceWorkflowState.notRequired => SourceAuthState.connected,
    raw.SourceWorkflowState.needsAuth ||
    raw.SourceWorkflowState.reauthRequired => SourceAuthState.needsAuth,
    raw.SourceWorkflowState.syncing ||
    raw.SourceWorkflowState.importing ||
    raw.SourceWorkflowState.degraded ||
    raw.SourceWorkflowState.needsAttention => SourceAuthState.reconnecting,
    _ => SourceAuthState.unknown,
  };
}

SourceImportState sourceImportStateFromStatus(raw.SourceWorkflowState state) {
  return switch (state) {
    raw.SourceWorkflowState.ready ||
    raw.SourceWorkflowState.complete => SourceImportState.ready,
    raw.SourceWorkflowState.syncing ||
    raw.SourceWorkflowState.importing ||
    raw.SourceWorkflowState.degraded ||
    raw.SourceWorkflowState.idle => SourceImportState.pending,
    raw.SourceWorkflowState.blocked ||
    raw.SourceWorkflowState.needsAuth ||
    raw.SourceWorkflowState.reauthRequired ||
    raw.SourceWorkflowState.failed => SourceImportState.blocked,
    _ => SourceImportState.unknown,
  };
}

SourceCapabilityKind sourceCapabilityKindFromRuntime(
  raw.SourceCapability capability,
) {
  return switch (capability) {
    raw.SourceCapability.live => SourceCapabilityKind.liveTv,
    raw.SourceCapability.guide => SourceCapabilityKind.guide,
    raw.SourceCapability.catchup => SourceCapabilityKind.catchup,
    raw.SourceCapability.archive => SourceCapabilityKind.archive,
    raw.SourceCapability.movies => SourceCapabilityKind.movies,
    raw.SourceCapability.series => SourceCapabilityKind.series,
    _ => SourceCapabilityKind.other,
  };
}
