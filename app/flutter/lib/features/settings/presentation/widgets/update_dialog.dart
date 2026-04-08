import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/crispy_spacing.dart';

/// Dialog showing update details and download action.
///
/// Displays the new version, changelog, and a platform-appropriate
/// download button. On web, shows a "refresh browser" message.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.assetsJson,
    required this.platform,
    required this.getPlatformAssetUrl,
    super.key,
  });

  final String latestVersion;
  final String changelog;
  final String downloadUrl;
  final String assetsJson;
  final String platform;
  final String? Function(String assetsJson, String platform)
  getPlatformAssetUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.green.shade400),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(child: Text('Update Available — v$latestVersion')),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kIsWeb)
                const Text('Refresh your browser to get the latest version.')
              else ...[
                Text(
                  "What's New",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: CrispySpacing.sm),
                Text(changelog.isEmpty ? 'No changelog available.' : changelog),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        if (!kIsWeb)
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            onPressed: () {
              final assetUrl = getPlatformAssetUrl(assetsJson, platform);
              final url = assetUrl ?? downloadUrl;
              if (url.isNotEmpty) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}
