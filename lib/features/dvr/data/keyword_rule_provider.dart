import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';

// ─────────────────────────────────────────────────────────
//  Domain model
// ─────────────────────────────────────────────────────────

/// Field to match the keyword against.
enum KeywordMatchField {
  /// Match against the program/show title.
  title,

  /// Match against the program description.
  description,

  /// Match against title OR description.
  any;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
    KeywordMatchField.title => 'Title only',
    KeywordMatchField.description => 'Description only',
    KeywordMatchField.any => 'Title or Description',
  };
}

/// An auto-record keyword rule.
///
/// When the matching engine (future task) finds a program whose
/// [matchField] contains [keyword], it schedules a recording
/// automatically. The rule is UI-only for now.
@immutable
class KeywordRule {
  const KeywordRule({
    required this.id,
    required this.keyword,
    this.matchField = KeywordMatchField.any,
    this.channelFilter,
    this.startHour,
    this.endHour,
  });

  /// Unique identifier (timestamp-based).
  final String id;

  /// The keyword to search for (case-insensitive).
  final String keyword;

  /// Which field(s) to match against.
  final KeywordMatchField matchField;

  /// Optional channel name filter. Null = all channels.
  final String? channelFilter;

  /// Optional time window start (0–23). Null = no restriction.
  final int? startHour;

  /// Optional time window end (0–23). Null = no restriction.
  final int? endHour;

  /// Whether a time window restriction is configured.
  bool get hasTimeWindow => startHour != null && endHour != null;

  KeywordRule copyWith({
    String? keyword,
    KeywordMatchField? matchField,
    String? channelFilter,
    bool clearChannelFilter = false,
    int? startHour,
    int? endHour,
    bool clearTimeWindow = false,
  }) {
    return KeywordRule(
      id: id,
      keyword: keyword ?? this.keyword,
      matchField: matchField ?? this.matchField,
      channelFilter:
          clearChannelFilter ? null : (channelFilter ?? this.channelFilter),
      startHour: clearTimeWindow ? null : (startHour ?? this.startHour),
      endHour: clearTimeWindow ? null : (endHour ?? this.endHour),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyword': keyword,
    'matchField': matchField.name,
    'channelFilter': channelFilter,
    'startHour': startHour,
    'endHour': endHour,
  };

  factory KeywordRule.fromJson(Map<String, dynamic> json) => KeywordRule(
    id: json['id'] as String,
    keyword: json['keyword'] as String,
    matchField: KeywordMatchField.values.firstWhere(
      (e) => e.name == json['matchField'],
      orElse: () => KeywordMatchField.any,
    ),
    channelFilter: json['channelFilter'] as String?,
    startHour: json['startHour'] as int?,
    endHour: json['endHour'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordRule &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

// ─────────────────────────────────────────────────────────
//  Persistence key
// ─────────────────────────────────────────────────────────

const _kKeywordRulesKey = 'crispy_dvr_keyword_rules';

// ─────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────

/// Manages the list of DVR keyword auto-record rules.
///
/// Rules are persisted via [CacheService] as a JSON list.
/// The matching engine that acts on these rules is a
/// future implementation task.
class KeywordRuleNotifier extends AsyncNotifier<List<KeywordRule>> {
  late CacheService _cache;

  @override
  Future<List<KeywordRule>> build() async {
    _cache = ref.read(cacheServiceProvider);
    return _load();
  }

  Future<List<KeywordRule>> _load() async {
    final json = await _cache.getSetting(_kKeywordRulesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => KeywordRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist(List<KeywordRule> rules) async {
    await _cache.setSetting(
      _kKeywordRulesKey,
      jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
  }

  /// Adds a new keyword rule.
  Future<void> addRule(KeywordRule rule) async {
    final current = state.value ?? [];
    final updated = [...current, rule];
    await _persist(updated);
    state = AsyncData(updated);
  }

  /// Replaces an existing rule by ID.
  Future<void> updateRule(KeywordRule rule) async {
    final current = state.value ?? [];
    final updated = current.map((r) => r.id == rule.id ? rule : r).toList();
    await _persist(updated);
    state = AsyncData(updated);
  }

  /// Removes the rule with the given [id].
  Future<void> removeRule(String id) async {
    final current = state.value ?? [];
    final updated = current.where((r) => r.id != id).toList();
    await _persist(updated);
    state = AsyncData(updated);
  }
}

/// Provider for the list of keyword auto-record rules.
final keywordRuleProvider =
    AsyncNotifierProvider<KeywordRuleNotifier, List<KeywordRule>>(
      KeywordRuleNotifier.new,
    );
