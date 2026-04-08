import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// DVR & Recordings settings section.
class DvrSettingsSection extends StatelessWidget {
  const DvrSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'DVR & Recordings',
          icon: Icons.fiber_manual_record,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Recordings'),
              subtitle: const Text('Manage scheduled & completed'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.dvr),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Cloud Storage'),
              subtitle: const Text('Browse cloud recordings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.cloudBrowser),
            ),
          ],
        ),
      ],
    );
  }
}
