import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/parent.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/parent/parent_home.dart';
import 'package:little_steps/features/parent/parent_providers.dart';
import 'package:little_steps/features/parent/parent_screen.dart';

import '../../helpers/test_app.dart';

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 結束前把畫面拆掉，讓 drift 的 stream 取消計時器跑完。
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

/// 家長區的資料來自 `watchParentView()`，裡面的 drift 查詢要真的 async 才會完成；
/// 假時間的 pumpAndSettle 等不到，所以每次操作後讓真的事件迴圈跑幾輪再 pump。
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 3 && find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$d')));
    await tester.pump();
  }
  await settle(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await settle(tester);
  await tester.tap(f);
  await settle(tester);
}

/// 在 widget 測試的假時間裡，drift 的 watch().first 不會自己完成，要用真的 async 讀。
Future<T> read<T>(WidgetTester tester, Future<T> Function() fn) async => (await tester.runAsync(fn)) as T;

const lessonText = '先把書包放好再開始，比較不會分心';
const reflectionText = '今天其實有一點點累但還是試了';

LessonResult lesson(String text) =>
    LessonResult(text: text, kind: LessonKind.method, source: LessonSource.template);

/// 已經設好 PIN 的家長區，輸入正確 PIN 進去。
Future<List<String>> openParent(WidgetTester tester, TestEnv env) async {
  useTallSurface(tester);
  final shared = <String>[];
  await env.seed();
  await env.repo.setParentPin('2468');
  await pumpScreen(
    tester,
    env,
    const ParentGateScreen(),
    extra: [parentShareProvider.overrideWithValue((text, subject) async => shared.add(text))],
  );
  await enterPin(tester, '2468');
  expect(find.byType(ParentHome), findsOneWidget);
  return shared;
}

void main() {
  group('PIN gate', () {
    testWidgets('first entry sets the PIN (typed twice), later entries verify it', (tester) async {
      final env = TestEnv();
      await pumpScreen(tester, env, const ParentGateScreen());
      expect(find.byType(ParentHome), findsNothing);
      expect(find.text(ParentCopy.pinSetTitle.fill(AgeTone.concise, {'n': '4'})), findsOneWidget);

      await enterPin(tester, '1357');
      expect(find.text(ParentCopy.pinConfirmTitle.concise), findsOneWidget);
      expect((await read(tester, env.repo.settings)).parentPin, isNull);
      await enterPin(tester, '1357');
      expect(find.byType(ParentHome), findsOneWidget);
      expect((await read(tester, env.repo.settings)).parentPin, '1357');

      // 重新進來：要輸入密碼，錯的進不去。
      await unmount(tester);
      await pumpScreen(tester, env, const ParentGateScreen());
      expect(find.text(ParentCopy.pinEnterTitle.concise), findsOneWidget);
      await enterPin(tester, '0000');
      expect(find.byType(ParentHome), findsNothing);
      expect(find.byKey(const ValueKey('pin-message')), findsOneWidget);
      await enterPin(tester, '1357');
      expect(find.byType(ParentHome), findsOneWidget);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('mismatched confirmation starts over and saves nothing', (tester) async {
      final env = TestEnv();
      await pumpScreen(tester, env, const ParentGateScreen());
      await enterPin(tester, '1111');
      await enterPin(tester, '2222');
      expect(find.byType(ParentHome), findsNothing);
      expect(find.text(ParentCopy.pinMismatch.concise), findsOneWidget);
      expect((await read(tester, env.repo.settings)).parentPin, isNull);

      // 刪掉一位再補上也可以。
      await tester.tap(find.byKey(const ValueKey('pin-key-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pin-backspace')));
      await tester.pump();
      await enterPin(tester, '4444');
      await enterPin(tester, '4444');
      expect(find.byType(ParentHome), findsOneWidget);
      expect((await read(tester, env.repo.settings)).parentPin, '4444');
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });
  });

  group('parent home', () {
    testWidgets('task templates: add, edit, delete, restore defaults', (tester) async {
      final env = TestEnv();
      await openParent(tester, env);
      final presets = await read(tester, env.repo.taskTemplates);

      await tapKey(tester, 'add-task');
      await tester.enterText(find.byKey(const ValueKey('task-emoji-field')), '🪴');
      await tester.enterText(find.byKey(const ValueKey('task-text-field')), '幫植物澆水');
      await tapKey(tester, 'dialog-save');
      var all = await read(tester, env.repo.taskTemplates);
      final added = all.singleWhere((t) => t.text == '幫植物澆水');
      expect(added.emoji, '🪴');
      expect(added.origin, TemplateOrigin.parent);
      expect(find.text('幫植物澆水'), findsOneWidget);

      await tapKey(tester, 'edit-${added.id}');
      await tester.enterText(find.byKey(const ValueKey('task-text-field')), '幫陽台的植物澆水');
      await tapKey(tester, 'dialog-save');
      all = await read(tester, env.repo.taskTemplates);
      expect(all.singleWhere((t) => t.id == added.id).text, '幫陽台的植物澆水');
      expect(find.text('幫陽台的植物澆水'), findsOneWidget);

      final victim = presets.first;
      await tapKey(tester, 'delete-${victim.id}');
      expect((await read(tester, env.repo.taskTemplates)).any((t) => t.id == victim.id), isFalse);
      expect(find.byKey(ValueKey('task-${victim.id}')), findsNothing);

      // 還原預設要先確認；取消就什麼都不動。
      await tapKey(tester, 'restore-defaults');
      await tester.tap(find.text(ParentCopy.cancel.concise));
      await settle(tester);
      expect((await read(tester, env.repo.taskTemplates)).any((t) => t.id == victim.id), isFalse);

      await tapKey(tester, 'restore-defaults');
      await tapKey(tester, 'restore-confirm');
      final restored = await read(tester, env.repo.taskTemplates);
      expect(restored.map((t) => t.text).toSet(), presets.map((t) => t.text).toSet());
      expect(restored.any((t) => t.text.contains('植物')), isFalse);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('cue templates are normalized to start with 我', (tester) async {
      final env = TestEnv();
      await openParent(tester, env);
      await tapKey(tester, 'add-cue');
      await tester.enterText(find.byKey(const ValueKey('cue-text-field')), '刷完牙');
      await tapKey(tester, 'dialog-save');
      expect((await read(tester, env.repo.cueTemplates)).map((c) => c.text), contains('我刷完牙'));
      expect(find.text('我刷完牙'), findsOneWidget);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('reminder slot can be added', (tester) async {
      final env = TestEnv();
      await openParent(tester, env);
      final before = (await read(tester, env.repo.settings)).reminderSlots.length;
      await tapKey(tester, 'add-slot');
      await tester.enterText(find.byKey(const ValueKey('slot-label-field')), '練琴前');
      await tapKey(tester, 'dialog-save');
      final slots = (await read(tester, env.repo.settings)).reminderSlots;
      expect(slots, hasLength(before + 1));
      final s = slots.singleWhere((s) => s.label == '練琴前');
      expect(s.endMinute, greaterThan(s.startMinute));
      expect(find.text('練琴前'), findsOneWidget);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('LLM switch and tone persist', (tester) async {
      final env = TestEnv();
      await openParent(tester, env);
      final was = (await read(tester, env.repo.settings)).llmEnabled;
      await tapKey(tester, 'llm-switch');
      expect((await read(tester, env.repo.settings)).llmEnabled, !was);
      await tapKey(tester, 'llm-switch');
      expect((await read(tester, env.repo.settings)).llmEnabled, was);

      await tester.ensureVisible(find.byKey(const ValueKey('parent-tone')));
      await tester.tap(find.text(ParentCopy.toneConcise.concise));
      await settle(tester);
      expect((await read(tester, env.repo.settings)).tone, AgeTone.concise);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('export hands the full json to the share sheet', (tester) async {
      final env = TestEnv();
      final shared = await openParent(tester, env);
      await tapKey(tester, 'export');
      expect(shared, hasLength(1));
      expect(shared.single, contains('little_steps'));
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('delete all needs two confirmations, then clears lessons', (tester) async {
      final env = TestEnv();
      await env.repo.saveLesson('2026-10-22', lesson(lessonText));
      await openParent(tester, env);

      // 第一道取消：什麼都不刪。
      await tapKey(tester, 'delete-all');
      await tester.tap(find.text(ParentCopy.cancel.concise));
      await settle(tester);
      expect(await read(tester, () => env.repo.watchLessons().first), hasLength(1));

      await tapKey(tester, 'delete-all');
      await tapKey(tester, 'delete-continue');
      // 沒打字之前按不下去。
      final btn = tester.widget<FilledButton>(find.byKey(const ValueKey('delete-final')));
      expect(btn.onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('delete-type-field')), ParentCopy.deleteConfirmWord.concise);
      await settle(tester);
      await tapKey(tester, 'delete-final');
      expect(await read(tester, () => env.repo.watchLessons().first), isEmpty);
      expect((await read(tester, env.repo.settings)).parentPin, isNull);
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });

    testWidgets('only lessons the child shared appear; reflections and plans never do', (tester) async {
      final env = TestEnv();
      await env.seed();
      await env.repo.savePlans('2026-10-22', const [PlanDraft(emoji: '🎒', task: '整理明天的書包', cue: '我吃完晚飯')]);
      await env.repo.saveReflection('2026-10-22', reflectionText);
      final l = await env.repo.saveLesson('2026-10-22', lesson(lessonText));
      await env.repo.saveLesson('2026-10-21', lesson('另一則沒有分享的筆記內容'));
      await openParent(tester, env);

      expect(find.byKey(const ValueKey('shared-empty')), findsOneWidget);
      expect(find.textContaining(lessonText), findsNothing);

      await env.repo.setSharedWithParent(l!.id, true);
      await unmount(tester);
      await openParent(tester, env);
      expect(find.text(lessonText), findsOneWidget);
      expect(find.text(ParentCopy.sharedNote.concise), findsOneWidget);

      // 整棵樹裡找不到孩子沒分享的字、回顧原話、計畫內容。
      final texts = [
        for (final e in find.byType(Text).evaluate()) (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
      ].join('\n');
      expect(texts, isNot(contains('另一則沒有分享的筆記內容')));
      expect(texts, isNot(contains(reflectionText)));
      expect(texts, isNot(contains('整理明天的書包')));
      expect(texts, isNot(contains('%')));
      await unmount(tester);
      await tester.runAsync(env.dispose);
    });
  });
}
