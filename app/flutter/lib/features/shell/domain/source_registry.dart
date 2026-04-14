import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

enum SourceProviderKind {
  m3uUrl('M3U URL'),
  localM3u('local M3U'),
  xtream('Xtream'),
  stalker('Stalker');

  const SourceProviderKind(this.label);

  final String label;
}

enum SourceCapability {
  live('Live TV'),
  guide('Guide'),
  movies('Movies'),
  series('Series'),
  catchup('Catch-up'),
  archive('Archive playback'),
  search('Search'),
  subtitles('Subtitles'),
  tracks('Tracks'),
  localPlaylist('Local file');

  const SourceCapability(this.label);

  final String label;
}

enum SourceWorkflowState {
  idle('Idle'),
  ready('Ready'),
  syncing('Syncing'),
  degraded('Degraded'),
  needsAttention('Needs attention'),
  importing('Importing'),
  unavailable('Unavailable'),
  failed('Failed'),
  healthy('Healthy'),
  blocked('Blocked'),
  complete('Complete'),
  notRequired('Not required'),
  needsAuth('Needs auth'),
  reauthRequired('Reauth required');

  const SourceWorkflowState(this.label);

  final String label;
}

final class SourceCapabilitySupport {
  const SourceCapabilitySupport({
    required this.capability,
    required this.title,
    required this.summary,
    required this.supported,
  });

  final SourceCapability capability;
  final String title;
  final String summary;
  final bool supported;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': switch (capability) {
        SourceCapability.live => 'live_tv',
        SourceCapability.guide => 'guide',
        SourceCapability.movies => 'movies',
        SourceCapability.series => 'series',
        SourceCapability.catchup => 'catch_up',
        SourceCapability.archive => 'archive_playback',
        SourceCapability.search => 'search',
        SourceCapability.subtitles => 'subtitles',
        SourceCapability.tracks => 'tracks',
        SourceCapability.localPlaylist => 'local_playlist',
      },
      'title': title,
      'summary': summary,
      'supported': supported,
    };
  }
}

final class SourceProviderStatus {
  const SourceProviderStatus({
    required this.healthStatus,
    required this.authStatus,
    required this.importStatus,
    required this.refreshStatus,
    required this.healthSummary,
    required this.lastChecked,
    required this.lastSync,
    this.errorTitle,
    this.errorSummary,
  });

  final SourceWorkflowState healthStatus;
  final SourceWorkflowState authStatus;
  final SourceWorkflowState importStatus;
  final SourceWorkflowState refreshStatus;
  final String healthSummary;
  final String lastChecked;
  final String lastSync;
  final String? errorTitle;
  final String? errorSummary;

  bool get hasError => errorTitle != null || errorSummary != null;

  SourceProviderStatus copyWith({
    SourceWorkflowState? healthStatus,
    SourceWorkflowState? authStatus,
    SourceWorkflowState? importStatus,
    SourceWorkflowState? refreshStatus,
    String? healthSummary,
    String? lastChecked,
    String? lastSync,
    String? errorTitle,
    String? errorSummary,
  }) {
    return SourceProviderStatus(
      healthStatus: healthStatus ?? this.healthStatus,
      authStatus: authStatus ?? this.authStatus,
      importStatus: importStatus ?? this.importStatus,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      healthSummary: healthSummary ?? this.healthSummary,
      lastChecked: lastChecked ?? this.lastChecked,
      lastSync: lastSync ?? this.lastSync,
      errorTitle: errorTitle ?? this.errorTitle,
      errorSummary: errorSummary ?? this.errorSummary,
    );
  }

  Map<String, dynamic> healthJson() {
    return <String, dynamic>{
      'status': healthStatus.label,
      'summary': healthSummary,
      'last_checked': lastChecked,
      'last_sync': lastSync,
    };
  }
}

final class SourceAuthDetails {
  const SourceAuthDetails({
    required this.status,
    required this.progress,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
    required this.fieldLabels,
    required this.helperLines,
  });

  final SourceWorkflowState status;
  final String progress;
  final String summary;
  final String primaryAction;
  final String secondaryAction;
  final List<String> fieldLabels;
  final List<String> helperLines;

  SourceAuthDetails copyWith({
    SourceWorkflowState? status,
    String? progress,
    String? summary,
    String? primaryAction,
    String? secondaryAction,
    List<String>? fieldLabels,
    List<String>? helperLines,
  }) {
    return SourceAuthDetails(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      summary: summary ?? this.summary,
      primaryAction: primaryAction ?? this.primaryAction,
      secondaryAction: secondaryAction ?? this.secondaryAction,
      fieldLabels: fieldLabels ?? this.fieldLabels,
      helperLines: helperLines ?? this.helperLines,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status.label,
      'progress': progress,
      'summary': summary,
      'primary_action': primaryAction,
      'secondary_action': secondaryAction,
      'field_labels': fieldLabels,
      'helper_lines': helperLines,
    };
  }
}

final class SourceImportDetails {
  const SourceImportDetails({
    required this.status,
    required this.progress,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final SourceWorkflowState status;
  final String progress;
  final String summary;
  final String primaryAction;
  final String secondaryAction;

  SourceImportDetails copyWith({
    SourceWorkflowState? status,
    String? progress,
    String? summary,
    String? primaryAction,
    String? secondaryAction,
  }) {
    return SourceImportDetails(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      summary: summary ?? this.summary,
      primaryAction: primaryAction ?? this.primaryAction,
      secondaryAction: secondaryAction ?? this.secondaryAction,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status.label,
      'progress': progress,
      'summary': summary,
      'primary_action': primaryAction,
      'secondary_action': secondaryAction,
    };
  }
}

final class SourceProviderWizardCopy {
  const SourceProviderWizardCopy({
    required this.kind,
    required this.title,
    required this.summary,
    required this.helperLines,
  });

  final SourceProviderKind kind;
  final String title;
  final String summary;
  final List<String> helperLines;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'provider_key': kind.name,
      'provider_type': kind.label,
      'title': title,
      'summary': summary,
      'helper_lines': helperLines,
    };
  }
}

final class SourceWizardStepDescriptor {
  const SourceWizardStepDescriptor({
    required this.step,
    required this.title,
    required this.summary,
    required this.primaryAction,
    required this.secondaryAction,
    required this.fieldLabels,
    required this.helperLines,
  });

  final SourceWizardStep step;
  final String title;
  final String summary;
  final String primaryAction;
  final String secondaryAction;
  final List<String> fieldLabels;
  final List<String> helperLines;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'step': step.label,
      'title': title,
      'summary': summary,
      'primary_action': primaryAction,
      'secondary_action': secondaryAction,
      'field_labels': fieldLabels,
      'helper_lines': helperLines,
    };
  }
}

final class SourceProviderEntry {
  const SourceProviderEntry({
    required this.kind,
    required this.providerKey,
    required this.displayName,
    required this.family,
    required this.connectionMode,
    required this.summary,
    required this.endpointLabel,
    required this.capabilities,
    required this.status,
    required this.auth,
    required this.importDetails,
    required this.onboardingHint,
    required this.runtimeConfig,
  });

  final SourceProviderKind kind;
  final String providerKey;
  final String displayName;
  final String family;
  final String connectionMode;
  final String summary;
  final String endpointLabel;
  final List<SourceCapabilitySupport> capabilities;
  final SourceProviderStatus status;
  final SourceAuthDetails auth;
  final SourceImportDetails importDetails;
  final String onboardingHint;
  final Map<String, String> runtimeConfig;

  bool supports(SourceCapability capability) {
    return capabilities.any(
      (SourceCapabilitySupport item) =>
          item.capability == capability && item.supported,
    );
  }

  SourceProviderEntry copyWith({
    SourceProviderKind? kind,
    String? providerKey,
    String? displayName,
    String? family,
    String? connectionMode,
    String? summary,
    String? endpointLabel,
    List<SourceCapabilitySupport>? capabilities,
    SourceProviderStatus? status,
    SourceAuthDetails? auth,
    SourceImportDetails? importDetails,
    String? onboardingHint,
    Map<String, String>? runtimeConfig,
  }) {
    return SourceProviderEntry(
      kind: kind ?? this.kind,
      providerKey: providerKey ?? this.providerKey,
      displayName: displayName ?? this.displayName,
      family: family ?? this.family,
      connectionMode: connectionMode ?? this.connectionMode,
      summary: summary ?? this.summary,
      endpointLabel: endpointLabel ?? this.endpointLabel,
      capabilities: capabilities ?? this.capabilities,
      status: status ?? this.status,
      auth: auth ?? this.auth,
      importDetails: importDetails ?? this.importDetails,
      onboardingHint: onboardingHint ?? this.onboardingHint,
      runtimeConfig: runtimeConfig ?? this.runtimeConfig,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'provider_key': providerKey,
      'provider_type': kind.label,
      'display_name': displayName,
      'family': family,
      'connection_mode': connectionMode,
      'summary': summary,
      'endpoint_label': endpointLabel,
      'capabilities': capabilities
          .map((SourceCapabilitySupport item) => item.toJson())
          .toList(growable: false),
      'health': status.healthJson(),
      'auth': auth.toJson(),
      'import': importDetails.toJson(),
      'onboarding_hint': onboardingHint,
      if (runtimeConfig.isNotEmpty) 'runtime_config': runtimeConfig,
    };
  }
}
