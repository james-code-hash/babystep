// 情境：成長軌跡的三種樣子（J3）與月回顧（J4），用好幾天真的用下來。
//
// 跨月的幾天：有排的日子才有記號（石頭／葉子／星星），每個記號都一樣、不看結果、沒排的日子沒有空洞；
// 孩子在頁面上換樣子，會記住、會匯出。「這個月的我」用故事說、只跟自己比，可以翻到上個月。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/month.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/path/path_trail.dart';
import 'package:little_steps/features/path/sky_trail.dart';
import 'package:little_steps/features/path/tree_trail.dart';

import '../e2e/harness.dart';
import 'child_day.dart' show planOnePreset, reviewAll;

void trailMonthScenarios() {
  testWidgets('several days across two months: path, tree and sky mark only planned days, all alike; '
      'the month page tells a short story and turns back a month', (tester) async {
    // 10/30 排一件；11/2 排、聊完「做到了」；11/3 沒打開；11/4 排、聊完「今天沒做」。
    final app = await E2EApp.launch(tester, now: DateTime(2026, 10, 30, 7, 30));
    await planOnePreset(app, task: 1, cue: 0);
    await app.resumeAt(DateTime(2026, 11, 2, 20, 45));
    await planOnePreset(app, task: 0, cue: 0);
    await reviewAll(app, [Outcome.done]);
    await app.resumeAt(DateTime(2026, 11, 4, 20, 45));
    await planOnePreset(app, task: 0, cue: 1);
    await reviewAll(app, [Outcome.notToday]);
    const planned = ['2026-10-30', '2026-11-02', '2026-11-04'];
    final topTask = (await app.read((r) => r.plans('2026-11-02'))).single.task;

    // 小路（預設）：三塊石頭，11/3 沒有洞。
    await app.tap('nav-path');
    expect(find.byType(PathStone), findsNWidgets(3));
    for (final k in planned) {
      expect(app.has('stone-$k'), isTrue, reason: k);
    }
    expect(app.has('stone-2026-11-03'), isFalse);

    // 一棵樹、星空：一樣只有三個記號，而且長得一樣（「做到了」和「今天沒做」的那天沒差）。
    for (final (style, kind, type) in [('tree', 'leaf', TreeTrail), ('sky', 'star', SkyTrail)]) {
      await app.tap('trail-style-$style');
      expect(find.byType(type), findsOneWidget);
      expect(find.byType(TrailMark), findsNWidgets(3));
      Decoration? deco(String k) => tester.widget<Container>(find.byKey(ValueKey('$kind-$k'))).decoration;
      for (final k in planned) {
        expect(app.has('$kind-$k'), isTrue, reason: '$style $k');
        expect(deco(k), deco(planned.first), reason: '$style $k looks the same');
      }
      expect(app.has('$kind-2026-11-03'), isFalse);
    }
    await app.back();

    // 選的樣子會記住、會匯出。
    await app.tap('nav-path');
    expect(find.byType(SkyTrail), findsOneWidget);
    final export = jsonDecode(await app.read((r) => r.exportJson())) as Map<String, Object?>;
    expect((export['settings']! as Map)['trailStyle'], 'sky');

    // 這個月的我：兩天、最常排的那件；沒有百分比，只跟自己比。
    await app.tap('open-month');
    expect(app.has('month-page-2026-11'), isTrue);
    expect(app.has('month-story'), isTrue);
    expect(find.text(MonthCopy.days.fill(AgeTone.lively, {'n': '2'})), findsOneWidget);
    expect(find.text(MonthCopy.topTask.fill(AgeTone.lively, {'task': topTask})), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(app.has('month-letter-field'), isTrue, reason: 'this month can be written to');

    // 翻到上個月：一天，只能看不能寫。
    await app.tap('month-older');
    expect(app.has('month-page-2026-10'), isTrue);
    expect(find.text(MonthCopy.days.fill(AgeTone.lively, {'n': '1'})), findsOneWidget);
    expect(app.has('month-letter-field'), isFalse);
    expect(tester.widget<IconButton>(find.byKey(const ValueKey('month-older'))).onPressed, isNull);
    await app.tap('month-newer');
    expect(app.has('month-page-2026-11'), isTrue);
    await app.close();
  });

  testWidgets('a brand-new path / tree / sky page is friendly, offers the looks, and shows no gaps or counts',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 9, 0));
    await app.tap('nav-path');
    expect(app.has('path-empty'), isTrue);
    for (final style in ['tree', 'sky', 'path']) {
      await app.tap('trail-style-$style');
      expect(find.byType(TrailMark), findsNothing);
      expect(find.byType(PathStone), findsNothing);
      expect(app.visibleTexts().where((t) => RegExp(r'[0-9０-９]+\s*(天|塊|片|顆|次)').hasMatch(t)), isEmpty);
    }
    await app.tap('open-month');
    expect(app.has('month-page-2026-11'), isTrue);
    expect(find.textContaining('%'), findsNothing);
    await app.close();
  });
}
