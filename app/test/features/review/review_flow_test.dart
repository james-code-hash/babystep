import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/safety/safety_response.dart';
import 'package:go_router/go_router.dart';
import 'package:little_steps/copy/line.dart';
import 'package:little_steps/copy/review.dart';
import 'package:little_steps/core/routes.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/review/review_controller.dart';
import 'package:little_steps/providers.dart';

import '../../helpers/test_app.dart';
import 'review_test_utils.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  dbTestWidgets('done path: outcomes, chip answer, lesson saved, day ended', (tester) async {
    final service = CountingLessonService();
    final steps = await runFullReview(tester, env, service, Outcome.done);

    expect(steps, [
      'review-start',
      'review-question',
      'review-lesson',
      'review-save-yes',
      'review-save-no',
      'review-ending',
      'review-end-ok',
    ]);
    expect(find.text(ReviewCopy.ending.lively), findsOneWidget);

    final day = todayOf(env);
    final plans = await db(tester, () => env.repo.plans(day));
    expect(plans.map((p) => p.outcome), [Outcome.done, Outcome.done]);

    expect(service.calls, hasLength(1));
    final req = service.calls.single;
    expect(req.outcomes, [Outcome.done, Outcome.done]);
    expect(req.tasks, ['寫數學作業', '看一本書']);
    expect(req.childWords, ReviewCopy.anyDayChips.first.lively);

    final record = await db(tester, () => env.repo.dayRecord(day));
    expect(record?.ended, isTrue);
    expect(record?.reflection, ReviewCopy.anyDayChips.first.lively);

    final lessons = await db(tester, () => env.repo.watchLessons().first);
    expect(lessons.single.text, CountingLessonService.fixedLesson.text);
    expect(lessons.single.sharedWithParent, isFalse, reason: 'sharing is never the default');
  });

  dbTestWidgets('all-notToday path reaches the same ending and records endDay', (tester) async {
    final service = CountingLessonService();
    final steps = await runFullReview(tester, env, service, Outcome.notToday, planCount: 3, save: false);

    expect(steps, contains('review-question'));
    expect(steps, contains('review-lesson'));
    expect(steps, contains('review-save-yes'));
    expect(steps, contains('review-ending'));

    final day = todayOf(env);
    expect((await db(tester, () => env.repo.plans(day))).map((p) => p.outcome), everyElement(Outcome.notToday));
    expect(service.calls.single.outcomes, everyElement(Outcome.notToday));
    expect((await db(tester, () => env.repo.dayRecord(day)))?.ended, isTrue);
    expect(await db(tester, () => env.repo.watchLessons().first), isEmpty, reason: '不用 → nothing saved');
  });

  dbTestWidgets('the question step shows the picked question and its chips', (tester) async {
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, CountingLessonService());
    await reviewOutcomes(tester, [Outcome.notToday], 1);
    final q = tester
        .widget<Text>(find.descendant(of: find.byKey(const ValueKey('review-question')), matching: find.byType(Text)))
        .data;
    expect(ReviewCopy.anyDayQuestions.lines.map((l) => l.lively), contains(q));
    final chipTexts = [for (final w in tester.widgetList<ActionChip>(find.byType(ActionChip))) (w.label as Text).data];
    for (final c in ReviewCopy.didSomethingChips) {
      expect(chipTexts, isNot(contains(c.lively)));
    }
    expect(hasKey('review-skip'), isTrue);
    expect(hasKey('review-write'), isTrue);
  });

  group('question pool', () {
    Future<ReviewState> reachQuestion(int seed, List<Outcome> outcomes) async {
      final e = TestEnv(seed: seed);
      addTearDown(e.dispose);
      await seedPlans(e, count: outcomes.length);
      final container = e.container(extra: [lessonServiceProvider.overrideWithValue(CountingLessonService())]);
      addTearDown(container.dispose);
      final sub = container.listen(reviewControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final c = container.read(reviewControllerProvider.notifier);
      await c.start();
      c.begin();
      for (final o in outcomes) {
        await c.choose(o);
        c.next();
      }
      return container.read(reviewControllerProvider);
    }

    test('all-notToday days only get questions and chips that make sense without doing', () async {
      final seen = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final s = await reachQuestion(seed, [Outcome.notToday, Outcome.notToday]);
        expect(s.stage, ReviewStage.question);
        expect(ReviewCopy.anyDayQuestions.lines, contains(s.question));
        seen.add(s.question!.lively);
        for (final c in ReviewCopy.didSomethingChips) {
          expect(s.chips, isNot(contains(c)));
        }
        for (final c in ReviewCopy.notTodayChips) {
          expect(s.chips, contains(c));
        }
      }
      expect(seen.length, greaterThan(1), reason: 'the question is picked at random');
    });

    test('days with something done can also get doing-questions', () async {
      final seen = <Line>{};
      for (var seed = 0; seed < 40; seed++) {
        final s = await reachQuestion(seed, [Outcome.done]);
        seen.add(s.question!);
        expect(s.chips, containsAll(ReviewCopy.didSomethingChips));
        expect(s.chips, isNot(contains(ReviewCopy.notTodayChips.first)));
      }
      expect(seen.intersection(ReviewCopy.didSomethingQuestions.lines.toSet()), isNotEmpty);
    });
  });

  dbTestWidgets('skip question → learn with childWords null, reflection null', (tester) async {
    final service = CountingLessonService();
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, service);
    await reviewOutcomes(tester, [Outcome.partly], 1);
    await tapKey(tester, 'review-skip');

    expect(service.calls.single.childWords, isNull);
    expect(service.calls.single.outcomes, [Outcome.partly]);
    expect(hasKey('review-lesson'), isTrue);
    expect((await db(tester, () => env.repo.dayRecord(todayOf(env))))?.reflection, isNull);
  });

  dbTestWidgets('free text answer is saved and sent as childWords', (tester) async {
    final service = CountingLessonService();
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, service);
    await reviewOutcomes(tester, [Outcome.done], 1);
    await tapKey(tester, 'review-write');
    await tester.enterText(find.byKey(const ValueKey('review-text')), '我先寫最難的那一題');
    await tapKey(tester, 'review-send');

    expect(service.calls.single.childWords, '我先寫最難的那一題');
    expect((await db(tester, () => env.repo.dayRecord(todayOf(env))))?.reflection, '我先寫最難的那一題');
  });

  dbTestWidgets('crisis text → no reflection saved, learn never called, goodnight ending', (tester) async {
    final service = CountingLessonService();
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, service);
    await reviewOutcomes(tester, [Outcome.notToday], 1);
    await tapKey(tester, 'review-write');
    await tester.enterText(find.byKey(const ValueKey('review-text')), '我今天好想死');
    await tapKey(tester, 'review-send');
    // 真的安全閘門：先顯示預寫的安全回應，孩子關掉後才往下。
    expect(find.byType(SafetyResponseScreen), findsOneWidget);
    await tapKey(tester, 'safety-close');

    expect(service.calls, isEmpty);
    final record = await db(tester, () => env.repo.dayRecord(todayOf(env)));
    expect(record?.reflection, isNull);
    expect(record?.ended, isTrue);
    expect(await db(tester, () => env.repo.watchLessons().first), isEmpty);
    expect(hasKey('review-lesson'), isFalse);
    expect(find.text(ReviewCopy.goodnight.lively), findsOneWidget);
  });

  dbTestWidgets('thinking indicator appears only after llmThinkingAfter with a slow service', (tester) async {
    final service = CountingLessonService(delay: const Duration(seconds: 6));
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, service);
    await reviewOutcomes(tester, [Outcome.done], 1);
    await tapKey(tester, 'review-skip', doSettle: false);
    // 讓 saveReflection（真的 SQLite）跑完，learn 才會開始。
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump();
    expect(service.calls, hasLength(1));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(ReviewCopy.thinking.lively), findsNothing);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text(ReviewCopy.thinking.lively), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.text(ReviewCopy.thinking.lively), findsNothing);
    expect(hasKey('review-lesson'), isTrue);
  });

  dbTestWidgets('a fast service never shows the thinking line and leaves no timer behind', (tester) async {
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, CountingLessonService());
    await reviewOutcomes(tester, [Outcome.done], 1);
    await tapKey(tester, 'review-skip');
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(ReviewCopy.thinking.lively), findsNothing);
    expect(hasKey('review-lesson'), isTrue);
  });

  dbTestWidgets('safety-source lesson is never offered for saving', (tester) async {
    const safety = LessonResult(text: '我們先休息一下。', kind: LessonKind.plainDay, source: LessonSource.safety);
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, CountingLessonService(result: safety));
    await reviewOutcomes(tester, [Outcome.done], 1);
    await tapKey(tester, 'review-skip');
    expect(hasKey('review-save-yes'), isFalse);
    expect(hasKey('review-save-no'), isFalse);
    await tapKey(tester, 'review-continue');
    expect(hasKey('review-ending'), isTrue);
    expect(await db(tester, () => env.repo.watchLessons().first), isEmpty);
  });

  dbTestWidgets('changing an outcome before moving on keeps only the last choice', (tester) async {
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, CountingLessonService());
    await tapKey(tester, 'review-start');
    await tapKey(tester, 'outcome-done');
    await tapKey(tester, 'outcome-notToday');
    expect((await db(tester, () => env.repo.plans(todayOf(env)))).single.outcome, Outcome.notToday);
  });

  dbTestWidgets('no plans today → calm message and a way back', (tester) async {
    await pumpReview(tester, env, CountingLessonService());
    expect(find.text(ReviewCopy.noPlans.lively), findsOneWidget);
    expect(hasKey('review-back'), isTrue);
    expect(hasKey('outcome-done'), isFalse);
  });

  dbTestWidgets('day already ended → 今天聊完了 and a way back', (tester) async {
    await seedPlans(env, count: 1);
    await db(tester, () => env.repo.endDay(todayOf(env)));
    final service = CountingLessonService();
    await pumpReview(tester, env, service);
    expect(find.text(ReviewCopy.alreadyEnded.lively), findsOneWidget);
    expect(hasKey('review-start'), isFalse);
    expect(service.calls, isEmpty);
  });

  dbTestWidgets('concise tone uses the concise ending', (tester) async {
    await env.seed();
    await db(tester, () => env.repo.setTone(AgeTone.concise));
    await seedPlans(env, count: 1);
    await pumpReview(tester, env, CountingLessonService());
    await reviewOutcomes(tester, [Outcome.done], 1);
    await tapKey(tester, 'review-skip');
    await tapKey(tester, 'review-save-no');
    expect(find.text(ReviewCopy.ending.concise), findsOneWidget);
  });

  dbTestWidgets('好 on the ending screen goes home (full app router)', (tester) async {
    await seedPlans(env, count: 1);
    final service = CountingLessonService();
    await pumpApp(tester, env, extra: [lessonServiceProvider.overrideWithValue(service)]);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go(Routes.review);
    await settle(tester);
    await reviewOutcomes(tester, [Outcome.partly], 1);
    await tapKey(tester, 'review-skip');
    await tapKey(tester, 'review-save-yes');
    await tapKey(tester, 'review-end-ok');
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.home);
    expect((await db(tester, () => env.repo.watchLessons().first)), hasLength(1));
  });

  test('controller state machine refuses out-of-order steps', () async {
    final container = env.container(extra: [lessonServiceProvider.overrideWithValue(CountingLessonService())]);
    addTearDown(container.dispose);
    await seedPlans(env, count: 1);
    final sub = container.listen(reviewControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final c = container.read(reviewControllerProvider.notifier);
    await c.start();
    expect(container.read(reviewControllerProvider).stage, ReviewStage.opening);
    c.next(); // 還沒開始，不動
    await c.answer('x'); // 還沒到問題，不動
    expect(container.read(reviewControllerProvider).stage, ReviewStage.opening);
    c.begin();
    c.next(); // 還沒選，不能往下
    expect(container.read(reviewControllerProvider).stage, ReviewStage.outcomes);
  });
}
