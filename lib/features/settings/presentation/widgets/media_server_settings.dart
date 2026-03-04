import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Media Servers settings section.
class MediaServerSettingsSection extends StatelessWidget {
  const MediaServerSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Media Servers',
          icon: Icons.dns,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Browse Media Servers'),
              subtitle: const Text('Manage Jellyfin, Emby & Plex'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.mediaServers),
            ),
            ListTile(
              leading: const Icon(Icons.connected_tv),
              title: const Text('Connect Jellyfin'),
              subtitle: const Text('Access your Jellyfin library'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.jellyfinLogin),
            ),
          ],
        ),
      ],
    );
  }
}
