// 情境：孩子的核心循環（HANDOFF §4 第一、二項）。
//
// 早上自己排 1–3 件事（預設、自己寫的事、自己寫的時間點）→ 傍晚步步探頭 → 晚上回顧三種狀態
// → 自己寫一句 → 步步學到 → 記進筆記本 → 筆記本按愛心、分享給家長 → 小路多一塊石頭
// → 隔天打開又是新的一天。也走心情低「今天先不排」與「每件都沒做」的一天。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/plan.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';

import '../e2e/harness.dart';

/// 首頁 → 排一件預設的事（第 [task] 個預設、第 [cue] 個時間點、跳過為什麼）。
Future<void> planOnePreset(E2EApp app, {int task = 0, int cue = 0}) async {
  await app.tap(app.has('home-plan') ? 'home-plan' : 'home-replan');
  await app.tap('mood-okay');
  await app.tap('plan-next');
  await app.tap('task-preset-task-$task');
  await app.tap('plan-next');
  await app.tap('cue-preset-cue-$cue');
  await app.tap('plan-next');
  await app.tap('why-skip');
  if (app.has('stuck-skip')) await app.tap('stuck-skip');
  expect(app.has('confirm-0'), isTrue);
  await app.tap('plan-next');
  expect(find.byType(HomeScreen), findsOneWidget);
}

/// 首頁 → 回顧：每件都選 [outcome]（或依序用 [outcomes]）→ 選第一個短答案 → 存進筆記本 → 結束。
Future<void> reviewAll(E2EApp app, List<Outcome> outcomes, {bool save = true}) async {
  await app.tap('home-review');
  await app.tap('review-start');
  for (final o in outcomes) {
    expect(app.has('review-plan'), isTrue);
    expect(app.has('review-response'), isFalse, reason: 'nothing is pre-selected');
    await app.tap('outcome-${o.name}');
    expect(app.has('review-response'), isTrue);
    await app.tap('review-next');
  }
  expect(app.has('review-question'), isTrue);
  await app.tap('review-chip-0');
  expect(app.has('review-lesson'), isTrue);
  await app.tap(save ? 'review-save-yes' : 'review-save-no');
  expect(app.has('review-ending'), isTrue);
  await app.tap('review-end-ok');
  expect(app.has('home-ended'), isTrue);
}

void childDayScenarios() {
  testWidgets('core loop: plan three things my way, Bubu peeks, review all three outcomes, teach Bubu, next day',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30));
    final day = app.today;

    // ---- 早上：首頁只有一個邀請，沒有數字。
    expect(app.has('home-plan'), isTrue);
    expect(app.has('home-review'), isFalse);
    expect(app.has('home-peek'), isFalse, reason: 'no plans yet, nothing to peek about');

    await app.tap('home-plan');
    await app.tap('mood-happy');
    expect(find.text(PlanCopy.moodHappyReply.lively), findsOneWidget);
    await app.tap('plan-next');

    // 選三件：一件預設、一件自己寫、再一件預設；第四件選不進去。
    await app.tap('task-preset-task-0');
    await app.tap('task-write-own');
    await app.tap('emoji-🎨');
    await app.enter('task-custom-field', '畫一張圖');
    await app.tap('task-custom-add');
    await app.tap('task-preset-task-1');
    await app.tap('task-preset-task-2');
    final selected = tester.widgetList<FilterChip>(find.byType(FilterChip)).where((c) => c.selected);
    expect(selected, hasLength(AppConfig.maxPlansPerDay));
    expect(find.text(PlanCopy.chooseFull.fill(AgeTone.lively, {'max': '${AppConfig.maxPlansPerDay}'})), findsOneWidget);
    await app.tap('plan-next');

    // 第一件：預設時間點＋選一個為什麼。
    expect(app.has('ifthen-sentence'), isFalse, reason: 'no cue is picked for the child');
    await app.tap('cue-preset-cue-0');
    expect(app.has('ifthen-sentence'), isTrue);
    await app.tap('plan-next');
    await app.tap('why-0');
    await app.tap('plan-next');
    // 第二件：自己寫的時間點（補成「我⋯」）＋自己寫為什麼。
    await app.tap('cue-write-own');
    await app.enter('cue-custom-field', '寫完功課');
    await app.tap('cue-custom-use');
    await app.tap('plan-next');
    await app.tap('why-write-own');
    await app.enter('why-custom-field', '我喜歡畫畫');
    await app.tap('why-custom-use');
    await app.tap('plan-next');
    // 第三件：換一個說法再用。
    await app.tap('cue-preset-cue-2');
    await app.tap('ifthen-edit-task');
    await app.enter('ifthen-task-field', '看一本恐龍的書');
    await app.tap('ifthen-task-done');
    await app.tap('plan-next');
    await app.tap('why-skip');

    // 確認：三件都在，按下去回首頁。
    for (var i = 0; i < 3; i++) {
      expect(app.has('confirm-$i'), isTrue);
    }
    await app.tap('plan-next');
    expect(find.byType(HomeScreen), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(app.has('home-plan-card-$i'), isTrue);
    }
    final plans = await app.read((r) => r.plans(day));
    expect(plans, hasLength(3));
    expect(plans.map((p) => p.task), contains('畫一張圖'));
    expect(plans.map((p) => p.task), contains('看一本恐龍的書'));
    expect(plans.map((p) => p.cue), contains('我寫完功課'));
    expect(plans.map((p) => p.why), contains('我喜歡畫畫'));
    expect(plans.every((p) => p.outcome == null), isTrue);
    // 自己寫的事與時間點進了孩子自己的庫，下次可以再選。
    expect((await app.read((r) => r.taskTemplates(origins: {TemplateOrigin.child}))).single.text, '畫一張圖');
    expect((await app.read((r) => r.cueTemplates(origins: {TemplateOrigin.child}))).single.text, '我寫完功課');
    // 早上 7:30 不在預設提醒時段裡：不探頭。
    expect(app.has('home-peek'), isFalse);

    // ---- 晚上 7:30 打開 App：在「吃完晚飯」時段裡，步步探頭；三個回答份量一樣，回答只換成一句話。
    await app.resumeAt(DateTime(2026, 11, 4, 19, 30));
    expect(app.has('home-peek'), isTrue);
    expect(tester.widget(find.byKey(const ValueKey('peek-go'))).runtimeType,
        tester.widget(find.byKey(const ValueKey('peek-not-today'))).runtimeType);
    await app.tap('peek-later');
    expect(app.has('home-peek-reply'), isTrue);

    // ---- 回顧：做到了／做了一點／今天沒做，各一件；自己寫一句話。
    await app.tap('home-review');
    await app.tap('review-start');
    for (final o in [Outcome.done, Outcome.partly, Outcome.notToday]) {
      expect(app.has('review-response'), isFalse);
      await app.tap('outcome-${o.name}');
      await app.tap('review-next');
    }
    expect(app.has('review-question'), isTrue);
    expect(app.has('review-text'), isFalse, reason: 'lively: short answers first, writing is one tap away');
    await app.tap('review-write');
    await app.enter('review-text', '我先把顏料都準備好');
    await app.tap('review-send');
    expect(app.has('review-lesson'), isTrue);
    await app.tap('review-save-yes');
    expect(app.has('review-ending'), isTrue);
    await app.tap('review-end-ok');

    // 首頁：今天聊完了，沒有任何行動呼籲。
    expect(app.has('home-ended'), isTrue);
    expect(find.byType(FilledButton), findsNothing);
    final after = await app.read((r) => r.plans(day));
    expect(after.map((p) => p.outcome), [Outcome.done, Outcome.partly, Outcome.notToday]);
    final record = await app.read((r) => r.dayRecord(day));
    expect(record!.ended, isTrue);
    expect(record.reflection, '我先把顏料都準備好');
    final lessons = await app.read((r) => r.watchLessons().first);
    expect(lessons, hasLength(1));
    expect(lessons.single.sharedWithParent, isFalse, reason: 'sharing is never the default');
    final lesson = lessons.single;

    // ---- 家長區（第一次進：設定 PIN）：孩子還沒分享，什麼都看不到——沒有計畫、回顧原話、結果。
    await app.openParent(firstTime: true);
    expect(app.has('shared-empty'), isTrue);
    final parentTexts = app.visibleTexts().join('\n');
    for (final private in ['我先把顏料都準備好', '畫一張圖', '看一本恐龍的書', '%']) {
      expect(parentTexts, isNot(contains(private)));
    }
    await app.lockParent();

    // ---- 筆記本：這一頁在，按愛心、分享給家長（孩子的動作）。
    await app.tap('nav-notebook');
    expect(app.has('lesson-${lesson.id}'), isTrue);
    await app.tap('fav-${lesson.id}');
    await app.tap('share-${lesson.id}');
    final stored = (await app.read((r) => r.watchLessons().first)).single;
    expect(stored.favorite, isTrue);
    expect(stored.sharedWithParent, isTrue);
    await app.back();

    // 分享之後家長才看得到這一頁（而且只有這一頁）。
    await app.openParent();
    expect(app.has('shared-${lesson.id}'), isTrue);
    await app.lockParent();

    // ---- 小路：今天多一塊石頭。
    await app.tap('nav-path');
    expect(app.has('stone-$day'), isTrue);
    await app.back();

    // ---- 隔天早上打開：新的一天，又是一個邀請；昨天的東西都還在。
    await app.resumeAt(DateTime(2026, 11, 5, 7, 45));
    expect(app.has('home-ended'), isFalse);
    expect(app.has('home-plan'), isTrue);
    expect(await app.read((r) => r.watchLessons().first), hasLength(1));
    await app.close();
  });

  testWidgets('low mood: "not today" just goes home and saves nothing; planning later the same day still works',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30));
    final before = await app.read((r) => r.exportJson());
    await app.tap('home-plan');
    await app.tap('mood-low');
    expect(find.text(PlanCopy.moodLowReply.lively), findsOneWidget);
    await app.tap('mood-rest');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.has('home-plan'), isTrue);
    expect(await app.read((r) => r.exportJson()), before, reason: 'mood is never stored');

    // 心情不會被記住，也不會影響之後：同一天晚一點還是可以排。
    await planOnePreset(app);
    expect(await app.read((r) => r.plans(app.today)), hasLength(1));
    final json = await app.read((r) => r.exportJson());
    expect(json.toLowerCase(), isNot(contains('mood')));
    await app.close();
  });

  testWidgets('a "not today" day is fully neutral: same steps, same ending, Bubu still learns', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 20, 45));
    await planOnePreset(app, task: 1, cue: 2);
    await reviewAll(app, [Outcome.notToday]);
    final lessons = await app.read((r) => r.watchLessons().first);
    expect(lessons, hasLength(1), reason: 'Bubu learns something on a not-today day too');
    expect((await app.read((r) => r.plans(app.today))).single.outcome, Outcome.notToday);

    // 小路上這一天的石頭和別天一樣（每塊都一樣，不看結果）。
    await app.tap('nav-path');
    expect(app.has('stone-${app.today}'), isTrue);
    await app.back();
    await app.close();
  });

  testWidgets('re-planning replaces today\'s plans; cancelling a re-plan keeps them', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30));
    await planOnePreset(app, task: 0, cue: 0);
    final first = (await app.read((r) => r.plans(app.today))).single;

    // 重排到一半按返回：原本的計畫還在。
    await app.tap('home-replan');
    await app.tap('plan-back');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect((await app.read((r) => r.plans(app.today))).single.id, first.id);

    await planOnePreset(app, task: 1, cue: 1);
    final now = (await app.read((r) => r.plans(app.today))).single;
    expect(now.task, isNot(first.task));
    expect(app.has('home-plan-card-0'), isTrue);
    expect(app.has('home-plan-card-1'), isFalse);
    await app.close();
  });

  testWidgets('peeks follow the reminder slots and stop at the daily cap', (tester) async {
    // 16:30 在預設的「放學後」時段（16:00–18:00）。
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 16, 30));
    expect(app.has('home-peek'), isFalse, reason: 'no plan, no peek');
    await planOnePreset(app);
    final seen = <bool>[];
    for (var visit = 0; visit < AppConfig.maxPeeksPerDay + 2; visit++) {
      seen.add(app.has('home-peek'));
      if (app.has('home-peek')) await app.tap('peek-go');
      await app.tap('nav-explore');
      await app.back();
    }
    expect(seen.where((s) => s), hasLength(AppConfig.maxPeeksPerDay));
    expect(seen.first, isTrue, reason: 'right after planning inside a slot');

    // 超過時段（21:00）：不探頭。
    await app.resumeAt(DateTime(2026, 11, 5, 21, 0));
    await planOnePreset(app);
    expect(app.has('home-peek'), isFalse, reason: 'outside every slot');
    await app.close();
  });
}
