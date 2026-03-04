import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// History settings section: clear watch history.
class HistorySettingsSection extends ConsumerStatefulWidget {
  const HistorySettingsSection({super.key});

  @override
  ConsumerState<HistorySettingsSection> createState() =>
      _HistorySettingsSectionState();
}

class _HistorySettingsSectionState
    extends ConsumerState<HistorySettingsSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'History',
          icon: Icons.history,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear Watch History'),
              subtitle: const Text(
                'Remove all continue watching '
                'progress',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showClearHistoryDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear Watch History?'),
            content: const Text(
              'This will remove all continue watching '
              'progress. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(watchHistoryServiceProvider).clearAll();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Watch history cleared'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: errorColor),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }
}
