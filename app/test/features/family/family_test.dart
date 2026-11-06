// 全家一起（I2）：家長的「今天的我」、家人留言由步步轉達、孩子可以關掉、家長看不到已讀。
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/family.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/data/db.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/parent/parent_family.dart';
import 'package:little_steps/features/settings/settings_screen.dart';

import '../../helpers/test_app.dart';
import '../parent/parent_screen_test.dart' show openParent, read, tapKey, unmount;

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final rules = loadCopyRules();

  group('parent text filter', () {
    test('encouragement passes; evaluation, pressure and guilt are blocked', () {
      expect(familyTextProblem(rules, '我看到你今天自己把書包整理好了'), isNull);
      expect(familyTextProblem(rules, '散步二十分鐘'), isNull);
      for (final bad in ['你好棒', '你真聰明', '加油', '明天要早點寫功課', '一定要練琴', '媽媽很失望', '下次記得']) {
        expect(familyTextProblem(rules, bad), isNotNull, reason: bad);
      }
    });
  });

  testWidgets('parent writes "today" and a note; a blocked note stays in the dialog', (tester) async {
    final env = TestEnv();
    await openParent(tester, env);
    expect(find.byKey(const ValueKey('family-today-empty')), findsOneWidget);

    await tapKey(tester, 'family-today-add');
    await tester.tap(find.byKey(const ValueKey('family-who-1'))); // 媽媽
    await tester.enterText(find.byKey(const ValueKey('family-text-field')), '散步二十分鐘');
    await tapKey(tester, 'dialog-save');
    expect(find.text('散步二十分鐘'), findsOneWidget);
    final today = await read(tester, () => env.repo.familyToday(dayKeyOf(env.clock.now())));
    expect(today.single.who, '媽媽');

    await tapKey(tester, 'family-note-add');
    await tester.enterText(find.byKey(const ValueKey('family-who-field')), '爸爸');
    await tester.enterText(find.byKey(const ValueKey('family-text-field')), '你好棒');
    await tapKey(tester, 'dialog-save');
    expect(find.byKey(const ValueKey('family-blocked')), findsOneWidget);
    expect(await read(tester, env.repo.familyNotes), isEmpty);
    await tester.enterText(find.byKey(const ValueKey('family-text-field')), '我看到你今天自己把書包整理好了');
    await tapKey(tester, 'dialog-save');
    expect(find.byKey(const ValueKey('family-blocked')), findsNothing);
    expect((await read(tester, env.repo.familyNotes)).single.who, '爸爸');
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });

  group('child home', () {
    testWidgets('shows family "today" and relays a note word for word; once read it is not relayed again',
        (tester) async {
      _tall(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.saveFamilyToday(dayKeyOf(env.clock.now()), who: '媽媽', text: '散步二十分鐘');
      await env.repo.addFamilyNote(who: '爸爸', text: '我看到你今天自己把書包整理好了');
      await pumpApp(tester, env);
      await settleAll(tester);

      expect(find.byKey(const ValueKey('home-family-today')), findsOneWidget);
      expect(find.text(FamilyCopy.homeItem.fill(AgeTone.lively, {'who': '媽媽', 'text': '散步二十分鐘'})), findsOneWidget);
      expect(find.text(FamilyCopy.noteInvite.fill(AgeTone.lively, {'who': '爸爸'})), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('family-note-open')));
      await settleAll(tester);
      expect(find.byKey(const ValueKey('family-note-dialog')), findsOneWidget);
      // 原封不動，沒有步步的評論。
      expect(tester.widget<Text>(find.byKey(const ValueKey('family-note-text'))).data, '我看到你今天自己把書包整理好了');
      await tester.tap(find.byKey(const ValueKey('family-note-close')));
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-family-note')), findsNothing);
      expect((await tester.runAsync(env.repo.familyNotes))!.single.childRead, isTrue);
      await finishTest(tester, env);
    });

    testWidgets('"later" hides the note for this visit only and records nothing', (tester) async {
      _tall(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.addFamilyNote(who: '阿嬤', text: '週末一起去公園');
      await pumpApp(tester, env);
      await settleAll(tester);
      await tester.tap(find.byKey(const ValueKey('family-note-later')));
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-family-note')), findsNothing);
      expect((await tester.runAsync(env.repo.familyNotes))!.single.childRead, isFalse);
      await finishTest(tester, env);
    });

    testWidgets('the child can turn relaying off in their own settings', (tester) async {
      _tall(tester);
      final env = TestEnv();
      await env.seed();
      await env.repo.addFamilyNote(who: '阿嬤', text: '週末一起去公園');
      await pumpScreen(tester, env, const ChildSettingsScreen());
      await settleAll(tester);
      await tester.tap(find.byKey(const ValueKey('family-notes-switch')));
      await settleAll(tester);
      expect((await tester.runAsync(env.repo.settings))!.familyNotesOn, isFalse);
      await unmount(tester);

      await pumpApp(tester, env);
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-family-note')), findsNothing);
      await finishTest(tester, env);
    });
  });

  test('a v1 database upgrades to the current schema (family tables, stuck plan) and keeps its data', () async {
    final raw = NativeDatabase.memory(setup: (db) {
      db.execute('CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
      db.execute("INSERT INTO settings VALUES ('tone', 'concise')");
      db.execute('CREATE TABLE plans (id TEXT NOT NULL PRIMARY KEY, day_key TEXT NOT NULL, position INTEGER NOT NULL, '
          'emoji TEXT NOT NULL, task TEXT NOT NULL, cue TEXT NOT NULL, why TEXT NULL, outcome TEXT NULL)');
      db.execute("INSERT INTO plans VALUES ('p1', '2026-10-01', 0, '✏️', '寫數學', '我吃完晚飯', NULL, 'done')");
      db.execute('PRAGMA user_version = 1');
    });
    final db = AppDatabase(DatabaseConnection(raw));
    expect((await db.select(db.settings).get()).single.value, 'concise');
    final plan = (await db.select(db.plans).get()).single;
    expect(plan.task, '寫數學');
    expect(plan.stuckPlan, isNull);
    expect(await db.select(db.familyTodayEntries).get(), isEmpty);
    expect(await db.select(db.familyNotes).get(), isEmpty);
    await db.close();
  });
}
