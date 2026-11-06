// 情境：家長區（底線 6、7、8）。
//
// PIN 守門、建議的事情與時間點（孩子可以不選）、說話方式、LLM 開關（沒有可用的 LLM 時退回範本）、
// 匯出、提醒時段讓步步探頭、刪除全部資料回到剛安裝的樣子。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_inputs.dart';
import 'package:little_steps/copy/home.dart';
import 'package:little_steps/copy/parent.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/data/database_store.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/parent/parent_home.dart';
import 'package:little_steps/providers.dart';

import '../e2e/harness.dart';
import 'child_day.dart' show planOnePreset, reviewAll;

void parentScenarios() {
  testWidgets('PIN: set it by typing twice, a mismatch starts over, a wrong PIN stays out, lock goes home',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 20, 0));
    await app.tap('nav-parent');
    expect(find.text(ParentCopy.pinSetTitle.fill(AgeTone.concise, {'n': '${AppConfig.parentPinLength}'})),
        findsOneWidget);
    await app.pin('1111');
    await app.pin('2222');
    expect(find.text(ParentCopy.pinMismatch.concise), findsOneWidget);
    expect((await app.read((r) => r.settings())).parentPin, isNull);
    await app.pin('2468');
    await app.pin('2468');
    expect(find.byType(ParentHome), findsOneWidget);
    expect((await app.read((r) => r.settings())).parentPin, '2468');
    await app.lockParent();

    await app.tap('nav-parent');
    await app.pin('0000');
    expect(find.byType(ParentHome), findsNothing);
    expect(app.has('pin-message'), isTrue);
    await app.pin('2468');
    expect(find.byType(ParentHome), findsOneWidget);
    await app.lockParent();
    await app.close();
  });

  testWidgets('suggestions: what the parent adds shows up for the child, who can still pick something else',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30));
    await app.openParent(firstTime: true);

    // 建議一件事、一個時間點（自動補成「我⋯」）；刪掉一件預設的。
    await app.tap('add-task');
    await app.enter('task-emoji-field', '🪴');
    await app.enter('task-text-field', '幫植物澆水');
    await app.tap('dialog-save');
    await app.tap('add-cue');
    await app.enter('cue-text-field', '刷完牙');
    await app.tap('dialog-save');
    final suggested = (await app.read((r) => r.taskTemplates(origins: {TemplateOrigin.parent}))).single;
    final suggestedCue = (await app.read((r) => r.cueTemplates(origins: {TemplateOrigin.parent}))).single;
    expect(suggestedCue.text, '我刷完牙');
    await app.tap('delete-preset-task-3');
    await app.lockParent();

    // 孩子排計畫：看得到建議，也看不到被刪掉的那件；這次選了別的。
    await app.tap('home-plan');
    await app.tap('mood-okay');
    await app.tap('plan-next');
    expect(app.has('task-${suggested.id}'), isTrue);
    expect(app.has('task-preset-task-3'), isFalse);
    await app.tap('task-preset-task-0');
    await app.tap('plan-next');
    expect(app.has('cue-${suggestedCue.id}'), isTrue);
    await app.tap('cue-preset-cue-1');
    await app.tap('plan-next');
    await app.tap('why-skip');
    await app.tap('plan-next');
    final plan = (await app.read((r) => r.plans(app.today))).single;
    expect(plan.task, isNot('幫植物澆水'), reason: 'a suggestion is only a suggestion');

    // 還原預設：先確認；被刪的回來，家長加的建議拿掉。
    await app.openParent();
    await app.tap('restore-defaults');
    await app.tapText(ParentCopy.cancel.concise);
    expect((await app.read((r) => r.taskTemplates())).any((t) => t.id == 'preset-task-3'), isFalse);
    await app.tap('restore-defaults');
    await app.tap('restore-confirm');
    final all = await app.read((r) => r.taskTemplates());
    expect(all.any((t) => t.id == 'preset-task-3'), isTrue);
    expect(all.any((t) => t.text == '幫植物澆水'), isFalse);
    await app.lockParent();
    await app.close();
  });

  testWidgets('tone from the parent area reaches the child; the LLM switch with no LLM still teaches Bubu by template; '
      'export hands over everything except mood', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 20, 45));
    await app.openParent(firstTime: true);
    await app.tap('parent-tone');
    await app.tapText(ParentCopy.toneConcise.concise);
    expect(app.container.read(toneProvider), AgeTone.concise);
    await app.tap('llm-switch');
    expect((await app.read((r) => r.settings())).llmEnabled, isTrue);
    await app.lockParent();
    expect(find.text(HomeCopy.planInvite.concise), findsOneWidget);

    // 這個環境沒有 LLM（沒設 emulator、沒部署）：照樣學到，走範本。
    expect(app.container.read(lessonLlmClientProvider), isNull);
    await planOnePreset(app);
    await reviewAll(app, [Outcome.partly]);
    final lesson = (await app.read((r) => r.watchLessons().first)).single;
    expect(lesson.source, LessonSource.template);

    await app.openParent();
    await app.tap('export');
    expect(app.shared, hasLength(1));
    final json = app.shared.single;
    expect(json, contains('little_steps'));
    expect(json, contains(lesson.text));
    expect(json.toLowerCase(), isNot(contains('mood')));
    await app.lockParent();
    await app.close();
  });

  testWidgets('reminder slots: Bubu peeks only inside a slot; a slot that ends before it starts cannot be saved',
      (tester) async {
    // 16:30：預設「放學後」16:00–18:00 涵蓋現在。
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 16, 30));
    await planOnePreset(app);
    expect(app.has('home-peek'), isTrue);
    await app.tap('peek-not-today');
    expect(app.has('home-peek-reply'), isTrue);

    // 家長刪掉兩個預設時段 → 回首頁不探頭。
    await app.openParent(firstTime: true);
    await app.tap('delete-preset-slot-0');
    await app.tap('delete-preset-slot-1');
    expect((await app.read((r) => r.settings())).reminderSlots, isEmpty);
    await app.lockParent();
    expect(app.has('home-peek'), isFalse);

    // 新增時段：預設 16:00–17:00。先把結束改成 15:00（比開始早）→ 存不了；再改回來 → 存下。
    await app.openParent();
    await app.tap('add-slot');
    await app.enter('slot-label-field', '練琴前');
    await _pickTime(app, 'slot-end', hour: 15);
    expect(app.has('slot-invalid'), isTrue);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('dialog-save'))).onPressed, isNull);
    await _pickTime(app, 'slot-end', hour: 17);
    expect(app.has('slot-invalid'), isFalse);
    await app.tap('dialog-save');
    final slot = (await app.read((r) => r.settings())).reminderSlots.single;
    expect((slot.label, slot.startMinute, slot.endMinute), ('練琴前', 16 * 60, 17 * 60));
    await app.lockParent();
    expect(app.has('home-peek'), isTrue, reason: 'the new slot covers 16:30');
    await app.close();
  });

  testWidgets('delete all: two confirmations, then the whole app starts over like a fresh install', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 20, 45));
    // 用了一陣子：簡潔語氣、換了裝扮、排過也聊完、家人留了話、自己寫了一件事。
    await app.tap('nav-settings');
    await app.tap('tone-concise');
    await app.tap('open-dress-up');
    await app.tap('hat-straw');
    await app.back();
    await app.back();
    await planOnePreset(app);
    await reviewAll(app, [Outcome.done]);
    await app.openParent(firstTime: true);
    await app.tap('family-note-add');
    await app.enter('family-who-field', '阿嬤');
    await app.enter('family-text-field', '週末一起去公園');
    await app.tap('dialog-save');
    expect(await app.read((r) => r.familyNotes()), hasLength(1));
    final oldDb = app.container.read(databaseProvider);
    final store = app.container.read(databaseStoreProvider);

    // 第一道取消：什麼都沒刪。
    await app.tap('delete-all');
    await app.tapText(ParentCopy.cancel.concise);
    expect(await app.read((r) => r.watchLessons().first), hasLength(1));

    await app.tap('delete-all');
    await app.tap('delete-continue');
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('delete-final'))).onPressed, isNull,
        reason: 'nothing typed yet');
    await app.enter('delete-type-field', ParentCopy.deleteConfirmWord.concise);
    await app.tap('delete-final');
    // 裝置上要刪檔重開，給它一點時間。
    for (var i = 0; i < 100 && find.byType(ParentHome).evaluate().isNotEmpty; i++) {
      await app.settle(rounds: 2);
    }

    // 直接回到剛安裝的首頁，不用重開 App。
    expect(find.byType(ParentHome), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.has('home-ended'), isFalse);
    expect(find.text(HomeCopy.planInvite.lively), findsOneWidget);
    expect(app.container.read(toneProvider), AgeTone.lively);
    expect(app.container.read(bubuDressUpProvider), DressUp.initial);
    expect(await app.read((r) => r.watchLessons().first), isEmpty);
    expect(await app.read((r) => r.familyNotes()), isEmpty);
    expect(await app.read((r) => r.plannedDays()), isEmpty);
    expect((await app.read((r) => r.settings())).parentPin, isNull);
    expect(await app.read((r) => r.taskTemplates()), isNotEmpty, reason: 'defaults are back');
    if (app.onDevice) {
      // 真的換了一個資料庫檔（刪檔重開），不只是清資料列。
      expect(identical(app.container.read(databaseProvider), oldDb), isFalse);
      expect(identical(app.container.read(databaseProvider), store!.current), isTrue,
          reason: 'the rebuilt app uses the database the store reopened');
    }

    // PIN 也沒了：家長區要重新設定。
    await app.tap('nav-parent');
    expect(find.text(ParentCopy.pinSetTitle.fill(AgeTone.concise, {'n': '${AppConfig.parentPinLength}'})),
        findsOneWidget);
    await app.close();
  });
}

/// 打開時間選擇器，切到鍵盤輸入，把時間改成 [hour]:00（24 小時制；12 小時制的裝置只改小時，下午不動），按確定。
Future<void> _pickTime(E2EApp app, String button, {required int hour}) async {
  final tester = app.tester;
  await app.tap(button);
  final keyboard = find.byIcon(Icons.keyboard_outlined);
  if (keyboard.evaluate().isNotEmpty) {
    await tester.tap(keyboard);
    await app.settle();
  }
  final fields = find.descendant(of: find.byType(Dialog).last, matching: find.byType(TextField));
  final context = tester.element(fields.first);
  final localizations = MaterialLocalizations.of(context);
  final format = localizations.timeOfDayFormat(alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
  final twelve = hourFormat(of: format) == HourFormat.h;
  await app.enterInto(fields.first, '${twelve ? hour - 12 : hour}');
  await app.enterInto(fields.at(1), '00');
  await app.tapText(localizations.okButtonLabel);
  expect(find.byType(TimePickerDialog), findsNothing);
}
