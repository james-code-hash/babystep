// 完整分齡（I3）：兩種說話方式在流程上的差別，不只是語氣。
//   活潑（小樹苗，6–8）：字大一點、選項帶圖示、建議 1–2 件（軟性）、回顧短答案在前。
//   簡潔（小探險家，9–12）：多一步可跳過的「卡住的話，我就⋯」（MCII）、回顧一開始就能寫字。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/plan.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/plan/plan_screen.dart';

import '../../helpers/test_app.dart';
import '../review/review_test_utils.dart' as review;

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settleAll(tester);
}

Future<TestEnv> _openPlan(WidgetTester tester, AgeTone tone) async {
  _tall(tester);
  final env = TestEnv();
  await env.seed();
  await env.repo.setTone(tone);
  await pumpApp(tester, env);
  await settleAll(tester);
  await _tap(tester, 'home-plan');
  expect(find.byType(PlanFlowScreen), findsOneWidget);
  await _tap(tester, 'mood-happy');
  await _tap(tester, 'plan-next');
  return env;
}

/// 選一件事、挑第一個時間點、跳過為什麼。
Future<void> _oneItemToAfterWhy(WidgetTester tester) async {
  await _tap(tester, 'task-preset-task-0');
  await _tap(tester, 'plan-next');
  await _tap(tester, 'cue-preset-cue-0');
  await _tap(tester, 'plan-next');
  await _tap(tester, 'why-skip');
}

void main() {
  group('concise (9–12): "if I get stuck, I will…" step', () {
    testWidgets('comes after "why", is saved with the plan and shown on confirm and home', (tester) async {
      final env = await _openPlan(tester, AgeTone.concise);
      await _oneItemToAfterWhy(tester);
      expect(find.byKey(const ValueKey('plan-stuck-0')), findsOneWidget);
      await _tap(tester, 'stuck-0');
      expect(find.text(PlanCopy.stuckLine.fill(AgeTone.concise, {'stuck': PlanCopy.stuckOneMinute.concise})),
          findsOneWidget);
      await _tap(tester, 'plan-next');
      expect(find.byKey(const ValueKey('confirm-stuck-0')), findsOneWidget);

      // 從確認頁往回，回到「卡住的時候」。
      await _tap(tester, 'plan-back');
      expect(find.byKey(const ValueKey('plan-stuck-0')), findsOneWidget);
      await _tap(tester, 'plan-next');
      await _tap(tester, 'plan-next'); // 就這樣排
      final plans = (await tester.runAsync(() => env.repo.plans(dayKeyOf(env.clock.now()))))!;
      expect(plans.single.stuck, PlanCopy.stuckOneMinute.concise);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(PlanCopy.stuckLine.fill(AgeTone.concise, {'stuck': PlanCopy.stuckOneMinute.concise})),
          findsOneWidget);
      await finishTest(tester, env);
    });

    testWidgets('can be skipped; nothing is saved for it', (tester) async {
      final env = await _openPlan(tester, AgeTone.concise);
      await _oneItemToAfterWhy(tester);
      await _tap(tester, 'stuck-skip');
      expect(find.byKey(const ValueKey('confirm-stuck-0')), findsNothing);
      await _tap(tester, 'plan-next');
      final plans = (await tester.runAsync(() => env.repo.plans(dayKeyOf(env.clock.now()))))!;
      expect(plans.single.stuck, isNull);
      await finishTest(tester, env);
    });
  });

  group('lively (6–8)', () {
    testWidgets('no stuck step: "why" goes straight to confirm', (tester) async {
      final env = await _openPlan(tester, AgeTone.lively);
      await _oneItemToAfterWhy(tester);
      expect(find.byKey(const ValueKey('plan-stuck-0')), findsNothing);
      expect(find.byKey(const ValueKey('confirm-0')), findsOneWidget);
      await finishTest(tester, env);
    });

    testWidgets('a soft note at two items; a third can still be added', (tester) async {
      final env = await _openPlan(tester, AgeTone.lively);
      await _tap(tester, 'task-preset-task-0');
      await _tap(tester, 'task-preset-task-1');
      expect(find.text(PlanCopy.chooseEnough.lively), findsOneWidget);
      await _tap(tester, 'task-preset-task-2');
      expect(find.text(PlanCopy.chooseEnough.lively), findsOneWidget);
      final chip = tester.widget<FilterChip>(find.byKey(const ValueKey('task-preset-task-2')));
      expect(chip.selected, isTrue, reason: 'the hard cap is still ${AppConfig.maxPlansPerDay}');
      await finishTest(tester, env);
    });

    testWidgets('cue chips carry a picture; concise ones are plain text', (tester) async {
      for (final tone in AgeTone.values) {
        final env = await _openPlan(tester, tone);
        await _tap(tester, 'task-preset-task-0');
        await _tap(tester, 'plan-next');
        final chip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('cue-preset-cue-0')));
        final label = (chip.label as Text).data!;
        final icon = PlanCopy.cueIcon(label.split(' ').last);
        expect(icon, isNotNull, reason: 'preset cue should have a picture');
        expect(label.startsWith(icon!), tone == AgeTone.lively, reason: '$tone: $label');
        await finishTest(tester, env);
      }
    });
  });

  testWidgets('text is a bit larger for lively on child screens, but not in the parent area', (tester) async {
    for (final tone in AgeTone.values) {
      _tall(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.setTone(tone);
      await pumpApp(tester, env);
      await settleAll(tester);
      final home = MediaQuery.of(tester.element(find.byType(HomeScreen))).textScaler.scale(10);
      expect(home, closeTo(tone == AgeTone.lively ? 10 * AgeConfig.sproutTextScale : 10, 0.001), reason: '$tone');
      await _tap(tester, 'nav-parent');
      final parent = MediaQuery.of(tester.element(find.byKey(const ValueKey('pin-title')))).textScaler.scale(10);
      expect(parent, closeTo(10, 0.001), reason: 'parent area keeps the system size ($tone)');
      await finishTest(tester, env);
    }
  });

  group('review question', () {
    for (final tone in AgeTone.values) {
      testWidgets('$tone: writing box ${tone == AgeTone.concise ? 'open' : 'closed'} at first', (tester) async {
        final env = TestEnv();
        await review.seedPlans(env, count: 1);
        await env.repo.setTone(tone);
        await review.pumpReview(tester, env, review.CountingLessonService());
        await review.reviewOutcomes(tester, [Outcome.done], 1);
        expect(find.byKey(const ValueKey('review-question')), findsOneWidget);
        expect(find.byKey(const ValueKey('review-text')), tone == AgeTone.concise ? findsOneWidget : findsNothing);
        await finishTest(tester, env);
      });
    }
  });
}
