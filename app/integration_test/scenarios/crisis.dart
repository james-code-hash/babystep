// 情境：危機內容（底線 9）。孩子任何一個能自由打字的地方，寫出危機訊號都走預寫好的安全回應：
// 顯示求助專線、這段話不存、不交給 LLM、之後流程照常往下（不卡住、不責備）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/review.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/providers.dart';
import 'package:little_steps/safety/safety_response.dart';

import '../e2e/harness.dart';
import 'child_day.dart' show planOnePreset;

/// 安全回應正蓋在畫面上，每一條求助專線都在；孩子關掉。
Future<void> expectSafetyThenClose(E2EApp app) async {
  expect(find.byType(SafetyResponseScreen), findsOneWidget);
  final helplines = app.container.read(crisisDetectorProvider).helplines;
  expect(helplines, isNotEmpty);
  for (final h in helplines) {
    expect(find.byKey(Key('helpline-${h.id}')), findsOneWidget);
  }
  await app.tap('safety-close');
  expect(find.byType(SafetyResponseScreen), findsNothing);
}

void crisisScenarios() {
  testWidgets('evening review: a crisis sentence shows the safety response, is never stored, and the day still ends',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 19, 30));
    await planOnePreset(app);
    await app.tap('home-review');
    await app.tap('review-start');
    await app.tap('outcome-notToday');
    await app.tap('review-next');
    await app.tap('review-write');
    const words = '我今天好想死';
    await app.enter('review-text', words);
    await app.tap('review-send');
    await expectSafetyThenClose(app);

    // 沒有「步步學到」、沒有存進筆記本；直接是晚安。
    expect(app.has('review-lesson'), isFalse);
    expect(find.text(ReviewCopy.goodnight.lively), findsOneWidget);
    await app.tap('review-end-ok');
    expect(app.has('home-ended'), isTrue);

    final record = await app.read((r) => r.dayRecord(app.today));
    expect(record!.reflection, isNull);
    expect(record.ended, isTrue);
    expect(await app.read((r) => r.watchLessons().first), isEmpty);
    expect(await app.read((r) => r.exportJson()), isNot(contains('想死')));
    expect(find.textContaining('想死'), findsNothing);
    await app.close();
  });

  testWidgets('morning plan: self-harm or distress words as my own task, cue or reason are caught each time and never used',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30));
    await app.tap('home-plan');
    await app.tap('mood-unsaid');
    await app.tap('plan-next');

    // 自己寫的事。
    await app.tap('task-write-own');
    await app.enter('task-custom-field', '我想死');
    await app.tap('task-custom-add');
    await expectSafetyThenClose(app);
    expect(find.textContaining('想死'), findsNothing);

    // 流程沒有卡住：選一件預設的繼續。
    await app.tap('task-preset-task-0');
    await app.tap('plan-next');

    // 自己寫的時間點。
    await app.tap('cue-write-own');
    await app.enter('cue-custom-field', '我不想活了');
    await app.tap('cue-custom-use');
    await expectSafetyThenClose(app);
    expect(app.has('ifthen-sentence'), isFalse, reason: 'the words were not used as a cue');
    await app.tap('cue-preset-cue-0');
    await app.tap('plan-next');

    // 自己寫的為什麼。
    await app.tap('why-write-own');
    await app.enter('why-custom-field', '因為沒有人愛我');
    await app.tap('why-custom-use');
    await expectSafetyThenClose(app);
    await app.tap('why-skip');
    await app.tap('plan-next');

    final plans = await app.read((r) => r.plans(app.today));
    expect(plans.single.why, isNull);
    final json = await app.read((r) => r.exportJson());
    for (final w in ['想死', '不想活', '沒有人愛我']) {
      expect(json, isNot(contains(w)));
    }
    expect(await app.read((r) => r.taskTemplates(origins: {TemplateOrigin.child})), isEmpty);
    expect(await app.read((r) => r.cueTemplates(origins: {TemplateOrigin.child})), isEmpty);
    await app.close();
  });

  testWidgets('9–12 "if I get stuck" step: an abuse signal is caught too', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30));
    await app.tap('nav-settings');
    await app.tap('tone-concise');
    await app.back();
    await app.tap('home-plan');
    await app.tap('mood-okay');
    await app.tap('plan-next');
    await app.tap('task-preset-task-0');
    await app.tap('plan-next');
    await app.tap('cue-preset-cue-0');
    await app.tap('plan-next');
    await app.tap('why-skip');
    await app.tap('stuck-write-own');
    await app.enter('stuck-custom-field', '卡住的話他會打我');
    await app.tap('stuck-custom-use');
    await expectSafetyThenClose(app);
    await app.tap('stuck-skip');
    await app.tap('plan-next');
    expect((await app.read((r) => r.plans(app.today))).single.stuck, isNull);
    expect(await app.read((r) => r.exportJson()), isNot(contains('打我')));
    await app.close();
  });

  testWidgets('month page: a worrying sentence to the family is caught and never saved', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 19, 30));
    await app.tap('nav-path');
    await app.tap('open-month');
    await app.enter('month-letter-field', '我不想活了');
    await app.tap('month-letter-save');
    await expectSafetyThenClose(app);
    expect(await app.read((r) => r.monthLetters()), isEmpty);
    expect(find.textContaining('不想活'), findsNothing);
    expect(app.has('month-letter-field'), isTrue, reason: 'the child can still write something else');
    await app.close();
  });
}
