import 'dart:convert';

import 'package:crispy_tivi/features/shell/domain/playback_target.dart';

final class LiveTvRuntimeSnapshot {
  const LiveTvRuntimeSnapshot({
    required this.title,
    required this.version,
    required this.provider,
    required this.browsing,
    required this.channels,
    required this.guide,
    required this.selection,
    required this.notes,
  });

  const LiveTvRuntimeSnapshot.empty()
    : title = 'CrispyTivi Live TV Runtime',
      version = '0',
      provider = const LiveTvRuntimeProviderSnapshot.empty(),
      browsing = const LiveTvRuntimeBrowsingSnapshot.empty(),
      channels = const <LiveTvRuntimeChannelSnapshot>[],
      guide = const LiveTvRuntimeGuideSnapshot.empty(),
      selection = const LiveTvRuntimeSelectionSnapshot.empty(),
      notes = const <String>[];

  factory LiveTvRuntimeSnapshot.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('live tv runtime must be a JSON object');
    }
    return LiveTvRuntimeSnapshot.fromJson(decoded);
  }

  factory LiveTvRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    final List<LiveTvRuntimeChannelSnapshot> channels = _readList(
      json,
      'channels',
      parser:
          (Map<String, dynamic> value) =>
              LiveTvRuntimeChannelSnapshot.fromJson(value),
    );
    final LiveTvRuntimeGuideSnapshot guide =
        LiveTvRuntimeGuideSnapshot.fromJson(
          _readObject(json, 'guide', parent: 'live_tv_runtime'),
        );
    final LiveTvRuntimeBrowsingSnapshot browsing =
        LiveTvRuntimeBrowsingSnapshot.fromJson(
          _readObject(json, 'browsing', parent: 'live_tv_runtime'),
        );
    final LiveTvRuntimeSelectionSnapshot selection =
        LiveTvRuntimeSelectionSnapshot.fromJson(
          _readObject(json, 'selection', parent: 'live_tv_runtime'),
        );

    return LiveTvRuntimeSnapshot(
      title: _readString(json, 'title', parent: 'live_tv_runtime'),
      version: _readString(json, 'version', parent: 'live_tv_runtime'),
      provider: LiveTvRuntimeProviderSnapshot.fromJson(
        _readObject(json, 'provider', parent: 'live_tv_runtime'),
      ),
      browsing: browsing,
      channels: channels,
      guide: guide,
      selection: selection,
      notes: _readOptionalStringList(json, 'notes'),
    );
  }

  final String title;
  final String version;
  final LiveTvRuntimeProviderSnapshot provider;
  final LiveTvRuntimeBrowsingSnapshot browsing;
  final List<LiveTvRuntimeChannelSnapshot> channels;
  final LiveTvRuntimeGuideSnapshot guide;
  final LiveTvRuntimeSelectionSnapshot selection;
  final List<String> notes;

  List<LiveTvRuntimeGroupSnapshot> get orderedGroups {
    if (browsing.groups.isEmpty) {
      return const <LiveTvRuntimeGroupSnapshot>[];
    }
    final Map<String, LiveTvRuntimeGroupSnapshot> byTitle =
        <String, LiveTvRuntimeGroupSnapshot>{
          for (final LiveTvRuntimeGroupSnapshot group in browsing.groups)
            group.title: group,
        };
    final List<LiveTvRuntimeGroupSnapshot> ordered = browsing.groupOrder
        .map((String title) => byTitle[title])
        .whereType<LiveTvRuntimeGroupSnapshot>()
        .toList(growable: true);
    for (final LiveTvRuntimeGroupSnapshot group in browsing.groups) {
      if (!ordered.contains(group)) {
        ordered.add(group);
      }
    }
    return List<LiveTvRuntimeGroupSnapshot>.unmodifiable(ordered);
  }

  String get selectedGroupId {
    for (final LiveTvRuntimeGroupSnapshot group in orderedGroups) {
      if (group.selected) {
        return group.id;
      }
    }
    for (final LiveTvRuntimeGroupSnapshot group in orderedGroups) {
      if (group.title == browsing.selectedGroup) {
        return group.id;
      }
    }
    return orderedGroups.isNotEmpty ? orderedGroups.first.id : 'all';
  }

  String get selectedChannelNumber {
    final String browsingValue = browsing.selectedChannel.trim();
    for (final LiveTvRuntimeChannelSnapshot channel in channels) {
      if (channel.number == browsingValue ||
          '${channel.number} ${channel.name}' == browsingValue ||
          '${channel.number} ${channel.name}'.contains(browsingValue)) {
        return channel.number;
      }
    }
    return selection.channelNumber.isNotEmpty
        ? selection.channelNumber
        : (channels.isNotEmpty ? channels.first.number : '');
  }

  LiveTvRuntimeGroupSnapshot groupById(String id) {
    return orderedGroups.firstWhere(
      (LiveTvRuntimeGroupSnapshot group) => group.id == id,
      orElse: () => throw StateError('missing live tv runtime group $id'),
    );
  }

  LiveTvRuntimeChannelSnapshot channelByNumber(String number) {
    return channels.firstWhere(
      (LiveTvRuntimeChannelSnapshot channel) => channel.number == number,
      orElse: () => throw StateError('missing live tv runtime channel $number'),
    );
  }

  List<LiveTvRuntimeChannelSnapshot> channelsForGroup(String groupId) {
    if (channels.isEmpty) {
      return const <LiveTvRuntimeChannelSnapshot>[];
    }
    final LiveTvRuntimeGroupSnapshot? selectedGroup = orderedGroups
        .cast<LiveTvRuntimeGroupSnapshot?>()
        .firstWhere(
          (LiveTvRuntimeGroupSnapshot? group) => group?.id == groupId,
          orElse: () => null,
        );
    if (selectedGroup == null || selectedGroup.id == 'all') {
      return List<LiveTvRuntimeChannelSnapshot>.unmodifiable(channels);
    }
    return List<LiveTvRuntimeChannelSnapshot>.unmodifiable(
      channels.where((LiveTvRuntimeChannelSnapshot channel) {
        return channel.group == selectedGroup.title;
      }),
    );
  }

  LiveTvRuntimeGuideSnapshot guideForChannelNumbers(Iterable<String> numbers) {
    final Set<String> allowed = numbers.toSet();
    return LiveTvRuntimeGuideSnapshot(
      title: guide.title,
      windowStart: guide.windowStart,
      windowEnd: guide.windowEnd,
      timeSlots: guide.timeSlots,
      rows: guide.rows
          .where((LiveTvRuntimeGuideRowSnapshot row) {
            return allowed.contains(row.channelNumber);
          })
          .toList(growable: false),
    );
  }

  LiveTvRuntimeGuideRowSnapshot? guideRowForChannel(String channelNumber) {
    for (final LiveTvRuntimeGuideRowSnapshot row in guide.rows) {
      if (row.channelNumber == channelNumber) {
        return row;
      }
    }
    return null;
  }

  LiveTvRuntimeGuideSlotSnapshot? guideSlotForTitle(
    String channelNumber,
    String slotTitle,
  ) {
    final LiveTvRuntimeGuideRowSnapshot? row = guideRowForChannel(
      channelNumber,
    );
    if (row == null) {
      return null;
    }
    for (final LiveTvRuntimeGuideSlotSnapshot slot in row.slots) {
      if (slot.start == slotTitle || slot.title == slotTitle) {
        return slot;
      }
    }
    return null;
  }
}

final class LiveTvRuntimeProviderSnapshot {
  const LiveTvRuntimeProviderSnapshot({
    required this.providerKey,
    required this.providerType,
    required this.family,
    required this.connectionMode,
    required this.sourceName,
    required this.status,
    required this.summary,
    required this.lastSync,
    required this.guideHealth,
  });

  const LiveTvRuntimeProviderSnapshot.empty()
    : providerKey = '',
      providerType = '',
      family = '',
      connectionMode = '',
      sourceName = '',
      status = 'Unknown',
      summary = '',
      lastSync = '',
      guideHealth = '';

  factory LiveTvRuntimeProviderSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeProviderSnapshot(
      providerKey: _readString(json, 'provider_key', parent: 'provider'),
      providerType: _readString(json, 'provider_type', parent: 'provider'),
      family: _readString(json, 'family', parent: 'provider'),
      connectionMode: _readString(json, 'connection_mode', parent: 'provider'),
      sourceName: _readString(json, 'source_name', parent: 'provider'),
      status: _readString(json, 'status', parent: 'provider'),
      summary: _readString(json, 'summary', parent: 'provider'),
      lastSync: _readString(json, 'last_sync', parent: 'provider'),
      guideHealth: _readString(json, 'guide_health', parent: 'provider'),
    );
  }

  final String providerKey;
  final String providerType;
  final String family;
  final String connectionMode;
  final String sourceName;
  final String status;
  final String summary;
  final String lastSync;
  final String guideHealth;
}

final class LiveTvRuntimeBrowsingSnapshot {
  const LiveTvRuntimeBrowsingSnapshot({
    required this.activePanel,
    required this.selectedGroup,
    required this.selectedChannel,
    required this.groupOrder,
    required this.groups,
  });

  const LiveTvRuntimeBrowsingSnapshot.empty()
    : activePanel = 'Channels',
      selectedGroup = 'All',
      selectedChannel = '',
      groupOrder = const <String>[],
      groups = const <LiveTvRuntimeGroupSnapshot>[];

  factory LiveTvRuntimeBrowsingSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeBrowsingSnapshot(
      activePanel: _readString(json, 'active_panel', parent: 'browsing'),
      selectedGroup: _readString(json, 'selected_group', parent: 'browsing'),
      selectedChannel: _readString(
        json,
        'selected_channel',
        parent: 'browsing',
      ),
      groupOrder: _readStringList(json, 'group_order', parent: 'browsing'),
      groups: _readList(
        json,
        'groups',
        parser:
            (Map<String, dynamic> value) =>
                LiveTvRuntimeGroupSnapshot.fromJson(value),
      ),
    );
  }

  final String activePanel;
  final String selectedGroup;
  final String selectedChannel;
  final List<String> groupOrder;
  final List<LiveTvRuntimeGroupSnapshot> groups;
}

final class LiveTvRuntimeGroupSnapshot {
  const LiveTvRuntimeGroupSnapshot({
    required this.id,
    required this.title,
    required this.summary,
    required this.channelCount,
    required this.selected,
  });

  factory LiveTvRuntimeGroupSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeGroupSnapshot(
      id: _readString(json, 'id', parent: 'group'),
      title: _readString(json, 'title', parent: 'group'),
      summary: _readString(json, 'summary', parent: 'group'),
      channelCount: _readInt(json, 'channel_count', parent: 'group'),
      selected: _readBool(json, 'selected', parent: 'group'),
    );
  }

  final String id;
  final String title;
  final String summary;
  final int channelCount;
  final bool selected;
}

final class LiveTvRuntimeProgramSnapshot {
  const LiveTvRuntimeProgramSnapshot({
    required this.title,
    required this.summary,
    required this.start,
    required this.end,
    required this.progressPercent,
  });

  const LiveTvRuntimeProgramSnapshot.empty()
    : title = '',
      summary = '',
      start = '',
      end = '',
      progressPercent = 0;

  factory LiveTvRuntimeProgramSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeProgramSnapshot(
      title: _readString(json, 'title', parent: 'program'),
      summary: _readString(json, 'summary', parent: 'program'),
      start: _readString(json, 'start', parent: 'program'),
      end: _readString(json, 'end', parent: 'program'),
      progressPercent: _readInt(json, 'progress_percent', parent: 'program'),
    );
  }

  final String title;
  final String summary;
  final String start;
  final String end;
  final int progressPercent;

  String get timeRange {
    if (start.isEmpty && end.isEmpty) {
      return 'Schedule pending';
    }
    return '$start - $end';
  }
}

final class LiveTvRuntimeGuideSlotSnapshot {
  const LiveTvRuntimeGuideSlotSnapshot({
    required this.start,
    required this.end,
    required this.title,
    required this.state,
  });

  factory LiveTvRuntimeGuideSlotSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeGuideSlotSnapshot(
      start: _readString(json, 'start', parent: 'guide.slot'),
      end: _readString(json, 'end', parent: 'guide.slot'),
      title: _readString(json, 'title', parent: 'guide.slot'),
      state: _readString(json, 'state', parent: 'guide.slot'),
    );
  }

  final String start;
  final String end;
  final String title;
  final String state;

  String get displayRange => '$start - $end';
}

final class LiveTvRuntimeGuideRowSnapshot {
  const LiveTvRuntimeGuideRowSnapshot({
    required this.channelNumber,
    required this.channelName,
    required this.slots,
  });

  factory LiveTvRuntimeGuideRowSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeGuideRowSnapshot(
      channelNumber: _readString(json, 'channel_number', parent: 'guide.row'),
      channelName: _readString(json, 'channel_name', parent: 'guide.row'),
      slots: _readList(
        json,
        'slots',
        parser:
            (Map<String, dynamic> value) =>
                LiveTvRuntimeGuideSlotSnapshot.fromJson(value),
      ),
    );
  }

  final String channelNumber;
  final String channelName;
  final List<LiveTvRuntimeGuideSlotSnapshot> slots;
}

final class LiveTvRuntimeGuideSnapshot {
  const LiveTvRuntimeGuideSnapshot({
    required this.title,
    required this.windowStart,
    required this.windowEnd,
    required this.timeSlots,
    required this.rows,
  });

  const LiveTvRuntimeGuideSnapshot.empty()
    : title = 'Live TV Guide',
      windowStart = '',
      windowEnd = '',
      timeSlots = const <String>[],
      rows = const <LiveTvRuntimeGuideRowSnapshot>[];

  factory LiveTvRuntimeGuideSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeGuideSnapshot(
      title: _readString(json, 'title', parent: 'guide'),
      windowStart: _readString(json, 'window_start', parent: 'guide'),
      windowEnd: _readString(json, 'window_end', parent: 'guide'),
      timeSlots: _readStringList(json, 'time_slots', parent: 'guide'),
      rows: _readList(
        json,
        'rows',
        parser:
            (Map<String, dynamic> value) =>
                LiveTvRuntimeGuideRowSnapshot.fromJson(value),
      ),
    );
  }

  final String title;
  final String windowStart;
  final String windowEnd;
  final List<String> timeSlots;
  final List<LiveTvRuntimeGuideRowSnapshot> rows;
}

final class LiveTvRuntimeChannelSnapshot {
  const LiveTvRuntimeChannelSnapshot({
    required this.number,
    required this.name,
    required this.group,
    required this.state,
    required this.liveEdge,
    required this.catchUp,
    required this.archive,
    required this.current,
    required this.next,
    this.playbackSource,
    this.playbackStream,
  });

  factory LiveTvRuntimeChannelSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeChannelSnapshot(
      number: _readString(json, 'number', parent: 'channel'),
      name: _readString(json, 'name', parent: 'channel'),
      group: _readString(json, 'group', parent: 'channel'),
      state: _readString(json, 'state', parent: 'channel'),
      liveEdge: _readBool(json, 'live_edge', parent: 'channel'),
      catchUp: _readBool(json, 'catch_up', parent: 'channel'),
      archive: _readBool(json, 'archive', parent: 'channel'),
      current: LiveTvRuntimeProgramSnapshot.fromJson(
        _readObject(json, 'current', parent: 'channel'),
      ),
      next: LiveTvRuntimeProgramSnapshot.fromJson(
        _readObject(json, 'next', parent: 'channel'),
      ),
      playbackSource: readOptionalPlaybackSource(
        json,
        'playback_source',
        parent: 'channel',
      ),
      playbackStream: readOptionalPlaybackStream(
        json,
        'playback_stream',
        parent: 'channel',
      ),
    );
  }

  final String number;
  final String name;
  final String group;
  final String state;
  final bool liveEdge;
  final bool catchUp;
  final bool archive;
  final LiveTvRuntimeProgramSnapshot current;
  final LiveTvRuntimeProgramSnapshot next;
  final PlaybackSourceSnapshot? playbackSource;
  final PlaybackStreamSnapshot? playbackStream;
}

final class LiveTvRuntimeSelectionSnapshot {
  const LiveTvRuntimeSelectionSnapshot({
    required this.channelNumber,
    required this.channelName,
    required this.status,
    required this.liveEdge,
    required this.catchUp,
    required this.archive,
    required this.now,
    required this.next,
    required this.primaryAction,
    required this.secondaryAction,
    required this.badges,
    required this.detailLines,
  });

  const LiveTvRuntimeSelectionSnapshot.empty()
    : channelNumber = '',
      channelName = '',
      status = '',
      liveEdge = false,
      catchUp = false,
      archive = false,
      now = const LiveTvRuntimeProgramSnapshot.empty(),
      next = const LiveTvRuntimeProgramSnapshot.empty(),
      primaryAction = 'Watch live',
      secondaryAction = 'Start over',
      badges = const <String>[],
      detailLines = const <String>[];

  factory LiveTvRuntimeSelectionSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveTvRuntimeSelectionSnapshot(
      channelNumber: _readString(json, 'channel_number', parent: 'selection'),
      channelName: _readString(json, 'channel_name', parent: 'selection'),
      status: _readString(json, 'status', parent: 'selection'),
      liveEdge: _readBool(json, 'live_edge', parent: 'selection'),
      catchUp: _readBool(json, 'catch_up', parent: 'selection'),
      archive: _readBool(json, 'archive', parent: 'selection'),
      now: LiveTvRuntimeProgramSnapshot.fromJson(
        _readObject(json, 'now', parent: 'selection'),
      ),
      next: LiveTvRuntimeProgramSnapshot.fromJson(
        _readObject(json, 'next', parent: 'selection'),
      ),
      primaryAction: _readString(json, 'primary_action', parent: 'selection'),
      secondaryAction: _readString(
        json,
        'secondary_action',
        parent: 'selection',
      ),
      badges: _readStringList(json, 'badges', parent: 'selection'),
      detailLines: _readStringList(json, 'detail_lines', parent: 'selection'),
    );
  }

  final String channelNumber;
  final String channelName;
  final String status;
  final bool liveEdge;
  final bool catchUp;
  final bool archive;
  final LiveTvRuntimeProgramSnapshot now;
  final LiveTvRuntimeProgramSnapshot next;
  final String primaryAction;
  final String secondaryAction;
  final List<String> badges;
  final List<String> detailLines;
}

Map<String, dynamic> _readObject(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$parent.$key must be an object');
  }
  return value;
}

List<T> _readList<T>(
  Map<String, dynamic> json,
  String key, {
  required T Function(Map<String, dynamic>) parser,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  return List<T>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('$key must contain only objects');
      }
      return parser(entry);
    }),
  );
}

String _readString(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$parent.$key must be a non-empty string');
  }
  return value;
}

List<String> _readStringList(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$parent.$key must be an array');
  }
  return List<String>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! String || entry.isEmpty) {
        throw FormatException('$parent.$key must contain only strings');
      }
      return entry;
    }),
  );
}

List<String> _readOptionalStringList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array');
  }
  return List<String>.unmodifiable(
    value.map((Object? entry) {
      if (entry is! String || entry.isEmpty) {
        throw FormatException('$key must contain only strings');
      }
      return entry;
    }),
  );
}

int _readInt(Map<String, dynamic> json, String key, {required String parent}) {
  final Object? value = json[key];
  if (value is! int) {
    throw FormatException('$parent.$key must be an int');
  }
  return value;
}

bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required String parent,
}) {
  final Object? value = json[key];
  if (value is! bool) {
    throw FormatException('$parent.$key must be a bool');
  }
  return value;
}
