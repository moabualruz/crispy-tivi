import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/group_icon_helper.dart';
import '../../../../core/widgets/focus_wrapper.dart';

/// A single row in the mobile groups drill-down list.
class ChannelGroupRow extends ConsumerWidget {
  const ChannelGroupRow({
    super.key,
    required this.group,
    required this.channelCount,
    required this.onTap,
  });

  final String group;
  final int channelCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final backend = ref.read(crispyBackendProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      child: FocusWrapper(
        onSelect: onTap,
        borderRadius: CrispyRadius.sm,
        semanticLabel: '$group, $channelCount channels',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                getGroupIcon(group, backend: backend),
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: CrispySpacing.md),
              Expanded(
                child: Text(
                  group,
                  style: textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$channelCount',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: CrispySpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
