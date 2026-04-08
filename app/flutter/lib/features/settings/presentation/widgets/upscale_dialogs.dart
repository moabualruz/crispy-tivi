import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../player/domain/entities/upscale_mode.dart';
import '../../../player/domain/entities/upscale_quality.dart';
import 'settings_selection_dialog.dart';

/// Shows an upscale mode selection dialog.
///
/// Lists all [UpscaleMode] values with label + description.
/// Saves the selected mode via [SettingsNotifier.setUpscaleMode].
void showUpscaleModeDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentMode,
  required bool Function() isMounted,
}) {
  showSettingsSelectionDialog<UpscaleMode>(
    context: context,
    title: 'Upscaling Mode',
    options: UpscaleMode.values,
    currentValue: UpscaleMode.values.firstWhere(
      (m) => m.value == currentMode,
      orElse: () => UpscaleMode.values.first,
    ),
    getLabel: (m) => m.label,
    getDescription: (m) => m.description,
    onSelect: (m) {
      ref.read(settingsNotifierProvider.notifier).setUpscaleMode(m.value);
    },
    isMounted: isMounted,
  );
}

/// Shows an upscale quality selection dialog.
///
/// Lists all [UpscaleQuality] values with label +
/// description. Saves the selected quality via
/// [SettingsNotifier.setUpscaleQuality].
void showUpscaleQualityDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentQuality,
  required bool Function() isMounted,
}) {
  showSettingsSelectionDialog<UpscaleQuality>(
    context: context,
    title: 'Upscaling Quality',
    options: UpscaleQuality.values,
    currentValue: UpscaleQuality.values.firstWhere(
      (q) => q.value == currentQuality,
      orElse: () => UpscaleQuality.values.first,
    ),
    getLabel: (q) => q.label,
    getDescription: (q) => q.description,
    onSelect: (q) {
      ref.read(settingsNotifierProvider.notifier).setUpscaleQuality(q.value);
    },
    isMounted: isMounted,
  );
}
