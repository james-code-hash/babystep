// 情境：探索角與驚喜盒（J1、J2）。隨便逛、沒有要完成的事、什麼都不記錄。
//
// - 每日一個小疑問：先問、點了才看答案、可以換一題；隔天換一個（只看日期）。
// - 畫給步步：畫、送給步步、擦掉；離開就不見，資料庫一個字都沒變。
// - 驚喜盒：某些日子才有（只看日期，不是獎勵），打開、再搖一次；其他日子連「少了什麼」的暗示都沒有。
// - 輕點首頁的步步：嚇一跳＋一句話，過一下回到原樣。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/bubu/surprise.dart';
import 'package:little_steps/copy/explore.dart';
import 'package:little_steps/copy/surprise.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/explore/explore_screen.dart';

import '../e2e/harness.dart';
import 'child_day.dart' show planOnePreset, reviewAll;

DateTime _firstDay({required bool box, required DateTime from}) {
  var d = from;
  while (surpriseBoxOn(d) != box) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

void exploreScenarios() {
  testWidgets('curio of the day: answer only on tap, "another" works, tomorrow brings a new one; drawing is never kept',
      (tester) async {
    final app = await E2EApp.launch(tester, now: _firstDay(box: false, from: DateTime(2026, 11, 4, 17, 0)));
    final before = await app.read((r) => r.exportJson());
    await app.tap('nav-explore');
    final today = ExploreCopy.curios[curioIndexFor(app.clock.now())];
    expect(app.has('curio-${today.id}'), isTrue);
    expect(app.has('curio-answer'), isFalse);
    await app.tap('curio-reveal');
    expect(find.text(today.answer.lively), findsOneWidget);
    await app.tap('curio-another');
    expect(app.has('curio-${today.id}'), isFalse);
    expect(app.has('curio-answer'), isFalse);

    // 驚喜盒不是每天都有；沒有的日子也沒有「少了什麼」的暗示。
    expect(app.has('surprise-card'), isFalse);
    expect(find.text(SurpriseCopy.boxTitle.lively), findsNothing);

    // 畫一筆、送給步步、擦掉。
    FilledButton give() => tester.widget<FilledButton>(find.byKey(const ValueKey('draw-give')));
    await app.tap('draw-color-2');
    expect(give().onPressed, isNull, reason: 'nothing to give yet');
    await tester.drag(find.byKey(const ValueKey('draw-canvas')), const Offset(120, 60));
    await app.settle();
    expect(give().onPressed, isNotNull);
    await app.tap('draw-give');
    final thanks = tester.widget<Text>(find.byKey(const ValueKey('draw-thanks'))).data;
    expect(ExploreCopy.drawThanks.lines.map((l) => l.lively), contains(thanks));
    await app.tap('draw-clear');
    expect(app.has('draw-thanks'), isFalse);
    expect(give().onPressed, isNull);
    // 再畫一筆就離開：回來是空白的（不存）。
    await tester.drag(find.byKey(const ValueKey('draw-canvas')), const Offset(-80, 40));
    await app.settle();
    await app.back();
    await app.tap('nav-explore');
    await app.tap('draw-color-0');
    expect(give().onPressed, isNull, reason: 'the drawing is gone after leaving');
    await app.back();
    expect(await app.read((r) => r.exportJson()), before, reason: 'exploring writes nothing');

    // 隔天：換一個小疑問。
    await app.resumeAt(app.clock.now().add(const Duration(days: 1)));
    await app.tap('nav-explore');
    final tomorrow = ExploreCopy.curios[curioIndexFor(app.clock.now())];
    expect(tomorrow.id, isNot(today.id));
    expect(app.has('curio-${tomorrow.id}'), isTrue);
    await app.back();
    await app.close();
  });

  testWidgets('surprise box shows up on its own days whatever the child did; open it, shake again, nothing saved',
      (tester) async {
    final day = _firstDay(box: true, from: DateTime(2026, 11, 4, 20, 45));
    final app = await E2EApp.launch(tester, now: day);
    // 和做了什麼無關：今天一件都說「今天沒做」，盒子照樣在。
    await planOnePreset(app);
    await reviewAll(app, [Outcome.notToday]);
    final before = await app.read((r) => r.exportJson());

    await app.tap('nav-explore');
    expect(app.has('surprise-card'), isTrue);
    expect(app.has('surprise-story'), isFalse);
    await app.tap('surprise-box');
    final story = tester.widget<Text>(find.byKey(const ValueKey('surprise-story'))).data;
    expect(SurpriseCopy.stories.lines.map((l) => l.lively), contains(story));
    await app.tap('surprise-again');
    expect(app.has('surprise-story'), isTrue);
    await app.back();
    expect(await app.read((r) => r.exportJson()), before);
    await app.close();
  });

  testWidgets('tapping Bubu on Home: a little surprise and a line, then back to normal; nothing recorded',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 10, 0));
    final before = await app.read((r) => r.exportJson());
    BubuExpression face() => tester.widget<BubuView>(find.byType(BubuView).first).expression;
    final resting = face();
    await tester.tap(find.byKey(const ValueKey('home-bubu')));
    await tester.pump();
    expect(face(), BubuExpression.surprised);
    expect(SurpriseCopy.pokes.lines.any((l) => find.text(l.lively).evaluate().isNotEmpty), isTrue);
    const fade = Duration(milliseconds: SurpriseConfig.pokeMs + 100);
    await tester.pump(fade);
    if (app.onDevice) await tester.runAsync(() => Future<void>.delayed(fade));
    await app.settle();
    expect(face(), resting);
    expect(SurpriseCopy.pokes.lines.any((l) => find.text(l.lively).evaluate().isNotEmpty), isFalse);
    expect(await app.read((r) => r.exportJson()), before);
    await app.close();
  });
}
