import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/notebook.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/notebook/notebook_screen.dart';

import '../../helpers/test_app.dart';
import '../review/review_test_utils.dart' show db, dbTestWidgets, settle;

/// 「N 則／頁／篇⋯」這類數量文字（C4：不顯示數量）。
final _countText = RegExp(r'[0-9０-９]+\s*(則|頁|篇|條|個|張|次|本|天)');

List<String> allTexts(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? '',
];

Future<Lesson> addLesson(TestEnv env, DateTime at, String text) async {
  env.clock.fixed = at;
  final l = await env.repo.saveLesson(
    dayKeyOf(at),
    LessonResult(text: text, kind: LessonKind.method, source: LessonSource.template),
  );
  return l!;
}

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  dbTestWidgets('empty notebook is friendly and shows no counts', (tester) async {
    await pumpScreen(tester, env, const NotebookScreen());
    await settle(tester);
    expect(find.text(NotebookCopy.empty.lively), findsOneWidget);
    for (final t in allTexts(tester)) {
      expect(_countText.hasMatch(t), isFalse, reason: t);
    }
  });

  dbTestWidgets('newest first, zh_TW dates, never a count', (tester) async {
    await env.seed();
    await addLesson(env, DateTime(2026, 10, 21, 20), '原來先收書包，早上就不會找東西。');
    await addLesson(env, DateTime(2026, 10, 22, 20), '原來累的時候可以先休息一下。');
    await addLesson(env, DateTime(2026, 10, 23, 20), '原來喝完水是一個好開始的信號。');
    await pumpScreen(tester, env, const NotebookScreen());
    await settle(tester);

    // 新的在前（閱讀順序）：手機是一欄往下；平板多欄時由左到右、再往下（E11）。
    final newest = tester.getTopLeft(find.text('原來喝完水是一個好開始的信號。'));
    final middle = tester.getTopLeft(find.text('原來累的時候可以先休息一下。'));
    expect(newest.dy < middle.dy || (newest.dy == middle.dy && newest.dx < middle.dx), isTrue,
        reason: 'newest page comes first in reading order');
    expect(find.text('10月23日'), findsOneWidget);
    expect(find.text('10月22日'), findsOneWidget);

    for (final t in allTexts(tester)) {
      expect(_countText.hasMatch(t), isFalse, reason: 'count-like text: $t');
    }
    // 也不該有進度條或目標。
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  dbTestWidgets('favorite heart persists and the 只看愛心 filter uses it', (tester) async {
    await env.seed();
    final a = await addLesson(env, DateTime(2026, 10, 22, 20), '原來換個順序就順了。');
    await addLesson(env, DateTime(2026, 10, 23, 20), '原來先做最簡單的就接得下去。');
    await pumpScreen(tester, env, const NotebookScreen());
    await settle(tester);

    await tester.tap(find.byKey(ValueKey('fav-${a.id}')));
    await settle(tester);
    var stored = await db(tester, () => env.repo.watchLessons().first);
    expect(stored.firstWhere((l) => l.id == a.id).favorite, isTrue);
    expect(find.byIcon(Icons.favorite), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('notebook-favorites-only')));
    await settle(tester);
    expect(find.text('原來換個順序就順了。'), findsOneWidget);
    expect(find.text('原來先做最簡單的就接得下去。'), findsNothing);

    // 拿掉愛心 → 篩選後是空的，給一句友善的話。
    await tester.tap(find.byKey(ValueKey('fav-${a.id}')));
    await settle(tester);
    stored = await db(tester, () => env.repo.watchLessons().first);
    expect(stored.firstWhere((l) => l.id == a.id).favorite, isFalse);
    expect(find.text(NotebookCopy.emptyFavorites.lively), findsOneWidget);
  });

  dbTestWidgets('給家長看 is off by default, explained, and persists when the child turns it on', (tester) async {
    await env.seed();
    final a = await addLesson(env, DateTime(2026, 10, 23, 20), '原來吃完晚飯是開始的好時間。');
    await pumpScreen(tester, env, const NotebookScreen());
    await settle(tester);

    final sw = find.byKey(ValueKey('share-${a.id}'));
    expect(tester.widget<Switch>(sw).value, isFalse);
    expect(find.text(NotebookCopy.shareExplain.lively), findsOneWidget);
    expect((await db(tester, () => env.repo.parentView())).sharedLessons, isEmpty);

    await tester.tap(sw);
    await settle(tester);
    expect((await db(tester, () => env.repo.watchLessons().first)).single.sharedWithParent, isTrue);
    expect(tester.widget<Switch>(sw).value, isTrue);
    final pv = await db(tester, () => env.repo.parentView());
    expect(pv.sharedLessons.single.text, '原來吃完晚飯是開始的好時間。');

    await tester.tap(sw);
    await settle(tester);
    expect((await db(tester, () => env.repo.parentView())).sharedLessons, isEmpty);
  });

  test('formatNoteDate uses zh_TW month/day', () {
    expect(formatNoteDate('2026-10-23'), '10月23日');
    expect(formatNoteDate('2027-01-05'), '1月5日');
  });
}
