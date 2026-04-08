import 'package:flutter/material.dart';

import '../providers/dvr_providers.dart';
import 'recording_list.dart';
import 'storage_bar.dart';
import 'storage_breakdown_sheet.dart';
import 'transfer_list.dart';

/// TV layout for the Recordings screen.
///
/// Full-width tab content — recordings navigate directly to
/// their detail/playback screens on selection.
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
    return FocusTraversalGroup(
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
    );
  }
}
