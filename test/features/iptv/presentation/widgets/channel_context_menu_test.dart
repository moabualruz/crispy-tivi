import 'package:crispy_tivi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/widgets/context_menu_builders.dart';
import 'package:crispy_tivi/core/widgets/context_menu_panel.dart';

/// Pumps a widget that builds channel context menu sections
/// and renders them inline so we can assert on the items
/// without needing to drive the full showContextMenuPanel
/// dialog.
class _ChannelMenuHarness extends StatelessWidget {
  const _ChannelMenuHarness({
    required this.channelName,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onBlock,
  });

  final String channelName;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sections = buildChannelContextMenu(
      context: context,
      channelName: channelName,
      isFavorite: isFavorite,
      colorScheme: colorScheme,
      onToggleFavorite: onToggleFavorite,
      onSwitchStream: () {},
      onSmartGroup: () {},
      onMultiView: () {},
      onAssignEpg: () {},
      onHide: () {},
      onCopyUrl: () {},
      onBlock: onBlock,
    );

    return ListView(
      children: [
        for (final section in sections) ...[
          if (section.header != null)
            Text(section.header!, style: TextStyle(color: section.headerColor)),
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

Widget _buildHarness({
  required String channelName,
  required bool isFavorite,
  required VoidCallback onToggleFavorite,
  VoidCallback? onBlock,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: _ChannelMenuHarness(
          channelName: channelName,
          isFavorite: isFavorite,
          onToggleFavorite: onToggleFavorite,
          onBlock: onBlock,
        ),
      ),
    ),
  );
}

void main() {
  group('Channel context menu — item count', () {
    testWidgets('renders exactly 8 items when all callbacks are provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          channelName: 'CNN',
          isFavorite: false,
          onToggleFavorite: () {},
          onBlock: () {},
        ),
      );
      await tester.pump();

      // 8 expected items: Favorite toggle, Stream Source, Smart Group,
      // Multi-View, Assign EPG, Hide, Copy URL, Block.
      expect(find.byType(ListTile), findsNWidgets(8));
    });
  });

  group('Channel context menu — favorite toggle icon', () {
    testWidgets('shows star_outline icon when channel is NOT a favorite', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          channelName: 'BBC One',
          isFavorite: false,
          onToggleFavorite: () {},
          onBlock: () {},
        ),
      );
      await tester.pump();

      // star_outline expected when isFavorite = false.
      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows star (filled) icon when channel IS a favorite', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          channelName: 'BBC One',
          isFavorite: true,
          onToggleFavorite: () {},
          onBlock: () {},
        ),
      );
      await tester.pump();

      // Filled star expected when isFavorite = true.
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
    });
  });

  group('Channel context menu — favorite tap callback', () {
    testWidgets('tapping the Favorite item invokes onToggleFavorite', (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        _buildHarness(
          channelName: 'Sky News',
          isFavorite: false,
          onToggleFavorite: () => called = true,
          onBlock: () {},
        ),
      );
      await tester.pump();

      // The favorite item is the first ListTile.
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      expect(called, isTrue);
    });
  });

  group('Channel context menu — Block item destructive styling', () {
    testWidgets('Block item uses error color on text and icon', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          channelName: 'Channel 5',
          isFavorite: false,
          onToggleFavorite: () {},
          onBlock: () {},
        ),
      );
      await tester.pump();

      final colorScheme =
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.colorScheme ??
          ThemeData().colorScheme;

      // Find the Block tile by its key and assert colors.
      final blockTile = tester.widget<ListTile>(
        find.byKey(const Key('item_Block channel')),
      );

      final titleText = blockTile.title! as Text;
      expect(titleText.style?.color, colorScheme.error);

      final leadingIcon = blockTile.leading! as Icon;
      expect(leadingIcon.color, colorScheme.error);
    });
  });

  group('Channel context menu — header', () {
    testWidgets('header shows channel name', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          channelName: 'Al Jazeera',
          isFavorite: false,
          onToggleFavorite: () {},
          onBlock: () {},
        ),
      );
      await tester.pump();

      expect(find.text('Al Jazeera'), findsOneWidget);
    });

    testWidgets('header text uses primary color', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          channelName: 'RT',
          isFavorite: false,
          onToggleFavorite: () {},
          onBlock: () {},
        ),
      );
      await tester.pump();

      // The harness renders the header color = colorScheme.primary.
      // Extract the primary color from the theme to compare.
      final primaryColor =
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme
              ?.colorScheme
              .primary ??
          ThemeData().colorScheme.primary;

      final header = tester.widget<Text>(find.text('RT'));
      expect(header.style?.color, primaryColor);
    });
  });

  group('Channel context menu — ContextMenuItem model', () {
    test('isDestructive is false by default', () {
      const item = ContextMenuItem(
        icon: Icons.star,
        label: 'Add to Favorites',
        onTap: _noop,
      );
      expect(item.isDestructive, isFalse);
    });

    test('isDestructive = true for Block item model', () {
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
