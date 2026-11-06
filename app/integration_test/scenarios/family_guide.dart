// 情境：第二階段給大人的功能。
//
// - 話術轉譯器：選一個情境，看到「接住感受＋給選擇＋說理由」。
// - 家長微課程：這週那一則排第一、標出來；下週換下一則（只看日期）。
// - 全家一起：大人的「今天的我」出現在孩子首頁；留言由步步原封不動轉達，評價／催促的話擋下；
//   孩子可以「等一下」、可以在自己的設定裡關掉轉達；家長看不到已讀。
// - 月回顧的信：家長寫一句（擋下評價），孩子在「這個月的我」原封不動看到；孩子寫的家長也看得到。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/family.dart';
import 'package:little_steps/copy/parent_guide.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/parent/parent_guide.dart';
import 'package:little_steps/providers.dart';

import '../e2e/harness.dart';

void familyGuideScenarios() {
  testWidgets('talk helper: each situation shows feeling + choice + reason; weekly lesson rotates by date only',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 21, 0)); // 週三
    await app.openParent(firstTime: true);

    await app.tap('open-talk');
    expect(find.byType(ParentTalkScreen), findsOneWidget);
    for (final s in ParentGuideCopy.scripts) {
      await app.tap('talk-${s.id}');
      expect(app.has('talk-card-${s.id}'), isTrue, reason: s.id);
      for (final part in ['feeling', 'choice', 'reason']) {
        expect(app.has('talk-part-$part'), isTrue, reason: '${s.id}: $part');
      }
    }
    await app.back();

    final thisWeek = lessonFor(app.clock.now());
    expect(find.textContaining(thisWeek.title.concise), findsOneWidget, reason: 'entry names this week\'s lesson');
    await app.tap('open-lessons');
    expect(app.has('lesson-this-week'), isTrue);
    final top = tester.getTopLeft(find.byKey(ValueKey('lesson-${thisWeek.id}'))).dy;
    for (final l in ParentGuideCopy.lessons) {
      final f = find.byKey(ValueKey('lesson-${l.id}'));
      if (f.evaluate().isNotEmpty) expect(tester.getTopLeft(f).dy, greaterThanOrEqualTo(top));
    }
    await app.back();
    await app.lockParent();

    // 下週一再打開：換下一則（不管孩子這週做了什麼）。
    await app.resumeAt(DateTime(2026, 11, 9, 21, 0));
    final nextWeek = lessonFor(app.clock.now());
    expect(nextWeek.id, isNot(thisWeek.id));
    await app.openParent();
    expect(find.textContaining(nextWeek.title.concise), findsOneWidget);
    await app.lockParent();
    await app.close();
  });

  testWidgets('family: grown-ups\' "today" and a note relayed word for word; blocked words stay with the parent; '
      'the child can say "later" or turn relaying off', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 18, 0));
    await app.openParent(firstTime: true);
    expect(app.has('family-today-empty'), isTrue);

    // 媽媽今天自己想做的事。
    await app.tap('family-today-add');
    await app.tap('family-who-1');
    await app.enter('family-text-field', '散步二十分鐘');
    await app.tap('dialog-save');
    // 留話：評價、催促被擋下，留在對話框裡；改成描述看到的事才送出。
    await app.tap('family-note-add');
    await app.enter('family-who-field', '爸爸');
    for (final bad in ['你好棒', '明天要早點寫功課']) {
      await app.enter('family-text-field', bad);
      await app.tap('dialog-save');
      expect(app.has('family-blocked'), isTrue, reason: bad);
    }
    expect(await app.read((r) => r.familyNotes()), isEmpty);
    await app.enter('family-text-field', '我看到你今天自己把書包整理好了');
    await app.tap('dialog-save');
    expect(app.has('family-blocked'), isFalse);
    await app.lockParent();

    // 孩子的首頁：家人今天的事、步步問要不要看留話。
    expect(app.has('home-family-today'), isTrue);
    expect(find.text(FamilyCopy.homeItem.fill(AgeTone.lively, {'who': '媽媽', 'text': '散步二十分鐘'})), findsOneWidget);
    expect(app.has('home-family-note'), isTrue);
    // 打開：原封不動，步步不加評論；看過就不再轉達。
    await app.tap('family-note-open');
    expect(tester.widget<Text>(find.byKey(const ValueKey('family-note-text'))).data, '我看到你今天自己把書包整理好了');
    await app.tap('family-note-close');
    expect(app.has('home-family-note'), isFalse);

    // 家長那邊看不到「已讀」。
    await app.openParent();
    final note = (await app.read((r) => r.familyNotes())).single;
    expect(note.childRead, isTrue);
    expect(app.has('family-note-${note.id}'), isTrue);
    expect(find.textContaining('已讀'), findsNothing);
    expect(find.textContaining('看過'), findsNothing);
    // 再留一句。
    await app.tap('family-note-add');
    await app.enter('family-who-field', '阿嬤');
    await app.enter('family-text-field', '週末一起去公園');
    await app.tap('dialog-save');
    await app.lockParent();
    expect(app.has('home-family-note'), isTrue);
    // 等一下：這次先不看，什麼都不記。
    await app.tap('family-note-later');
    expect(app.has('home-family-note'), isFalse);
    expect((await app.read((r) => r.familyNotes())).where((n) => !n.childRead), hasLength(1));
    // 「等一下」只算這一次：去別的地方再回到首頁，步步會再問一次。
    await app.tap('nav-explore');
    await app.back();
    expect(app.has('home-family-note'), isTrue);

    // 孩子在自己的設定裡關掉轉達：留話不再出現（也沒有被標成已讀）。
    await app.tap('nav-settings');
    await app.tap('family-notes-switch');
    await app.back();
    expect(app.has('home-family-note'), isFalse);
    expect(app.container.read(unreadFamilyNotesProvider).value, isEmpty);
    expect((await app.read((r) => r.familyNotes())).where((n) => !n.childRead), hasLength(1));
    expect(app.has('home-family-today'), isTrue, reason: 'family "today" is not a message, it stays');
    await app.close();
  });

  testWidgets('month letters: the parent writes one sentence the child reads word for word; the child\'s reaches the parent',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 20, 0));
    // 孩子先在「這個月的我」寫一句給家人。
    await app.tap('nav-path');
    await app.tap('open-month');
    await app.enter('month-letter-field', '謝謝你們陪我練琴');
    await app.tap('month-letter-save');
    expect(app.has('month-letter-child'), isTrue);
    await app.back();
    await app.back();

    // 家長看到孩子那句，回一句；評價被擋。
    await app.openParent(firstTime: true);
    expect(app.has('parent-month-child'), isTrue);
    await app.tap('month-letter-write');
    await app.enter('letter-field', '你這個月好棒');
    await tester.tap(find.byKey(const ValueKey('letter-save')));
    await app.settle();
    expect(app.has('letter-blocked'), isTrue);
    await app.enter('letter-field', '我看到你常常自己先把書包準備好');
    await tester.tap(find.byKey(const ValueKey('letter-save')));
    await app.settle();
    expect(app.has('parent-month-parent'), isTrue);
    await app.lockParent();

    // 孩子打開這個月：家長那句原封不動。
    await app.tap('nav-path');
    await app.tap('open-month');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('month-letter-parent')),
        matching: find.text('我看到你常常自己先把書包準備好'),
      ),
      findsOneWidget,
    );
    // 孩子可以收回自己那句。
    await app.tap('month-letter-remove');
    expect(app.has('month-letter-child'), isFalse);
    expect((await app.read((r) => r.monthLetters())).map((l) => l.author), [LetterAuthor.parent]);
    await app.close();
  });
}
