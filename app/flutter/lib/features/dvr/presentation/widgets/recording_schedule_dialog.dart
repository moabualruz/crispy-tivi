import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../providers/dvr_providers.dart';
import '../../domain/entities/recording.dart';
import '../../domain/recording_quality.dart';
import 'auto_delete_policy_picker.dart';
import 'conflict_resolver_dialog.dart';

/// Shows the [RecordingScheduleDialog] to create a new DVR recording
/// with auto-delete policy and quality selection.
void showRecordingScheduleDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => RecordingScheduleDialog(ref: ref),
  );
}

/// Full-featured schedule dialog combining channel/time inputs,
/// auto-delete policy, and per-recording quality selection.
///
/// Replaces the minimal [ScheduleDialog] with a richer UX surface.
class RecordingScheduleDialog extends ConsumerStatefulWidget {
  /// Creates a [RecordingScheduleDialog].
  ///
  /// [ref] is forwarded from the caller to access providers.
  const RecordingScheduleDialog({required this.ref, super.key});

  /// The [WidgetRef] from the caller, used to access providers.
  final WidgetRef ref;

  @override
  ConsumerState<RecordingScheduleDialog> createState() =>
      _RecordingScheduleDialogState();
}

class _RecordingScheduleDialogState
    extends ConsumerState<RecordingScheduleDialog> {
  final _channelCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  late DateTime _startTime;
  late DateTime _endTime;
  bool _isRecurring = false;

  // FE-DVR-04: Auto-delete policy
  AutoDeletePolicy _autoDeletePolicy = AutoDeletePolicy.keepAll;
  int _keepEpisodeCount = 5;

  // FE-DVR-08: Per-recording quality
  RecordingQuality _quality = RecordingQuality.auto;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now().add(const Duration(minutes: 5));
    _endTime = _startTime.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _channelCtrl.dispose();
    _programCtrl.dispose();
    _urlCtrl.dispose();
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

  Future<void> _submit() async {
    if (_channelCtrl.text.isEmpty || _programCtrl.text.isEmpty) return;

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
        channelName: _channelCtrl.text,
        programName: _programCtrl.text,
        startTime: _startTime,
        endTime: _endTime,
        streamUrl: _urlCtrl.text.isEmpty ? null : _urlCtrl.text,
        isRecurring: _isRecurring,
        recurDays: _isRecurring ? 127 : 0,
      );

      if (resolution != ConflictResolution.cancelled && mounted) {
        Navigator.pop(context);
      }
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule Recording'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Channel & program ──────────────────────────
              TextField(
                controller: _channelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Channel Name',
                  prefixIcon: Icon(Icons.tv),
                ),
              ),
              const SizedBox(height: CrispySpacing.sm),
              TextField(
                controller: _programCtrl,
                decoration: const InputDecoration(
                  labelText: 'Program Name',
                  prefixIcon: Icon(Icons.movie),
                ),
              ),
              const SizedBox(height: CrispySpacing.sm),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Stream URL (optional)',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: CrispySpacing.md),
              // ── Time pickers ───────────────────────────────
              _SectionLabel('TIME'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text('Start: ${formatDMYHHmm(_startTime)}'),
                onTap: _pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text('End: ${formatDMYHHmm(_endTime)}'),
                onTap: _pickEnd,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring'),
                subtitle: const Text('Repeat daily at same time'),
                value: _isRecurring,
                onChanged: (v) => setState(() => _isRecurring = v),
              ),
              const SizedBox(height: CrispySpacing.md),
              // ── FE-DVR-08: Quality selection ───────────────
              _SectionLabel('RECORDING QUALITY'),
              const SizedBox(height: CrispySpacing.xs),
              _QualitySelector(
                value: _quality,
                onChanged: (q) => setState(() => _quality = q),
              ),
              const SizedBox(height: CrispySpacing.md),
              // ── FE-DVR-04: Auto-delete policy ─────────────
              _SectionLabel('AUTO-DELETE POLICY'),
              const SizedBox(height: CrispySpacing.xs),
              AutoDeletePolicyPicker(
                value: _autoDeletePolicy,
                keepEpisodeCount: _keepEpisodeCount,
                showLabel: false,
                maxKeepCount: 10,
                onChanged:
                    (policy, count) => setState(() {
                      _autoDeletePolicy = policy;
                      _keepEpisodeCount = count;
                    }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Schedule')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Quality selector widget
// ─────────────────────────────────────────────────────────

/// Horizontal segmented row for [RecordingQuality] selection.
class _QualitySelector extends StatelessWidget {
  const _QualitySelector({required this.value, required this.onChanged});

  final RecordingQuality value;
  final ValueChanged<RecordingQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Wrap(
      spacing: CrispySpacing.sm,
      children:
          RecordingQuality.values.map((q) {
            final selected = value == q;
            return ChoiceChip(
              label: Text(q.shortLabel),
              selected: selected,
              selectedColor: cs.primaryContainer,
              labelStyle: tt.labelMedium?.copyWith(
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              tooltip: q.description,
              onSelected: (_) => onChanged(q),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
              ),
            );
          }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Section label
// ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Text(
      text,
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Date/time picker helper
// ─────────────────────────────────────────────────────────

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
