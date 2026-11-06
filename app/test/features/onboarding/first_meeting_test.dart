// 初次見面與取名字（文案庫 §4.1，D6）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/bubu.dart';
import 'package:little_steps/copy/home.dart';
import 'package:little_steps/copy/line.dart';
import 'package:little_steps/copy/onboarding.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/onboarding/pet_name.dart';
import 'package:little_steps/safety/safety_response.dart';

import '../../helpers/test_app.dart';

void main() {
  tearDown(() => PetName.current = null);

  group('PetName', () {
    test('every 步步 in a line becomes the chosen name; filled-in values stay as they are', () {
      PetName.current = '小花';
      expect(HomeCopy.notebook.of(AgeTone.lively), '小花的筆記本');
      expect(OnboardingCopy.nameBack.fill(AgeTone.lively, {'original': PetName.original}), '換回步步');
      PetName.current = '  ';
      expect(PetName.current, PetName.original, reason: 'blank means 步步');
      expect(HomeCopy.notebook.of(AgeTone.lively), '步步的筆記本');
    });

    test('names the copy rules would block, or too long, are not used', () {
      final rules = loadCopyRules();
      expect(petNameAllowed('小花', rules), isTrue);
      expect(petNameAllowed('毛毛球', rules), isTrue);
      expect(petNameAllowed('👨‍👩‍👧🐱', rules), isTrue, reason: 'counted like the input box: two characters');
      for (final bad in ['天才', '好棒', '加油', '金幣', '', '   ', '一二三四五六七', '{task}']) {
        expect(petNameAllowed(bad, rules), isFalse, reason: bad);
      }
    });

    test('with a name, every greeting still passes the copy rules', () {
      final rules = loadCopyRules();
      PetName.current = '小花';
      for (final pool in [BubuCopy.greetings, BubuCopy.greetingsMorning, BubuCopy.greetingsDay]) {
        for (final l in pool.lines) {
          for (final tone in AgeTone.values) {
            expect(rules.check(l.of(tone), tone: tone), isEmpty, reason: l.of(tone));
          }
        }
      }
    });
  });

  testWidgets('a fresh install meets Bubu first; skipping the name keeps 步步', (tester) async {
    final env = TestEnv(onboarded: false);
    await pumpApp(tester, env);
    expect(find.byKey(const ValueKey('first-meeting')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-plan')), findsNothing);
    final hellos = OnboardingCopy.hello.lines.map((l) => l.lively);
    final said = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('first-meeting-bubble')), matching: find.byType(Text)));
    expect(hellos, contains(said.data));

    await tester.tap(find.byKey(const ValueKey('hello-next')));
    await settleAll(tester);
    await tester.tap(find.byKey(const ValueKey('pet-name-keep')));
    await settleAll(tester);
    await tester.tap(find.byKey(const ValueKey('hello-done')));
    await settleAll(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('first-meeting')), findsNothing);
    expect(find.byKey(const ValueKey('home-plan')), findsOneWidget);
    final s = (await tester.runAsync(env.repo.settings))!;
    expect((s.onboarded, s.petName), (true, null));
    await finishTest(tester, env);
  });

  testWidgets('a crisis word as a name goes to the safety response and is never saved', (tester) async {
    final env = TestEnv(onboarded: false);
    await pumpApp(tester, env);
    await tester.tap(find.byKey(const ValueKey('hello-next')));
    await settleAll(tester);
    await tester.enterText(find.byKey(const ValueKey('pet-name-field')), '我想死');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pet-name-use')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SafetyResponseScreen), findsOneWidget);
    expect((await tester.runAsync(env.repo.settings))!.petName, isNull);
    await finishTest(tester, env);
  });

  testWidgets('the export carries the name; nothing else about the meeting', (tester) async {
    final env = TestEnv();
    await env.seed();
    await tester.runAsync(() => env.repo.setPetName('小花'));
    final json = (await tester.runAsync(env.repo.exportJson))!;
    expect(json, contains('"petName": "小花"'));
    await tester.runAsync(env.dispose);
  });
}
