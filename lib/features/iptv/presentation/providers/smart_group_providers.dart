import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/cache_service.dart';

/// Parsed smart group data for the UI.
class SmartGroup {
  const SmartGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  factory SmartGroup.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return SmartGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      members:
          rawMembers
              .map((m) => SmartGroupMember.fromJson(m as Map<String, dynamic>))
              .toList(),
    );
  }

  final String id;
  final String name;
  final List<SmartGroupMember> members;
}

/// A member within a smart group.
class SmartGroupMember {
  const SmartGroupMember({
    required this.channelId,
    required this.sourceId,
    required this.priority,
  });

  factory SmartGroupMember.fromJson(Map<String, dynamic> json) {
    return SmartGroupMember(
      channelId: json['channel_id'] as String,
      sourceId: json['source_id'] as String? ?? '',
      priority: json['priority'] as int? ?? 0,
    );
  }

  final String channelId;
  final String sourceId;
  final int priority;
}

/// Auto-detected smart group candidate.
class SmartGroupCandidate {
  const SmartGroupCandidate({
    required this.suggestedName,
    required this.members,
  });

  factory SmartGroupCandidate.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return SmartGroupCandidate(
      suggestedName: json['suggested_name'] as String,
      members:
          rawMembers
              .map((m) => CandidateMember.fromJson(m as Map<String, dynamic>))
              .toList(),
    );
  }

  final String suggestedName;
  final List<CandidateMember> members;
}

/// A member within a candidate suggestion.
class CandidateMember {
  const CandidateMember({
    required this.channelId,
    required this.sourceId,
    required this.channelName,
  });

  factory CandidateMember.fromJson(Map<String, dynamic> json) {
    return CandidateMember(
      channelId: json['channel_id'] as String,
      sourceId: json['source_id'] as String? ?? '',
      channelName: json['channel_name'] as String? ?? '',
    );
  }

  final String channelId;
  final String sourceId;
  final String channelName;
}

/// All smart groups, loaded from CacheService.
final smartGroupsProvider = FutureProvider.autoDispose<List<SmartGroup>>((
  ref,
) async {
  final cache = ref.watch(cacheServiceProvider);
  final raw = await cache.getSmartGroupsParsed();
  return raw.map(SmartGroup.fromJson).toList();
});

/// Set of channel IDs that belong to any smart group.
/// Used by channel list to show bolt icon overlay.
final smartGroupChannelIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final groups = await ref.watch(smartGroupsProvider.future);
  final ids = <String>{};
  for (final g in groups) {
    for (final m in g.members) {
      ids.add(m.channelId);
    }
  }
  return ids;
});

/// Auto-detected smart group candidates.
final smartGroupCandidatesProvider =
    FutureProvider.autoDispose<List<SmartGroupCandidate>>((ref) async {
      final cache = ref.watch(cacheServiceProvider);
      final raw = await cache.getSmartGroupCandidatesParsed();
      return raw.map(SmartGroupCandidate.fromJson).toList();
    });
