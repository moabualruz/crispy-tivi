import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/utils/date_format_utils.dart';

/// In-app notification service for toasts, status
/// updates, and EPG program reminders.
///
/// Uses an overlay-based approach that works across
/// all platforms including web. Persists reminders
/// to database for cross-session recovery.
class NotificationService extends Notifier<NotificationState> {
  Timer? _reminderTimer;
  CacheService? _cache;

  @override
  NotificationState build() {
    _cache = ref.read(cacheServiceProvider);

    // Load reminders from database on startup.
    _loadRemindersFromDb();

    // Poll for upcoming reminders every 60s.
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkReminders(),
    );
    ref.onDispose(() => _reminderTimer?.cancel());
    return const NotificationState();
  }

  /// Load reminders from database (unfired only).
  Future<void> _loadRemindersFromDb() async {
    if (_cache == null) return;
    final maps = await _cache!.loadReminders();
    final reminders = maps.map(_mapToReminder).toList();
    state = state.copyWith(reminders: reminders);
  }

  /// Show a transient toast message.
  void showToast(String message, {ToastType type = ToastType.info}) {
    final toast = AppToast(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(toasts: [...state.toasts, toast]);

    // Auto-dismiss after 4 seconds.
    Future.delayed(const Duration(seconds: 4), () {
      dismissToast(toast.id);
    });
  }

  /// Dismiss a specific toast.
  void dismissToast(String id) {
    state = state.copyWith(
      toasts: state.toasts.where((t) => t.id != id).toList(),
    );
  }

  /// Schedule a reminder for a program.
  void addReminder({
    required String programName,
    required String channelName,
    required DateTime startTime,
  }) {
    final reminder = ProgramReminder(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      programName: programName,
      channelName: channelName,
      startTime: startTime,
      notifyAt: startTime.subtract(const Duration(minutes: 5)),
    );
    state = state.copyWith(reminders: [...state.reminders, reminder]);

    // Persist to database.
    _cache?.saveReminder(_reminderToMap(reminder));

    showToast(
      'Reminder set for "$programName" at '
      '${formatHHmm(startTime)}',
      type: ToastType.success,
    );
  }

  /// Remove a reminder.
  void removeReminder(String id) {
    state = state.copyWith(
      reminders: state.reminders.where((r) => r.id != id).toList(),
    );
    _cache?.deleteReminder(id);
  }

  /// Convenience: show sync status.
  void showSyncStatus(int channelCount) {
    showToast('Synced $channelCount channels', type: ToastType.success);
  }

  /// Convenience: show DVR recording status.
  void showRecordingStarted(String programName) {
    showToast('Recording started: $programName', type: ToastType.info);
  }

  void showRecordingCompleted(String programName) {
    showToast('Recording complete: $programName', type: ToastType.success);
  }

  void showRecordingFailed(String programName) {
    showToast('Recording failed: $programName', type: ToastType.error);
  }

  /// Check for reminders that should fire now.
  void _checkReminders() {
    final now = DateTime.now();
    final due = dueReminders(state.reminders, now);

    for (final reminder in due) {
      showToast(
        '"${reminder.programName}" starts '
        'in 5 min on ${reminder.channelName}',
        type: ToastType.warning,
      );

      // Mark as fired in state.
      final updated =
          state.reminders.map((r) {
            if (r.id == reminder.id) {
              return ProgramReminder(
                id: r.id,
                programName: r.programName,
                channelName: r.channelName,
                startTime: r.startTime,
                notifyAt: r.notifyAt,
                fired: true,
              );
            }
            return r;
          }).toList();
      state = state.copyWith(reminders: updated);

      // Mark as fired in database.
      _cache?.markReminderFired(reminder.id);
    }
  }

  // ── Map converters ──────────────────────────────

  static ProgramReminder _mapToReminder(Map<String, dynamic> m) {
    return ProgramReminder(
      id: m['id'] as String,
      programName: m['program_name'] as String,
      channelName: m['channel_name'] as String,
      startTime: DateTime.parse(m['start_time'] as String),
      notifyAt: DateTime.parse(m['notify_at'] as String),
      fired: m['fired'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _reminderToMap(ProgramReminder r) {
    return {
      'id': r.id,
      'program_name': r.programName,
      'channel_name': r.channelName,
      'start_time': r.startTime.toIso8601String(),
      'notify_at': r.notifyAt.toIso8601String(),
      'fired': r.fired,
    };
  }
}

// ═════════════════════════════════════════════════
//  Pure helper functions
// ═════════════════════════════════════════════════

/// Returns reminders from [reminders] that have not yet
/// fired and whose [ProgramReminder.notifyAt] is before
/// [now].
List<ProgramReminder> dueReminders(
  List<ProgramReminder> reminders,
  DateTime now,
) => reminders.where((r) => !r.fired && r.notifyAt.isBefore(now)).toList();

// ═════════════════════════════════════════════════
//  Models
// ═════════════════════════════════════════════════

enum ToastType { info, success, warning, error }

@immutable
class AppToast {
  const AppToast({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String message;
  final ToastType type;
  final DateTime createdAt;
}

@immutable
class ProgramReminder {
  const ProgramReminder({
    required this.id,
    required this.programName,
    required this.channelName,
    required this.startTime,
    required this.notifyAt,
    this.fired = false,
  });

  final String id;
  final String programName;
  final String channelName;
  final DateTime startTime;
  final DateTime notifyAt;
  final bool fired;
}

@immutable
class NotificationState {
  const NotificationState({
    this.toasts = const [],
    this.reminders = const [],
    this.enabled = true,
  });

  final List<AppToast> toasts;
  final List<ProgramReminder> reminders;
  final bool enabled;

  NotificationState copyWith({
    List<AppToast>? toasts,
    List<ProgramReminder>? reminders,
    bool? enabled,
  }) {
    return NotificationState(
      toasts: toasts ?? this.toasts,
      reminders: reminders ?? this.reminders,
      enabled: enabled ?? this.enabled,
    );
  }
}

// ═════════════════════════════════════════════════
//  Provider
// ═════════════════════════════════════════════════

final notificationServiceProvider =
    NotifierProvider<NotificationService, NotificationState>(
      NotificationService.new,
    );
