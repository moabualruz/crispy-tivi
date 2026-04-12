import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:flutter/foundation.dart';

enum PlayerContentKind { live, movie, episode }

enum PlayerChromeState { transport, expandedInfo }

enum PlayerChooserKind { audio, subtitles, quality, source }

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
  final List<String> options;
  final int selectedIndex;
}

@immutable
final class PlayerSession {
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

  PlayerQueueItem get activeItem => queue[activeIndex];

  PlayerSession copyWith({
    int? activeIndex,
    List<PlayerChooserGroup>? chooserGroups,
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
    );
  }

  PlayerChooserGroup chooser(PlayerChooserKind kind) {
    return chooserGroups.firstWhere(
      (PlayerChooserGroup group) => group.kind == kind,
    );
  }

  PlayerSession selectQueueIndex(int index) {
    if (index == activeIndex) {
      return this;
    }
    return copyWith(activeIndex: index.clamp(0, queue.length - 1));
  }

  PlayerSession selectChooserOption(PlayerChooserKind kind, int optionIndex) {
    return copyWith(
      chooserGroups: chooserGroups
          .map(
            (PlayerChooserGroup group) => group.kind == kind
                ? PlayerChooserGroup(
                    kind: group.kind,
                    title: group.title,
                    options: group.options,
                    selectedIndex: optionIndex.clamp(0, group.options.length - 1),
                  )
                : group,
          )
          .toList(growable: false),
    );
  }
}
