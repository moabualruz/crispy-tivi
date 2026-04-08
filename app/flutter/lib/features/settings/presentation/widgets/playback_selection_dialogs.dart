import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../dvr/domain/entities/recording_profile.dart';
import '../../../player/domain/entities/stream_profile.dart';
import 'settings_selection_dialog.dart';

/// Shows an aspect ratio selection dialog.
void showAspectRatioDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentRatio,
  required bool Function() isMounted,
}) {
  const options = ['Auto', '16:9', '4:3', 'Fill'];

  showSettingsSelectionDialog<String>(
    context: context,
    title: 'Aspect Ratio',
    options: options,
    currentValue: currentRatio,
    getLabel: (o) => o,
    onSelect: (o) {
      ref.read(settingsNotifierProvider.notifier).setAspectRatio(o);
    },
    isMounted: isMounted,
  );
}

/// Shows a stream quality profile selection dialog.
void showStreamProfileDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentProfile,
  required bool Function() isMounted,
}) {
  showSettingsSelectionDialog<StreamProfile>(
    context: context,
    title: 'Stream Quality',
    options: StreamProfile.values,
    currentValue: StreamProfile.values.firstWhere(
      (p) => p.name == currentProfile,
      orElse: () => StreamProfile.auto,
    ),
    getLabel: (p) => p.label,
    getDescription: (p) => p.description,
    onSelect: (p) {
      ref.read(settingsNotifierProvider.notifier).setStreamProfile(p.name);
    },
    isMounted: isMounted,
  );
}

/// Shows a recording quality profile selection dialog.
void showRecordingProfileDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentProfile,
  required bool Function() isMounted,
}) {
  showSettingsSelectionDialog<RecordingProfile>(
    context: context,
    title: 'Recording Quality',
    options: RecordingProfile.values,
    currentValue: RecordingProfile.values.firstWhere(
      (p) => p.name == currentProfile,
      orElse: () => RecordingProfile.original,
    ),
    getLabel: (p) => p.label,
    getDescription: (p) => '${p.description} (${p.estimatedSizePerHour})',
    onSelect: (p) {
      ref.read(settingsNotifierProvider.notifier).setRecordingProfile(p.name);
    },
    isMounted: isMounted,
  );
}

/// Shows an external player selection dialog.
void showExternalPlayerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentPlayer,
}) {
  const options = [
    ('none', 'Built-in (Default)'),
    ('systemDefault', 'System Default'),
    ('vlc', 'VLC'),
    ('mxPlayer', 'MX Player'),
    ('mxPlayerPro', 'MX Player Pro'),
    ('kodi', 'Kodi'),
    ('justPlayer', 'Just Player'),
    ('mpv', 'mpv'),
    ('iina', 'IINA'),
    ('potPlayer', 'PotPlayer'),
    ('celluloid', 'Celluloid'),
    ('infuse', 'Infuse'),
  ];

  showDialog<void>(
    context: context,
    builder:
        (ctx) => SimpleDialog(
          title: const Text('External Player'),
          children:
              options.map((opt) {
                final (value, label) = opt;
                final isSelected = value == currentPlayer;

                return SimpleDialogOption(
                  onPressed: () {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .setExternalPlayer(value);
                    // ignore: use_build_context_synchronously
                    if (context.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                        size: 20,
                      ),
                      const SizedBox(width: CrispySpacing.md),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
  );
}
