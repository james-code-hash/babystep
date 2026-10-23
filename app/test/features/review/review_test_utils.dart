import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/review/outcome_buttons.dart';
import 'package:little_steps/features/review/review_screen.dart';
import 'package:little_steps/providers.dart';

import '../../helpers/test_app.dart';

/// 會數呼叫次數的假「步步學到」。[delay] 不為 null 時模擬慢的 LLM。
class CountingLessonService implements LessonService {
  CountingLessonService({this.result = fixedLesson, this.delay});

  static const fixedLesson = LessonResult(
    text: '原來先想好時間點，開始就比較容易。',
    kind: LessonKind.method,
    source: LessonSource.template,
  );

  final LessonResult result;
  final Duration? delay;
  final calls = <LessonRequest>[];

  @override
  Future<LessonResult> learn(LessonRequest request) async {
    calls.add(request);
    if (delay != null) await Future<void>.delayed(delay!);
    return result;
  }
}

String todayOf(TestEnv env) => dayKeyOf(env.clock.now());

Future<List<Plan>> seedPlans(TestEnv env, {int count = 2}) async {
  await env.seed();
  const drafts = [
    PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我吃完晚飯'),
    PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡'),
    PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我放學回到家'),
  ];
  return env.repo.savePlans(todayOf(env), drafts.take(count).toList());
}

Future<void> pumpReview(
  WidgetTester tester,
  TestEnv env,
  LessonService service, {
  List<Override> extra = const [],
}) async {
  await pumpScreen(
    tester,
    env,
    const ReviewFlowScreen(),
    extra: [lessonServiceProvider.overrideWithValue(service), ...extra],
  );
  await settle(tester);
}

/// 和 testWidgets 一樣，但結束時先卸掉畫面並跑掉 drift 取消串流時排的 0 秒 timer。
void dbTestWidgets(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    }
  });
}

/// 在測試本體讀寫資料庫：widget 掛上去之後，drift 的查詢要在 real async 裡跑才會完成。
Future<T> db<T>(WidgetTester tester, Future<T> Function() body) async => (await tester.runAsync(body)) as T;

/// drift（in-memory SQLite）從 widget callback 發出的查詢要真的非同步輪轉才會完成；
/// 交替跑一點 real async 與 pump，直到畫面穩定。
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pumpAndSettle();
  }
}

Future<void> tapKey(WidgetTester tester, String key, {bool doSettle = true}) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  if (doSettle) {
    await settle(tester);
  } else {
    await tester.pump();
  }
}

bool hasKey(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;

/// 開場 → 每件事都選 [outcomes] 裡對應的狀態（不夠就用最後一個）→ 停在歷程問題。
Future<void> reviewOutcomes(WidgetTester tester, List<Outcome> outcomes, int planCount) async {
  await tapKey(tester, 'review-start');
  for (var i = 0; i < planCount; i++) {
    final o = outcomes[i < outcomes.length ? i : outcomes.length - 1];
    expect(hasKey('review-plan'), isTrue, reason: 'plan $i shown');
    expect(hasKey('review-response'), isFalse, reason: 'no default selection');
    await tapKey(tester, OutcomeButtons.keyFor(o).value);
    expect(hasKey('review-response'), isTrue, reason: 'Bubu responds to $o');
    await tapKey(tester, 'review-next');
  }
}

/// 一次完整回顧，記下走過的每一步（用來比較三種狀態的路徑是否等價）。
Future<List<String>> runFullReview(
  WidgetTester tester,
  TestEnv env,
  CountingLessonService service,
  Outcome outcome, {
  int planCount = 2,
  bool save = true,
}) async {
  await seedPlans(env, count: planCount);
  await pumpReview(tester, env, service);
  final steps = <String>[];
  void mark(String key) {
    if (hasKey(key)) steps.add(key);
  }

  mark('review-start');
  await reviewOutcomes(tester, [outcome], planCount);
  mark('review-question');
  await tapKey(tester, 'review-chip-0');
  mark('review-lesson');
  mark('review-save-yes');
  mark('review-save-no');
  await tapKey(tester, save ? 'review-save-yes' : 'review-save-no');
  mark('review-ending');
  mark('review-end-ok');
  return steps;
}
