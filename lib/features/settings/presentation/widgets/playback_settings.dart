import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/widgets/async_value_ui.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../dvr/domain/entities/recording_profile.dart';
import '../../../player/domain/entities/audio_output.dart';
import '../../../player/domain/entities/hardware_decoder.dart';
import '../../../player/domain/entities/passthrough_codec.dart';
import '../../../player/domain/entities/stream_profile.dart';
import 'playback_audio_dialogs.dart';
import 'playback_hwdec_dialog.dart';
import 'playback_selection_dialogs.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart'
    show SettingsBadge, SettingsCard, kSettingsIndent;

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
      children: [
        SectionHeader(
          title: 'Playback',
          icon: Icons.play_circle,
          colorTitle: true,
          trailing: IconButton(
            icon: const Icon(Icons.restore, size: 20),
            tooltip: 'Reset to defaults',
            onPressed: () => _confirmReset(context, ref),
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
            // -- Picture-in-Picture --
            SwitchListTile(
              title: const Text('PiP on Minimize'),
              subtitle: const Text(
                'Auto-enter Picture-in-Picture '
                'when minimized',
              ),
              secondary: const Icon(Icons.picture_in_picture),
              value: config.player.pipOnMinimize,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setPipOnMinimize(val);
              },
            ),
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
          ],
        ),
      ],
    );
  }

  // ── Reset ────────────────────────────────────

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset Playback Settings'),
            content: const Text(
              'Reset all playback settings to their '
              'factory defaults?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(settingsNotifierProvider.notifier)
          .resetSection('playback');
    }
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
}
