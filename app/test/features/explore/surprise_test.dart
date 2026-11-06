// 驚喜盒與隱藏互動（J2）：哪天出現只看日期、不規律；內容不評價、不記錄。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/bubu/surprise.dart';
import 'package:little_steps/copy/surprise.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/explore/explore_screen.dart';
import 'package:little_steps/features/home/home_screen.dart';

import '../../helpers/test_app.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

DateTime _firstDay(bool on) {
  var d = DateTime(2026, 10, 1, 19, 30);
  while (surpriseBoxOn(d) != on) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

void main() {
  group('when the box shows up', () {
    test('same answer all day long', () {
      for (var i = 0; i < 60; i++) {
        final d = DateTime(2026, 1, 1).add(Duration(days: i));
        expect(surpriseBoxOn(d.add(const Duration(hours: 7))), surpriseBoxOn(d.add(const Duration(hours: 22))));
      }
    });

    test('some days, not most days, and not on a fixed weekday', () {
      final days = [for (var i = 0; i < 365; i++) DateTime(2026, 1, 1).add(Duration(days: i))];
      final on = days.where(surpriseBoxOn).toList();
      expect(on.length, inInclusiveRange(365 * 0.2, 365 * 0.5));
      expect(on.map((d) => d.weekday).toSet(), hasLength(7));
    });
  });

  test('every story and poke passes the copy rules in both tones', () {
    final rules = loadCopyRules();
    for (final pool in [SurpriseCopy.stories, SurpriseCopy.pokes]) {
      for (final l in pool.lines) {
        for (final tone in AgeTone.values) {
          expect(rules.check(l.of(tone), tone: tone), isEmpty, reason: l.of(tone));
        }
      }
    }
    final (line, _) = pickSurprise(Random(3));
    expect(SurpriseCopy.stories.lines, contains(line));
  });

  testWidgets('on a box day: tap to open, shake again for another; nothing is saved', (tester) async {
    _tall(tester);
    final env = TestEnv(now: _firstDay(true));
    await pumpScreen(tester, env, const ExploreScreen());
    final before = (await tester.runAsync(env.repo.exportJson))!;
    expect(find.byKey(const ValueKey('surprise-story')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('surprise-box')));
    await tester.pumpAndSettle();
    final story = tester.widget<Text>(find.byKey(const ValueKey('surprise-story'))).data;
    expect(SurpriseCopy.stories.lines.map((l) => l.lively), contains(story));
    await tester.tap(find.byKey(const ValueKey('surprise-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('surprise-story')), findsOneWidget);
    expect((await tester.runAsync(env.repo.exportJson))!, before);
    await finishTest(tester, env);
  });

  testWidgets('on other days there is no box, and no hint that one is missing', (tester) async {
    _tall(tester);
    final env = TestEnv(now: _firstDay(false));
    await pumpScreen(tester, env, const ExploreScreen());
    expect(find.byKey(const ValueKey('surprise-card')), findsNothing);
    expect(find.text(SurpriseCopy.boxTitle.lively), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('tapping Bubu on Home gets a little reaction that fades back', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await pumpApp(tester, env);
    await settleAll(tester);
    BubuExpression face() => tester.widget<BubuView>(find.byType(BubuView).first).expression;
    final resting = face();
    await tester.tap(find.byKey(const ValueKey('home-bubu')));
    await tester.pump();
    expect(face(), BubuExpression.surprised);
    expect(SurpriseCopy.pokes.lines.any((l) => find.text(l.lively).evaluate().isNotEmpty), isTrue);
    await tester.pump(const Duration(milliseconds: SurpriseConfig.pokeMs + 50));
    await tester.pumpAndSettle();
    expect(face(), resting);
    expect(SurpriseCopy.pokes.lines.any((l) => find.text(l.lively).evaluate().isNotEmpty), isFalse);
    expect(find.byType(HomeScreen), findsOneWidget);
    await finishTest(tester, env);
  });
}
