import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../../config/settings_notifier.dart';
import '../../../../../core/data/cache_service.dart';
import '../../../../../core/utils/screen_brightness_helper.dart';
import '../../../data/shader_service.dart';
import '../../../domain/entities/stream_profile.dart';
import '../../providers/player_providers.dart';
import 'osd_audio_device_picker.dart';
import 'osd_shader_picker.dart';
import 'osd_sync_offset.dart';

// ─────────────────────────────────────────────────────────────
//  Time formatting helpers
// ─────────────────────────────────────────────────────────────

/// Builds the right-side text for the VOD seek bar.
///
/// When [showFinish] is enabled and speed > 0, displays
/// `-MM:SS · HH:MM` (remaining · wall-clock finish time).
/// Otherwise shows total duration.
String buildRemainingText(
  BuildContext context,
  dynamic backend,
  Duration remaining,
  int durationMs,
  double speed,
  bool showFinish,
) {
  if (!showFinish || speed <= 0 || remaining <= Duration.zero) {
    return backend.formatPlaybackDuration(durationMs, durationMs) as String;
  }
  final remainMs = remaining.inMilliseconds;
  final remainLabel =
      '-${backend.formatPlaybackDuration(remainMs, durationMs) as String}';
  final adjustedRemaining = Duration(milliseconds: (remainMs / speed).round());
  final finish = DateTime.now().add(adjustedRemaining);
  final is24h = MediaQuery.alwaysUse24HourFormatOf(context);
  final finishLabel = formatFinishTime(finish, is24h);
  return '$remainLabel · $finishLabel';
}

/// Formats a [DateTime] as a wall-clock time string.
@visibleForTesting
String formatFinishTime(DateTime time, bool is24Hour) {
  if (is24Hour) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
  final hour12 =
      time.hour == 0
          ? 12
          : time.hour > 12
          ? time.hour - 12
          : time.hour;
  final amPm = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:${time.minute.toString().padLeft(2, '0')} $amPm';
}

/// Maps deinterlace mode key to a user-facing label.
String deinterlaceLabel(String mode) => switch (mode) {
  'auto' => 'Auto',
  'on' => 'On',
  _ => 'Off',
};

// Note: deinterlaceLabel intentionally returns plain strings ('Auto', 'On',
// 'Off') because the value is passed as a parameter to
// playerDeinterlace(mode) in OsdOverflowMenu, which formats the full label.

// ─────────────────────────────────────────────────────────────
//  Dialog launchers
// ─────────────────────────────────────────────────────────────

/// Shows a simple dialog to pick stream quality profile.
void showQualityPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(runtimeStreamProfileProvider);

  showDialog<StreamProfile>(
    context: context,
    builder:
        (ctx) => SimpleDialog(
          title: Text(context.l10n.playerStreamQuality),
          children:
              StreamProfile.values.map((profile) {
                final isSelected = profile == current;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color:
                        isSelected ? Theme.of(ctx).colorScheme.primary : null,
                  ),
                  title: Text(profile.label),
                  subtitle: Text(profile.description),
                  onTap: () {
                    ref
                        .read(runtimeStreamProfileProvider.notifier)
                        .set(profile);
                    ref.read(playerServiceProvider).refresh();
                    Navigator.of(ctx).pop(profile);
                  },
                );
              }).toList(),
        ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Rotation Lock Dialog
// ─────────────────────────────────────────────────────────────

/// User-facing labels for [DeviceOrientation] values.
///
/// Note: these labels are context-free (static function), so they use
/// the ARB keys indirectly. The dialog that calls this is built with a
/// [StatefulBuilder] that receives context — pass context there instead.
String orientationLabel(DeviceOrientation o, BuildContext context) =>
    switch (o) {
      DeviceOrientation.portraitUp => context.l10n.playerPortrait,
      DeviceOrientation.portraitDown => context.l10n.playerPortraitUpsideDown,
      DeviceOrientation.landscapeLeft => context.l10n.playerLandscapeLeft,
      DeviceOrientation.landscapeRight => context.l10n.playerLandscapeRight,
    };

/// Loads the persisted allowed-orientation set from [CacheService].
/// Returns all orientations if no preference is stored.
Future<Set<DeviceOrientation>> loadRotationLock(WidgetRef ref) async {
  final cache = ref.read(cacheServiceProvider);
  final indices = await cache.getSettingIntList(kRotationLockKey);
  if (indices == null) return Set.from(DeviceOrientation.values);
  return indices.map((i) => DeviceOrientation.values[i]).toSet();
}

/// Persists the allowed-orientation set and applies it immediately.
Future<void> saveRotationLock(
  WidgetRef ref,
  Set<DeviceOrientation> orientations,
) async {
  final indices = orientations.map((o) => o.index).toList()..sort();
  await ref
      .read(cacheServiceProvider)
      .setSettingIntList(kRotationLockKey, indices);
  SystemChrome.setPreferredOrientations(orientations.toList());
}

/// Shows a multi-select dialog for device orientations with a
/// min-1 guard (cannot deselect the last orientation).
void showRotationLockDialog(BuildContext context, WidgetRef ref) async {
  final current = await loadRotationLock(ref);

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      var selected = Set<DeviceOrientation>.from(current);

      return StatefulBuilder(
        builder: (ctx, setState) {
          return SimpleDialog(
            title: Text(context.l10n.playerRotationLock),
            children: [
              ...DeviceOrientation.values.map(
                (orientation) => CheckboxListTile(
                  title: Text(orientationLabel(orientation, ctx)),
                  value: selected.contains(orientation),
                  onChanged: (value) {
                    setState(() {
                      if (selected.contains(orientation) &&
                          selected.length > 1) {
                        selected.remove(orientation);
                      } else {
                        selected.add(orientation);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(ctx.l10n.commonCancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        saveRotationLock(ref, selected);
                        Navigator.of(ctx).pop();
                      },
                      child: Text(ctx.l10n.commonSave),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Opens the audio/subtitle sync offset dialog.
void showSyncOffsetDialog(BuildContext context) {
  showDialog<void>(context: context, builder: (_) => const SyncOffsetDialog());
}

/// Opens the audio device picker dialog.
void showAudioDevicePicker(BuildContext context, WidgetRef ref) {
  final playerService = ref.read(playerServiceProvider);
  final devices = playerService.player.audioDevices;
  final currentDevice = playerService.player.currentAudioDeviceName;

  showDialog<void>(
    context: context,
    builder:
        (_) => AudioDevicePickerDialog(
          devices: devices,
          currentDeviceName: currentDevice,
          onSelect: (name) {
            playerService.player.setAudioDevice(name);
          },
        ),
  );
}

/// Toggles always-on-top for the player window (Windows/Linux).
void toggleAlwaysOnTop(WidgetRef ref) {
  if (kIsWeb) return;
  if (!Platform.isWindows && !Platform.isLinux) return;

  final notifier = ref.read(alwaysOnTopProvider.notifier);
  notifier.toggle();
  final newValue = ref.read(alwaysOnTopProvider);
  windowManager.setAlwaysOnTop(newValue);
}

/// Shows a brightness slider dialog (Android/iOS).
void showBrightnessDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final brightness = ref.watch(screenBrightnessProvider);
          final isAuto = brightness == null;

          return SimpleDialog(
            title: Text(context.l10n.playerScreenBrightness),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.brightness_low, size: 20),
                    Expanded(
                      child: Slider(
                        value: brightness ?? 1.0,
                        onChanged: (value) {
                          ref
                              .read(screenBrightnessProvider.notifier)
                              .setBrightness(value);
                          ScreenBrightnessHelper.setBrightness(value);
                        },
                      ),
                    ),
                    const Icon(Icons.brightness_high, size: 20),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(screenBrightnessProvider.notifier).resetToSystem();
                    ScreenBrightnessHelper.resetBrightness();
                  },
                  icon: Icon(
                    Icons.brightness_auto,
                    color: isAuto ? Theme.of(ctx).colorScheme.primary : null,
                  ),
                  label: Text(
                    isAuto
                        ? context.l10n.playerAutoSystem
                        : context.l10n.playerResetToAuto,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Shows the shader preset picker and applies the selected preset.
void showShaderPresetPickerDialog(
  BuildContext context,
  WidgetRef ref,
  ShaderPreset current,
) async {
  final picked = await showShaderPresetPicker(context, currentPreset: current);
  if (picked == null) return;
  ref.read(settingsNotifierProvider.notifier).setShaderPreset(picked.id);
}
