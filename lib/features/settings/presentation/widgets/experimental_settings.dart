import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../player/domain/entities/upscale_mode.dart';
import '../../../player/domain/entities/upscale_quality.dart';
import '../../../player/presentation/providers/upscale_providers.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart' show SettingsCard, kSettingsIndent;

/// Experimental features section in settings.
///
/// Contains the global video upscaling toggle and
/// sub-options (mode, quality, GPU info). Upscaling
/// is disabled by default; this acts as a master
/// switch for the entire pipeline.
class ExperimentalSettingsSection extends ConsumerWidget {
  const ExperimentalSettingsSection({super.key, required this.upscaleEnabled});

  /// Whether the master upscale toggle is on.
  final bool upscaleEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(upscaleModeProvider);
    final quality = ref.watch(upscaleQualityProvider);
    final gpuAsync = ref.watch(gpuInfoProvider);
    final activeTier = ref.watch(upscaleActiveProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Experimental',
          icon: Icons.science,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            // ── Master toggle ──
            SwitchListTile(
              title: const Text('Video Upscaling'),
              subtitle: const Text(
                'Enable GPU-accelerated '
                'upscaling pipeline',
              ),
              secondary: const Icon(Icons.auto_awesome),
              value: upscaleEnabled,
              onChanged: (val) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .setUpscaleEnabled(val);
              },
            ),
            // ── Sub-options (visible when enabled) ──
            if (upscaleEnabled) ...[
              const Divider(height: 1, indent: kSettingsIndent),
              // -- Upscale Mode --
              ListTile(
                leading: const SizedBox(width: CrispySpacing.lg),
                title: const Text('Upscale Mode'),
                subtitle: Text(mode.label),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => _showModeDialog(
                      context: context,
                      ref: ref,
                      current: mode,
                    ),
              ),
              const Divider(height: 1, indent: kSettingsIndent),
              // -- Upscale Quality --
              ListTile(
                leading: const SizedBox(width: CrispySpacing.lg),
                title: const Text('Upscale Quality'),
                subtitle: Text(quality.label),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    () => _showQualityDialog(
                      context: context,
                      ref: ref,
                      current: quality,
                    ),
              ),
              const Divider(height: 1, indent: kSettingsIndent),
              // -- Detected GPU (read-only) --
              ListTile(
                leading: const SizedBox(width: CrispySpacing.lg),
                title: const Text('Detected GPU'),
                subtitle: Text(gpuAsync.value?.name ?? 'Detecting...'),
              ),
              const Divider(height: 1, indent: kSettingsIndent),
              // -- Active Method (read-only) --
              ListTile(
                leading: const SizedBox(width: CrispySpacing.lg),
                title: const Text('Active Method'),
                subtitle: Text(_tierLabel(activeTier)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────

  /// Maps a tier int to a human-readable label.
  String _tierLabel(int? tier) {
    switch (tier) {
      case 0:
        return 'RTX Video SDK (AI)';
      case 1:
        return 'Hardware AI (RTX/Intel VSR)';
      case 2:
        return 'MetalFX / Core ML';
      case 3:
        return 'FSR / GSR / WebGL';
      case 4:
        return 'Software (Lanczos/Spline)';
      default:
        return 'None (unprocessed)';
    }
  }

  /// Shows a dialog to pick the [UpscaleMode].
  void _showModeDialog({
    required BuildContext context,
    required WidgetRef ref,
    required UpscaleMode current,
  }) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Upscale Mode'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    UpscaleMode.values.map((m) {
                      final sel = m == current;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          sel
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: sel ? Theme.of(ctx).colorScheme.primary : null,
                        ),
                        title: Text(m.label),
                        subtitle: Text(m.description),
                        onTap: () {
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .setUpscaleMode(m.value);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  /// Shows a dialog to pick [UpscaleQuality].
  void _showQualityDialog({
    required BuildContext context,
    required WidgetRef ref,
    required UpscaleQuality current,
  }) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Upscale Quality'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    UpscaleQuality.values.map((q) {
                      final sel = q == current;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          sel
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: sel ? Theme.of(ctx).colorScheme.primary : null,
                        ),
                        title: Text(q.label),
                        subtitle: Text(q.description),
                        onTap: () {
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .setUpscaleQuality(q.value);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }
}
