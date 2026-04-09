import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/home/presentation/widgets/vod_row.dart';
import 'package:crispy_tivi/features/vod/domain/entities/vod_item.dart';
import 'package:crispy_tivi/features/vod/presentation/widgets/vod_poster_card.dart';

void main() {
  testWidgets('VodRow virtualizes large horizontal rails', (tester) async {
    final items = List.generate(
      100,
      (index) => VodItem(
        id: 'vod-$index',
        name: 'Item $index',
        streamUrl: 'http://example.com/$index',
        type: VodType.movie,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              child: VodRow(title: 'Large Row', items: items),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialCards = tester.widgetList(find.byType(VodPosterCard)).length;
    expect(initialCards, greaterThan(0));
    expect(initialCards, lessThan(items.length));

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-2400, 0),
    );
    await tester.pumpAndSettle();

    final afterScrollCards =
        tester.widgetList(find.byType(VodPosterCard)).length;
    expect(afterScrollCards, greaterThan(0));
    expect(afterScrollCards, lessThan(items.length));
  });
}
