// 再看一次口袋（M1）：孩子端的入口、記一張、翻一張、收好、刪、藏起來、分享。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/pocket.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/domain/pocket.dart';
import 'package:little_steps/features/pocket/pocket_widgets.dart';
import 'package:little_steps/providers.dart';
import 'package:little_steps/safety/safety_response.dart';

import '../../helpers/test_app.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settleAll(tester);
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> _pump(WidgetTester tester, TestEnv env, PocketAccess access) async {
  await pumpApp(tester, env, extra: [pocketAccessProvider.overrideWithValue(access)]);
  await settleAll(tester);
}

void main() {
  const lively = AgeTone.lively;

  testWidgets('without the add-on the child sees no pocket anywhere: no entry, no intro, no setting', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await _pump(tester, env, PocketAccess.none);
    expect(find.byKey(const ValueKey('nav-pocket')), findsNothing);
    expect(find.byKey(const ValueKey('home-pocket-intro')), findsNothing);
    await _tap(tester, 'nav-settings');
    expect(find.byKey(const ValueKey('pocket-visible-switch')), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('with the add-on Bubu introduces the pocket once; after that only the quiet entry stays', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await _pump(tester, env, PocketAccess.full);
    expect(find.byKey(const ValueKey('home-pocket-intro')), findsOneWidget);
    expect(find.text(PocketCopy.introBubu.of(lively)), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-pocket')), findsOneWidget);
    await _tap(tester, 'pocket-intro-later');
    expect(find.byKey(const ValueKey('home-pocket-intro')), findsNothing);
    expect((await tester.runAsync(env.repo.settings))!.pocketIntroduced, isTrue);
    expect(find.byKey(const ValueKey('nav-pocket')), findsOneWidget);
    await finishTest(tester, env);
  });

  testWidgets('the child puts a card in and sees it on the wall, with no count anywhere', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-pocket');
    expect(find.byKey(const ValueKey('pocket-empty')), findsOneWidget);
    await _tap(tester, 'pocket-add');

    // 沒有題目不能放（只提醒一句，不存）。
    await _tap(tester, 'pocket-save');
    expect(find.text(PocketCopy.needPrompt.of(lively)), findsOneWidget);
    expect((await tester.runAsync(env.repo.pocketCards))!, isEmpty);

    // 開一組新的。
    await _tap(tester, 'pocket-group-new');
    await tester.enterText(find.byKey(const ValueKey('pocket-group-name')), '數學小考');
    await _tap(tester, 'pocket-group-create');

    await _enter(tester, 'pocket-prompt', '3/4 + 1/8');
    await _tap(tester, 'pocket-subject-math');
    await _enter(tester, 'pocket-thought', '我把分母也加起來了');
    await _tap(tester, 'pocket-stuck-notYet');
    await _enter(tester, 'pocket-if', '看到分數加法');
    await _enter(tester, 'pocket-then', '先看分母一不一樣');
    await _tap(tester, 'pocket-save');

    final cards = (await tester.runAsync(env.repo.pocketCards))!;
    expect(cards, hasLength(1));
    final c = cards.single;
    expect(c.subject, PocketSubject.math);
    expect(c.stuck, PocketStuck.notYet);
    expect(c.groupId, isNotNull);
    expect(c.knowNow, isNull, reason: 'left blank on purpose; the child can come back to it');
    expect(find.byKey(ValueKey('pocket-tile-${c.id}')), findsOneWidget);
    expect(find.text('數學小考'), findsWidgets);
    // 牆上沒有任何數字（張數、進度）。題目本身的 3/4 + 1/8 除外。
    final digits = RegExp(r'\d');
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((s) => s != '3/4 + 1/8');
    expect(texts.where(digits.hasMatch), isEmpty);
    await finishTest(tester, env);
  });

  testWidgets('a worrying sentence goes to the safety path and the card is never saved', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-pocket');
    await _tap(tester, 'pocket-add');
    await _enter(tester, 'pocket-prompt', '考卷');
    await _enter(tester, 'pocket-thought', '我不想活了');
    await tester.ensureVisible(find.byKey(const ValueKey('pocket-save')));
    await tester.tap(find.byKey(const ValueKey('pocket-save')));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyResponseScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-close')));
    await settleAll(tester);
    expect((await tester.runAsync(env.repo.pocketCards))!, isEmpty);
    await finishTest(tester, env);
  });

  testWidgets('flipping a card: think first or flip now, then three equal buttons and one curious line',
      (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    final c = await env.repo.savePocketCard(const PocketCardDraft(
      subject: PocketSubject.math,
      prompt: '7×8',
      knowNow: '是五十六',
    ));
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-pocket');
    await _tap(tester, 'pocket-tile-${c.id}');

    expect(find.byKey(const ValueKey('pocket-front-prompt')), findsOneWidget);
    expect(find.byKey(const ValueKey('pocket-back')), findsNothing, reason: 'the back stays hidden until the child flips');
    expect(find.text(PocketCopy.frontAsk.of(lively)), findsOneWidget);
    await _tap(tester, 'pocket-think');
    expect(find.text(PocketCopy.thinking.of(lively)), findsOneWidget);
    await _tap(tester, 'pocket-flip');
    expect(find.byKey(const ValueKey('pocket-back')), findsOneWidget);
    expect(find.text('是五十六'), findsOneWidget);
    expect(find.text(PocketCopy.blank.of(lively)), findsWidgets, reason: 'empty boxes say so, without nagging');

    for (final f in PocketFeeling.values) {
      await _tap(tester, 'feeling-${f.name}');
      expect(find.text(PocketCopy.reply(f).of(lively)), findsOneWidget);
    }
    await finishTest(tester, env);
  });

  testWidgets('filing away, sharing and deleting are the child\'s own choices', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    final c = await env.repo.savePocketCard(const PocketCardDraft(prompt: '7×8'));
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-pocket');
    await _tap(tester, 'pocket-tile-${c.id}');

    await _tap(tester, 'pocket-file-away');
    expect((await tester.runAsync(() => env.repo.pocketCard(c.id)))!.filedAway, isTrue);
    await _tap(tester, 'pocket-share');
    expect((await tester.runAsync(() => env.repo.pocketCard(c.id)))!.sharedWithParent, isTrue);

    // 先留著：什麼都沒變。
    await _tap(tester, 'pocket-delete');
    expect(find.text(PocketCopy.deleteAsk.of(lively)), findsOneWidget);
    await _tap(tester, 'pocket-delete-no');
    expect((await tester.runAsync(env.repo.pocketCards))!, hasLength(1));
    await _tap(tester, 'pocket-delete');
    await _tap(tester, 'pocket-delete-yes');
    expect((await tester.runAsync(env.repo.pocketCards))!, isEmpty);
    await finishTest(tester, env);
  });

  testWidgets('read-only (trial over or refunded): cards stay readable, only "add" quietly goes away', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    final c = await env.repo.savePocketCard(const PocketCardDraft(prompt: '7×8'));
    await _pump(tester, env, PocketAccess.readOnly);
    expect(find.byKey(const ValueKey('home-pocket-intro')), findsNothing);
    await _tap(tester, 'nav-pocket');
    expect(find.byKey(const ValueKey('pocket-add')), findsNothing);
    expect(find.byKey(const ValueKey('pocket-draw')), findsOneWidget);
    await _tap(tester, 'pocket-tile-${c.id}');
    expect(find.byKey(const ValueKey('pocket-edit')), findsNothing);
    expect(find.byKey(const ValueKey('pocket-flip')), findsOneWidget);
    expect(find.byKey(const ValueKey('pocket-delete')), findsOneWidget);
    await finishTest(tester, env);
  });

  testWidgets('read-only with no cards: nothing to show, so no entry', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await _pump(tester, env, PocketAccess.readOnly);
    expect(find.byKey(const ValueKey('nav-pocket')), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('the child can hide the pocket in their own settings; cards stay', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    await env.repo.savePocketCard(const PocketCardDraft(prompt: '7×8'));
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-settings');
    await _tap(tester, 'pocket-visible-switch');
    expect((await tester.runAsync(env.repo.settings))!.pocketHidden, isTrue);
    await tester.tap(find.byType(BackButton));
    await settleAll(tester);
    expect(find.byKey(const ValueKey('nav-pocket')), findsNothing);
    expect((await tester.runAsync(env.repo.pocketCards))!, hasLength(1));
    await finishTest(tester, env);
  });

  testWidgets('when the chosen filter\'s chip goes away the wall falls back to all cards, not an empty wall',
      (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    await env.repo.savePocketCard(const PocketCardDraft(prompt: '還在口袋'));
    final filed = await env.repo.savePocketCard(const PocketCardDraft(prompt: '收好了'));
    await env.repo.setPocketFiledAway(filed.id, true);
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-pocket');
    await _tap(tester, 'pocket-filter-filed');
    await _tap(tester, 'pocket-tile-${filed.id}');
    await _tap(tester, 'pocket-file-away'); // 拿回口袋
    await tester.tap(find.byType(BackButton));
    await settleAll(tester);
    expect(find.byKey(const ValueKey('pocket-filter-filed')), findsNothing);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('pocket-filter-all'))).selected, isTrue);
    expect(find.text('還在口袋'), findsOneWidget);
    expect(find.text('收好了'), findsOneWidget);
    await finishTest(tester, env);
  });

  testWidgets('"draw one" opens one of the cards that are not filed away', (tester) async {
    _tall(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setPocketIntroduced();
    final keep = await env.repo.savePocketCard(const PocketCardDraft(prompt: '還在口袋'));
    final filed = await env.repo.savePocketCard(const PocketCardDraft(prompt: '收好了'));
    await env.repo.setPocketFiledAway(filed.id, true);
    await _pump(tester, env, PocketAccess.full);
    await _tap(tester, 'nav-pocket');
    await _tap(tester, 'pocket-draw');
    expect(find.text('還在口袋'), findsOneWidget);
    expect(find.text('收好了'), findsNothing);
    expect(keep.filedAway, isFalse);
    await finishTest(tester, env);
  });

  group('feeling buttons parity (rule 4)', () {
    testWidgets('three buttons have the same size, colour and text style; none is pre-selected', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Center(child: SizedBox(width: 400, child: FeelingButtons(onChanged: (_) {})))),
        ),
      ));
      await tester.pumpAndSettle();
      final sizes = [for (final f in PocketFeeling.values) tester.getSize(find.byKey(FeelingButtons.keyFor(f)))];
      expect(sizes.toSet(), hasLength(1));
      final materials = [
        for (final f in PocketFeeling.values)
          tester.widget<Material>(find.descendant(of: find.byKey(FeelingButtons.keyFor(f)), matching: find.byType(Material)).first),
      ];
      expect(materials.map((m) => m.color).toSet(), hasLength(1));
      expect(materials.map((m) => (m.shape! as RoundedRectangleBorder).side.color).toSet(), {Colors.transparent});
      final styles = [
        for (final f in PocketFeeling.values)
          tester.widget<Text>(find.descendant(of: find.byKey(FeelingButtons.keyFor(f)), matching: find.byType(Text))).style,
      ];
      expect(styles.toSet(), hasLength(1));
    });
  });
}
