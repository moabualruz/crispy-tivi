import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/recording.dart';
import 'recording_card.dart';
import 'schedule_dialog.dart';

/// Scrollable list of [Recording]s with an empty-state
/// placeholder when the list is empty.
///
/// When [showScheduleCta] is `true` (default for the
/// Scheduled tab) the empty state also shows a button
/// to open the schedule dialog.
///
/// When [groupedView] is `true` (FE-DVR-05), recordings are
/// grouped by show name. Each group shows a sticky header with
/// the show name and episode count; tapping the header
/// expands/collapses that group.
class RecordingList extends ConsumerStatefulWidget {
  /// Creates a recording list.
  const RecordingList({
    super.key,
    required this.recordings,
    required this.emptyMessage,
    required this.emptyIcon,
    this.showScheduleCta = false,
    // FE-DVR-05
    this.groupedView = false,
  });

  /// Recordings to display.
  final List<Recording> recordings;

  /// Message shown when [recordings] is empty.
  final String emptyMessage;

  /// Icon shown alongside [emptyMessage].
  final IconData emptyIcon;

  /// When true, shows a "Schedule a recording" button in the
  /// empty state.
  final bool showScheduleCta;

  /// FE-DVR-05: When true, recordings are grouped by show name.
  final bool groupedView;

  @override
  ConsumerState<RecordingList> createState() => _RecordingListState();
}

class _RecordingListState extends ConsumerState<RecordingList> {
  // FE-DVR-05: tracks which group titles are collapsed.
  final Set<String> _collapsed = {};

  void _toggleGroup(String title) {
    setState(() {
      if (_collapsed.contains(title)) {
        _collapsed.remove(title);
      } else {
        _collapsed.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.emptyIcon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(widget.emptyMessage),
            if (widget.showScheduleCta) ...[
              const SizedBox(height: CrispySpacing.md),
              FilledButton.icon(
                onPressed: () => showScheduleDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Schedule a recording'),
              ),
            ],
          ],
        ),
      );
    }

    if (widget.groupedView) {
      return _GroupedRecordingList(
        recordings: widget.recordings,
        collapsed: _collapsed,
        onToggleGroup: _toggleGroup,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(CrispySpacing.md),
      itemCount: widget.recordings.length,
      itemBuilder: (context, index) {
        final rec = widget.recordings[index];
        return RecordingCard(recording: rec);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  FE-DVR-05: Grouped-by-show recording list
// ─────────────────────────────────────────────────────────

/// FE-DVR-05: Renders [recordings] as collapsible groups keyed by
/// [Recording.programName]. Each group header shows the show name
/// and episode count. Tapping the header expands/collapses the group.
class _GroupedRecordingList extends StatelessWidget {
  const _GroupedRecordingList({
    required this.recordings,
    required this.collapsed,
    required this.onToggleGroup,
  });

  final List<Recording> recordings;
  final Set<String> collapsed;
  final ValueChanged<String> onToggleGroup;

  /// Builds a map of show title → list of recordings.
  Map<String, List<Recording>> _groupByShow() {
    final groups = <String, List<Recording>>{};
    for (final rec in recordings) {
      (groups[rec.programName] ??= []).add(rec);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final groups = _groupByShow();
    final titles = groups.keys.toList();

    // FE-DVR-05: CustomScrollView with per-group SliverList.
    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: CrispySpacing.sm)),
        for (final title in titles) ...[
          // Group header
          SliverToBoxAdapter(
            child: _GroupHeader(
              title: title,
              episodeCount: groups[title]!.length,
              isCollapsed: collapsed.contains(title),
              onTap: () => onToggleGroup(title),
              cs: cs,
              tt: tt,
            ),
          ),
          // Group episodes (hidden when collapsed)
          if (!collapsed.contains(title))
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.md),
              sliver: SliverList.builder(
                itemCount: groups[title]!.length,
                itemBuilder:
                    (_, i) => RecordingCard(recording: groups[title]![i]),
              ),
            ),
        ],
      ],
    );
  }
}

/// FE-DVR-05: Sticky-style header for a show group.
///
/// Shows the show name, episode count badge, and a chevron
/// that rotates when collapsed.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.episodeCount,
    required this.isCollapsed,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final String title;
  final int episodeCount;
  final bool isCollapsed;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    // FE-DVR-05
    return Semantics(
      button: true,
      label: 'Toggle group',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CrispySpacing.sm),
              // Episode count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.sm,
                  vertical: CrispySpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                ),
                child: Text(
                  '$episodeCount ep',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: CrispySpacing.xs),
              // Animated chevron
              AnimatedRotation(
                turns: isCollapsed ? -0.25 : 0,
                duration: CrispyAnimation.osdShow,
                child: Icon(
                  Icons.expand_more,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
