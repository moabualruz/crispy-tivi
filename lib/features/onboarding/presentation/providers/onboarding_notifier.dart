import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../../../iptv/application/playlist_sync_service.dart';

/// Steps in the onboarding wizard.
enum OnboardingStep { welcome, typePicker, form, syncing }

/// Sync status during the onboarding flow.
enum SyncStatus { idle, syncing, success, error }

/// Immutable state for the onboarding wizard.
@immutable
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.welcome,
    this.sourceType,
    this.syncStatus = SyncStatus.idle,
    this.syncErrorMessage,
    this.channelCount = 0,
    this.lastSource,
  });

  final OnboardingStep step;
  final PlaylistSourceType? sourceType;
  final SyncStatus syncStatus;
  final String? syncErrorMessage;
  final int channelCount;
  final PlaylistSource? lastSource;

  OnboardingState copyWith({
    OnboardingStep? step,
    PlaylistSourceType? sourceType,
    SyncStatus? syncStatus,
    String? syncErrorMessage,
    int? channelCount,
    PlaylistSource? lastSource,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      sourceType: sourceType ?? this.sourceType,
      syncStatus: syncStatus ?? this.syncStatus,
      syncErrorMessage: syncErrorMessage,
      channelCount: channelCount ?? this.channelCount,
      lastSource: lastSource ?? this.lastSource,
    );
  }
}

/// Manages the onboarding wizard state transitions.
class OnboardingNotifier extends Notifier<OnboardingState> {
  bool _disposed = false;

  @override
  OnboardingState build() {
    ref.onDispose(() => _disposed = true);
    return const OnboardingState();
  }

  /// Navigate to a specific wizard step.
  void goToStep(OnboardingStep step) {
    state = state.copyWith(step: step);
  }

  /// Select a source type and advance to the form step.
  void selectSourceType(PlaylistSourceType type) {
    state = state.copyWith(sourceType: type, step: OnboardingStep.form);
  }

  /// Navigate back one step.
  void goBack() {
    switch (state.step) {
      case OnboardingStep.form:
        state = state.copyWith(step: OnboardingStep.typePicker);
      case OnboardingStep.typePicker:
        state = state.copyWith(step: OnboardingStep.welcome);
      case OnboardingStep.welcome:
      case OnboardingStep.syncing:
        break; // Cannot go back from welcome or syncing
    }
  }

  /// Persist the source and start sync.
  Future<void> submitSource(PlaylistSource source) async {
    state = state.copyWith(
      lastSource: source,
      step: OnboardingStep.syncing,
      syncStatus: SyncStatus.syncing,
      syncErrorMessage: null,
    );

    await ref.read(settingsNotifierProvider.notifier).addSource(source);

    try {
      final result = await ref
          .read(playlistSyncServiceProvider)
          .syncSource(source);
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: SyncStatus.success,
        channelCount: result.totalChannels,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: SyncStatus.error,
        syncErrorMessage: e.toString(),
      );
    }
  }

  /// Retry syncing the last submitted source.
  Future<void> retrySync() async {
    final source = state.lastSource;
    if (source == null) return;

    state = state.copyWith(
      syncStatus: SyncStatus.syncing,
      syncErrorMessage: null,
    );

    try {
      final result = await ref
          .read(playlistSyncServiceProvider)
          .syncSource(source);
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: SyncStatus.success,
        channelCount: result.totalChannels,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: SyncStatus.error,
        syncErrorMessage: e.toString(),
      );
    }
  }

  /// Remove the bad source and return to the form for editing.
  void editSource() {
    final source = state.lastSource;
    if (source != null) {
      ref.read(settingsNotifierProvider.notifier).removeSource(source.id);
    }
    state = state.copyWith(
      step: OnboardingStep.form,
      syncStatus: SyncStatus.idle,
      syncErrorMessage: null,
    );
  }
}

/// Provider for the onboarding wizard state.
final onboardingProvider =
    NotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );
