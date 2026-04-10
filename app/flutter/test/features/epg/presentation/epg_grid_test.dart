import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/epg/presentation/widgets/virtual_epg_grid.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VirtualEpgGrid renders channels and programs', (tester) async {
    // Mock Data
    final channels = List.generate(
      10,
      (i) => Channel(
        id: 'ch_$i',
        name: 'Channel $i',
        streamUrl: 'http://stream/$i',
        logoUrl: 'http://logo/$i',
      ),
    );

    final now = DateTime.now().toUtc();
    final startTime = now.subtract(const Duration(hours: 1));
    final endTime = now.add(const Duration(hours: 4));

    final epgData = <String, List<EpgEntry>>{};
    for (var ch in channels) {
      epgData[ch.id] = [
        EpgEntry(
          channelId: ch.id,
          title: 'Program A on ${ch.name}',
          startTime: startTime,
          endTime: startTime.add(const Duration(hours: 1)),
        ),
        EpgEntry(
          channelId: ch.id,
          title: 'Program B on ${ch.name}',
          startTime: startTime.add(const Duration(hours: 1)),
          endTime: startTime.add(const Duration(hours: 2)),
        ),
      ];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VirtualEpgGrid(
            channels: channels,
            epgEntries: epgData,
            startDate: startTime,
            endDate: endTime,
            pixelsPerMinute: 5.0,
            channelBuilder: (context, channel) {
              return Text(channel.name);
            },
            programBuilder: (context, entry, w, h) {
              return Text(entry.title);
            },
          ),
        ),
      ),
    );

    // Verify Channels are rendered
    expect(find.text('Channel 0'), findsOneWidget);
    expect(find.text('Channel 5'), findsOneWidget);

    // Verify Programs are rendered
    // 'Program B' starts at startTime + 1h.
    // 1h = 60 mins * 5 px/min = 300px offset.
    // Ensure it's in the view or scroll to it.
    // Initial view should show at least Program A.
    expect(find.text('Program A on Channel 0'), findsOneWidget);

    // Check for Scrollable (matches SingleChildScrollView and ListView)
    expect(find.byType(Scrollable), findsWidgets);

    // Verify "Now Line"
    expect(find.byKey(const Key('nowLine')), findsOneWidget);
  });

  testWidgets('VirtualEpgGrid reports a bounded visible row range', (
    tester,
  ) async {
    final channels = List.generate(
      100,
      (i) => Channel(
        id: 'ch_$i',
        name: 'Channel $i',
        streamUrl: 'http://stream/$i',
      ),
    );
    final now = DateTime.now().toUtc();
    final startTime = now.subtract(const Duration(hours: 1));
    final endTime = now.add(const Duration(hours: 4));
    final epgData = <String, List<EpgEntry>>{};
    for (final channel in channels) {
      epgData[channel.id] = [
        EpgEntry(
          channelId: channel.id,
          title: 'Program on ${channel.name}',
          startTime: startTime,
          endTime: startTime.add(const Duration(hours: 1)),
        ),
      ];
    }

    int? firstRow;
    int? lastRow;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 360,
            child: VirtualEpgGrid(
              channels: channels,
              epgEntries: epgData,
              startDate: startTime,
              endDate: endTime,
              pixelsPerMinute: 5.0,
              onVisibleRowRangeChanged: (first, last) {
                firstRow = first;
                lastRow = last;
              },
              channelBuilder: (context, channel) => Text(channel.name),
              programBuilder: (context, entry, w, h) => Text(entry.title),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(firstRow, isNotNull);
    expect(lastRow, isNotNull);
    expect(firstRow, 0);
    expect(lastRow!, lessThan(channels.length));
  });
}
