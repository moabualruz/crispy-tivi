import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_config.dart';
import '../../../../config/settings_notifier.dart';
import '../../../../core/widgets/async_value_ui.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../dvr/domain/entities/recording_profile.dart';
import '../../../player/domain/entities/audio_output.dart';
import '../../../player/domain/entities/hardware_decoder.dart';
import '../../../player/domain/entities/passthrough_codec.dart';
import '../../../player/domain/entities/stream_profile.dart';
import '../../../player/domain/segment_skip_config.dart';
import 'playback_audio_dialogs.dart';
import 'playback_hwdec_dialog.dart';
import 'playback_selection_dialogs.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart'
    show SettingsBadge, SettingsCard, kSettingsIndent, showSettingsResetDialog;

/// Playback settings section: hardware decoder, aspect
/// ratio, stream quality, recording quality, AFR, PiP,
/// external player, timezone, audio output, and audio
/// passthrough.
class PlaybackSettingsSection extends ConsumerWidget {
  const PlaybackSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return settingsAsync.whenShrink(
      data: (settings) => _buildContent(context, ref, settings),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) {
    final config = settings.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'Playback',
          icon: Icons.play_circle,
          colorTitle: true,
          trailing: IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Reset to defaults',
            onPressed:
                () => showSettingsResetDialog(
                  context,
                  ref,
                  'Reset Playback Settings',
                  'playback',
                ),
          ),
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Hardware Decoder'),
              subtitle: Text(_hwdecModeLabel(config.player.hwdecMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showHwdecDialog(
                    context: context,
                    ref: ref,
                    currentMode: config.player.hwdecMode,
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.aspect_ratio),
              title: const Text('Aspect Ratio'),
              subtitle: Text(config.player.defaultAspectRatio),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showAspectRatioDialog(
                    context: context,
                    ref: ref,
                    currentRatio: config.player.defaultAspectRatio,
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),
            // -- Stream Quality Profile --
            ListTile(
              leading: const Icon(Icons.high_quality),
              title: const Text('Stream Quality'),
              subtitle: Text(_streamProfileLabel(config.player.streamProfile)),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showStreamProfileDialog(
                    context: context,
                    ref: ref,
                    currentProfile: config.player.streamProfile,
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),
            // -- Recording Quality Profile --
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Row(
                children: [
                  Text('Recording Quality'),
                  SizedBox(width: CrispySpacing.sm),
                  SettingsBadge.experimental(),
                ],
              ),
              subtitle: Text(
                _recordingProfileLabel(config.player.recordingProfile),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showRecordingProfileDialog(
                    context: context,
                    ref: ref,
                    currentProfile: config.player.recordingProfile,
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),
            // -- Auto Frame Rate (AFR) --
            SwitchListTile(
              title: const Text('Auto Frame Rate'),
              subtitle: const Text('Match display refresh to video FPS'),
              secondary: const Icon(Icons.speed),
              value: config.player.afrEnabled,
              onChanged: (val) {
                ref.read(settingsNotifierProvider.notifier).setAfrEnabled(val);
              },
            ),
            // AFR sub-options
            if (config.player.afrEnabled) ...[
              const Divider(height: 1, indent: kSettingsIndent),
              SwitchListTile(
                title: const Text('Apply to Live TV'),
                subtitle: const Text(
                  'Auto-switch refresh for live '
                  'channels',
                ),
                secondary: const SizedBox(width: CrispySpacing.lg),
                value: config.player.afrLiveTv,
                onChanged: (val) {
                  ref.read(settingsNotifierProvider.notifier).setAfrLiveTv(val);
                },
              ),
              const Divider(height: 1, indent: kSettingsIndent),
              SwitchListTile(
                title: const Text('Apply to VOD'),
                subtitle: const Text(
                  'Auto-switch refresh for '
                  'movies/series',
                ),
                secondary: const SizedBox(width: CrispySpacing.lg),
                value: config.player.afrVod,
                onChanged: (val) {
                  ref.read(settingsNotifierProvider.notifier).setAfrVod(val);
                },
              ),
            ],
            const Divider(height: 1),
            // -- Skip Buttons (FE-PS-03) --
            SwitchListTile(
              title: const Text('Skip Intro / Credits Buttons'),
              subtitle: const Text(
                'Show skip buttons during VOD '
                'playback for intros and credits',
              ),
              secondary: const Icon(Icons.skip_next_rounded),
              value: config.player.showSkipButtons,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setShowSkipButtons(val);
              },
            ),
            // -- Per-type segment skip config --
            if (config.player.showSkipButtons) ...[
              ListTile(
                leading: const SizedBox(width: kSettingsIndent),
                title: const Text('Segment Skip Behavior'),
                subtitle: const Text('Per-type skip mode for each segment'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSegmentSkipDialog(context, ref, config),
              ),
            ],
            const Divider(height: 1),
            // -- Next-up overlay mode --
            ListTile(
              leading: const Icon(Icons.queue_play_next),
              title: const Text('Next-Up Overlay'),
              subtitle: Text(parseNextUpMode(config.player.nextUpMode).label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showNextUpModeDialog(context, ref, config),
            ),
            const Divider(height: 1),
            // -- External Player --
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('External Player'),
              subtitle: Text(
                _externalPlayerLabel(config.player.externalPlayer),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showExternalPlayerDialog(
                    context: context,
                    ref: ref,
                    currentPlayer: config.player.externalPlayer,
                  ),
            ),
            const Divider(height: 1),
            // -- EPG Timezone --
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('EPG Timezone'),
              subtitle: Text(_timezoneLabel(config.player.epgTimezone)),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showTimezoneDialog(
                    context: context,
                    ref: ref,
                    currentTimezone: config.player.epgTimezone,
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),
            // -- Audio Output --
            ListTile(
              leading: const Icon(Icons.speaker),
              title: const Text('Audio Output'),
              subtitle: Text(_audioOutputLabel(config.player.audioOutput)),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showAudioOutputDialog(
                    context: context,
                    ref: ref,
                    currentOutput: config.player.audioOutput,
                    isMounted: () => context.mounted,
                  ),
            ),
            const Divider(height: 1),
            // -- Audio Passthrough --
            SwitchListTile(
              title: const Text('Audio Passthrough'),
              subtitle: const Text(
                'Pass Dolby/DTS bitstream to '
                'AV receiver',
              ),
              secondary: const Icon(Icons.surround_sound),
              value: config.player.audioPassthroughEnabled,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setAudioPassthroughEnabled(val);
              },
            ),
            // Passthrough codecs
            if (config.player.audioPassthroughEnabled) ...[
              const Divider(height: 1, indent: kSettingsIndent),
              ListTile(
                leading: const SizedBox(width: CrispySpacing.lg),
                title: const Text('Passthrough Codecs'),
                subtitle: Text(
                  _passthroughCodecsLabel(config.player.audioPassthroughCodecs),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => showPassthroughCodecsDialog(
                      context: context,
                      ref: ref,
                      currentCodecs: config.player.audioPassthroughCodecs,
                      isMounted: () => context.mounted,
                    ),
              ),
            ],
            const Divider(height: 1),
            // -- Loudness Normalization --
            SwitchListTile(
              title: const Text('Loudness Normalization'),
              subtitle: const Text(
                'Normalize volume levels across '
                'channels (EBU R128)',
              ),
              secondary: const Icon(Icons.graphic_eq),
              value: config.player.loudnessNormalization,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setLoudnessNormalization(val);
              },
            ),
            const Divider(height: 1),
            // -- Stereo Downmix --
            SwitchListTile(
              title: const Text('Stereo Downmix'),
              subtitle: const Text(
                'Convert surround sound to stereo '
                'for headphones',
              ),
              secondary: const Icon(Icons.headphones),
              value: config.player.stereoDownmix,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setStereoDownmix(val);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Labels ───────────────────────────────────

  String _hwdecModeLabel(String mode) =>
      HardwareDecoder.fromMpvValue(mode).label;

  String _streamProfileLabel(String name) =>
      StreamProfile.values
          .firstWhere((p) => p.name == name, orElse: () => StreamProfile.auto)
          .label;

  String _recordingProfileLabel(String name) =>
      RecordingProfile.values
          .firstWhere(
            (p) => p.name == name,
            orElse: () => RecordingProfile.original,
          )
          .label;

  String _externalPlayerLabel(String player) {
    const labels = {
      'none': 'Built-in (Default)',
      'systemDefault': 'System Default',
      'vlc': 'VLC',
      'mxPlayer': 'MX Player',
      'mxPlayerPro': 'MX Player Pro',
      'kodi': 'Kodi',
      'justPlayer': 'Just Player',
      'mpv': 'mpv',
      'iina': 'IINA',
      'potPlayer': 'PotPlayer',
      'celluloid': 'Celluloid',
      'infuse': 'Infuse',
    };
    return labels[player] ?? 'Built-in (Default)';
  }

  String _timezoneLabel(String tz) => TimezoneUtils.getLabel(tz);

  String _audioOutputLabel(String output) =>
      AudioOutput.fromMpvValue(output).label;

  String _passthroughCodecsLabel(List<String> codecs) {
    if (codecs.isEmpty) return 'None';
    return PassthroughCodec.fromMpvValues(
      codecs,
    ).map((c) => c.label).join(', ');
  }

  // ── Segment Skip Dialog ─────────────────────────

  void _showSegmentSkipDialog(
    BuildContext context,
    WidgetRef ref,
    AppConfig config,
  ) {
    final currentConfig = decodeSegmentSkipConfig(
      config.player.segmentSkipConfig,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SegmentSkipConfigDialog(
          initialConfig: currentConfig,
          onSave: (newConfig) {
            ref
                .read(settingsNotifierProvider.notifier)
                .setSegmentSkipConfig(encodeSegmentSkipConfig(newConfig));
          },
        );
      },
    );
  }

  // ── Next-Up Mode Dialog ─────────────────────────

  void _showNextUpModeDialog(
    BuildContext context,
    WidgetRef ref,
    AppConfig config,
  ) {
    final currentMode = parseNextUpMode(config.player.nextUpMode);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Next-Up Overlay'),
          children: [
            for (final mode in NextUpMode.values)
              SimpleDialogOption(
                onPressed: () {
                  ref
                      .read(settingsNotifierProvider.notifier)
                      .setNextUpMode(mode.name);
                  Navigator.of(dialogContext).pop();
                },
                child: Row(
                  children: [
                    Icon(
                      mode == currentMode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: CrispySpacing.md),
                    Text(mode.label),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Dialog for configuring per-type segment skip behavior.
class _SegmentSkipConfigDialog extends StatefulWidget {
  const _SegmentSkipConfigDialog({
    required this.initialConfig,
    required this.onSave,
  });

  final Map<SegmentType, SegmentSkipMode> initialConfig;
  final ValueChanged<Map<SegmentType, SegmentSkipMode>> onSave;

  @override
  State<_SegmentSkipConfigDialog> createState() =>
      _SegmentSkipConfigDialogState();
}

class _SegmentSkipConfigDialogState extends State<_SegmentSkipConfigDialog> {
  late final Map<SegmentType, SegmentSkipMode> _config;

  @override
  void initState() {
    super.initState();
    _config = Map.of(widget.initialConfig);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segment Skip Behavior'),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in SegmentType.values)
              ListTile(
                title: Text(type.label),
                trailing: DropdownButton<SegmentSkipMode>(
                  value: _config[type] ?? SegmentSkipMode.ask,
                  underline: const SizedBox.shrink(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _config[type] = val);
                    }
                  },
                  items: [
                    for (final mode in SegmentSkipMode.values)
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_config);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
