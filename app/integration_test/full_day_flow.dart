// 離線一整天的流程（HANDOFF §4 第一、二項）。integration_test 與 widget test 共用這份。
// 不需要網路、不需要 Firebase：資料庫是 in-memory，LLM 關閉，步步學到走範本。
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/app.dart';
import 'package:little_steps/bootstrap.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/data/db.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  // drift 的查詢需要真的 async 才會完成。
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// 早上計畫 → 晚上回顧 [outcome] → 步步學到 → 記進筆記本 → 結束。
Future<void> runFullDay(WidgetTester tester, Outcome outcome) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
  // 晚上七點半：早上排的計畫，晚上回顧（同一個 dayKey）。
  final clock = FixedClock(DateTime(2026, 10, 23, 7, 30));
  final overrides = await tester.runAsync(() => bootstrapOverrides(database: db));
  await tester.pumpWidget(ProviderScope(
    overrides: [...overrides!, clockProvider.overrideWithValue(clock)],
    child: const LittleStepsApp(),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);

  // 早上：心情暖身（不存）→ 選一件事 → 如果⋯我就⋯ → 為什麼（跳過）→ 確認。
  await _tap(tester, 'home-plan');
  await _tap(tester, 'mood-happy');
  await _tap(tester, 'plan-next');
  await _tap(tester, 'task-preset-task-0');
  await _tap(tester, 'plan-next');
  await _tap(tester, 'cue-preset-cue-0');
  await _tap(tester, 'plan-next');
  await _tap(tester, 'why-skip');
  await _tap(tester, 'plan-next');
  expect(find.byKey(const ValueKey('home-review')), findsOneWidget);

  // 晚上：回顧三種狀態之一 → 歷程問題 → 步步學到 → 記進筆記本 → 結束。
  clock.fixed = DateTime(2026, 10, 23, 19, 30);
  await _tap(tester, 'home-review');
  await _tap(tester, 'review-start');
  await _tap(tester, 'outcome-${outcome.name}');
  await _tap(tester, 'review-next');
  await _tap(tester, 'review-chip-0');
  expect(find.byKey(const ValueKey('review-lesson')), findsOneWidget);
  await _tap(tester, 'review-save-yes');
  expect(find.byKey(const ValueKey('review-ending')), findsOneWidget);
  await _tap(tester, 'review-end-ok');

  // 首頁進入「今天聊完了」，沒有任何行動呼籲。
  expect(find.byKey(const ValueKey('home-ended')), findsOneWidget);
  expect(find.byType(FilledButton), findsNothing);

  final repo = Repository(db, clock: clock);
  final lessons = (await tester.runAsync(() => repo.watchLessons().first))!;
  expect(lessons, hasLength(1), reason: 'Bubu learned something on a $outcome day too');
  final record = await tester.runAsync(() => repo.dayRecord(dayKeyOf(clock.now())));
  expect(record!.ended, isTrue);

  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(db.close);
}
