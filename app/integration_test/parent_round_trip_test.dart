// 在真的裝置（或 Linux 桌面版）上，用 App 真正的啟動方式（磁碟上的資料庫、背景 isolate）
// 驗證稽核找到的兩個 bug：
//   cd app && fvm flutter test integration_test/parent_round_trip_test.dart -d <device>
//
// 1. 家長「刪除全部資料」→ 回首頁：說話方式、裝扮、「今天聊完了」都回到剛安裝的樣子，不用重開 App。
// 2. 家長新增一個涵蓋現在的提醒時段 → 回首頁：步步探頭。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:little_steps/app_root.dart';
import 'package:little_steps/bootstrap.dart';
import 'package:little_steps/bubu/bubu_inputs.dart';
import 'package:little_steps/copy/parent.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/data/database_store.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/parent/parent_home.dart';
import 'package:little_steps/providers.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  final list = find.descendant(of: find.byKey(const ValueKey('parent-list')), matching: find.byType(Scrollable));
  if (f.evaluate().isEmpty && list.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: list.first);
  }
  await tester.ensureVisible(f);
  await _settle(tester);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _pin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$d')));
    await tester.pump();
  }
  await _settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete all, then back home: a fresh install without restarting; a new slot makes Bubu peek',
      (tester) async {
    final clock = FixedClock(DateTime(2026, 10, 23, 16, 30));
    final day = dayKeyOf(clock.now());
    final overrides = await bootstrapOverrides();
    await tester.pumpWidget(AppRoot(overrides: [...overrides, clockProvider.overrideWithValue(clock)]));
    await _settle(tester);
    var container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    Repository repo() => container.read(repositoryProvider);

    // 孩子用了一陣子：簡潔語氣、換了裝扮、今天聊完了、記了一則筆記。
    await repo().setParentPin('2468');
    await repo().setTone(AgeTone.concise);
    await repo().setDressUp(const DressUp(hat: 'straw', neck: 'bow', color: 'mint'));
    await repo().savePlans(day, const [PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我放學回到家')]);
    await repo().endDay(day);
    await repo().saveLesson(day, const LessonResult(
      text: '原來先做最難的那一題，後面就輕鬆很多',
      kind: LessonKind.method,
      source: LessonSource.template,
    ));
    await _settle(tester);
    expect(find.byKey(const ValueKey('home-ended')), findsOneWidget);
    expect(container.read(toneProvider), AgeTone.concise);

    // ---- 1. 刪除全部資料
    final oldDb = container.read(databaseProvider);
    await _tap(tester, 'nav-parent');
    await _pin(tester, '2468');
    await _tap(tester, 'delete-all');
    await _tap(tester, 'delete-continue');
    await tester.enterText(find.byKey(const ValueKey('delete-type-field')), ParentCopy.deleteConfirmWord.concise);
    await _settle(tester);
    await _tap(tester, 'delete-final');
    // 整個 App 原地重新開始，直接回到首頁（H2）。刪檔重開要一點時間。
    for (var i = 0; i < 100 && find.byType(ParentHome).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _settle(tester);
    expect(find.byType(ParentHome), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

    expect(find.byKey(const ValueKey('home-ended')), findsNothing);
    expect(find.byKey(const ValueKey('home-plan')), findsOneWidget);
    expect(container.read(toneProvider), AgeTone.lively);
    expect(container.read(bubuDressUpProvider), DressUp.initial);
    // 資料庫檔真的換了一個（刪檔重開），不只是清掉資料列。
    expect(container.read(databaseStoreProvider), isNotNull);
    expect(identical(container.read(databaseProvider), oldDb), isFalse);

    // ---- 2. 新增提醒時段（預設 16:00–17:00，涵蓋 16:30）→ 回首頁要探頭
    await repo().setReminderSlots(const []);
    await repo().savePlans(day, const [PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我放學回到家')]);
    await _settle(tester);
    expect(find.byKey(const ValueKey('home-peek')), findsNothing);
    await _tap(tester, 'nav-parent');
    // 刪除之後 PIN 也沒了：重新設一次。
    await _pin(tester, '1357');
    await _pin(tester, '1357');
    await _tap(tester, 'add-slot');
    await tester.enterText(find.byKey(const ValueKey('slot-label-field')), '放學後');
    await _tap(tester, 'dialog-save');
    await _tap(tester, 'parent-lock');
    expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);

    // 收尾：清掉這次測試寫在裝置上的資料。
    await container.read(databaseStoreProvider)!.reset();
  });
}
