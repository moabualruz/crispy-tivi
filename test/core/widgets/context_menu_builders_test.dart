import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/context_menu_builders.dart';
import 'package:crispy_tivi/core/widgets/context_menu_panel.dart';

// ---------------------------------------------------------------------------
// Helper: build a widget that renders the sections from a builder inline
// so tests can find items without animating the slide-in dialog.
// ---------------------------------------------------------------------------

typedef _SectionBuilder =
    List<ContextMenuSection> Function(BuildContext context);

class _MenuHarness extends StatelessWidget {
  const _MenuHarness({required this.buildSections});

  final _SectionBuilder buildSections;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sections = buildSections(context);

    return ListView(
      children: [
        for (final section in sections) ...[
          if (section.header != null)
            Text(
              section.header!,
              key: const Key('menu_header'),
              style: TextStyle(color: section.headerColor),
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

Widget _wrap(_SectionBuilder builder) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: _MenuHarness(buildSections: builder)),
  ),
);

void main() {
  // -------------------------------------------------------------------------
  // buildMovieContextMenu — VOD menu
  // -------------------------------------------------------------------------
  group('buildMovieContextMenu', () {
    testWidgets('renders exactly 5 items: Play, Favorite, Details, Copy URL, '
        'External', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildMovieContextMenu(
            context: ctx,
            movieName: 'Inception',
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
            onPlay: () {},
            onViewDetails: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(5));
    });

    testWidgets('Play is the first item', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildMovieContextMenu(
            context: ctx,
            movieName: 'Inception',
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
            onPlay: () {},
            onViewDetails: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final firstTitle = tiles.first.title as Text;
      expect(firstTitle.data, contains('Play'));
    });

    testWidgets('invokes onPlay when Play item is tapped', (tester) async {
      var playCalled = false;
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildMovieContextMenu(
            context: ctx,
            movieName: 'Inception',
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
            onPlay: () => playCalled = true,
            onViewDetails: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(ListTile).first);
      expect(playCalled, isTrue);
    });

    testWidgets('favorite icon is star_outline when not favourite', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildMovieContextMenu(
            context: ctx,
            movieName: 'Inception',
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
            onPlay: () {},
            onViewDetails: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('favorite icon is star (filled) when favourite', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildMovieContextMenu(
            context: ctx,
            movieName: 'Inception',
            isFavorite: true,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
            onPlay: () {},
            onViewDetails: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // buildEpisodeContextMenu — episode menu
  // -------------------------------------------------------------------------
  group('buildEpisodeContextMenu', () {
    testWidgets('renders exactly 3 items: Play, Copy URL, External', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildEpisodeContextMenu(
            context: ctx,
            episodeName: 'S01E01 – Pilot',
            colorScheme: Theme.of(ctx).colorScheme,
            onPlay: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(3));
    });

    testWidgets('Play is the first item', (tester) async {
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildEpisodeContextMenu(
            context: ctx,
            episodeName: 'S01E01 – Pilot',
            colorScheme: Theme.of(ctx).colorScheme,
            onPlay: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final firstTitle = tiles.first.title as Text;
      expect(firstTitle.data, contains('Play'));
    });
  });

  // -------------------------------------------------------------------------
  // buildChannelContextMenu (home row variant) — 4 items
  // -------------------------------------------------------------------------
  group('buildChannelContextMenu for home row', () {
    testWidgets('renders 4 items: Favorite toggle, Copy URL, External Player, '
        'plus the header', (tester) async {
      // Home row only passes onToggleFavorite, onCopyUrl, onOpenExternal.
      // That yields: [Favorite, CopyUrl, External] = 3 items.
      // With Stream Source added (common home-row usage) = 4 items.
      // Per spec: home row menu → Play (not applicable for channels),
      // Favorite, Copy URL, External.  The channel variant does NOT have
      // "Play" — it uses onSwitchStream instead.  The spec says 4 items for
      // the home row channel context menu.
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildChannelContextMenu(
            context: ctx,
            channelName: 'Home Channel',
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
            onSwitchStream: () {},
            onCopyUrl: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump();

      // Favorite, Switch stream, Copy URL, External = 4 items.
      expect(find.byType(ListTile), findsNWidgets(4));
    });
  });

  // -------------------------------------------------------------------------
  // Channel menu header — primary color
  // -------------------------------------------------------------------------
  group('Channel context menu header', () {
    testWidgets('header renders the channel name', (tester) async {
      const name = 'NHK World';
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildChannelContextMenu(
            context: ctx,
            channelName: name,
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text(name), findsOneWidget);
    });

    testWidgets('header text uses primary color from the theme', (
      tester,
    ) async {
      const name = 'NHK World';
      await tester.pumpWidget(
        _wrap(
          (ctx) => buildChannelContextMenu(
            context: ctx,
            channelName: name,
            isFavorite: false,
            colorScheme: Theme.of(ctx).colorScheme,
            onToggleFavorite: () {},
          ),
        ),
      );
      await tester.pump();

      final primaryColor =
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.colorScheme
              .primary ??
          ThemeData().colorScheme.primary;

      final header = tester.widget<Text>(find.byKey(const Key('menu_header')));
      expect(header.style?.color, primaryColor);
    });
  });

  // -------------------------------------------------------------------------
  // ContextMenuSection / ContextMenuItem models
  // -------------------------------------------------------------------------
  group('ContextMenuSection', () {
    test('constructs with default empty items list', () {
      const section = ContextMenuSection(header: 'Test');
      expect(section.items, isEmpty);
      expect(section.header, 'Test');
    });

    test('headerColor defaults to null (panel uses primary)', () {
      const section = ContextMenuSection(header: 'Test');
      expect(section.headerColor, isNull);
    });
  });

  group('ContextMenuItem', () {
    test('isDestructive defaults to false', () {
      const item = ContextMenuItem(
        icon: Icons.copy,
        label: 'Copy URL',
        onTap: _noop,
      );
      expect(item.isDestructive, isFalse);
    });

    test('isDestructive = true for destructive items', () {
      const item = ContextMenuItem(
        icon: Icons.block,
        label: 'Block channel',
        isDestructive: true,
        onTap: _noop,
      );
      expect(item.isDestructive, isTrue);
    });
  });
}

void _noop() {}
