// FE-EPG-02

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/utils/date_format_utils.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../domain/entities/epg_entry.dart';
import '../../domain/entities/epg_reminder.dart';

// ── Provider ──────────────────────────────────────────────────

/// FE-EPG-02: Manages the list of user-set EPG reminders.
///
/// Reminders are sorted by [EpgReminder.startTime] ascending.
/// Expired reminders (programme has started > 1 h ago) are
/// pruned automatically on each state write.
class EpgReminderNotifier extends Notifier<List<EpgReminder>> {
  @override
  List<EpgReminder> build() => const [];

  /// Adds a reminder for [entry] on [channelId] / [channelName].
  ///
  /// No-op if a reminder already exists for the same program.
  void addReminder({
    required EpgEntry entry,
    required String channelId,
    required String channelName,
  }) {
    final id = '${channelId}_${entry.startTime.millisecondsSinceEpoch}';
    if (state.any((r) => r.programId == id)) return;

    final reminder = EpgReminder(
      channelId: channelId,
      programId: id,
      startTime: entry.startTime,
      title: entry.title,
      channelName: channelName,
    );

    final updated = [reminder, ...state]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    state = _prune(updated);
  }

  /// Removes the reminder with [programId].
  void removeReminder(String programId) {
    state = _prune(state.where((r) => r.programId != programId).toList());
  }

  /// Returns true when a reminder exists for [programId].
  bool hasReminder(String programId) =>
      state.any((r) => r.programId == programId);

  /// Removes reminders whose programme started more than 1 h ago.
  List<EpgReminder> _prune(List<EpgReminder> reminders) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    return reminders.where((r) => r.startTime.isAfter(cutoff)).toList();
  }

  // ── Notification stub (FE-EPG-02) ─────────────────────────

  /// Checks all upcoming reminders and returns those that are due
  /// (≤ 5 min before programme start).
  ///
  /// TODO(BACKLOG): wire flutter_local_notifications — notification feature.
  /// Show a system notification when a reminder becomes due.
  List<EpgReminder> getDueReminders() {
    final now = DateTime.now().toUtc();
    return state.where((r) => r.isDue(now)).toList();
  }
}

/// Global provider for [EpgReminderNotifier].
// FE-EPG-02
final epgReminderProvider =
    NotifierProvider<EpgReminderNotifier, List<EpgReminder>>(
      EpgReminderNotifier.new,
    );

// ── Set-Reminder button widget ─────────────────────────────────

/// FE-EPG-02: Small icon button shown on EPG programme detail popups.
///
/// Toggles the reminder for [entry] on [channelId] / [channelName].
/// Renders a filled bell icon when a reminder is set, outline otherwise.
class EpgReminderToggleButton extends ConsumerWidget {
  const EpgReminderToggleButton({
    required this.entry,
    required this.channelId,
    required this.channelName,
    super.key,
  });

  final EpgEntry entry;
  final String channelId;
  final String channelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programId = '${channelId}_${entry.startTime.millisecondsSinceEpoch}';
    final reminders = ref.watch(epgReminderProvider);
    final hasReminder = reminders.any((r) => r.programId == programId);
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: hasReminder ? 'Remove reminder' : 'Set reminder',
      child: IconButton(
        icon: Icon(
          hasReminder ? Icons.notifications_active : Icons.notifications_none,
          color: hasReminder ? cs.primary : cs.onSurfaceVariant,
        ),
        onPressed: () {
          if (hasReminder) {
            ref.read(epgReminderProvider.notifier).removeReminder(programId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reminder removed for "${entry.title}"'),
                duration: CrispyAnimation.snackBarDuration,
              ),
            );
          } else {
            ref
                .read(epgReminderProvider.notifier)
                .addReminder(
                  entry: entry,
                  channelId: channelId,
                  channelName: channelName,
                );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Reminder set for "${entry.title}"'),
                duration: CrispyAnimation.snackBarDuration,
              ),
            );
          }
        },
      ),
    );
  }
}

// ── Bell indicator badge ───────────────────────────────────────

/// FE-EPG-02: Tiny bell icon shown on EPG programme blocks that have
/// an active reminder. Displayed as an overlay on the programme tile.
class EpgReminderBell extends ConsumerWidget {
  const EpgReminderBell({
    required this.channelId,
    required this.startTime,
    super.key,
  });

  final String channelId;
  final DateTime startTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programId = '${channelId}_${startTime.millisecondsSinceEpoch}';
    final reminders = ref.watch(epgReminderProvider);
    final hasReminder = reminders.any((r) => r.programId == programId);

    if (!hasReminder) return const SizedBox.shrink();

    return Icon(
      Icons.notifications_active,
      size: 12,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

// ── Reminder management sheet ──────────────────────────────────

/// FE-EPG-02: Bottom sheet listing all upcoming reminders.
///
/// Supports swipe-to-delete. Shows sorted upcoming reminders only
/// (past reminders are pruned automatically). Empty state is shown
/// when there are no reminders.
///
/// Open via [showEpgReminderSheet].
class EpgReminderSheet extends ConsumerWidget {
  const EpgReminderSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(epgReminderProvider);
    final now = DateTime.now().toUtc();
    final upcoming =
        reminders.where((r) => !r.isPast(now)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder:
          (ctx, scrollController) => Column(
            children: [
              // ── Handle ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CrispySpacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(CrispyRadius.full),
                  ),
                ),
              ),

              // ── Title row ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: cs.primary,
                      size: 20,
                    ),
                    const SizedBox(width: CrispySpacing.sm),
                    Text(
                      'Reminders',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (upcoming.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          for (final r in upcoming) {
                            ref
                                .read(epgReminderProvider.notifier)
                                .removeReminder(r.programId);
                          }
                        },
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Content ──
              Expanded(
                child:
                    upcoming.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 48,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(height: CrispySpacing.sm),
                              Text(
                                'No reminders set',
                                style: tt.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: CrispySpacing.xs),
                              Text(
                                'Tap the bell icon on any EPG programme to '
                                'set a reminder.',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: upcoming.length,
                          itemBuilder: (_, index) {
                            final reminder = upcoming[index];
                            return _ReminderTile(
                              reminder: reminder,
                              onDismiss:
                                  () => ref
                                      .read(epgReminderProvider.notifier)
                                      .removeReminder(reminder.programId),
                            );
                          },
                        ),
              ),
            ],
          ),
    );
  }
}

/// Opens [EpgReminderSheet] as a modal bottom sheet.
// FE-EPG-02
Future<void> showEpgReminderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(CrispyRadius.lg),
      ),
    ),
    builder: (_) => const EpgReminderSheet(),
  );
}

// ── Reminder tile ──────────────────────────────────────────────

/// A single upcoming reminder row with swipe-to-delete.
class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.onDismiss});

  final EpgReminder reminder;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final local = reminder.startTime.toLocal();
    final timeStr = formatHHmm(local);
    final dateStr =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';

    return Dismissible(
      key: ValueKey(reminder.programId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: CrispySpacing.md),
        color: cs.error,
        child: Icon(Icons.delete_outline, color: cs.onError),
      ),
      onDismissed: (_) => onDismiss(),
      child: FocusWrapper(
        onSelect: onDismiss,
        semanticLabel: 'Remove reminder for ${reminder.title}',
        borderRadius: CrispyRadius.none,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
            ),
            child: Icon(
              Icons.notifications_active,
              color: cs.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            reminder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${reminder.channelName} · $dateStr $timeStr',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: IconButton(
            icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            tooltip: 'Remove',
            onPressed: onDismiss,
          ),
        ),
      ),
    );
  }
}
