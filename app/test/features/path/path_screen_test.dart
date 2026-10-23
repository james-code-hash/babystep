import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/path.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/path/path_insights.dart';
import 'package:little_steps/features/path/path_screen.dart';
import 'package:little_steps/features/path/path_trail.dart';

import '../../helpers/test_app.dart';

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 結束前把畫面拆掉，讓 drift 的 stream 取消計時器跑完。
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

BoxDecoration stoneDecoration(WidgetTester tester, String dayKey) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byKey(ValueKey('stone-$dayKey')), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('path screen', () {
    testWidgets('draws exactly one stone per planned day, and nothing for the days in between', (tester) async {
      useTallSurface(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.savePlans('2026-10-08', const [PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我放學回到家')]);
      await env.repo.savePlans('2026-10-15', const [
        PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡'),
        PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我吃完晚飯'),
      ]);
      await env.repo.savePlans('2026-10-20', const [PlanDraft(emoji: '🎒', task: '整理書包', cue: '我吃完晚飯')]);

      await pumpScreen(tester, env, const PathScreen());

      expect(find.byType(PathStone), findsNWidgets(3));
      for (final k in ['2026-10-08', '2026-10-15', '2026-10-20']) {
        expect(find.byKey(ValueKey('stone-$k')), findsOneWidget);
      }
      // 沒計畫的日子不畫：沒有空格、沒有「漏掉」的石頭。
      for (final k in ['2026-10-09', '2026-10-16', '2026-10-21', '2026-10-22', '2026-10-23']) {
        expect(find.byKey(ValueKey('stone-$k')), findsNothing);
      }
      // 石頭上是那天第一件事的圖示和日期。
      expect(find.descendant(of: find.byKey(const ValueKey('stone-2026-10-15')), matching: find.text('📖')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('stone-2026-10-15')), matching: find.text('✏️')), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('stone-2026-10-20')), matching: find.text('10/20')), findsOneWidget);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('stones look identical whatever the outcomes are', (tester) async {
      useTallSurface(tester);
      final env = TestEnv();
      await env.seed();
      final a = await env.repo.savePlans('2026-10-18', const [PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我放學回到家')]);
      final b = await env.repo.savePlans('2026-10-20', const [PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我放學回到家')]);
      final c = await env.repo.savePlans('2026-10-22', const [PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我放學回到家')]);

      await pumpScreen(tester, env, const PathScreen());
      final before = stoneDecoration(tester, '2026-10-18');

      await env.repo.setOutcome(a.single.id, Outcome.done);
      await env.repo.setOutcome(b.single.id, Outcome.partly);
      await env.repo.setOutcome(c.single.id, Outcome.notToday);
      await tester.pumpAndSettle();

      final decorations = [for (final k in ['2026-10-18', '2026-10-20', '2026-10-22']) stoneDecoration(tester, k)];
      for (final d in decorations) {
        expect(d, before);
      }
      // 每塊石頭的子樹結構也一樣（只有日期文字不同）。
      int count(String k) =>
          find.descendant(of: find.byKey(ValueKey('stone-$k')), matching: find.byWidgetPredicate((_) => true)).evaluate().length;
      expect({count('2026-10-18'), count('2026-10-20'), count('2026-10-22')}.length, 1);
      expect(find.byType(PathStone), findsNWidgets(3));
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('self-only insights: most-used cue, most-planned thing, days this month', (tester) async {
      useTallSurface(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.savePlans('2026-09-30', const [PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我洗完澡')]);
      await env.repo.savePlans('2026-10-02', const [PlanDraft(emoji: '📖', task: '看一本書', cue: '我吃完晚飯')]);
      await env.repo.savePlans('2026-10-12', const [
        PlanDraft(emoji: '📖', task: '看一本書', cue: '我吃完晚飯'),
        PlanDraft(emoji: '🎒', task: '整理書包', cue: '我洗完澡'),
      ]);
      await env.repo.savePlans('2026-10-21', const [PlanDraft(emoji: '🎒', task: '收拾玩具', cue: '我吃完晚飯')]);

      await pumpScreen(tester, env, const PathScreen());

      expect(find.byType(PathStone), findsNWidgets(4));
      expect(find.text('你最常用的開始信號是「吃完晚飯」耶。'), findsOneWidget);
      expect(find.text('你常給自己排的事是「看一本書」。'), findsOneWidget);
      expect(find.text('這個月你自己想清楚了 3 天要做什麼耶。'), findsOneWidget);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('concise tone uses the concise lines', (tester) async {
      useTallSurface(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.setTone(AgeTone.concise);
      await env.repo.savePlans('2026-10-20', const [PlanDraft(emoji: '🎒', task: '整理書包', cue: '我吃完晚飯')]);
      await pumpScreen(tester, env, const PathScreen());
      expect(find.text('這個月你自己想清楚了 1 天要做什麼。'), findsOneWidget);
      // 只出現一次就不說「最常」。
      expect(find.byKey(const ValueKey('insight-cue')), findsNothing);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('empty state is friendly and has no stones', (tester) async {
      final env = TestEnv();
      await pumpScreen(tester, env, const PathScreen());
      expect(find.byType(PathStone), findsNothing);
      expect(find.byKey(const ValueKey('path-empty')), findsOneWidget);
      expect(find.text(PathCopy.empty.lively), findsOneWidget);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });
  });

  group('PathInsights', () {
    PlannedDay day(String k, List<String> tasks, List<String> cues) =>
        PlannedDay(dayKey: k, emojis: [for (final _ in tasks) '⭐'], tasks: tasks, cues: cues);

    test('needs at least two uses to call something "most"', () {
      final i = PathInsights.from([day('2026-10-01', ['看書'], ['我洗完澡'])], DateTime(2026, 10, 23));
      expect(i.topCue, isNull);
      expect(i.topTask, isNull);
      expect(i.daysThisMonth, 1);
    });

    test('ties go to the most recently used', () {
      final i = PathInsights.from([
        day('2026-10-01', ['看書', '練琴'], ['我洗完澡', '我吃完晚飯']),
        day('2026-10-05', ['練琴', '看書'], ['我吃完晚飯', '我洗完澡']),
      ], DateTime(2026, 10, 23));
      expect(i.topTask, '看書');
      expect(i.topCue, '我洗完澡');
    });

    test('only counts days in the given month', () {
      final i = PathInsights.from([
        day('2026-09-30', ['看書'], ['我洗完澡']),
        day('2026-10-01', ['看書'], ['我洗完澡']),
        day('2026-11-01', ['看書'], ['我洗完澡']),
      ], DateTime(2026, 10, 23));
      expect(i.daysThisMonth, 1);
    });

    test('cue loses its leading 我 in the sentence only', () {
      expect(PathCopy.cueWithoutMe('我吃完晚飯'), '吃完晚飯');
      expect(PathCopy.cueWithoutMe('我'), '我');
    });
  });

  test('PathTrail stone centers wind gently and never leave the width', () {
    final pts = PathTrail.stoneCenters(10, 400);
    expect(pts, hasLength(10));
    for (final p in pts) {
      expect(p.dx, inInclusiveRange(0, 400));
    }
    for (var i = 1; i < pts.length; i++) {
      expect(pts[i].dy, greaterThan(pts[i - 1].dy));
    }
  });
}
