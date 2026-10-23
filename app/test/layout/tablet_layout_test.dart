// 平板版面（docs/decisions.md E11）：每個主要畫面在平板直放／橫放、Android 平板、手機上
// 都不溢出、內容不超過設定的最大寬度、只有寬螢幕才出現雙欄、回顧三顆按鈕在每個寬度都一樣大。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/core/layout.dart';
import 'package:little_steps/core/routes.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/parent/parent_home.dart';
import 'package:little_steps/features/review/outcome_buttons.dart';
import 'package:little_steps/providers.dart';
import 'package:little_steps/safety/safety_response.dart';

import '../features/review/review_test_utils.dart' show CountingLessonService, seedPlans;
import '../helpers/test_app.dart';

const sizes = <String, Size>{
  'iPad portrait': Size(820, 1180),
  'iPad landscape': Size(1180, 820),
  'iPad Pro 12.9 landscape': Size(1366, 1024),
  'Android tablet': Size(800, 1280),
  'phone (control)': Size(390, 844),
};

bool isWide(Size s) => s.width >= LayoutConfig.twoPaneMinWidth;
bool isTablet(Size s) => s.shortestSide >= LayoutConfig.tabletMinShortestSide;

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

/// 有計畫的日子（給小路）與筆記（給筆記本）；今天也有兩件計畫（給回顧）。
Future<void> seedContent(TestEnv env) async {
  await seedPlans(env, count: 2);
  final now = env.clock.now();
  const notes = ['原來先想好時間點，開始就比較容易。', '原來累的時候可以先休息一下。', '原來先收書包，早上就不會找東西。', '原來換個順序就順了。'];
  for (var back = 1; back <= notes.length; back++) {
    final day = now.subtract(Duration(days: back * 2));
    await env.repo.savePlans(dayKeyOf(day), const [PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡')]);
    env.clock.fixed = DateTime(day.year, day.month, day.day, 20);
    await env.repo.saveLesson(
      dayKeyOf(day),
      LessonResult(text: notes[back - 1], kind: LessonKind.method, source: LessonSource.template),
    );
  }
  env.clock.fixed = now;
}

Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 3 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settleDb(tester);
}

Future<void> open(WidgetTester tester, String route) async {
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(route);
  await settleDb(tester);
}

/// 版面檢查：沒有例外／溢出、寬度上限、雙欄只在寬螢幕。
void expectLayout(WidgetTester tester, Size size, String where, {required bool twoPaneScreen, bool wideFrame = false}) {
  expect(tester.takeException(), isNull, reason: '$where: no exception or overflow');
  final single = isTablet(size) ? LayoutConfig.contentMaxWidthTablet : LayoutConfig.contentMaxWidthPhone;
  final frames = find.byKey(AdaptiveFrame.frameKey);
  expect(frames, findsAtLeastNWidgets(1), reason: '$where: content sits in an AdaptiveFrame');
  final twoPane = twoPaneScreen && isWide(size);
  if (twoPane) {
    expect(find.byKey(TwoPaneRow.rowKey), findsOneWidget, reason: '$where: Bubu beside the content');
    final main = tester.getSize(find.byKey(TwoPaneRow.mainKey)).width;
    expect(main, lessThanOrEqualTo(LayoutConfig.contentMaxWidthTablet), reason: '$where: main pane width');
    expect(tester.getSize(find.byKey(TwoPaneRow.sideKey)).width, LayoutConfig.sidePaneWidth);
  } else {
    expect(find.byKey(TwoPaneRow.rowKey), findsNothing, reason: '$where: single column on ${size.width} wide');
  }
  for (final e in frames.evaluate()) {
    final w = tester.getSize(find.byWidget(e.widget)).width;
    final limit = (twoPane || wideFrame) ? LayoutConfig.wideMaxWidth : single;
    expect(w, lessThanOrEqualTo(limit), reason: '$where: frame width $w');
    expect(w, lessThanOrEqualTo(size.width));
  }
}

double largestBubu(WidgetTester tester) =>
    tester.widgetList<BubuView>(find.byType(BubuView)).map((b) => b.size).fold(0, (a, b) => a > b ? a : b);

void main() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    group('$name ${size.width.toInt()}x${size.height.toInt()}', () {
      late TestEnv env;
      setUp(() => env = TestEnv());
      Future<void> start(WidgetTester tester, {String? pin}) async {
        useSize(tester, size);
        addTearDown(tester.view.reset);
        await seedContent(env);
        if (pin != null) await env.repo.setParentPin(pin);
        await pumpApp(tester, env, extra: [lessonServiceProvider.overrideWithValue(CountingLessonService())]);
        await settleAll(tester);
      }

      testWidgets('home', (tester) async {
        await start(tester);
        expectLayout(tester, size, 'home', twoPaneScreen: true);
        final expected = isWide(size)
            ? LayoutConfig.bubuSidePane
            : (isTablet(size) ? LayoutConfig.bubuHeroTablet : LayoutConfig.bubuHeroPhone);
        expect(largestBubu(tester), expected, reason: 'Bubu is larger on tablets');
        await finishTest(tester, env);
      });

      testWidgets('plan flow, every step', (tester) async {
        await start(tester);
        await open(tester, Routes.plan);
        expectLayout(tester, size, 'plan mood', twoPaneScreen: true);
        await tap(tester, 'mood-happy');
        await tap(tester, 'plan-next');
        expectLayout(tester, size, 'plan choose', twoPaneScreen: true);
        await tap(tester, 'task-preset-task-0');
        await tap(tester, 'plan-next');
        expectLayout(tester, size, 'plan if-then', twoPaneScreen: true);
        await tap(tester, 'cue-preset-cue-0');
        await tap(tester, 'plan-next');
        expectLayout(tester, size, 'plan why', twoPaneScreen: true);
        await tap(tester, 'why-skip');
        expectLayout(tester, size, 'plan confirm', twoPaneScreen: true);
        expect(find.byKey(const ValueKey('confirm-0')), findsOneWidget);
        await finishTest(tester, env);
      });

      testWidgets('review flow, outcome buttons identical, ending', (tester) async {
        await start(tester);
        await open(tester, Routes.review);
        expectLayout(tester, size, 'review opening', twoPaneScreen: false);
        await tap(tester, 'review-start');
        for (var i = 0; i < 2; i++) {
          expectLayout(tester, size, 'review outcomes $i', twoPaneScreen: true);
          final sizes = {for (final o in Outcome.values) tester.getSize(find.byKey(OutcomeButtons.keyFor(o)))};
          expect(sizes, hasLength(1), reason: 'three outcome buttons share one size');
          expect(sizes.single.height, OutcomeButtons.height);
          expect(sizes.single.width, greaterThanOrEqualTo(AppConfig.minTapTarget));
          await tap(tester, OutcomeButtons.keyFor(Outcome.notToday).value);
          expectLayout(tester, size, 'review response $i', twoPaneScreen: true);
          await tap(tester, 'review-next');
        }
        expectLayout(tester, size, 'review question', twoPaneScreen: true);
        await tap(tester, 'review-chip-0');
        expect(find.byKey(const ValueKey('review-lesson')), findsOneWidget);
        expectLayout(tester, size, 'review lesson', twoPaneScreen: true);
        await tap(tester, 'review-save-no');
        expect(find.byKey(const ValueKey('review-ending')), findsOneWidget);
        expectLayout(tester, size, 'review ending', twoPaneScreen: false);
        await finishTest(tester, env);
      });

      testWidgets('notebook: multi-column pages on tablet, newest first', (tester) async {
        await start(tester);
        await open(tester, Routes.notebook);
        expectLayout(tester, size, 'notebook', twoPaneScreen: false, wideFrame: isTablet(size));
        final pages = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('lesson-'),
        );
        expect(pages, findsAtLeastNWidgets(2));
        final first = tester.getTopLeft(pages.at(0));
        final second = tester.getTopLeft(pages.at(1));
        if (isTablet(size)) {
          expect(second.dy, first.dy, reason: 'pages share a row on tablets');
          expect(second.dx, greaterThan(first.dx));
        } else {
          expect(second.dy, greaterThan(first.dy), reason: 'one column on phones');
        }
        await finishTest(tester, env);
      });

      testWidgets('path', (tester) async {
        await start(tester);
        await open(tester, Routes.path);
        expectLayout(tester, size, 'path', twoPaneScreen: true);
        expect(find.byKey(const ValueKey('insight-task')), findsOneWidget);
        await finishTest(tester, env);
      });

      testWidgets('child settings and dress-up', (tester) async {
        await start(tester);
        await open(tester, Routes.settings);
        expectLayout(tester, size, 'settings', twoPaneScreen: false);
        await tap(tester, 'open-dress-up');
        expectLayout(tester, size, 'dress-up', twoPaneScreen: true);
        await finishTest(tester, env);
      });

      testWidgets('parent PIN pad is centered, parent home framed', (tester) async {
        await start(tester, pin: '2468');
        await open(tester, Routes.parent);
        expectLayout(tester, size, 'parent PIN', twoPaneScreen: false);
        final frame = tester.getSize(find.byKey(AdaptiveFrame.frameKey));
        expect(frame.width, lessThanOrEqualTo(LayoutConfig.pinMaxWidth));
        final dots = tester.getCenter(find.byKey(const ValueKey('pin-dots')));
        expect((dots.dx - size.width / 2).abs(), lessThan(1), reason: 'PIN pad centered');
        final key = tester.getSize(find.byKey(const ValueKey('pin-key-5')));
        expect(key.width, greaterThanOrEqualTo(AppConfig.minTapTarget));
        for (final d in '2468'.split('')) {
          await tester.tap(find.byKey(ValueKey('pin-key-$d')));
          await tester.pump();
        }
        await settleDb(tester);
        expect(find.byType(ParentHome), findsOneWidget);
        expectLayout(tester, size, 'parent home', twoPaneScreen: false);
        await finishTest(tester, env);
      });

      testWidgets('safety response', (tester) async {
        await start(tester);
        unawaited(SafetyResponseScreen.show(tester.element(find.byType(HomeScreen)), null));
        await settleDb(tester);
        expect(find.byType(SafetyResponseScreen), findsOneWidget);
        expectLayout(tester, size, 'safety', twoPaneScreen: false);
        await finishTest(tester, env);
      });
    });
  }
}
