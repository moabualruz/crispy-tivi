import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live tv runtime snapshot allows empty first-run runtime state', () {
    const String source = '''
{
  "title": "CrispyTivi Live TV Runtime",
  "version": "1",
  "provider": {
    "provider_key": "none",
    "provider_type": "None",
    "family": "none",
    "connection_mode": "none",
    "source_name": "No provider configured",
    "status": "Idle",
    "summary": "Add a provider in Settings to populate Live TV.",
    "last_sync": "Never",
    "guide_health": "Unavailable"
  },
  "browsing": {
    "active_panel": "Channels",
    "selected_group": "All",
    "selected_channel": "No channel selected",
    "group_order": [],
    "groups": []
  },
  "channels": [],
  "guide": {
    "title": "Live TV Guide",
    "window_start": "Now",
    "window_end": "Later",
    "time_slots": [],
    "rows": []
  },
  "selection": {
    "channel_number": "none",
    "channel_name": "No channel selected",
    "status": "Idle",
    "live_edge": false,
    "catch_up": false,
    "archive": false,
    "now": {
      "title": "No live program",
      "summary": "Add a provider to hydrate live listings.",
      "start": "Now",
      "end": "Later",
      "progress_percent": 0
    },
    "next": {
      "title": "No upcoming program",
      "summary": "Live runtime will populate after provider setup.",
      "start": "Later",
      "end": "Later",
      "progress_percent": 0
    },
    "primary_action": "Add provider",
    "secondary_action": "Open Settings",
    "badges": ["Live", "Idle"],
    "detail_lines": ["No configured provider is currently ready for Live TV."]
  },
  "notes": ["Rust-owned empty Live TV runtime for first-run state."]
}
''';

    final LiveTvRuntimeSnapshot snapshot = LiveTvRuntimeSnapshot.fromJsonString(
      source,
    );

    expect(snapshot.channels, isEmpty);
    expect(snapshot.guide.rows, isEmpty);
    expect(snapshot.provider.status, 'Idle');
    expect(snapshot.selection.primaryAction, 'Add provider');
  });

  test('live tv runtime snapshot parses browse and guide runtime state', () {
    const String source = '''
{
  "title": "CrispyTivi Live TV Runtime",
  "version": "1",
  "provider": {
    "provider_key": "home_fiber_iptv",
    "provider_type": "M3U + XMLTV",
    "family": "playlist",
    "connection_mode": "remote_url",
    "source_name": "Home Fiber IPTV",
    "status": "Healthy",
    "summary": "Runtime provider summary.",
    "last_sync": "2 minutes ago",
    "guide_health": "EPG verified"
  },
  "browsing": {
    "active_panel": "Channels",
    "selected_group": "All",
    "selected_channel": "101 Crispy One",
    "group_order": ["All", "Sports"],
    "groups": [
      {
        "id": "all",
        "title": "All",
        "summary": "All live channels in browse order.",
        "channel_count": 2,
        "selected": true
      },
      {
        "id": "sports",
        "title": "Sports",
        "summary": "Sports lane.",
        "channel_count": 1,
        "selected": false
      }
    ]
  },
  "channels": [
    {
      "number": "101",
      "name": "Crispy One",
      "group": "News",
      "state": "selected",
      "live_edge": true,
      "catch_up": true,
      "archive": true,
      "current": {
        "title": "Midnight Bulletin",
        "summary": "Late-night national news.",
        "start": "21:00",
        "end": "22:00",
        "progress_percent": 55
      },
      "next": {
        "title": "Market Close",
        "summary": "Market close summary.",
        "start": "22:00",
        "end": "22:30",
        "progress_percent": 0
      }
    },
    {
      "number": "118",
      "name": "Arena Live",
      "group": "Sports",
      "state": "playing",
      "live_edge": true,
      "catch_up": true,
      "archive": true,
      "current": {
        "title": "Championship Replay",
        "summary": "Fast-moving sports replay lane.",
        "start": "21:30",
        "end": "23:30",
        "progress_percent": 33
      },
      "next": {
        "title": "Locker Room",
        "summary": "Archive playback available.",
        "start": "23:30",
        "end": "00:00",
        "progress_percent": 0
      }
    }
  ],
  "guide": {
    "title": "Live TV Guide",
    "window_start": "21:00",
    "window_end": "23:00",
    "time_slots": ["Now", "21:30"],
    "rows": [
      {
        "channel_number": "101",
        "channel_name": "Crispy One",
        "slots": [
          {
            "start": "21:00",
            "end": "22:00",
            "title": "Midnight Bulletin",
            "state": "current"
          }
        ]
      }
    ]
  },
  "selection": {
    "channel_number": "101",
    "channel_name": "Crispy One",
    "status": "Live",
    "live_edge": true,
    "catch_up": true,
    "archive": true,
    "now": {
      "title": "Midnight Bulletin",
      "summary": "Top national stories.",
      "start": "21:00",
      "end": "22:00",
      "progress_percent": 55
    },
    "next": {
      "title": "Market Close",
      "summary": "Closing bell recap.",
      "start": "22:00",
      "end": "22:30",
      "progress_percent": 0
    },
    "primary_action": "Watch live",
    "secondary_action": "Start over",
    "badges": ["Live", "News"],
    "detail_lines": ["Selected detail stays in the right lane."]
  },
  "notes": ["Rust-owned runtime snapshot."]
}
''';

    final LiveTvRuntimeSnapshot snapshot = LiveTvRuntimeSnapshot.fromJsonString(
      source,
    );

    expect(snapshot.title, 'CrispyTivi Live TV Runtime');
    expect(snapshot.selectedChannelNumber, '101');
    expect(snapshot.provider.sourceName, 'Home Fiber IPTV');
    expect(snapshot.groupById('sports').title, 'Sports');
    expect(snapshot.channelsForGroup('all').length, 2);
    expect(
      snapshot.guideRowForChannel('101')?.slots.single.title,
      'Midnight Bulletin',
    );
    expect(snapshot.guideSlotForTitle('101', '21:00')?.state, 'current');
  });

  test('live tv runtime snapshot rejects missing provider object', () {
    expect(
      () => LiveTvRuntimeSnapshot.fromJsonString('''
{
  "title": "CrispyTivi Live TV Runtime",
  "version": "1",
  "browsing": {
    "active_panel": "Channels",
    "selected_group": "All",
    "selected_channel": "101 Crispy One",
    "group_order": ["All"],
    "groups": [
      {
        "id": "all",
        "title": "All",
        "summary": "All live channels in browse order.",
        "channel_count": 1,
        "selected": true
      }
    ]
  },
  "channels": [
    {
      "number": "101",
      "name": "Crispy One",
      "group": "News",
      "state": "selected",
      "live_edge": true,
      "catch_up": true,
      "archive": true,
      "current": {
        "title": "Midnight Bulletin",
        "summary": "Late-night national news.",
        "start": "21:00",
        "end": "22:00",
        "progress_percent": 55
      },
      "next": {
        "title": "Market Close",
        "summary": "Market close summary.",
        "start": "22:00",
        "end": "22:30",
        "progress_percent": 0
      }
    }
  ],
  "guide": {
    "title": "Live TV Guide",
    "window_start": "21:00",
    "window_end": "23:00",
    "time_slots": ["Now"],
    "rows": [
      {
        "channel_number": "101",
        "channel_name": "Crispy One",
        "slots": [
          {
            "start": "21:00",
            "end": "22:00",
            "title": "Midnight Bulletin",
            "state": "current"
          }
        ]
      }
    ]
  },
  "selection": {
    "channel_number": "101",
    "channel_name": "Crispy One",
    "status": "Live",
    "live_edge": true,
    "catch_up": true,
    "archive": true,
    "now": {
      "title": "Midnight Bulletin",
      "summary": "Top national stories.",
      "start": "21:00",
      "end": "22:00",
      "progress_percent": 55
    },
    "next": {
      "title": "Market Close",
      "summary": "Closing bell recap.",
      "start": "22:00",
      "end": "22:30",
      "progress_percent": 0
    },
    "primary_action": "Watch live",
    "secondary_action": "Start over",
    "badges": ["Live", "News"],
    "detail_lines": ["Selected detail stays in the right lane."]
  }
}
'''),
      throwsFormatException,
    );
  });
}
