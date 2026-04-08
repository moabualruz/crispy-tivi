import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/widgets/async_filled_button.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/domain/entities/playlist_source.dart';
import '../providers/profile_service_providers.dart';
import '../../domain/entities/user_profile.dart';

/// Dialog for managing which sources a profile can access.
///
/// Shows all configured playlist sources with checkboxes.
/// Admin profiles have full access (shown as read-only).
class SourceAccessDialog extends ConsumerStatefulWidget {
  const SourceAccessDialog({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<SourceAccessDialog> createState() => _SourceAccessDialogState();
}

class _SourceAccessDialogState extends ConsumerState<SourceAccessDialog> {
  late Set<String> _selectedSourceIds;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSourceIds = {};
    _loadCurrentAccess();
  }

  Future<void> _loadCurrentAccess() async {
    final service = ref.read(sourceAccessServiceProvider.notifier);
    final accessibleSources = await service.getAccessibleSources(
      widget.profile.id,
    );

    if (mounted) {
      setState(() {
        // If null, it means all sources (admin)
        // Otherwise, it's the list of accessible source IDs
        if (accessibleSources != null) {
          _selectedSourceIds = accessibleSources.toSet();
        }
        _loading = false;
      });
    }
  }

  Future<void> _saveAccess() async {
    setState(() => _saving = true);

    final currentProfile =
        ref.read(profileServiceProvider).value?.activeProfile;
    if (currentProfile == null) {
      setState(() => _saving = false);
      return;
    }

    final service = ref.read(sourceAccessServiceProvider.notifier);
    final success = await service.setAccess(
      widget.profile.id,
      _selectedSourceIds.toList(),
      requestingProfileId: currentProfile.id,
    );

    if (mounted) {
      setState(() => _saving = false);

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Source access updated for ${widget.profile.name}'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update source access')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('Source Access: ${widget.profile.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child:
            _loading
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(CrispySpacing.lg),
                    child: CircularProgressIndicator(),
                  ),
                )
                : settingsAsync.when(
                  loading: () => const LoadingStateWidget(),
                  error: (e, _) => Text('Error: $e'),
                  data:
                      (settings) => _buildSourceList(
                        context,
                        settings.sources,
                        colorScheme,
                        textTheme,
                      ),
                ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!widget.profile.isAdmin)
          AsyncFilledButton(
            isLoading: _saving,
            label: 'Save',
            onPressed: _saving || _loading ? null : _saveAccess,
          ),
      ],
    );
  }

  Widget _buildSourceList(
    BuildContext context,
    List<PlaylistSource> sources,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(CrispySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_remove,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: CrispySpacing.md),
            Text('No sources configured', style: textTheme.bodyLarge),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              'Add playlist sources in Settings first.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Admin has full access - show read-only
    if (widget.profile.isAdmin) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(CrispySpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: colorScheme.primary),
                const SizedBox(width: CrispySpacing.md),
                Expanded(
                  child: Text(
                    'Admin profiles have access to all sources.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CrispySpacing.md),
          ...sources.map(
            (source) => _SourceTile(
              source: source,
              isChecked: true,
              enabled: false,
              onChanged: null,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Select all / deselect all
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSourceIds = sources.map((s) => s.id).toSet();
                });
              },
              child: const Text('Select All'),
            ),
            const SizedBox(width: CrispySpacing.sm),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSourceIds.clear();
                });
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        const Divider(),
        // Source list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              final isChecked = _selectedSourceIds.contains(source.id);
              return _SourceTile(
                source: source,
                isChecked: isChecked,
                enabled: true,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedSourceIds.add(source.id);
                    } else {
                      _selectedSourceIds.remove(source.id);
                    }
                  });
                },
              );
            },
          ),
        ),
        const Divider(),
        // Summary
        Padding(
          padding: const EdgeInsets.only(top: CrispySpacing.sm),
          child: Text(
            '${_selectedSourceIds.length} of ${sources.length} sources selected',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single source tile with checkbox.
class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.isChecked,
    required this.enabled,
    required this.onChanged,
  });

  final PlaylistSource source;
  final bool isChecked;
  final bool enabled;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CheckboxListTile(
      value: isChecked,
      onChanged: enabled ? onChanged : null,
      title: Text(source.name),
      subtitle: Text(
        source.type == PlaylistSourceType.xtream
            ? 'Xtream Codes'
            : 'M3U Playlist',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      secondary: Icon(
        source.type == PlaylistSourceType.xtream
            ? Icons.api
            : Icons.playlist_play,
        color: enabled ? null : colorScheme.outline,
      ),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
