import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/gpu_info.dart';
import '../../../player/domain/entities/hardware_decoder.dart';

/// Shows a hardware decoder selection dialog with GPU
/// auto-detection and recommended decoder badge.
void showHwdecDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentMode,
  required bool Function() isMounted,
}) async {
  final gpuHelper = GpuInfoHelper();
  final gpuInfo = await gpuHelper.detectGpu();

  if (!isMounted()) return;

  showDialog(
    // ignore: use_build_context_synchronously
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Hardware Decoder'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GPU Info section
                if (gpuInfo.isDetected) ...[
                  _GpuInfoBanner(gpuInfo: gpuInfo),
                  const SizedBox(height: CrispySpacing.md),
                  if (gpuInfo.recommendedDecoder != HardwareDecoder.auto)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CrispySpacing.sm),
                      child: Text(
                        'Recommended: '
                        '${gpuInfo.recommendedDecoder.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
                // Decoder options
                ...gpuInfo.availableDecoders.map(
                  (decoder) => _DecoderOption(
                    decoder: decoder,
                    isSelected: decoder.mpvValue == currentMode,
                    isRecommended:
                        decoder == gpuInfo.recommendedDecoder &&
                        decoder != HardwareDecoder.auto,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setHwdecMode(decoder.mpvValue);
                      Navigator.pop(ctx);
                      if (isMounted()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Hardware decoder: '
                              '${decoder.label}',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
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

/// Banner showing detected GPU information.
class _GpuInfoBanner extends StatelessWidget {
  const _GpuInfoBanner({required this.gpuInfo});

  final GpuInfo gpuInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CrispySpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Icon(Icons.memory, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected GPU',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  gpuInfo.gpuName ?? 'Unknown',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single decoder option row in the dialog.
class _DecoderOption extends StatelessWidget {
  const _DecoderOption({
    required this.decoder,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  final HardwareDecoder decoder;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Row(
        children: [
          Text(
            decoder.label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isRecommended) ...[
            const SizedBox(width: CrispySpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                'Best',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        decoder.description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      onTap: onTap,
    );
  }
}
