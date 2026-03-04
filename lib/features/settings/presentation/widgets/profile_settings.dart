import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../profiles/data/profile_service.dart';
import 'settings_shared_widgets.dart';

/// Profiles settings section.
///
/// Shows a link to the profile selection screen where
/// users can switch profiles or add new ones.
class ProfileSettingsSection extends ConsumerWidget {
  const ProfileSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileCount = ref.watch(
      profileServiceProvider.select((s) => s.asData?.value.profiles.length),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Profiles',
          icon: Icons.people,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: const Text('Manage Profiles'),
              subtitle: Text(
                profileCount == null
                    ? 'Loading…'
                    : profileCount == 1
                    ? '1 profile — tap to add more'
                    : '$profileCount profiles',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => context.push(
                    AppRoutes.profiles,
                    extra: const {'explicit': true},
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
