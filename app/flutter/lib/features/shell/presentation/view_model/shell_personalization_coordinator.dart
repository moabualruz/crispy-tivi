import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

final class ShellPersonalizationCoordinator {
  const ShellPersonalizationCoordinator({
    required PersonalizationRuntimeRepository personalizationRepository,
  }) : _personalizationRepository = personalizationRepository;

  final PersonalizationRuntimeRepository _personalizationRepository;

  Future<PersonalizationRuntimeSnapshot> updateStartupRoute({
    required PersonalizationRuntimeSnapshot snapshot,
    required ShellRoute route,
  }) async {
    final PersonalizationRuntimeSnapshot updated = snapshot.updateStartupRoute(
      route.label,
    );
    await _personalizationRepository.save(updated);
    return updated;
  }

  Future<PersonalizationRuntimeSnapshot> toggleFavoriteMediaKey({
    required PersonalizationRuntimeSnapshot snapshot,
    required String contentKey,
  }) async {
    final PersonalizationRuntimeSnapshot updated = snapshot
        .toggleFavoriteMediaKey(contentKey);
    await _personalizationRepository.save(updated);
    return updated;
  }

  Future<PersonalizationRuntimeSnapshot> persistPlayerSession({
    required PersonalizationRuntimeSnapshot snapshot,
    required PlayerSession session,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final PlayerQueueItem item = session.activeItem;
    final PlaybackSourceSnapshot? source = item.playbackSource;
    if (source == null) {
      return snapshot;
    }
    final PersistentPlaybackKind kind = switch (session.kind) {
      PlayerContentKind.live => PersistentPlaybackKind.live,
      PlayerContentKind.movie => PersistentPlaybackKind.movie,
      PlayerContentKind.episode => PersistentPlaybackKind.episode,
    };
    final int resumeSeconds =
        positionSeconds > 0
            ? positionSeconds
            : (item.playbackStream?.resumePositionSeconds ?? 0);
    final int resolvedDurationSeconds =
        durationSeconds > 0
            ? durationSeconds
            : _resolveDurationSeconds(item);
    final double progressValue =
        resolvedDurationSeconds > 0
            ? (resumeSeconds / resolvedDurationSeconds).clamp(0, 1)
            : item.progressValue;
    final PersistentPlaybackEntry entry = PersistentPlaybackEntry(
      kind: kind,
      contentKey: source.contentKey,
      channelNumber:
          kind == PersistentPlaybackKind.live ? source.contentKey : null,
      title: item.title,
      caption: item.subtitle,
      summary: item.summary,
      progressLabel: _progressLabelFor(
        resumeSeconds: resumeSeconds,
        durationSeconds: resolvedDurationSeconds,
        fallback: item.progressLabel,
      ),
      progressValue: progressValue,
      resumePositionSeconds: resumeSeconds,
      lastViewedAt: DateTime.now().toUtc().toIso8601String(),
      detailLines: item.detailLines,
      artwork: item.artwork,
      playbackSource: item.playbackSource,
      playbackStream: item.playbackStream,
    );
    final PersonalizationRuntimeSnapshot updated = snapshot.recordPlayback(
      entry,
    );
    await _personalizationRepository.save(updated);
    return updated;
  }

  int _resolveDurationSeconds(PlayerQueueItem item) {
    if (item.progressValue <= 0) {
      return 0;
    }
    final int resumeSeconds = item.playbackStream?.resumePositionSeconds ?? 0;
    if (resumeSeconds <= 0) {
      return 0;
    }
    return (resumeSeconds / item.progressValue).round();
  }

  String _progressLabelFor({
    required int resumeSeconds,
    required int durationSeconds,
    required String fallback,
  }) {
    if (resumeSeconds <= 0 || durationSeconds <= 0) {
      return fallback;
    }

    String clock(int seconds) {
      final int hours = seconds ~/ 3600;
      final int minutes = (seconds % 3600) ~/ 60;
      final int remainder = seconds % 60;
      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }

    return '${clock(resumeSeconds)} / ${clock(durationSeconds)} · Resume';
  }
}
