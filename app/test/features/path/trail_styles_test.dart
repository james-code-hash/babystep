// 成長軌跡的另外兩種樣子（J3）：一棵樹、星空。和小路一樣：只畫有計畫的日子、每個記號都一樣、沒有空洞。
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/path.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/path/path_screen.dart';
import 'package:little_steps/features/path/map_trail.dart';
import 'package:little_steps/features/path/path_trail.dart';
import 'package:little_steps/features/path/sky_trail.dart';
import 'package:little_steps/features/path/tree_trail.dart';

import '../../helpers/test_app.dart';
import 'path_screen_test.dart' show unmount, useTallSurface;

const _draft = [PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我放學回到家')];

PlannedDay _day(int i) => PlannedDay(dayKey: '2026-${(i ~/ 28 + 1).toString().padLeft(2, '0')}-'
    '${(i % 28 + 1).toString().padLeft(2, '0')}', emojis: const ['🎹'], tasks: const ['練習樂器'], cues: const ['我放學回到家']);

void main() {
  for (final (style, kind) in [(TrailStyle.tree, 'leaf'), (TrailStyle.sky, 'star'), (TrailStyle.map, 'place')]) {
    group('$style', () {
      testWidgets('one $kind per planned day, nothing for the days in between', (tester) async {
        useTallSurface(tester);
        final env = TestEnv();
        await env.seed();
        await env.repo.setTrailStyle(style);
        for (final k in ['2026-10-08', '2026-10-15', '2026-10-20']) {
          await env.repo.savePlans(k, _draft);
        }
        await pumpScreen(tester, env, const PathScreen());
        expect(find.byType(PathStone), findsNothing);
        for (final k in ['2026-10-08', '2026-10-15', '2026-10-20']) {
          expect(find.byKey(ValueKey('$kind-$k')), findsOneWidget);
        }
        for (final k in ['2026-10-09', '2026-10-16', '2026-10-21', '2026-10-23']) {
          expect(find.byKey(ValueKey('$kind-$k')), findsNothing);
        }
        expect(find.byType(TrailMark), findsNWidgets(3));
        await unmount(tester);
        await tester.runAsync(env.dispose);
      });

      testWidgets('every $kind looks the same whatever the outcomes are', (tester) async {
        useTallSurface(tester);
        final env = TestEnv();
        await env.seed();
        await env.repo.setTrailStyle(style);
        final ids = [
          for (final k in ['2026-10-18', '2026-10-20', '2026-10-22']) (await env.repo.savePlans(k, _draft)).single.id,
        ];
        await pumpScreen(tester, env, const PathScreen());
        Decoration deco(String k) => tester.widget<Container>(find.byKey(ValueKey('$kind-$k'))).decoration!;
        final before = deco('2026-10-18');
        await env.repo.setOutcome(ids[0], Outcome.done);
        await env.repo.setOutcome(ids[1], Outcome.partly);
        await env.repo.setOutcome(ids[2], Outcome.notToday);
        await tester.pumpAndSettle();
        for (final k in ['2026-10-18', '2026-10-20', '2026-10-22']) {
          expect(deco(k), before, reason: k);
        }
        await unmount(tester);
        await tester.runAsync(env.dispose);
      });
    });
  }

  testWidgets('the child picks the look on the page; it is saved and exported', (tester) async {
    useTallSurface(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.savePlans('2026-10-20', _draft);
    await pumpScreen(tester, env, const PathScreen());
    expect(find.byType(PathStone), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trail-style-tree')));
    await settleAll(tester);
    expect(find.byType(TreeTrail), findsOneWidget);
    expect(find.text(PathCopy.introTree.lively), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trail-style-sky')));
    await settleAll(tester);
    expect(find.byType(SkyTrail), findsOneWidget);
    expect((await tester.runAsync(env.repo.settings))!.trailStyle, TrailStyle.sky);
    final export = jsonDecode((await tester.runAsync(env.repo.exportJson))!) as Map<String, Object?>;
    expect((export['settings']! as Map)['trailStyle'], 'sky');
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });

  testWidgets('the empty page also offers the looks, with its own words', (tester) async {
    final env = TestEnv();
    await env.seed();
    await env.repo.setTrailStyle(TrailStyle.sky);
    await pumpScreen(tester, env, const PathScreen());
    expect(find.text(PathCopy.emptySky.lively), findsOneWidget);
    expect(find.byKey(const ValueKey('trail-style-path')), findsOneWidget);
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });

  // 地圖（J5）：一個月一章，新的在上；沒排事的月份不會變成空白地圖。
  group('map', () {
    PlannedDay d(String k) => PlannedDay(dayKey: k, emojis: const ['🎹'], tasks: const ['練習樂器'], cues: const []);

    test('chapters are months that have planned days, newest first, dates in order inside', () {
      final c = MapTrail.chapters([d('2026-08-30'), d('2026-10-02'), d('2026-10-20'), d('2026-10-11')]);
      expect(c.map((x) => x.month), ['2026-10', '2026-08'], reason: 'September had nothing: no empty map');
      expect(c.first.days.map((x) => x.dayKey), ['2026-10-02', '2026-10-11', '2026-10-20']);
    });

    test('titles name the month; the first is 出發; no chapter numbers', () {
      String t(String m, {bool first = false, bool year = false}) =>
          MapTrail.chapterTitle(m, first: first, withYear: year, tone: AgeTone.lively);
      expect(t('2026-08', first: true), '8月：出發');
      expect(t('2026-10'), '10月的旅程');
      expect(t('2027-01', year: true), '2027年1月的旅程');
      for (final l in [PathCopy.chapter, PathCopy.chapterFirst, PathCopy.chapterWithYear, PathCopy.chapterFirstWithYear]) {
        expect(l.lively, isNot(contains('第')), reason: 'not a level or a count');
      }
    });

    testWidgets('the page shows one titled map per month', (tester) async {
      useTallSurface(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.setTrailStyle(TrailStyle.map);
      for (final k in ['2026-08-30', '2026-10-08', '2026-10-15']) {
        await env.repo.savePlans(k, _draft);
      }
      await pumpScreen(tester, env, const PathScreen());
      expect(find.byKey(const ValueKey('map-chapter-2026-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-chapter-2026-08')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-chapter-2026-09')), findsNothing);
      expect(find.text('8月：出發'), findsOneWidget);
      expect(tester.getTopLeft(find.text('10月的旅程')).dy, lessThan(tester.getTopLeft(find.text('8月：出發')).dy));
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    test('places stay inside the map', () {
      for (final width in [320.0, 600.0]) {
        for (final p in MapTrail.placeCenters(31, width)) {
          expect(p.dx - TrailConfig.mapPlaceSize / 2, greaterThanOrEqualTo(0));
          expect(p.dx + TrailConfig.mapPlaceSize / 2, lessThanOrEqualTo(width));
          expect(p.dy - TrailConfig.mapPlaceSize / 2, greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('layout', () {
    test('leaves stay inside the width and do not pile on top of each other', () {
      for (final width in [320.0, 600.0]) {
        for (final n in [1, 2, 7, 40, 200]) {
          final l = TreeTrail.leafLayout(n, width);
          expect(l.leaves, hasLength(n));
          for (final p in l.leaves) {
            expect(p.dx - TrailConfig.leafSize / 2, greaterThanOrEqualTo(0), reason: '$width/$n');
            expect(p.dx + TrailConfig.leafSize / 2, lessThanOrEqualTo(width), reason: '$width/$n');
            expect(p.dy - TrailConfig.leafSize / 2, greaterThanOrEqualTo(0));
            expect(p.dy, lessThan(l.height - TrailConfig.trunkHeight + TrailConfig.leafSize));
          }
          var closest = double.infinity;
          for (var i = 0; i < n; i++) {
            for (var j = i + 1; j < n; j++) {
              closest = math.min(closest, (l.leaves[i] - l.leaves[j]).distance);
            }
          }
          if (n > 1) expect(closest, greaterThan(TrailConfig.leafSize * 0.6), reason: '$width/$n');
        }
      }
    });

    test('stars stay inside the sky and keep the date order as one unbroken line', () {
      final days = [for (var i = 0; i < 30; i++) _day(i)];
      final c = SkyTrail.starCenters(days, 360);
      for (final p in c) {
        expect(p.dx - TrailConfig.starSize / 2, greaterThanOrEqualTo(0));
        expect(p.dx + TrailConfig.starSize / 2, lessThanOrEqualTo(360));
      }
      // 相鄰兩顆星不會隔太遠（蛇行排列，線不會橫越整片天空）。
      for (var i = 1; i < c.length; i++) {
        expect((c[i] - c[i - 1]).distance, lessThan(360 / TrailConfig.starsPerRow * 1.8 + TrailConfig.starRowHeight));
      }
    });
  });
}
