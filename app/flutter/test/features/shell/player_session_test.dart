import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/playback_target.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_rust_api.dart';

void main() {
  setUpAll(() async {
    await RustShellRuntimeBridge.initializeMock(api: const TestRustApi());
  });

  test('chooser groups derive from runtime playback options', () {
    final PlayerQueueItem item = _item();
    final PlaybackSessionRuntimeRepository playbackRuntime =
        const RustPlaybackSessionRuntimeRepository();

    final List<PlayerChooserGroup> groups = playbackRuntime
        .chooserGroupsForQueueItem(item);

    expect(groups, hasLength(4));
    expect(groups[0].kind, PlayerChooserKind.source);
    expect(groups[0].options.first.label, 'Primary source');
    expect(groups[1].kind, PlayerChooserKind.quality);
    expect(groups[1].options[1].label, '1080p');
    expect(groups[2].kind, PlayerChooserKind.audio);
    expect(groups[2].options.first.label, 'Main mix');
    expect(groups[3].kind, PlayerChooserKind.subtitles);
    expect(groups[3].options.last.label, 'English CC');
  });

  test('chooser selection updates resolved playback uri', () {
    final PlaybackSessionRuntimeRepository playbackRuntime =
        const RustPlaybackSessionRuntimeRepository();
    final PlayerSession session = PlayerSession(
      kind: PlayerContentKind.movie,
      originLabel: 'Media · Movies',
      queueLabel: 'Up next',
      queue: <PlayerQueueItem>[_item()],
      activeIndex: 0,
      primaryActionLabel: 'Resume',
      secondaryActionLabel: 'Restart',
      chooserGroups: playbackRuntime.chooserGroupsForQueueItem(_item()),
      statsLines: const <String>['Playback path: backend'],
      playbackUri: _item().playbackStream?.uri,
    );

    final PlayerSession qualitySelected = playbackRuntime
        .selectPlayerSessionChooserOption(
          session,
          PlayerChooserKind.quality,
          1,
        );
    final PlayerSession sourceSelected = playbackRuntime
        .selectPlayerSessionChooserOption(
          qualitySelected,
          PlayerChooserKind.source,
          1,
        );

    expect(
      qualitySelected.playbackUri,
      'https://stream.crispy-tivi.test/media/the-last-harbor-1080.m3u8',
    );
    expect(
      sourceSelected.playbackUri,
      'https://stream.crispy-tivi.test/media/the-last-harbor-1080.m3u8',
    );
    expect(
      playbackRuntime
          .selectedTrackOptionForSession(
            sourceSelected,
            PlayerChooserKind.audio,
          )
          ?.id,
      'auto',
    );
    expect(
      playbackRuntime
          .selectedVariantOptionForSession(
            sourceSelected,
            PlayerChooserKind.source,
          )
          ?.id,
      'mirror',
    );
  });
}

PlayerQueueItem _item() {
  return PlayerQueueItem(
    eyebrow: 'Featured film',
    title: 'The Last Harbor',
    subtitle: 'Thriller · 2026 · Dolby Audio',
    summary: 'Resume directly into the film.',
    progressLabel: '01:24 / 02:11 · Resume from your last position',
    progressValue: 0.64,
    badges: const <String>['4K', 'Dolby Audio', 'Resume'],
    detailLines: const <String>[
      'The Last Harbor',
      'Feature playback keeps shell chrome out of the way.',
    ],
    playbackSource: const PlaybackSourceSnapshot(
      kind: 'movie',
      sourceKey: 'media_library',
      contentKey: 'the-last-harbor',
      sourceLabel: 'Media Library',
      handoffLabel: 'Play movie',
    ),
    playbackStream: const PlaybackStreamSnapshot(
      uri: 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
      transport: 'hls',
      live: false,
      seekable: true,
      resumePositionSeconds: 0,
      sourceOptions: <PlaybackVariantOptionSnapshot>[
        PlaybackVariantOptionSnapshot(
          id: 'primary',
          label: 'Primary source',
          uri: 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
          transport: 'hls',
          live: false,
          seekable: true,
          resumePositionSeconds: 0,
        ),
        PlaybackVariantOptionSnapshot(
          id: 'mirror',
          label: 'Mirror source',
          uri:
              'https://stream.crispy-tivi.test/media/the-last-harbor-mirror.m3u8',
          transport: 'hls',
          live: false,
          seekable: true,
          resumePositionSeconds: 0,
        ),
      ],
      qualityOptions: <PlaybackVariantOptionSnapshot>[
        PlaybackVariantOptionSnapshot(
          id: 'auto',
          label: 'Auto',
          uri: 'https://stream.crispy-tivi.test/media/the-last-harbor.m3u8',
          transport: 'hls',
          live: false,
          seekable: true,
          resumePositionSeconds: 0,
        ),
        PlaybackVariantOptionSnapshot(
          id: '1080p',
          label: '1080p',
          uri:
              'https://stream.crispy-tivi.test/media/the-last-harbor-1080.m3u8',
          transport: 'hls',
          live: false,
          seekable: true,
          resumePositionSeconds: 0,
        ),
      ],
      audioOptions: <PlaybackTrackOptionSnapshot>[
        PlaybackTrackOptionSnapshot(
          id: 'auto',
          label: 'Main mix',
          uri:
              'https://stream.crispy-tivi.test/media/the-last-harbor/audio-main.aac',
          language: 'en',
        ),
        PlaybackTrackOptionSnapshot(
          id: 'commentary',
          label: 'Commentary',
          uri:
              'https://stream.crispy-tivi.test/media/the-last-harbor/audio-commentary.aac',
          language: 'en',
        ),
      ],
      subtitleOptions: <PlaybackTrackOptionSnapshot>[
        PlaybackTrackOptionSnapshot(id: 'off', label: 'Off', uri: ''),
        PlaybackTrackOptionSnapshot(
          id: 'en-cc',
          label: 'English CC',
          uri:
              'https://stream.crispy-tivi.test/media/the-last-harbor/subtitles-en.vtt',
          language: 'en',
        ),
      ],
    ),
  );
}
