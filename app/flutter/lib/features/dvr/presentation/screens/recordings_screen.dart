import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_state_widget.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../providers/dvr_providers.dart';
import '../widgets/keyword_rule_dialog.dart';
import '../widgets/recording_list.dart';
import '../widgets/recording_search_delegate.dart';
import '../widgets/recordings_tv_layout.dart';
import '../widgets/schedule_dialog.dart';
import '../widgets/storage_bar.dart';
import '../widgets/storage_breakdown_sheet.dart';
import '../widgets/transfer_list.dart';

/// DVR recordings screen — list of scheduled, in-progress,
/// and completed recordings with storage monitor and
/// schedule dialog.
class RecordingsScreen extends ConsumerWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dvrServiceProvider);

    return stateAsync.when(
      loading: () => const Scaffold(body: LoadingStateWidget()),
      error:
          (err, _) =>
              Scaffold(body: ErrorStateWidget(message: 'DVR error: $err')),
      data: (state) => _DvrScaffold(state: state),
    );
  }
}

// FE-DVR-05: Grouped-by-show view toggle state lives here.
class _DvrScaffold extends ConsumerStatefulWidget {
  const _DvrScaffold({required this.state});

  final DvrState state;

  @override
  ConsumerState<_DvrScaffold> createState() => _DvrScaffoldState();
}

class _DvrScaffoldState extends ConsumerState<_DvrScaffold> {
  // FE-DVR-05: flat list (false) or grouped-by-show (true).
  bool _groupedView = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: TestKeys.dvrScreen,
        appBar: AppBar(
          title: const Text('Recordings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Scheduled'),
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
              Tab(
                key: TestKeys.tabCloudStorage,
                icon: Icon(Icons.cloud_upload, size: 18),
                text: 'Transfers',
              ),
            ],
          ),
          actions: [
            // FE-DVR-05: Toggle flat / grouped-by-show view.
            Tooltip(
              message: _groupedView ? 'Flat list' : 'Group by show',
              child: IconButton(
                icon: Icon(
                  _groupedView
                      ? Icons.format_list_bulleted
                      : Icons.folder_copy_outlined,
                ),
                onPressed: () => setState(() => _groupedView = !_groupedView),
              ),
            ),
            // FE-DVR-06: DVR-internal recording search
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search recordings',
              onPressed: () => showRecordingSearch(context, ref),
            ),
            // Keyword rules shortcut
            IconButton(
              icon: const Icon(Icons.manage_search),
              tooltip: 'Keyword Rules',
              onPressed: () => showKeywordRulesSheet(context),
            ),
            // Storage breakdown button
            Padding(
              padding: const EdgeInsets.only(right: CrispySpacing.sm),
              child: ActionChip(
                avatar: const Icon(Icons.storage, size: 16),
                label: Text(
                  state.totalStorageMB,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                tooltip: 'Storage Breakdown',
                onPressed: () => showStorageBreakdownSheet(context),
              ),
            ),
          ],
        ),
        body: ScreenTemplate(
          focusRestorationKey: 'recordings',
          compactBody: Column(
            children: [
              // FE-DVR-10: Storage bar — tapping opens the breakdown sheet.
              if (state.totalStorageBytes > 0)
                StorageBar(
                  totalBytes: state.totalStorageBytes,
                  onTap: () => showStorageBreakdownSheet(context),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    RecordingList(
                      recordings: state.scheduled,
                      emptyMessage: 'No scheduled recordings',
                      emptyIcon: Icons.schedule,
                      showScheduleCta: true,
                      // FE-DVR-05
                      groupedView: _groupedView,
                    ),
                    RecordingList(
                      recordings: state.inProgress,
                      emptyMessage: 'No active recordings',
                      emptyIcon: Icons.fiber_manual_record,
                      // FE-DVR-05
                      groupedView: _groupedView,
                    ),
                    RecordingList(
                      recordings: state.completed,
                      emptyMessage: 'No completed recordings',
                      emptyIcon: Icons.check_circle_outline,
                      // FE-DVR-05
                      groupedView: _groupedView,
                    ),
                    const TransferList(),
                  ],
                ),
              ),
            ],
          ),
          largeBody: RecordingsTvLayout(
            state: state,
            groupedView: _groupedView,
          ),
        ),
        floatingActionButton: _DvrSpeedDial(state: state),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Speed-dial FAB
// ─────────────────────────────────────────────────────────

/// Expandable FAB providing three DVR actions:
/// - Schedule a new recording
/// - Manage keyword auto-record rules
/// - View storage breakdown
class _DvrSpeedDial extends ConsumerStatefulWidget {
  const _DvrSpeedDial({required this.state});

  final DvrState state;

  @override
  ConsumerState<_DvrSpeedDial> createState() => _DvrSpeedDialState();
}

class _DvrSpeedDialState extends ConsumerState<_DvrSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: CrispyAnimation.osdShow);
    _rotate = Tween<double>(
      begin: 0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  void _close() {
    if (_open) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini actions (visible when open)
        if (_open) ...[
          _MiniAction(
            icon: Icons.storage,
            label: 'Storage',
            onPressed: () {
              _close();
              showStorageBreakdownSheet(context);
            },
          ),
          const SizedBox(height: CrispySpacing.sm),
          _MiniAction(
            icon: Icons.manage_search,
            label: 'Keyword Rules',
            onPressed: () {
              _close();
              showKeywordRulesSheet(context);
            },
          ),
          const SizedBox(height: CrispySpacing.sm),
          _MiniAction(
            icon: Icons.schedule,
            label: 'Schedule',
            onPressed: () {
              _close();
              showScheduleDialog(context, ref);
            },
          ),
          const SizedBox(height: CrispySpacing.sm),
        ],
        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          tooltip: _open ? 'Close' : 'DVR Actions',
          child: RotationTransition(
            turns: _rotate,
            child: Icon(_open ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }
}

/// A small labelled action button used in the speed dial.
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label card
        Card(
          margin: EdgeInsets.zero,
          color: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.sm,
              vertical: CrispySpacing.xs,
            ),
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(color: cs.onSurface),
            ),
          ),
        ),
        const SizedBox(width: CrispySpacing.sm),
        // Mini FAB
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onPressed,
          tooltip: label,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}
