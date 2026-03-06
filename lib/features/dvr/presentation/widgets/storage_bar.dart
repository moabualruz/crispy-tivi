import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/format_utils.dart';

/// Maximum storage quota used for the visual progress bar (10 GB in bytes).
///
/// The bar turns [ColorScheme.error] when usage exceeds 90 % of this value.
const int kMaxStorageBytes = 10 * 1024 * 1024 * 1024;

/// Horizontal storage-usage bar showing total MB used
/// with a color-coded progress indicator.
///
/// FE-DVR-10: When [onTap] is provided the entire bar is tappable
/// and opens the storage breakdown sheet.
class StorageBar extends StatelessWidget {
  /// Creates a storage bar for [totalBytes] of used space.
  ///
  /// Supply [onTap] to make the bar tappable (e.g., open a
  /// [StorageBreakdownSheet]).
  const StorageBar({
    super.key,
    required this.totalBytes,
    // FE-DVR-10: optional tap handler
    this.onTap,
  });

  /// Total storage consumed in bytes.
  final int totalBytes;

  /// FE-DVR-10: Optional callback invoked when the user taps the bar.
  ///
  /// When set, wraps the bar in an [InkWell] so users can tap to open
  /// the [StorageBreakdownSheet].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = (totalBytes / kMaxStorageBytes).clamp(0.0, 1.0);
    final cs = Theme.of(context).colorScheme;

    // FE-DVR-10: Wrap in InkWell when a tap handler is provided so
    // users can open the full storage breakdown sheet by tapping the bar.
    final bar = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatBytes(totalBytes)} used',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: CrispySpacing.xs),
          ClipRect(
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                fraction > 0.9 ? cs.error : cs.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return bar;

    return Semantics(
      button: true,
      label: 'Storage settings',
      child: InkWell(onTap: onTap, child: bar),
    );
  }
}
