import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/bubu/look.dart';
import 'package:little_steps/bubu/shop.dart';
import 'package:little_steps/copy/shop.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/settings/shop_screen.dart';

import '../../helpers/test_app.dart';

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<T> read<T>(WidgetTester tester, Future<T> Function() fn) async => (await tester.runAsync(fn)) as T;

DressUp previewOf(WidgetTester tester) =>
    tester.widget<BubuView>(find.byKey(const ValueKey('shop-preview'))).dressUp!;

void main() {
  testWidgets('trying on only changes the preview; wearing saves it', (tester) async {
    useTallSurface(tester);
    final env = TestEnv(now: DateTime(2026, 11, 7, 10));
    await pumpScreen(tester, env, const ShopScreen());

    // 十一月是秋天：秋天的架子在最前面。
    expect(find.text(ShopCopy.seasonShelf.fill(AgeTone.lively, {'season': '秋天'})), findsOneWidget);
    final first = BubuShop.seasonal[Season.autumn]!.first;
    await tester.tap(find.byKey(ValueKey('shop-${first.slot.name}-${first.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop-trying')), findsOneWidget);
    expect(previewOf(tester), first.wornOn(DressUp.initial));
    // 還沒按「穿上」：存起來的裝扮沒變。
    expect(await read(tester, env.repo.dressUp), DressUp.initial);

    await tester.tap(find.byKey(const ValueKey('shop-wear')));
    await settleAll(tester);
    expect(await read(tester, env.repo.dressUp), first.wornOn(DressUp.initial));
    expect(find.byKey(const ValueKey('shop-trying')), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('putting it back leaves the outfit as it was', (tester) async {
    useTallSurface(tester);
    final env = TestEnv(now: DateTime(2026, 4, 2, 10));
    await pumpScreen(tester, env, const ShopScreen());
    final item = BubuShop.seasonal[Season.spring]!.first;
    await tester.tap(find.byKey(ValueKey('shop-${item.slot.name}-${item.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-put-back')));
    await tester.pumpAndSettle();
    expect(previewOf(tester), DressUp.initial);
    expect(await read(tester, env.repo.dressUp), DressUp.initial);
    await finishTest(tester, env);
  });

  testWidgets('every item in the catalog is on a shelf and can be tried (no locks, no prices)', (tester) async {
    useTallSurface(tester);
    final env = TestEnv(now: DateTime(2026, 7, 1, 10));
    await pumpScreen(tester, env, const ShopScreen());
    for (final slot in AccessorySlot.values) {
      for (final a in BubuShop.itemsFor(slot).where((a) => a.id != 'none')) {
        final tile = find.byKey(ValueKey('shop-${slot.name}-${a.id}'));
        expect(tile, findsOneWidget, reason: '${slot.name}-${a.id}');
        expect(find.descendant(of: tile, matching: find.byType(InkWell)), findsOneWidget);
      }
    }
    // 畫面上沒有任何數字（價格、數量、剩幾天都不該有）。
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
    expect(RegExp(r'[0-9０-９]').hasMatch(texts), isFalse, reason: texts);
    await finishTest(tester, env);
  });
}
