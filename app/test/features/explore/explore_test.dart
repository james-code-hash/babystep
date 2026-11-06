// 探索角（J1）：每日一個小疑問只看日期；塗鴉送給步步，不評價、不存。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/explore.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/explore/explore_screen.dart';

import '../../helpers/test_app.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('daily curio', () {
    test('changes once a day and goes through every one', () {
      final start = DateTime(2026, 11, 1, 8);
      expect(curioIndexFor(start), curioIndexFor(DateTime(2026, 11, 1, 23, 59)));
      expect(curioIndexFor(start), isNot(curioIndexFor(DateTime(2026, 11, 2, 0, 1))));
      final seen = {
        for (var d = 0; d < ExploreCopy.curios.length; d++) curioIndexFor(start.add(Duration(days: d))),
      };
      expect(seen, hasLength(ExploreCopy.curios.length));
    });

    test('ids are unique and every line passes the copy rules in both tones', () {
      final rules = loadCopyRules();
      expect(ExploreCopy.curios.map((c) => c.id).toSet(), hasLength(ExploreCopy.curios.length));
      for (final c in ExploreCopy.curios) {
        for (final tone in AgeTone.values) {
          for (final s in [c.question.of(tone), c.answer.of(tone), c.topic.of(tone)]) {
            expect(rules.check(s, tone: tone), isEmpty, reason: '${c.id}: $s');
          }
        }
      }
      for (final l in ExploreCopy.drawThanks.lines) {
        expect(rules.check(l.lively, tone: AgeTone.lively), isEmpty, reason: l.lively);
      }
    });
  });

  testWidgets('the question shows first; the answer only after tapping; "another" closes it again', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await pumpScreen(tester, env, const ExploreScreen());
    final today = ExploreCopy.curios[curioIndexFor(env.clock.now())];
    expect(find.byKey(ValueKey('curio-${today.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('curio-answer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('curio-reveal')));
    await tester.pumpAndSettle();
    expect(find.text(today.answer.lively), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('curio-another')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('curio-${today.id}')), findsNothing);
    expect(find.byKey(const ValueKey('curio-answer')), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('draw, give it to Bubu, clear; nothing is written to the database', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await pumpScreen(tester, env, const ExploreScreen());
    final before = (await tester.runAsync(env.repo.exportJson))!;

    FilledButton give() => tester.widget<FilledButton>(find.byKey(const ValueKey('draw-give')));
    expect(give().onPressed, isNull, reason: 'nothing to give yet');

    await tester.ensureVisible(find.byKey(const ValueKey('draw-canvas')));
    await tester.tap(find.byKey(const ValueKey('draw-color-2')));
    await tester.drag(find.byKey(const ValueKey('draw-canvas')), const Offset(120, 60));
    await tester.pumpAndSettle();
    expect(give().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('draw-give')));
    await tester.pumpAndSettle();
    final thanks = tester.widget<Text>(find.byKey(const ValueKey('draw-thanks'))).data;
    expect(ExploreCopy.drawThanks.lines.map((l) => l.lively), contains(thanks));

    await tester.tap(find.byKey(const ValueKey('draw-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draw-thanks')), findsNothing);
    expect(give().onPressed, isNull);

    final after = (await tester.runAsync(env.repo.exportJson))!;
    expect(after, before);
    await finishTest(tester, env);
  });

  test('explore never reads what the child planned, reviewed or taught, and never writes', () {
    final forbidden = RegExp(r'\b(repositoryProvider|todayPlansProvider|todayRecordProvider|lessonsProvider|'
        r'plannedDaysProvider|databaseProvider|watchPlans|setOutcome)\b');
    for (final f in Directory('lib/features/explore').listSync(recursive: true).whereType<File>()) {
      final src = f.readAsStringSync();
      expect(forbidden.allMatches(src).map((m) => m.group(0)), isEmpty, reason: f.path);
      expect(src, isNot(contains('data/')), reason: '${f.path} must not import the data layer');
    }
  });
}
