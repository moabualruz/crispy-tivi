import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:flutter/foundation.dart';

enum PlayerContentKind { live, movie, episode }

enum PlayerChromeState { transport, expandedInfo }

enum PlayerChooserKind { audio, subtitles, quality, source }

@immutable
final class PlayerChooserOption {
  const PlayerChooserOption({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
final class PlayerQueueItem {
  const PlayerQueueItem({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.progressLabel,
    required this.progressValue,
    required this.badges,
    required this.detailLines,
    this.artwork,
    this.playbackSource,
    this.playbackStream,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String summary;
  final String progressLabel;
  final double progressValue;
  final List<String> badges;
  final List<String> detailLines;
  final ArtworkSource? artwork;
  final PlaybackSourceSnapshot? playbackSource;
  final PlaybackStreamSnapshot? playbackStream;
}

@immutable
final class PlayerChooserGroup {
  const PlayerChooserGroup({
    required this.kind,
    required this.title,
    required this.options,
    required this.selectedIndex,
  });

  final PlayerChooserKind kind;
  final String title;
  final List<PlayerChooserOption> options;
  final int selectedIndex;

  PlayerChooserOption get selectedOption => options[selectedIndex];
}

@immutable
final class PlayerSession {
  static const Object _keepPlaybackUri = Object();

  const PlayerSession({
    required this.kind,
    required this.originLabel,
    required this.queueLabel,
    required this.queue,
    required this.activeIndex,
    required this.primaryActionLabel,
    required this.secondaryActionLabel,
    required this.chooserGroups,
    required this.statsLines,
    this.playbackUri,
  });

  final PlayerContentKind kind;
  final String originLabel;
  final String queueLabel;
  final List<PlayerQueueItem> queue;
  final int activeIndex;
  final String primaryActionLabel;
  final String secondaryActionLabel;
  final List<PlayerChooserGroup> chooserGroups;
  final List<String> statsLines;
  final String? playbackUri;

  PlayerQueueItem get activeItem => queue[activeIndex];

  PlayerSession copyWith({
    int? activeIndex,
    List<PlayerChooserGroup>? chooserGroups,
    Object? playbackUri = _keepPlaybackUri,
  }) {
    return PlayerSession(
      kind: kind,
      originLabel: originLabel,
      queueLabel: queueLabel,
      queue: queue,
      activeIndex: activeIndex ?? this.activeIndex,
      primaryActionLabel: primaryActionLabel,
      secondaryActionLabel: secondaryActionLabel,
      chooserGroups: chooserGroups ?? this.chooserGroups,
      statsLines: statsLines,
      playbackUri:
          identical(playbackUri, _keepPlaybackUri)
              ? this.playbackUri
              : playbackUri as String?,
    );
  }

  PlayerChooserGroup chooser(PlayerChooserKind kind) {
    return chooserGroups.firstWhere(
      (PlayerChooserGroup group) => group.kind == kind,
    );
  }
}
