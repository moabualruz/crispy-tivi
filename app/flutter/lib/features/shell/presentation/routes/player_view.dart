import 'package:crispy_tivi/core/theme/crispy_shell_controls.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_icons.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/player_playback_controller.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_artwork.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_controls.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_iconography.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/material.dart';

typedef PlaybackSurfaceBuilder = Widget Function(String playbackUri);

class PlayerView extends StatelessWidget {
  const PlayerView({
    required this.session,
    required this.playbackController,
    required this.chromeState,
    required this.activeChooser,
    required this.onBack,
    required this.onOpenInfo,
    required this.onOpenChooser,
    required this.onSelectChooserOption,
    required this.onSelectQueueIndex,
    this.playbackSurfaceBuilder,
    super.key,
  });

  final PlayerSession session;
  final PlayerPlaybackController playbackController;
  final PlayerChromeState chromeState;
  final PlayerChooserKind? activeChooser;
  final VoidCallback onBack;
  final VoidCallback onOpenInfo;
  final ValueChanged<PlayerChooserKind> onOpenChooser;
  final void Function(PlayerChooserKind kind, int index) onSelectChooserOption;
  final ValueChanged<int> onSelectQueueIndex;
  final PlaybackSurfaceBuilder? playbackSurfaceBuilder;

  @override
  Widget build(BuildContext context) {
    final PlayerQueueItem item = session.activeItem;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final PlayerChooserGroup? chooser =
        activeChooser == null ? null : session.chooser(activeChooser!);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: CrispyShellRoles.backdropGradient,
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _PlaybackBackdrop(
              session: session,
              playbackController: playbackController,
              artwork: item.artwork,
              playbackSurfaceBuilder: playbackSurfaceBuilder,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: CrispyShellRoles.playerOverlayScrimDecoration(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ShellControlButton(
                      controlKey: const Key('player-back-action'),
                      label: 'Back',
                      semanticsLabel: 'Back',
                      icon: CrispyShellIcons.back(),
                      onPressed: onBack,
                      controlRole: ShellControlRole.action,
                      presentation: ShellControlPresentation.iconOnly,
                    ),
                    const SizedBox(width: CrispyOverhaulTokens.small),
                    Expanded(
                      child: Text(
                        session.originLabel,
                        style: textTheme.titleMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                    ),
                    if (chromeState == PlayerChromeState.transport)
                      ShellControlButton(
                        controlKey: const Key('player-open-info'),
                        label: 'More info',
                        semanticsLabel: 'More info',
                        icon: CrispyShellIcons.info(),
                        onPressed: onOpenInfo,
                        controlRole: ShellControlRole.action,
                        presentation: ShellControlPresentation.iconOnly,
                      ),
                  ],
                ),
                const Spacer(),
                if (chromeState == PlayerChromeState.expandedInfo)
                  _ExpandedInfoPanel(
                    session: session,
                    onSelectQueueIndex: onSelectQueueIndex,
                  ),
                const SizedBox(height: CrispyOverhaulTokens.large),
                DecoratedBox(
                  decoration: CrispyShellRoles.playerTransportDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.eyebrow,
                          style: textTheme.labelLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(
                          item.title,
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.compact),
                        Text(
                          item.subtitle,
                          style: textTheme.titleMedium?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.medium),
                        Text(
                          item.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.large),
                        LinearProgressIndicator(
                          key: const Key('player-progress-bar'),
                          value: item.progressValue,
                          minHeight: 6,
                          backgroundColor: CrispyOverhaulTokens.surfaceInset,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            CrispyOverhaulTokens.accentFocus,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.small),
                        Text(
                          item.progressLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            color: CrispyOverhaulTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CrispyOverhaulTokens.large),
                        _TransportControlRow(
                          session: session,
                          onOpenChooser: onOpenChooser,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (chooser != null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x66000000),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: DecoratedBox(
                      decoration: CrispyShellRoles.playerChooserDecoration(),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          CrispyOverhaulTokens.large,
                        ),
                        child: Column(
                          key: Key('player-chooser-${chooser.kind.name}'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                ShellIconGraphic(
                                  icon: CrispyShellIcons.playerChooser(
                                    chooser.kind,
                                  ),
                                  role: ShellIconRole.row,
                                ),
                                const SizedBox(
                                  width: CrispyOverhaulTokens.small,
                                ),
                                Text(
                                  chooser.title,
                                  style: textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: CrispyOverhaulTokens.medium),
                            ...List<Widget>.generate(chooser.options.length, (
                              int index,
                            ) {
                              final bool selected =
                                  chooser.selectedIndex == index;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: CrispyOverhaulTokens.small,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: ShellControlButton(
                                    controlKey: Key(
                                      'player-chooser-option-${chooser.kind.name}-$index',
                                    ),
                                    label: chooser.options[index].label,
                                    onPressed:
                                        () => onSelectChooserOption(
                                          chooser.kind,
                                          index,
                                        ),
                                    controlRole: ShellControlRole.selector,
                                    presentation:
                                        ShellControlPresentation.textOnly,
                                    contentAlignment:
                                        AlignmentDirectional.centerStart,
                                    expandLabelRow: true,
                                    selected: selected,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaybackBackdrop extends StatelessWidget {
  const _PlaybackBackdrop({
    required this.session,
    required this.playbackController,
    required this.artwork,
    required this.playbackSurfaceBuilder,
  });

  final PlayerSession session;
  final PlayerPlaybackController playbackController;
  final ArtworkSource? artwork;
  final PlaybackSurfaceBuilder? playbackSurfaceBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(decoration: CrispyShellRoles.previewStageDecoration()),
        if (artwork != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(
              CrispyOverhaulTokens.radiusSheet,
            ),
            child: ShellArtwork(
              source: artwork,
              borderRadius: BorderRadius.circular(
                CrispyOverhaulTokens.radiusSheet,
              ),
            ),
          ),
        if (session.playbackUri != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(
              CrispyOverhaulTokens.radiusSheet,
            ),
            child: AnimatedBuilder(
              animation: playbackController,
              builder: (BuildContext context, Widget? child) {
                if (playbackSurfaceBuilder != null) {
                  return playbackSurfaceBuilder!(session.playbackUri!);
                }
                final VideoController? controller =
                    playbackController.videoController;
                if (!playbackController.backendReady || controller == null) {
                  return DecoratedBox(
                    decoration: CrispyShellRoles.previewStageDecoration(),
                    child: const SizedBox.expand(),
                  );
                }
                return Video(
                  controller: controller,
                  controls: (VideoState state) => const SizedBox.shrink(),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ExpandedInfoPanel extends StatelessWidget {
  const _ExpandedInfoPanel({
    required this.session,
    required this.onSelectQueueIndex,
  });

  final PlayerSession session;
  final ValueChanged<int> onSelectQueueIndex;

  @override
  Widget build(BuildContext context) {
    final PlayerQueueItem item = session.activeItem;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: CrispyShellRoles.playerInfoDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.large),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Now playing', style: textTheme.titleLarge),
                  const SizedBox(height: CrispyOverhaulTokens.small),
                  Wrap(
                    spacing: CrispyOverhaulTokens.small,
                    runSpacing: CrispyOverhaulTokens.small,
                    children: item.badges
                        .map((String badge) => _StatBadge(label: badge))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  ...item.detailLines.map(
                    (String line) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: CrispyOverhaulTokens.small,
                      ),
                      child: Text(
                        line,
                        style: textTheme.bodyMedium?.copyWith(
                          color: CrispyOverhaulTokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CrispyOverhaulTokens.large),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(session.queueLabel, style: textTheme.titleLarge),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  ...List<Widget>.generate(session.queue.length, (int index) {
                    final PlayerQueueItem queueItem = session.queue[index];
                    final bool selected = index == session.activeIndex;
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: CrispyOverhaulTokens.small,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ShellControlButton(
                          controlKey: Key('player-queue-item-$index'),
                          label: '${queueItem.title} · ${queueItem.subtitle}',
                          onPressed: () => onSelectQueueIndex(index),
                          controlRole: ShellControlRole.selector,
                          presentation: ShellControlPresentation.textOnly,
                          contentAlignment: AlignmentDirectional.centerStart,
                          expandLabelRow: true,
                          selected: selected,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  ...session.statsLines.map(
                    (String line) => Text(
                      line,
                      style: textTheme.bodySmall?.copyWith(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportControlRow extends StatelessWidget {
  const _TransportControlRow({
    required this.session,
    required this.onOpenChooser,
  });

  final PlayerSession session;
  final ValueChanged<PlayerChooserKind> onOpenChooser;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CrispyOverhaulTokens.medium,
      runSpacing: CrispyOverhaulTokens.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (session.kind == PlayerContentKind.live)
              const _StateBadge(label: 'LIVE')
            else
              _TransportIconButton(
                itemKey: const Key('player-primary-action'),
                label: session.primaryActionLabel,
                emphasis: true,
              ),
            const SizedBox(width: CrispyOverhaulTokens.small),
            _TransportIconButton(
              itemKey: const Key('player-secondary-action'),
              label: session.secondaryActionLabel,
            ),
          ],
        ),
        const SizedBox(width: CrispyOverhaulTokens.medium),
        _ChooserIconButton(
          itemKey: const Key('player-audio-chooser'),
          kind: PlayerChooserKind.audio,
          onTap: () => onOpenChooser(PlayerChooserKind.audio),
        ),
        _ChooserIconButton(
          itemKey: const Key('player-subtitles-chooser'),
          kind: PlayerChooserKind.subtitles,
          onTap: () => onOpenChooser(PlayerChooserKind.subtitles),
        ),
        _ChooserIconButton(
          itemKey: const Key('player-quality-chooser'),
          kind: PlayerChooserKind.quality,
          onTap: () => onOpenChooser(PlayerChooserKind.quality),
        ),
        _ChooserIconButton(
          itemKey: const Key('player-source-chooser'),
          kind: PlayerChooserKind.source,
          onTap: () => onOpenChooser(PlayerChooserKind.source),
        ),
      ],
    );
  }
}

class _TransportIconButton extends StatelessWidget {
  const _TransportIconButton({
    required this.itemKey,
    required this.label,
    this.emphasis = false,
  });

  final Key itemKey;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      controlKey: itemKey,
      label: label,
      semanticsLabel: label,
      icon: CrispyShellIcons.playerAction(label),
      onPressed: () {},
      controlRole: ShellControlRole.action,
      presentation: ShellControlPresentation.iconOnly,
      emphasis: emphasis,
    );
  }
}

class _ChooserIconButton extends StatelessWidget {
  const _ChooserIconButton({
    required this.itemKey,
    required this.kind,
    required this.onTap,
  });

  final Key itemKey;
  final PlayerChooserKind kind;
  final VoidCallback onTap;

  String get _label {
    return switch (kind) {
      PlayerChooserKind.audio => 'Audio',
      PlayerChooserKind.subtitles => 'Subtitles',
      PlayerChooserKind.quality => 'Quality',
      PlayerChooserKind.source => 'Source',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ShellControlButton(
      controlKey: itemKey,
      label: _label,
      semanticsLabel: _label,
      icon: CrispyShellIcons.playerChooser(kind),
      onPressed: onTap,
      controlRole: ShellControlRole.action,
      presentation: ShellControlPresentation.iconOnly,
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: SizedBox(
        height: CrispyShellControls.height(ShellControlRole.action),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispyOverhaulTokens.medium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.fiber_manual_record_rounded,
                size: 12,
                color: Color(0xFFD96A63),
              ),
              const SizedBox(width: CrispyOverhaulTokens.compact),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: CrispyOverhaulTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.infoPlateDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.small,
          vertical: CrispyOverhaulTokens.compact,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ShellIconGraphic(
              icon: CrispyShellIcons.playerBadge(label),
              role: ShellIconRole.badge,
              color: CrispyOverhaulTokens.textSecondary,
            ),
            const SizedBox(width: CrispyOverhaulTokens.compact),
            Text(label),
          ],
        ),
      ),
    );
  }
}
