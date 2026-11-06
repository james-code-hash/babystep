// 月回顧（J4）：用故事說、只跟自己比；親子各寫一句；孩子那句孩子寫了家長才看得到。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/month.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/month/month_screen.dart';
import 'package:little_steps/providers.dart';
import 'package:little_steps/safety/safety_response.dart';

import '../../helpers/test_app.dart';
import '../parent/parent_screen_test.dart' show openParent, read, settle, tapKey, unmount;

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 存信會失敗的 repository（例如磁碟滿了）。
class _FailingLetters extends Repository {
  _FailingLetters(TestEnv env) : super(env.db, clock: env.clock);
  @override
  Future<void> saveMonthLetter(String monthKey, LetterAuthor author, String text) async =>
      throw StateError('disk full');
}

const _read = PlanDraft(emoji: '📖', task: '看一本書', cue: '我吃完晚飯');
const _tidy = PlanDraft(emoji: '🎒', task: '整理書包', cue: '我洗完澡');

Future<TestEnv> _seeded() async {
  final env = TestEnv(); // 2026-10-23
  await env.seed();
  await env.repo.savePlans('2026-09-10', const [_tidy]);
  await env.repo.savePlans('2026-10-02', const [_read]);
  await env.repo.savePlans('2026-10-12', const [_read, _tidy]);
  await env.repo.savePlans('2026-10-20', const [_read]);
  return env;
}

void main() {
  test('months: this month always, plus months with plans or letters, newest first', () {
    PlannedDay day(String k) => PlannedDay(dayKey: k, emojis: const [], tasks: const [], cues: const []);
    expect(monthsToShow(const [], const [], DateTime(2026, 11, 3)), ['2026-11']);
    expect(
      monthsToShow(
        [day('2026-08-01'), day('2026-10-05'), day('2026-10-09')],
        const [MonthLetter(monthKey: '2026-07', author: LetterAuthor.parent, text: 'x')],
        DateTime(2026, 11, 3),
      ),
      ['2026-11', '2026-10', '2026-08', '2026-07'],
    );
  });

  testWidgets('this month is a short story about the child, then older months can be turned to', (tester) async {
    _tall(tester);
    final env = await _seeded();
    await pumpScreen(tester, env, const MonthScreen());
    await settleAll(tester);
    expect(find.byKey(const ValueKey('month-page-2026-10')), findsOneWidget);
    expect(find.text(MonthCopy.days.fill(AgeTone.lively, {'n': '3'})), findsOneWidget);
    expect(find.text(MonthCopy.topTask.fill(AgeTone.lively, {'task': '看一本書'})), findsOneWidget);
    expect(find.text(MonthCopy.topCue.fill(AgeTone.lively, {'cue': '吃完晚飯'})), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byKey(const ValueKey('month-letter-field')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('month-older')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-page-2026-09')), findsOneWidget);
    expect(find.text(MonthCopy.days.fill(AgeTone.lively, {'n': '1'})), findsOneWidget);
    // 只出現一次就不說「最常」。
    expect(find.byKey(const ValueKey('month-letters')), findsNothing, reason: 'past months are read-only and empty');
    final older = tester.widget<IconButton>(find.byKey(const ValueKey('month-older')));
    expect(older.onPressed, isNull);
    await finishTest(tester, env);
  });

  testWidgets('the child writes a sentence to the family; the parent area shows it; it can be changed', (tester) async {
    _tall(tester);
    final env = await _seeded();
    await pumpScreen(tester, env, const MonthScreen());
    await settleAll(tester);
    await tester.enterText(find.byKey(const ValueKey('month-letter-field')), '謝謝你們陪我練琴');
    await tester.tap(find.byKey(const ValueKey('month-letter-save')));
    await settleAll(tester);
    expect(find.byKey(const ValueKey('month-letter-child')), findsOneWidget);
    var view = (await tester.runAsync(env.repo.parentView))!;
    expect(view.monthLetters.single.child, '謝謝你們陪我練琴');
    expect(view.monthLetters.single.parent, isNull);

    await tester.tap(find.byKey(const ValueKey('month-letter-remove')));
    await settleAll(tester);
    view = (await tester.runAsync(env.repo.parentView))!;
    expect(view.monthLetters, isEmpty);
    expect(find.byKey(const ValueKey('month-letter-field')), findsOneWidget);
    await finishTest(tester, env);
  });

  testWidgets('"change it" can be cancelled: the sentence stays as it was', (tester) async {
    _tall(tester);
    final env = await _seeded();
    await env.repo.saveMonthLetter('2026-10', LetterAuthor.child, '謝謝你們陪我練琴');
    await pumpScreen(tester, env, const MonthScreen());
    await settleAll(tester);
    expect(find.byKey(const ValueKey('month-letter-cancel')), findsNothing, reason: 'nothing to go back to yet');
    await tester.tap(find.byKey(const ValueKey('month-letter-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('month-letter-field')), '算了');
    await tester.tap(find.byKey(const ValueKey('month-letter-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-letter-field')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('month-letter-child')), matching: find.text('謝謝你們陪我練琴')),
        findsOneWidget);
    expect((await tester.runAsync(env.repo.monthLetters))!.single.text, '謝謝你們陪我練琴');
    await finishTest(tester, env);
  });

  testWidgets('if saving fails, the button comes back so the child can try again', (tester) async {
    _tall(tester);
    final env = await _seeded();
    await pumpScreen(tester, env, const MonthScreen(),
        extra: [repositoryProvider.overrideWithValue(_FailingLetters(env))]);
    await settleAll(tester);
    await tester.enterText(find.byKey(const ValueKey('month-letter-field')), '謝謝你們陪我練琴');
    await tester.tap(find.byKey(const ValueKey('month-letter-save')));
    await settleAll(tester);
    expect(tester.takeException(), isA<StateError>());
    final save = tester.widget<FilledButton>(find.byKey(const ValueKey('month-letter-save')));
    expect(save.onPressed, isNotNull);
    expect(find.text('謝謝你們陪我練琴'), findsOneWidget, reason: 'the words stay so the child can try again');
    await finishTest(tester, env);
  });

  testWidgets('a worrying sentence goes to the safety path and is never saved', (tester) async {
    _tall(tester);
    final env = await _seeded();
    await pumpScreen(tester, env, const MonthScreen());
    await settleAll(tester);
    await tester.enterText(find.byKey(const ValueKey('month-letter-field')), '我不想活了');
    await tester.tap(find.byKey(const ValueKey('month-letter-save')));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyResponseScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await settleAll(tester);
    expect((await tester.runAsync(env.repo.monthLetters))!, isEmpty);
    expect(find.textContaining('不想活'), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('the parent writes one sentence (blocked words stay in the dialog); the child sees it word for word',
      (tester) async {
    final env = await _seeded();
    await env.repo.saveMonthLetter('2026-10', LetterAuthor.child, '週末想一起去爬山');
    await openParent(tester, env);
    expect(find.byKey(const ValueKey('parent-month-child')), findsOneWidget);
    await tapKey(tester, 'month-letter-write');
    await tester.enterText(find.byKey(const ValueKey('letter-field')), '你這個月好棒');
    await tester.tap(find.byKey(const ValueKey('letter-save')));
    await settle(tester);
    expect(find.byKey(const ValueKey('letter-blocked')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('letter-field')), '我看到你常常自己先把書包準備好');
    await tester.tap(find.byKey(const ValueKey('letter-save')));
    await settle(tester);
    expect(find.byKey(const ValueKey('parent-month-parent')), findsOneWidget);
    final letters = await read(tester, env.repo.monthLetters);
    expect(letters.map((l) => (l.author, l.text)), containsAll([
      (LetterAuthor.parent, '我看到你常常自己先把書包準備好'),
      (LetterAuthor.child, '週末想一起去爬山'),
    ]));
    await unmount(tester);

    _tall(tester);
    await pumpScreen(tester, env, const MonthScreen());
    await settleAll(tester);
    expect(tester.widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('month-letter-parent')),
      matching: find.text('我看到你常常自己先把書包準備好'),
    )).data, '我看到你常常自己先把書包準備好');
    await finishTest(tester, env);
  });

  testWidgets('family "today" entries of the month are listed once each, without counts', (tester) async {
    _tall(tester);
    final env = await _seeded();
    await env.repo.saveFamilyToday('2026-10-03', who: '媽媽', text: '散步二十分鐘');
    await env.repo.saveFamilyToday('2026-10-04', who: '媽媽', text: '散步二十分鐘');
    await env.repo.saveFamilyToday('2026-09-04', who: '爸爸', text: '早點睡');
    await pumpScreen(tester, env, const MonthScreen());
    await settleAll(tester);
    expect(find.text(MonthCopy.familyItem.fill(AgeTone.lively, {'who': '媽媽', 'text': '散步二十分鐘'})), findsOneWidget);
    expect(find.textContaining('早點睡'), findsNothing);
    await finishTest(tester, env);
  });

  test('letters are exported', () async {
    final env = TestEnv();
    await env.seed();
    await env.repo.saveMonthLetter('2026-10', LetterAuthor.child, '謝謝');
    final j = jsonDecode(await env.repo.exportJson()) as Map<String, Object?>;
    expect(j['monthLetters'], [
      {'monthKey': '2026-10', 'author': 'child', 'text': '謝謝'},
    ]);
    await env.dispose();
  });
}
