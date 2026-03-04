import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../data/dvr_service.dart';
import '../../domain/entities/recording.dart';

// FE-DVR-02: Conflict detection dialog — shown from ScheduleDialog when
// DvrService.scheduleRecording() returns ScheduleResult.conflict.
// Presents existing and new recordings side-by-side; user can keep
// existing, replace with new, or cancel.

/// Resolution choice returned by [showConflictResolverDialog].
enum ConflictResolution {
  /// The user chose to keep the new recording and cancel the
  /// conflicting existing one.
  keepNew,

  /// The user chose to keep the existing recording and discard
  /// the new scheduling request.
  keepExisting,

  /// The user dismissed the dialog without making a choice.
  cancelled,
}

/// Shows the [ConflictResolverDialog] and returns the user's choice.
///
/// [conflictingRecordings] — scheduled recordings that overlap with
/// the proposed slot.
/// [newChannel] / [newProgram] / [newStart] / [newEnd] — details
/// of the recording the user is trying to schedule.
///
/// Returns a [ConflictResolution] indicating what the user chose.
Future<ConflictResolution> showConflictResolverDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<Recording> conflictingRecordings,
  required String newChannel,
  required String newProgram,
  required DateTime newStart,
  required DateTime newEnd,
  required String channelName,
  required String programName,
  required DateTime startTime,
  required DateTime endTime,
  String? channelId,
  String? channelLogoUrl,
  String? streamUrl,
  bool isRecurring = false,
  int recurDays = 0,
}) async {
  final result = await showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: true,
    builder:
        (_) => ConflictResolverDialog(
          ref: ref,
          conflictingRecordings: conflictingRecordings,
          newChannel: newChannel,
          newProgram: newProgram,
          newStart: newStart,
          newEnd: newEnd,
          channelName: channelName,
          programName: programName,
          startTime: startTime,
          endTime: endTime,
          channelId: channelId,
          channelLogoUrl: channelLogoUrl,
          streamUrl: streamUrl,
          isRecurring: isRecurring,
          recurDays: recurDays,
        ),
  );
  return result ?? ConflictResolution.cancelled;
}

/// Dialog shown when a new recording overlaps with one or more
/// existing scheduled recordings.
///
/// Presents both the existing and proposed recordings side-by-side
/// and lets the user decide which to keep.
class ConflictResolverDialog extends StatelessWidget {
  /// Creates a [ConflictResolverDialog].
  const ConflictResolverDialog({
    super.key,
    required this.ref,
    required this.conflictingRecordings,
    required this.newChannel,
    required this.newProgram,
    required this.newStart,
    required this.newEnd,
    required this.channelName,
    required this.programName,
    required this.startTime,
    required this.endTime,
    this.channelId,
    this.channelLogoUrl,
    this.streamUrl,
    this.isRecurring = false,
    this.recurDays = 0,
  });

  /// WidgetRef forwarded from the caller.
  final WidgetRef ref;

  /// Existing scheduled recordings that overlap with the new slot.
  final List<Recording> conflictingRecordings;

  // ── New recording details ──────────────────────────────
  final String newChannel;
  final String newProgram;
  final DateTime newStart;
  final DateTime newEnd;

  // ── Full scheduling params needed for force-schedule ──
  final String channelName;
  final String programName;
  final DateTime startTime;
  final DateTime endTime;
  final String? channelId;
  final String? channelLogoUrl;
  final String? streamUrl;
  final bool isRecurring;
  final int recurDays;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 22),
          const SizedBox(width: CrispySpacing.sm),
          const Text('Recording Conflict'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The new recording overlaps with '
                '${conflictingRecordings.length == 1 ? 'an existing' : '${conflictingRecordings.length} existing'} '
                'scheduled recording${conflictingRecordings.length > 1 ? 's' : ''}. '
                'Choose which to keep.',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: CrispySpacing.md),

              // ── New recording ──────────────────────────
              _SectionLabel(label: 'New recording', cs: cs),
              const SizedBox(height: CrispySpacing.xs),
              _RecordingTile(
                channelName: newChannel,
                programName: newProgram,
                start: newStart,
                end: newEnd,
                isNew: true,
                cs: cs,
                tt: tt,
              ),
              const SizedBox(height: CrispySpacing.md),

              // ── Conflicting recordings ─────────────────
              _SectionLabel(
                label:
                    conflictingRecordings.length == 1
                        ? 'Existing recording'
                        : 'Existing recordings',
                cs: cs,
              ),
              const SizedBox(height: CrispySpacing.xs),
              ...conflictingRecordings.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: CrispySpacing.xs),
                  child: _RecordingTile(
                    channelName: r.channelName,
                    programName: r.programName,
                    start: r.startTime,
                    end: r.endTime,
                    isNew: false,
                    cs: cs,
                    tt: tt,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictResolution.cancelled),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed:
              () => Navigator.pop(context, ConflictResolution.keepExisting),
          child: const Text('Keep Existing'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: () => _keepNew(context),
          child: const Text('Replace with New'),
        ),
      ],
    );
  }

  /// Force-schedules the new recording (removing conflicting ones)
  /// and closes the dialog.
  Future<void> _keepNew(BuildContext context) async {
    final notifier = ref.read(dvrServiceProvider.notifier);

    // Remove all conflicting recordings first.
    for (final r in conflictingRecordings) {
      await notifier.removeRecording(r.id);
    }

    // Force-schedule the new one (bypass conflict check).
    await notifier.forceScheduleRecording(
      channelName: channelName,
      programName: programName,
      startTime: startTime,
      endTime: endTime,
      channelId: channelId,
      channelLogoUrl: channelLogoUrl,
      streamUrl: streamUrl,
      isRecurring: isRecurring,
      recurDays: recurDays,
    );

    if (context.mounted) {
      Navigator.pop(context, ConflictResolution.keepNew);
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Internal helpers
// ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.channelName,
    required this.programName,
    required this.start,
    required this.end,
    required this.isNew,
    required this.cs,
    required this.tt,
  });

  final String channelName;
  final String programName;
  final DateTime start;
  final DateTime end;
  final bool isNew;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final accentColor = isNew ? cs.primary : cs.secondary;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: accentColor.withAlpha(80)),
        borderRadius: BorderRadius.circular(CrispyRadius.md),
        color: accentColor.withAlpha(20),
      ),
      padding: const EdgeInsets.all(CrispySpacing.sm),
      child: Row(
        children: [
          Icon(
            isNew ? Icons.add_circle_outline : Icons.schedule,
            color: accentColor,
            size: 18,
          ),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  programName,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$channelName  ·  '
                  '${formatDMYHHmm(start)} – ${formatHHmm(end)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
