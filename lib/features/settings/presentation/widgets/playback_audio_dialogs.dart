import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/timezone_utils.dart';
import '../../../player/domain/entities/audio_output.dart';
import '../../../player/domain/entities/passthrough_codec.dart';
import 'settings_selection_dialog.dart';

/// Shows an EPG timezone selection dialog.
void showTimezoneDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentTimezone,
  required bool Function() isMounted,
}) {
  final timezones = TimezoneUtils.availableTimezones;

  showSettingsSelectionDialog<String>(
    context: context,
    title: 'EPG Timezone',
    options: timezones,
    currentValue: currentTimezone,
    getLabel: (tz) => TimezoneUtils.getLabel(tz),
    getDescription: (tz) {
      final offset = TimezoneUtils.getOffsetLabel(tz);
      return offset.isNotEmpty ? offset : null;
    },
    onSelect: (tz) {
      ref.read(settingsNotifierProvider.notifier).setEpgTimezone(tz);
    },
    isMounted: isMounted,
  );
}

/// Shows an audio output selection dialog.
void showAudioOutputDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentOutput,
  required bool Function() isMounted,
}) {
  final availableOutputs = AudioOutput.availableForCurrentPlatform;

  showSettingsSelectionDialog<AudioOutput>(
    context: context,
    title: 'Audio Output',
    options: availableOutputs,
    currentValue: availableOutputs.firstWhere(
      (o) => o.mpvValue == currentOutput,
      orElse: () => AudioOutput.auto,
    ),
    getLabel: (o) => o.label,
    getDescription: (o) => o.description,
    onSelect: (o) {
      ref.read(settingsNotifierProvider.notifier).setAudioOutput(o.mpvValue);
    },
    isMounted: isMounted,
  );
}

/// Shows an audio passthrough codecs selection dialog.
void showPassthroughCodecsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> currentCodecs,
  required bool Function() isMounted,
}) {
  final selected = Set<String>.from(currentCodecs);

  showDialog<void>(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setDialogState) => AlertDialog(
                title: const Text('Passthrough Codecs'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick select buttons
                      Wrap(
                        spacing: CrispySpacing.sm,
                        children: [
                          ActionChip(
                            label: const Text('Dolby Family'),
                            onPressed: () {
                              setDialogState(() {
                                for (final codec
                                    in PassthroughCodec.dolbyCodecs) {
                                  selected.add(codec.mpvValue);
                                }
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('DTS Family'),
                            onPressed: () {
                              setDialogState(() {
                                for (final codec
                                    in PassthroughCodec.dtsCodecs) {
                                  selected.add(codec.mpvValue);
                                }
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('Clear All'),
                            onPressed: () {
                              setDialogState(() => selected.clear());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: CrispySpacing.md),
                      const Divider(),
                      // Codec checkboxes
                      ...PassthroughCodec.values.map((codec) {
                        if (codec == PassthroughCodec.atmos ||
                            codec == PassthroughCodec.dtsX) {
                          return const SizedBox.shrink();
                        }
                        return CheckboxListTile(
                          title: Text(codec.label),
                          subtitle: Text(
                            '${codec.description} '
                            '${codec.maxChannels}ch',
                          ),
                          value: selected.contains(codec.mpvValue),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selected.add(codec.mpvValue);
                              } else {
                                selected.remove(codec.mpvValue);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setAudioPassthroughCodecs(selected.toList());
                      Navigator.pop(ctx);
                      if (isMounted()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Passthrough codecs: '
                              '${selected.isEmpty ? "None" : selected.join(", ")}',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
        ),
  );
}
