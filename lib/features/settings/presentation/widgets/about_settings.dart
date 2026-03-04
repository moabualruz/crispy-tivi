import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/app_directories.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// About settings section: version, data storage,
/// database path, licenses.
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key, required this.appVersion});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'About', icon: Icons.info, colorTitle: true),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              subtitle: Text(appVersion),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Data Storage'),
              subtitle: Text(
                kIsWeb ? 'Browser (IndexedDB)' : AppDirectories.root,
              ),
              trailing:
                  kIsWeb
                      ? null
                      : IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy path',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: AppDirectories.root),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Path copied to '
                                'clipboard',
                              ),
                            ),
                          );
                        },
                      ),
            ),
            if (!kIsWeb) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Database'),
                subtitle: Text(
                  '${AppDirectories.data}'
                  '/crispy_tivi_v2.sqlite',
                ),
              ),
            ],
            if (kIsWeb) ...[
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.search_off),
                title: Text('Browser Find (Ctrl+F)'),
                subtitle: Text(
                  'Browser find is not supported on '
                  'Flutter web. Use the in-app search '
                  '(magnifying glass icon) instead.',
                ),
                isThreeLine: true,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Open Source Licenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(context: context),
            ),
          ],
        ),
      ],
    );
  }
}
