import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../profiles/domain/permission_guard.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Administration settings section. Only visible to
/// admin profiles.
class AdminSettingsSection extends ConsumerWidget {
  const AdminSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canManageProfilesProvider);
    if (!canManage) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Administration',
          icon: Icons.admin_panel_settings,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Manage Profiles'),
              subtitle: const Text('Assign roles and source access'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.profileManagement),
            ),
          ],
        ),
        const SizedBox(height: CrispySpacing.lg),
      ],
    );
  }
}
