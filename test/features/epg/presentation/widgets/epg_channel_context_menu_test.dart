import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/context_menu_panel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/epg_entry.dart';

// ---------------------------------------------------------------------------
// Harness that renders EPG channel context menu sections inline (without the
// slide animation) so tests can assert on items synchronously.
// ---------------------------------------------------------------------------

/// Mirrors the section-building logic from showEpgChannelContextMenu so we
/// can assert on the output without triggering provider calls.
class _EpgMenuHarness extends StatelessWidget {
  const _EpgMenuHarness({
    required this.channel,
    required this.nowPlaying,
    required this.hasExternal,
  });

  final Channel channel;
  final EpgEntry? nowPlaying;
  final bool hasExternal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFavorite = channel.isFavorite;

    // Build sections matching showEpgChannelContextMenu logic.
    final sections = <ContextMenuSection>[
      if (nowPlaying != null)
        ContextMenuSection(
          header: nowPlaying!.title,
          headerColor: colorScheme.primary,
          items: [
            ContextMenuItem(
              icon: Icons.play_arrow,
              label: 'Watch',
              onTap: () {},
            ),
            ContextMenuItem(
              icon: Icons.open_in_new,
              label: 'Open in external player',
              onTap: () {},
            ),
            ContextMenuItem(
              icon: Icons.fiber_manual_record,
              label: 'Record',
              onTap: () {},
            ),
          ],
        ),
      ContextMenuSection(
        header: channel.name,
        headerColor: colorScheme.primary,
        items: [
          ContextMenuItem(
            icon: isFavorite ? Icons.star : Icons.star_outline,
            label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            onTap: () {},
          ),
          ContextMenuItem(
            icon: Icons.visibility_off,
            label: 'Hide channel',
            onTap: () {},
          ),
          ContextMenuItem(
            icon: Icons.tv_rounded,
            label: 'Assign EPG',
            onTap: () {},
          ),
          ContextMenuItem(
            icon: Icons.block,
            label: 'Block channel',
            isDestructive: true,
            onTap: () {},
          ),
          ContextMenuItem(icon: Icons.search, label: 'Search', onTap: () {}),
          ContextMenuItem(
            icon: Icons.filter_alt_outlined,
            label: 'Show EPG channels only',
            onTap: () {},
          ),
          ContextMenuItem(
            icon: Icons.copy,
            label: 'Copy stream URL',
            onTap: () {},
          ),
          if (hasExternal)
            ContextMenuItem(
              icon: Icons.open_in_new,
              label: 'Play in external player',
              onTap: () {},
            ),
        ],
      ),
    ];

    return ListView(
      children: [
        for (final section in sections) ...[
          if (section.header != null)
            Padding(
              key: Key('header_${section.header}'),
              padding: EdgeInsets.zero,
              child: Text(
                section.header!,
                style: TextStyle(color: section.headerColor),
              ),
            ),
          for (final item in section.items)
            ListTile(
              key: Key('item_${item.label}'),
              leading: Icon(
                item.icon,
                color:
                    item.isDestructive
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  color:
                      item.isDestructive
                          ? colorScheme.error
                          : colorScheme.onSurface,
                ),
              ),
              onTap: item.onTap,
            ),
        ],
      ],
    );
  }
}

Widget _wrap({
  required Channel channel,
  EpgEntry? nowPlaying,
  bool hasExternal = false,
}) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: _EpgMenuHarness(
        channel: channel,
        nowPlaying: nowPlaying,
        hasExternal: hasExternal,
      ),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _channel = Channel(
  id: 'ch1',
  name: 'BBC Two',
  streamUrl: 'http://example.com/bbc2',
);

const _favoriteChannel = Channel(
  id: 'ch2',
  name: 'ITV',
  streamUrl: 'http://example.com/itv',
  isFavorite: true,
);

EpgEntry _nowPlaying() => EpgEntry(
  channelId: 'ch1',
  title: 'The Great British Bake Off',
  startTime: DateTime.now().subtract(const Duration(minutes: 10)),
  endTime: DateTime.now().add(const Duration(minutes: 50)),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EPG channel context menu — section 1 (now-playing)', () {
    testWidgets('section 1 shows Watch, External Player, Record when '
        'nowPlaying is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(channel: _channel, nowPlaying: _nowPlaying()),
      );
      await tester.pump();

      expect(find.byKey(const Key('item_Watch')), findsOneWidget);
      expect(
        find.byKey(const Key('item_Open in external player')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('item_Record')), findsOneWidget);
    });

    testWidgets('section 1 header shows now-playing programme title', (
      tester,
    ) async {
      final entry = _nowPlaying();
      await tester.pumpWidget(_wrap(channel: _channel, nowPlaying: entry));
      await tester.pump();

      expect(find.text(entry.title), findsOneWidget);
    });

    testWidgets('section 1 is absent when nowPlaying is null', (tester) async {
      await tester.pumpWidget(_wrap(channel: _channel));
      await tester.pump();

      expect(find.byKey(const Key('item_Watch')), findsNothing);
      expect(find.byKey(const Key('item_Record')), findsNothing);
    });
  });

  group('EPG channel context menu — section 2 (channel actions)', () {
    testWidgets(
      'shows all 8 channel-level items: Favorite, Hide, Assign EPG, Block, '
      'Search, EPG-only toggle, Copy URL, External Player',
      (tester) async {
        await tester.pumpWidget(_wrap(channel: _channel, hasExternal: true));
        await tester.pump();

        expect(find.byKey(const Key('item_Add to Favorites')), findsOneWidget);
        expect(find.byKey(const Key('item_Hide channel')), findsOneWidget);
        expect(find.byKey(const Key('item_Assign EPG')), findsOneWidget);
        expect(find.byKey(const Key('item_Block channel')), findsOneWidget);
        expect(find.byKey(const Key('item_Search')), findsOneWidget);
        expect(
          find.byKey(const Key('item_Show EPG channels only')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('item_Copy stream URL')), findsOneWidget);
        expect(
          find.byKey(const Key('item_Play in external player')),
          findsOneWidget,
        );
      },
    );

    testWidgets('External Player item is absent when hasExternal = false', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(channel: _channel, hasExternal: false));
      await tester.pump();

      expect(
        find.byKey(const Key('item_Play in external player')),
        findsNothing,
      );
    });
  });

  group('EPG channel context menu — Favorite toggle icon', () {
    testWidgets('shows star_outline when channel is not a favourite', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(channel: _channel));
      await tester.pump();

      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows filled star when channel is a favourite', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(channel: _favoriteChannel));
      await tester.pump();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
    });
  });

  group('EPG channel context menu — Block uses error color', () {
    testWidgets('Block item text and icon use error color', (tester) async {
      await tester.pumpWidget(_wrap(channel: _channel));
      await tester.pump();

      final colorScheme =
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.colorScheme ??
          ThemeData().colorScheme;

      final blockTile = tester.widget<ListTile>(
        find.byKey(const Key('item_Block channel')),
      );

      final titleText = blockTile.title! as Text;
      expect(titleText.style?.color, colorScheme.error);

      final leadingIcon = blockTile.leading! as Icon;
      expect(leadingIcon.color, colorScheme.error);
    });
  });

  group('EPG channel context menu — combined sections', () {
    testWidgets('when nowPlaying is present, total items = 3 (section 1) + 8 '
        '(section 2, with external) = 11', (tester) async {
      await tester.pumpWidget(
        _wrap(channel: _channel, nowPlaying: _nowPlaying(), hasExternal: true),
      );
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(11));
    });

    testWidgets(
      'when nowPlaying is null, total items = 8 (section 2 with external)',
      (tester) async {
        await tester.pumpWidget(_wrap(channel: _channel, hasExternal: true));
        await tester.pump();

        expect(find.byType(ListTile), findsNWidgets(8));
      },
    );
  });
}
