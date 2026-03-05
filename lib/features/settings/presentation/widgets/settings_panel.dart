import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/side_panel.dart';
import 'settings_shared_widgets.dart' show kSettingsPanelWidth;

/// Shows settings as a right-slide panel overlay
/// (TV/desktop).
///
/// On large screens, overlays the current content
/// with a sliding settings panel. Use this instead
/// of navigating to the full settings screen for a
/// TiviMate-style experience.
void showSettingsPanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close settings',
    transitionDuration: CrispyAnimation.normal,
    pageBuilder:
        (ctx, anim1, anim2) => SidePanel(
          title: 'Settings',
          width: kSettingsPanelWidth,
          onClose: () => Navigator.pop(ctx),
          child: const _SettingsPanelBody(),
        ),
  );
}

/// Settings body for use inside a [SidePanel].
///
/// Renders quick-access settings links that
/// navigate to the full settings screen.
class _SettingsPanelBody extends ConsumerWidget {
  const _SettingsPanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return settingsAsync.when(
      loading: () => const LoadingStateWidget(),
      error: (e, _) => ErrorStateWidget(message: 'Error: $e'),
      data: (settings) {
        final config = settings.config;

        void goToSection(String section) {
          Navigator.pop(context); // close panel
          context.go(
            AppRoutes.settings,
            extra: <String, dynamic>{'section': section},
          );
        }

        return ListView(
          padding: const EdgeInsets.all(CrispySpacing.md),
          children: [
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Appearance'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToSection('appearance'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_circle),
              title: const Text('Playback'),
              subtitle: Text('HW: ${config.player.hwdecMode}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToSection('playback'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Sources'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToSection('sources'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToSection('notifications'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToSection('about'),
            ),
          ],
        );
      },
    );
  }
}
