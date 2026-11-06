// 2026-11-06 稽核找到的兩個 bug：從家長區回到孩子的首頁時，畫面要跟著家長剛做的事更新。
//
// 1. 刪除全部資料 → 回首頁：說話方式、裝扮、「今天聊完了」都要回到剛安裝的樣子（不用重開 App）。
// 2. 新增一個涵蓋現在的提醒時段 → 回首頁：步步要探頭。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/app_root.dart';
import 'package:little_steps/bubu/bubu_inputs.dart';
import 'package:little_steps/copy/home.dart';
import 'package:little_steps/copy/parent.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/parent/parent_home.dart';

import '../features/parent/parent_screen_test.dart' show enterPin, settle, tapKey;
import '../helpers/test_app.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openParentFromHome(WidgetTester tester) async {
  await tapKey(tester, 'nav-parent');
  await enterPin(tester, '2468');
  expect(find.byType(ParentHome), findsOneWidget);
}

Future<void> _lockBackToHome(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('parent-lock')));
  await settle(tester);
  expect(find.byType(HomeScreen), findsOneWidget);
}

void main() {
  testWidgets('bug 2: a reminder slot added in the parent area makes Bubu peek on the way back home', (tester) async {
    _tall(tester);
    final env = TestEnv(now: DateTime(2026, 10, 23, 16, 30));
    await env.seed();
    await env.repo.setReminderSlots(const []);
    await env.repo.setParentPin('2468');
    await env.repo.savePlans(dayKeyOf(env.clock.now()), const [
      PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我放學回到家'),
    ]);
    await pumpApp(tester, env);
    await settle(tester);
    expect(find.byKey(const ValueKey('home-peek')), findsNothing);

    await _openParentFromHome(tester);
    // 新增時段的預設是 16:00–17:00（ParentConfig），涵蓋現在的 16:30。
    await tapKey(tester, 'add-slot');
    await tester.enterText(find.byKey(const ValueKey('slot-label-field')), '放學後');
    await tapKey(tester, 'dialog-save');
    await _lockBackToHome(tester);

    expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
    await finishTest(tester, env);
  });

  testWidgets('bug 1: after "delete all", the whole app starts over at a fresh Home without restarting',
      (tester) async {
    _tall(tester);
    // 刪檔重開（DatabaseStore.reset）在 widget test 的假時間裡跑不完，由 test/data/delete_all_test.dart
    // 與 integration_test/parent_round_trip_test.dart（真的磁碟、真的 isolate）驗；這裡驗「原地重新開始」。
    final env = TestEnv();
    final day = dayKeyOf(env.clock.now());
    await env.seed();
    await env.repo.setParentPin('2468');
    await env.repo.setTone(AgeTone.concise);
    await env.repo.setDressUp(const DressUp(hat: 'straw', neck: 'bow', color: 'mint'));
    await env.repo.savePlans(day, const [PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我吃完晚飯')]);
    await env.repo.endDay(day);
    await env.repo.saveLesson(day, const LessonResult(
      text: '原來先做最難的那一題，後面就輕鬆很多',
      kind: LessonKind.method,
      source: LessonSource.template,
    ));

    await tester.pumpWidget(AppRoot(overrides: env.overrides));
    await settle(tester);
    var container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(find.byKey(const ValueKey('home-ended')), findsOneWidget);
    expect(container.read(toneProvider), AgeTone.concise);
    expect(container.read(bubuDressUpProvider).hat, 'straw');

    await _openParentFromHome(tester);
    await tapKey(tester, 'delete-all');
    await tapKey(tester, 'delete-continue');
    await tester.enterText(find.byKey(const ValueKey('delete-type-field')), ParentCopy.deleteConfirmWord.concise);
    await settle(tester);
    await tapKey(tester, 'delete-final');
    await settleAll(tester, rounds: 10);

    // 整個 App 原地重新開始：直接回到首頁，家長區已經關掉（H2）。
    expect(find.byType(ParentHome), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(find.byKey(const ValueKey('home-ended')), findsNothing);
    expect(find.byKey(const ValueKey('home-plan')), findsOneWidget);
    expect(find.text(HomeCopy.planInvite.lively), findsOneWidget);
    expect(container.read(toneProvider), AgeTone.lively);
    expect(container.read(bubuDressUpProvider), DressUp.initial);
    await finishTest(tester, env);
  });
}
