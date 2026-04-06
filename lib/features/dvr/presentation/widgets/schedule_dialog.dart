import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../providers/dvr_providers.dart';
import '../../domain/entities/recording.dart';
import 'auto_delete_policy_picker.dart';
import 'conflict_resolver_dialog.dart';

/// Shows the [ScheduleDialog] to create a new DVR recording.
void showScheduleDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(context: context, builder: (_) => ScheduleDialog(ref: ref));
}

/// Dialog for scheduling a new DVR recording.
///
/// Contains two tabs:
/// - **Schedule**: channel/program/time fields with conflict detection
///   (FE-DVR-02) and auto-delete policy.
/// - **Auto-Record** (FE-DVR-07): keyword rule builder with channel
///   filter and EPG category filter, stored in [keywordRuleProvider].
///
/// If the requested time slot conflicts with an existing scheduled
/// recording, a [ConflictResolverDialog] is shown so the user can
/// choose which recording to keep.
class ScheduleDialog extends ConsumerStatefulWidget {
  /// Creates a [ScheduleDialog].
  ///
  /// [ref] is forwarded from the calling [ConsumerWidget] so the
  /// dialog can invoke [dvrServiceProvider] methods without
  /// needing its own [ProviderScope] ancestry.
  const ScheduleDialog({required this.ref, super.key});

  /// The [WidgetRef] from the caller, used to access providers.
  final WidgetRef ref;

  @override
  ConsumerState<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<ScheduleDialog>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ───────────────────────────────────
  late final TabController _tabCtrl;

  // ── Schedule tab state ───────────────────────────────
  final _channelCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  late DateTime _startTime;
  late DateTime _endTime;
  bool _isRecurring = false;
  AutoDeletePolicy _autoDeletePolicy = AutoDeletePolicy.keepAll;
  int _keepEpisodeCount = 5;

  // FE-DVR-01: Series auto-record — records all future episodes of the show.
  bool _recordAllEpisodes = false;

  // ── FE-DVR-07: Auto-Record tab state ─────────────────
  final _kwKeywordCtrl = TextEditingController();
  final _kwChannelCtrl = TextEditingController();
  KeywordMatchField _kwMatchField = KeywordMatchField.any;
  String? _kwCategoryFilter;
  bool _kwSaved = false;

  static const _epgCategories = [
    'Movies',
    'Series',
    'Sports',
    'News',
    'Kids',
    'Documentary',
    'Music',
    'Entertainment',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _startTime = DateTime.now().add(const Duration(minutes: 5));
    _endTime = _startTime.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _channelCtrl.dispose();
    _programCtrl.dispose();
    _urlCtrl.dispose();
    _kwKeywordCtrl.dispose();
    _kwChannelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(context, _startTime);
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(context, _endTime);
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  // FE-DVR-02: Conflict detection — delegates to DvrService which
  // calls the Rust backend for overlap detection, then shows
  // ConflictResolverDialog when a conflict is found.
  Future<void> _submit() async {
    if (_channelCtrl.text.isEmpty || _programCtrl.text.isEmpty) return;

    // FE-DVR-01: If "Record All Episodes" is enabled, save a keyword rule
    // that matches the program name so all future episodes are recorded.
    if (_recordAllEpisodes) {
      final seriesRule = KeywordRule(
        id: 'series_${DateTime.now().millisecondsSinceEpoch}',
        keyword: _programCtrl.text.trim(),
        matchField: KeywordMatchField.title,
        channelFilter:
            _channelCtrl.text.trim().isEmpty ? null : _channelCtrl.text.trim(),
      );
      await widget.ref.read(keywordRuleProvider.notifier).addRule(seriesRule);
    }

    final notifier = widget.ref.read(dvrServiceProvider.notifier);

    final result = await notifier.scheduleRecording(
      channelName: _channelCtrl.text,
      programName: _programCtrl.text,
      startTime: _startTime,
      endTime: _endTime,
      streamUrl: _urlCtrl.text.isEmpty ? null : _urlCtrl.text,
      isRecurring: _isRecurring,
      recurDays: _isRecurring ? 127 : 0,
    );

    if (result == ScheduleResult.conflict && mounted) {
      // Gather the specific recordings that conflict.
      final conflicts = notifier.getConflictingRecordings(
        startTime: _startTime,
        endTime: _endTime,
      );

      final resolution = await showConflictResolverDialog(
        context: context,
        ref: widget.ref,
        conflictingRecordings: conflicts,
        newChannel: _channelCtrl.text,
        newProgram: _programCtrl.text,
        newStart: _startTime,
        newEnd: _endTime,
        // Full params for force-schedule inside the dialog.
        channelName: _channelCtrl.text,
        programName: _programCtrl.text,
        startTime: _startTime,
        endTime: _endTime,
        streamUrl: _urlCtrl.text.isEmpty ? null : _urlCtrl.text,
        isRecurring: _isRecurring,
        recurDays: _isRecurring ? 127 : 0,
      );

      // Close the schedule dialog only if the user resolved the conflict.
      if (resolution != ConflictResolution.cancelled && mounted) {
        Navigator.pop(context);
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// FE-DVR-07: Saves the keyword auto-record rule to [keywordRuleProvider].
  Future<void> _saveKeywordRule() async {
    // FE-DVR-07
    final keyword = _kwKeywordCtrl.text.trim();
    if (keyword.isEmpty) return;

    final channel = _kwChannelCtrl.text.trim();
    final rule = KeywordRule(
      id: 'kw_${DateTime.now().millisecondsSinceEpoch}',
      keyword: keyword,
      matchField: _kwMatchField,
      channelFilter: channel.isEmpty ? null : channel,
    );

    await widget.ref.read(keywordRuleProvider.notifier).addRule(rule);

    if (mounted) {
      setState(() => _kwSaved = true);
      // Brief success feedback before closing.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-record rule saved for "$keyword"'),
          behavior: SnackBarBehavior.floating,
          duration: CrispyAnimation.snackBarDuration,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog header ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CrispySpacing.md,
                CrispySpacing.md,
                CrispySpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'DVR',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Tab bar ────────────────────────────────
            TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(icon: Icon(Icons.schedule, size: 18), text: 'Schedule'),
                Tab(
                  icon: Icon(Icons.manage_search, size: 18),
                  text: 'Auto-Record',
                ),
              ],
            ),
            // ── Tab content ───────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // FE-DVR-01
                  _ScheduleTab(
                    channelCtrl: _channelCtrl,
                    programCtrl: _programCtrl,
                    urlCtrl: _urlCtrl,
                    startTime: _startTime,
                    endTime: _endTime,
                    isRecurring: _isRecurring,
                    autoDeletePolicy: _autoDeletePolicy,
                    keepEpisodeCount: _keepEpisodeCount,
                    recordAllEpisodes: _recordAllEpisodes,
                    onPickStart: _pickStart,
                    onPickEnd: _pickEnd,
                    onRecurringChanged: (v) => setState(() => _isRecurring = v),
                    onPolicyChanged:
                        (p, c) => setState(() {
                          _autoDeletePolicy = p;
                          _keepEpisodeCount = c;
                        }),
                    onRecordAllEpisodesChanged:
                        (v) => setState(() => _recordAllEpisodes = v),
                  ),
                  // FE-DVR-07: Auto-Record keyword rule builder tab.
                  _AutoRecordTab(
                    keywordCtrl: _kwKeywordCtrl,
                    channelCtrl: _kwChannelCtrl,
                    matchField: _kwMatchField,
                    categoryFilter: _kwCategoryFilter,
                    epgCategories: _epgCategories,
                    onMatchFieldChanged:
                        (f) => setState(() => _kwMatchField = f),
                    onCategoryChanged:
                        (c) => setState(() => _kwCategoryFilter = c),
                    cs: cs,
                  ),
                ],
              ),
            ),
            // ── Actions ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(CrispySpacing.sm),
              child: ListenableBuilder(
                listenable: _tabCtrl,
                builder:
                    (context, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: CrispySpacing.sm),
                        if (_tabCtrl.index == 0)
                          FilledButton(
                            onPressed: _submit,
                            child: const Text('Schedule'),
                          )
                        else
                          FilledButton(
                            onPressed: _kwSaved ? null : _saveKeywordRule,
                            child: const Text('Save Rule'),
                          ),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Schedule tab content
// ─────────────────────────────────────────────────────────

/// Content for the "Schedule" tab of [ScheduleDialog].
class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.channelCtrl,
    required this.programCtrl,
    required this.urlCtrl,
    required this.startTime,
    required this.endTime,
    required this.isRecurring,
    required this.autoDeletePolicy,
    required this.keepEpisodeCount,
    // FE-DVR-01
    required this.recordAllEpisodes,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRecurringChanged,
    required this.onPolicyChanged,
    // FE-DVR-01
    required this.onRecordAllEpisodesChanged,
  });

  final TextEditingController channelCtrl;
  final TextEditingController programCtrl;
  final TextEditingController urlCtrl;
  final DateTime startTime;
  final DateTime endTime;
  final bool isRecurring;
  final AutoDeletePolicy autoDeletePolicy;
  final int keepEpisodeCount;

  /// FE-DVR-01: When true, creates a keyword rule to record all future
  /// episodes matching the program name.
  final bool recordAllEpisodes;

  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<bool> onRecurringChanged;
  final void Function(AutoDeletePolicy policy, int count) onPolicyChanged;

  /// FE-DVR-01
  final ValueChanged<bool> onRecordAllEpisodesChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: channelCtrl,
            decoration: const InputDecoration(
              labelText: 'Channel Name',
              prefixIcon: Icon(Icons.tv),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          TextField(
            controller: programCtrl,
            decoration: const InputDecoration(
              labelText: 'Program Name',
              prefixIcon: Icon(Icons.movie),
            ),
          ),
          const SizedBox(height: CrispySpacing.sm),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Stream URL (optional)',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: CrispySpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: Text('Start: ${formatDMYHHmm(startTime)}'),
            onTap: onPickStart,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: Text('End: ${formatDMYHHmm(endTime)}'),
            onTap: onPickEnd,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurring'),
            subtitle: const Text('Repeat daily at same time'),
            value: isRecurring,
            onChanged: onRecurringChanged,
          ),
          // FE-DVR-01: Series auto-record — records all future episodes.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.subscriptions_outlined),
            title: const Text('Record All Episodes'),
            subtitle: const Text(
              'Auto-record all future episodes of this show',
            ),
            value: recordAllEpisodes,
            onChanged: onRecordAllEpisodesChanged,
          ),
          const SizedBox(height: CrispySpacing.sm),
          AutoDeletePolicyPicker(
            value: autoDeletePolicy,
            keepEpisodeCount: keepEpisodeCount,
            onChanged: onPolicyChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  FE-DVR-07: Auto-Record tab content
// ─────────────────────────────────────────────────────────

/// FE-DVR-07: Keyword auto-record rule builder tab.
///
/// Fields:
/// - [keyword]: text to match against EPG programs.
/// - [channelCtrl]: optional channel name filter.
/// - [matchField]: title-only / description-only / either.
/// - [categoryFilter]: optional EPG category drop-down.
///
/// Saving creates a [KeywordRule] in [keywordRuleProvider]
/// (pure UI state — no Rust backend call required).
class _AutoRecordTab extends StatelessWidget {
  const _AutoRecordTab({
    required this.keywordCtrl,
    required this.channelCtrl,
    required this.matchField,
    required this.categoryFilter,
    required this.epgCategories,
    required this.onMatchFieldChanged,
    required this.onCategoryChanged,
    required this.cs,
  });

  final TextEditingController keywordCtrl;
  final TextEditingController channelCtrl;
  final KeywordMatchField matchField;
  final String? categoryFilter;
  final List<String> epgCategories;
  final ValueChanged<KeywordMatchField> onMatchFieldChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    // FE-DVR-07
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(CrispySpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto-record any program whose EPG info matches the '
            'keyword you enter below.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.md),

          // ── Keyword input ────────────────────────────
          TextField(
            controller: keywordCtrl,
            autofocus: false,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Keyword',
              hintText: 'e.g. Formula 1',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: CrispySpacing.md),

          // ── Match field ──────────────────────────────
          Text(
            'MATCH IN',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          SegmentedButton<KeywordMatchField>(
            segments:
                KeywordMatchField.values
                    .map(
                      (f) => ButtonSegment<KeywordMatchField>(
                        value: f,
                        label: Text(f.label),
                      ),
                    )
                    .toList(),
            selected: {matchField},
            onSelectionChanged: (sel) => onMatchFieldChanged(sel.first),
            style: ButtonStyle(
              textStyle: WidgetStatePropertyAll(tt.labelSmall),
            ),
          ),
          const SizedBox(height: CrispySpacing.md),

          // ── Channel filter ───────────────────────────
          TextField(
            controller: channelCtrl,
            decoration: const InputDecoration(
              labelText: 'Channel Filter (optional)',
              hintText: 'Leave blank to match all channels',
              prefixIcon: Icon(Icons.tv),
            ),
          ),
          const SizedBox(height: CrispySpacing.md),

          // ── EPG category filter ──────────────────────
          Text(
            'EPG CATEGORY (OPTIONAL)',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline.withAlpha(80)),
              borderRadius: BorderRadius.circular(CrispyRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CrispySpacing.sm,
              vertical: CrispySpacing.xs,
            ),
            child: DropdownButton<String?>(
              value: categoryFilter,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Any category'),
              items: [
                const DropdownMenuItem<String?>(child: Text('Any category')),
                ...epgCategories.map(
                  (cat) =>
                      DropdownMenuItem<String?>(value: cat, child: Text(cat)),
                ),
              ],
              onChanged: onCategoryChanged,
            ),
          ),
          const SizedBox(height: CrispySpacing.md),

          // ── Info chip ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(CrispySpacing.sm),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(60),
              borderRadius: BorderRadius.circular(CrispyRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: cs.onPrimaryContainer,
                ),
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Text(
                    'Rules are matched against future EPG data. '
                    'Recordings will be scheduled automatically when '
                    'a match is found.',
                    style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
