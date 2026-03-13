import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/tv_master_detail_layout.dart';
import '../../data/dvr_service.dart';
import 'recording_list.dart';
import 'storage_bar.dart';
import 'storage_breakdown_sheet.dart';
import 'transfer_list.dart';

/// TV master-detail layout for the Recordings screen.
///
/// Master panel: recording list from the active tab.
/// Detail panel: recording preview and metadata (empty state when none selected).
class RecordingsTvLayout extends StatelessWidget {
  /// Creates the recordings TV layout.
  const RecordingsTvLayout({
    required this.state,
    required this.groupedView,
    super.key,
  });

  /// Current DVR state with recordings.
  final DvrState state;

  /// Whether the grouped-by-show view is active.
  final bool groupedView;

  @override
  Widget build(BuildContext context) {
    return TvMasterDetailLayout(
      masterPanel: FocusTraversalGroup(
        child: Column(
          children: [
            if (state.totalStorageBytes > 0)
              StorageBar(
                totalBytes: state.totalStorageBytes,
                onTap: () => showStorageBreakdownSheet(context),
              ),
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Scheduled'),
                        Tab(text: 'In Progress'),
                        Tab(text: 'Completed'),
                        Tab(text: 'Transfers'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          RecordingList(
                            recordings: state.scheduled,
                            emptyMessage: 'No scheduled recordings',
                            emptyIcon: Icons.schedule,
                            showScheduleCta: true,
                            groupedView: groupedView,
                          ),
                          RecordingList(
                            recordings: state.inProgress,
                            emptyMessage: 'No active recordings',
                            emptyIcon: Icons.fiber_manual_record,
                            groupedView: groupedView,
                          ),
                          RecordingList(
                            recordings: state.completed,
                            emptyMessage: 'No completed recordings',
                            emptyIcon: Icons.check_circle_outline,
                            groupedView: groupedView,
                          ),
                          const TransferList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      detailPanel: const _RecordingsDetailPanel(),
    );
  }
}

class _RecordingsDetailPanel extends StatelessWidget {
  const _RecordingsDetailPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_outlined,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: CrispySpacing.md),
          Text(
            'Select a recording',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          Text(
            'Choose a recording to see details and playback options',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
