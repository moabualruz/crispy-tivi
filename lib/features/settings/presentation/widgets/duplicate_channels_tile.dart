import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/application/duplicate_detection_service.dart';
import 'settings_shared_widgets.dart';
import 'source_manage_dialogs.dart';

/// Displays the duplicate channel count and a "Manage" button.
///
/// Rendered only when [duplicateCountProvider] returns a non-zero
/// count. Extracted from [SourcesSettingsSection] (S-11).
class DuplicateChannelsTile extends ConsumerWidget {
  const DuplicateChannelsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duplicateCount = ref.watch(duplicateCountProvider);
    if (duplicateCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: CrispySpacing.sm),
      child: SettingsCard(
        children: [
          ListTile(
            leading: const Icon(Icons.copy_all),
            title: const Text('Duplicate Channels'),
            subtitle: Text(
              '$duplicateCount duplicate'
              '${duplicateCount == 1 ? '' : 's'}'
              ' found',
            ),
            trailing: TextButton(
              onPressed: () => showDuplicatesDialog(context: context, ref: ref),
              child: const Text('Manage'),
            ),
          ),
        ],
      ),
    );
  }
}
