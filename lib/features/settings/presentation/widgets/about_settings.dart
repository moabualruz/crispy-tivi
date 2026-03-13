import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/app_directories.dart';
import '../../../../core/data/cache_service.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';
import 'update_dialog.dart';

/// Default GitHub repo for update checks.
const _defaultRepoUrl = 'crispytivi/crispy-tivi';

/// About settings section: version, update check, data
/// storage, database path, licenses.
class AboutSettingsSection extends ConsumerStatefulWidget {
  const AboutSettingsSection({super.key, required this.appVersion});

  final String appVersion;

  @override
  ConsumerState<AboutSettingsSection> createState() =>
      _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends ConsumerState<AboutSettingsSection> {
  Map<String, dynamic>? _updateResult;
  bool _isChecking = false;
  String _checkFrequency = 'daily';

  @override
  void initState() {
    super.initState();
    _loadFrequency();
    _autoCheck();
  }

  Future<void> _loadFrequency() async {
    final cache = ref.read(cacheServiceProvider);
    final freq = await cache.getSetting('update_check_frequency');
    if (mounted && freq != null) {
      setState(() => _checkFrequency = freq);
    }
  }

  Future<void> _autoCheck() async {
    if (kIsWeb) return;
    final cache = ref.read(cacheServiceProvider);
    final freq = await cache.getSetting('update_check_frequency');
    if (freq == 'never') return;

    final interval =
        freq == 'weekly' ? const Duration(days: 7) : const Duration(days: 1);
    try {
      final result = await cache.checkForUpdateParsed(
        widget.appVersion,
        _defaultRepoUrl,
        checkInterval: interval,
      );
      if (mounted) {
        setState(() {
          _updateResult = result;
        });
      }
    } catch (_) {}
  }

  Future<void> _manualCheck() async {
    setState(() => _isChecking = true);
    try {
      final cache = ref.read(cacheServiceProvider);
      final result = await cache.checkForUpdateParsed(
        widget.appVersion,
        _defaultRepoUrl,
      );
      if (mounted) {
        setState(() {
          _updateResult = result;
          _isChecking = false;
        });
        if (_updateResult?['has_update'] == true) {
          _showUpdateDialog();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showUpdateDialog() {
    final cache = ref.read(cacheServiceProvider);
    showDialog<void>(
      context: context,
      builder:
          (_) => UpdateDialog(
            latestVersion: _updateResult!['latest_version'] as String,
            changelog: _updateResult!['changelog'] as String? ?? '',
            downloadUrl: _updateResult!['download_url'] as String? ?? '',
            assetsJson: _updateResult!['assets_json'] as String? ?? '[]',
            platform: _platformName,
            getPlatformAssetUrl: cache.getPlatformAssetUrl,
          ),
    );
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'unknown';
    }
  }

  Future<void> _setFrequency(String value) async {
    setState(() => _checkFrequency = value);
    final cache = ref.read(cacheServiceProvider);
    await cache.setSetting('update_check_frequency', value);
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = _updateResult?['has_update'] == true;
    final latestVersion = _updateResult?['latest_version'] as String? ?? '';
    final error = _updateResult?['error'] as String?;

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
              subtitle: Text(widget.appVersion),
            ),
            const Divider(height: 1),

            // ── Update Check ────────────────────
            if (kIsWeb)
              const ListTile(
                leading: Icon(Icons.browser_updated),
                title: Text('Updates'),
                subtitle: Text(
                  'Refresh your browser to get the latest version.',
                ),
              )
            else
              ListTile(
                leading: Icon(
                  hasUpdate ? Icons.system_update : Icons.update,
                  color: hasUpdate ? Colors.green : null,
                ),
                title: Text(
                  hasUpdate
                      ? 'Update Available: v$latestVersion'
                      : 'Check for Updates',
                ),
                subtitle:
                    _isChecking
                        ? const Text('Checking...')
                        : hasUpdate
                        ? const Text('Tap to view details')
                        : error != null
                        ? Text('Error: $error')
                        : _updateResult != null
                        ? const Text('You are up to date')
                        : null,
                trailing:
                    _isChecking
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : hasUpdate
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Check now',
                          onPressed: _manualCheck,
                        ),
                onTap: hasUpdate ? _showUpdateDialog : _manualCheck,
              ),

            if (!kIsWeb) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Update Check Frequency'),
                trailing: DropdownButton<String>(
                  value: _checkFrequency,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'never', child: Text('Never')),
                  ],
                  onChanged: (v) {
                    if (v != null) _setFrequency(v);
                  },
                ),
              ),
            ],

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
                              content: Text('Path copied to clipboard'),
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
