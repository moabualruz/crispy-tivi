import 'package:crispy_tivi/features/shell/data/asset_live_tv_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository loads live tv runtime asset', () async {
    const String assetJson = '''
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
  },
  "notes": ["Rust-owned runtime snapshot."]
}
''';

    final TestDefaultBinaryMessengerBinding binding =
        TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      ByteData? message,
    ) async {
      final String key = const StringCodec().decodeMessage(message)!;
      if (key == AssetLiveTvRuntimeRepository.assetPath) {
        return const StringCodec().encodeMessage(assetJson);
      }
      return null;
    });
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      ),
    );

    const AssetLiveTvRuntimeRepository repository =
        AssetLiveTvRuntimeRepository();
    final LiveTvRuntimeSnapshot snapshot = await repository.load();

    expect(snapshot.title, 'CrispyTivi Live TV Runtime');
    expect(snapshot.channels.single.name, 'Crispy One');
    expect(snapshot.selectedChannelNumber, '101');
    expect(snapshot.guide.timeSlots.single, 'Now');
  });
}
