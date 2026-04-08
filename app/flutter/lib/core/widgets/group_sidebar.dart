import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cache_service.dart';
import '../navigation/shell_providers.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';
import '../utils/group_icon_helper.dart';
import 'focus_wrapper.dart';
import 'glass_surface.dart';

/// Wraps a sidebar widget (typically [GroupSidebar]) with a
/// [FocusTraversalGroup] and registers its [FocusNode] with
/// [focusEscalationProvider] so Escape/Back escalates through:
///   content → sidebar → nav rail
///
/// Usage:
/// ```dart
/// SidebarFocusScope(
///   child: GroupSidebar(...),
/// )
/// ```
class SidebarFocusScope extends ConsumerStatefulWidget {
  const SidebarFocusScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SidebarFocusScope> createState() => _SidebarFocusScopeState();
}

class _SidebarFocusScopeState extends ConsumerState<SidebarFocusScope> {
  final FocusNode _sidebarNode = FocusNode(debugLabel: 'SidebarFocusScope');
  late final FocusEscalationNotifier _escalation;

  @override
  void initState() {
    super.initState();
    _escalation = ref.read(focusEscalationProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _escalation.setSidebarNode(_sidebarNode);
      }
    });
  }

  @override
  void dispose() {
    // Defer provider modification to avoid "modified during build" error.
    // The notifier call must happen outside the widget unmount phase.
    // Guard against provider disposal when the ProviderContainer is
    // torn down before the post-frame callback fires (e.g. in tests).
    final escalation = _escalation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        escalation.setSidebarNode(null);
      } on Exception catch (_) {
        // Provider already disposed — cleanup is moot.
      }
    });
    _sidebarNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Focus(focusNode: _sidebarNode, child: widget.child),
    );
  }
}

/// Width of the expanded sidebar on large screens.
const kSidebarWidth = 240.0;

/// Width when collapsed (icon-only mode).
const kSidebarCollapsedWidth = 64.0;

/// A left-anchored sidebar for group/category selection.
///
/// Glassmorphic sidebar panel designed for
/// large screens (≥1200px). Supports both expanded and collapsed modes.
///
/// ```dart
/// GroupSidebar(
///   groups: ['Favorites', 'Sports', 'News', 'Movies'],
///   selectedGroup: 'Sports',
///   onGroupSelected: (group) => setState(() => _selectedGroup = group),
/// )
/// ```
class GroupSidebar extends ConsumerWidget {
  const GroupSidebar({
    required this.groups,
    required this.onGroupSelected,
    this.selectedGroup,
    this.isCollapsed = false,
    this.onCollapseToggle,
    this.header,
    this.showAllOption = true,
    this.allOptionLabel = 'All',
    super.key,
  });

  /// List of group names to display.
  final List<String> groups;

  /// Currently selected group. Null means "All" is selected.
  final String? selectedGroup;

  /// Called when a group is tapped. Pass `null` for "All" selection.
  final ValueChanged<String?> onGroupSelected;

  /// Whether the sidebar is in collapsed (icon-only) mode.
  final bool isCollapsed;

  /// Called when collapse toggle is tapped.
  final VoidCallback? onCollapseToggle;

  /// Optional header widget above the group list.
  final Widget? header;

  /// Whether to show an "All" option at the top.
  final bool showAllOption;

  /// Label for the "All" option.
  final String allOptionLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final backend = ref.read(crispyBackendProvider);

    return AnimatedContainer(
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.enterCurve,
      width: isCollapsed ? kSidebarCollapsedWidth : kSidebarWidth,
      child: GlassSurface(
        borderRadius: CrispyRadius.none,
        padding: EdgeInsets.symmetric(
          vertical: CrispySpacing.md,
          horizontal: isCollapsed ? CrispySpacing.xs : CrispySpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header or collapse toggle
            if (header != null && !isCollapsed) ...[
              header!,
              const SizedBox(height: CrispySpacing.md),
            ],

            // Collapse toggle button
            if (onCollapseToggle != null)
              _SidebarIconButton(
                icon:
                    isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                onTap: onCollapseToggle!,
                tooltip: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
              ),

            if (onCollapseToggle != null)
              const SizedBox(height: CrispySpacing.sm),

            // "All" option
            if (showAllOption)
              _GroupItem(
                label: allOptionLabel,
                icon: Icons.grid_view_rounded,
                isSelected: selectedGroup == null,
                isCollapsed: isCollapsed,
                onTap: () => onGroupSelected(null),
              ),

            // Divider
            if (showAllOption && groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xs),
                child: Divider(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  height: 1,
                ),
              ),

            // Group list
            Expanded(
              child: ClipRect(
                child: ListView.builder(
                  itemCount: groups.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupItem(
                      label: group,
                      icon: getGroupIcon(group, backend: backend),
                      isSelected: selectedGroup == group,
                      isCollapsed: isCollapsed,
                      onTap: () => onGroupSelected(group),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual group item row.
class _GroupItem extends StatelessWidget {
  const _GroupItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    final textColor = isSelected ? colorScheme.primary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: CrispySpacing.xs),
      child: FocusWrapper(
        onSelect: onTap,
        borderRadius: CrispyRadius.sm,
        padding: EdgeInsets.zero,
        child: AnimatedContainer(
          duration: CrispyAnimation.fast,
          decoration: const BoxDecoration(color: Colors.transparent),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? CrispySpacing.sm : CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              if (!isCollapsed) ...[
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only button for sidebar actions.
class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.sm,
      padding: EdgeInsets.zero,
      semanticLabel: tooltip,
      child: Container(
        padding: const EdgeInsets.all(CrispySpacing.sm),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
