// 底線 7：家長端只能看到 ParentView，而 ParentView 只有範本、設定、孩子主動分享的筆記。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/domain/pocket.dart';

import '../helpers/test_app.dart';

/// ParentView.toJson() 允許出現的全部 key（任何深度）。要加欄位先過底線 7。
const allowedKeys = {
  // ParentView
  'taskTemplates', 'cueTemplates', 'settings', 'sharedLessons',
  // TaskTemplate / CueTemplate
  'id', 'emoji', 'text', 'origin', 'sortOrder',
  // ParentSettingsView
  'tone', 'llmEnabled', 'reminderSlots',
  // ReminderSlot
  'label', 'startMinute', 'endMinute',
  // SharedLesson
  'dayKey',
  // 全家一起（I2）：家長自己寫的「今天的我」與留言
  'familyToday', 'familyNotes', 'who',
  // 月回顧的信（J4）：孩子自己寫給家人的一句、家人寫給孩子的一句
  'monthLetters', 'month', 'child', 'parent',
  // 再看一次口袋（M1）：孩子按了「給家長看」的那幾張卡，整張照原樣（不帶收好沒、日期）
  'sharedPocketCards', 'subject', 'prompt', 'photo', 'thought', 'stuck', 'knowNow', 'ifCue', 'thenAction',
};

const forbiddenKeyFragments = [
  'outcome', 'reflection', 'mood', 'completion', 'rate', 'usage', 'duration', 'streak', 'lastopen', 'last_open',
  'pin', 'why', 'favorite', 'quote', 'kind', 'source', 'createdat', 'endedat', 'plan', 'cue_', 'task_',
  // 沒有已讀回條、看不到孩子有沒有關掉轉達（§4.11、I2）。
  'read', 'seen', 'opened', 'familynoteson',
  // 口袋：看不到孩子翻完按了什麼、收好了沒、藏起來沒（M1）。
  'feeling', 'filed', 'hidden',
];

Set<String> collectKeys(Object? json) {
  final out = <String>{};
  void walk(Object? v) {
    if (v is Map) {
      for (final e in v.entries) {
        out.add(e.key as String);
        walk(e.value);
      }
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  walk(json);
  return out;
}

void main() {
  late TestEnv env;
  setUp(() async {
    env = TestEnv();
    await env.seed();
  });
  tearDown(() => env.dispose());

  const childTask = '幫小烏龜換水的祕密任務';
  const childCue = '我看完卡通奇奇怪怪';
  const why = '因為烏龜很可愛的理由';
  const reflection = '其實我今天偷偷先玩了遊戲才寫';
  const unsharedLesson = '這是孩子沒有分享的私人筆記內容';
  const sharedLesson = '原來先整理桌子再寫會比較快。';
  const unsharedPocket = '孩子沒分享的口袋題目七乘八';
  const sharedPocket = '分數加法要先通分';

  Future<Map<String, Object?>> buildParentJson() async {
    await env.repo.addTaskTemplate(emoji: '🐢', text: childTask, origin: TemplateOrigin.child);
    await env.repo.addCueTemplate(text: childCue, origin: TemplateOrigin.child);
    await env.repo.addTaskTemplate(emoji: '🧺', text: '家長建議的事', origin: TemplateOrigin.parent);
    await env.repo.setParentPin('4826');

    final day = dayKeyOf(env.clock.now());
    final plans = await env.repo.savePlans(day, [
      PlanDraft(emoji: '🐢', task: childTask, cue: childCue, why: why),
      const PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡'),
      const PlanDraft(emoji: '🎹', task: '練習樂器', cue: '我吃完晚飯'),
    ]);
    await env.repo.setOutcome(plans[0].id, Outcome.done);
    await env.repo.setOutcome(plans[1].id, Outcome.partly);
    await env.repo.setOutcome(plans[2].id, Outcome.notToday);
    await env.repo.saveReflection(day, reflection);
    await env.repo.endDay(day);

    // 前一天：沒分享的筆記。
    await env.repo.saveLesson(
      '2026-10-22',
      const LessonResult(text: unsharedLesson, kind: LessonKind.method, source: LessonSource.template),
    );
    // 今天：孩子主動分享的筆記。
    final shared = await env.repo.saveLesson(
      day,
      const LessonResult(
        text: sharedLesson,
        kind: LessonKind.method,
        source: LessonSource.llm,
        sourceQuote: '先整理桌子',
      ),
    );
    await env.repo.setSharedWithParent(shared!.id, true);

    // 全家一起：家長寫了「今天的我」和兩則留言；孩子看過其中一則，也關掉了轉達。
    await env.repo.saveFamilyToday(day, who: '媽媽', text: '散步二十分鐘');
    final read = await env.repo.addFamilyNote(who: '爸爸', text: '我看到你自己把書包整理好了');
    await env.repo.addFamilyNote(who: '媽媽', text: '今天的晚餐有你喜歡的湯');
    await env.repo.markFamilyNoteRead(read.id);
    await env.repo.setFamilyNotesOn(false);

    // 月回顧：這個月孩子寫了一句給家人；上個月只有家長寫。
    await env.repo.saveMonthLetter('2026-10', LetterAuthor.child, '謝謝你們陪我');
    await env.repo.saveMonthLetter('2026-09', LetterAuthor.parent, '我看到你自己整理書包');

    // 再看一次口袋（M1）：一張沒分享（還收好了），一張分享了；孩子也把口袋藏起來了。
    final hidden = await env.repo.savePocketCard(
      const PocketCardDraft(subject: PocketSubject.math, prompt: unsharedPocket, thought: '我以為是五十四'),
    );
    await env.repo.setPocketFiledAway(hidden.id, true);
    final open = await env.repo.savePocketCard(const PocketCardDraft(
      subject: PocketSubject.math,
      prompt: sharedPocket,
      stuck: PocketStuck.notYet,
      knowNow: '分母要一樣才能加',
      ifCue: '看到分數加法',
      thenAction: '先看分母',
    ));
    await env.repo.setPocketShared(open.id, true);
    await env.repo.setPocketHidden(true);

    final view = await env.repo.parentView();
    // 走一次 JSON 編碼，確保拿到的是真的會被序列化的東西。
    return jsonDecode(jsonEncode(view.toJson())) as Map<String, Object?>;
  }

  test('keys are a subset of the whitelist', () async {
    final keys = collectKeys(await buildParentJson());
    expect(keys.difference(allowedKeys), isEmpty, reason: 'unexpected keys in ParentView');
  });

  test('no outcome / reflection / mood / usage / streak keys at any depth', () async {
    final keys = collectKeys(await buildParentJson());
    for (final k in keys) {
      for (final bad in forbiddenKeyFragments) {
        // 'sortOrder' 不含任何片段；'rate' 只會出現在 completionRate 之類。
        expect(k.toLowerCase().contains(bad), isFalse, reason: 'key "$k" contains "$bad"');
      }
    }
  });

  test('private content never appears in the serialized view', () async {
    final s = jsonEncode(await buildParentJson());
    for (final secret in [reflection, unsharedLesson, why, childTask, childCue, '先整理桌子"', '4826', unsharedPocket, '我以為是五十四']) {
      expect(s.contains(secret), isFalse, reason: 'ParentView leaks "$secret"');
    }
    for (final o in Outcome.values) {
      expect(s.contains('"${o.name}"'), isFalse, reason: 'ParentView leaks outcome ${o.name}');
    }
  });

  test('shared lessons are visible (the child chose to share)', () async {
    final j = await buildParentJson();
    final shared = (j['sharedLessons'] as List).cast<Map<String, Object?>>();
    expect(shared, hasLength(1));
    expect(shared.single['text'], sharedLesson);
  });

  test('only the pocket cards the child shared are visible, as the whole card but without filed-away or dates', () async {
    final j = await buildParentJson();
    final cards = (j['sharedPocketCards'] as List).cast<Map<String, Object?>>();
    expect(cards, hasLength(1));
    expect(cards.single, {
      'id': isA<String>(),
      'subject': 'math',
      'prompt': sharedPocket,
      'stuck': 'notYet',
      'knowNow': '分母要一樣才能加',
      'ifCue': '看到分數加法',
      'thenAction': '先看分母',
    });
    expect(j['settings'], isNot(contains('pocketHidden')));
  });

  test('family entries are visible to the parent, without any "child read it" or "child turned it off" signal',
      () async {
    final j = await buildParentJson();
    expect((j['familyToday'] as List).single, containsPair('text', '散步二十分鐘'));
    final notes = (j['familyNotes'] as List).cast<Map<String, Object?>>();
    expect(notes, hasLength(2));
    for (final n in notes) {
      expect(n.keys.toSet(), {'id', 'dayKey', 'who', 'text'});
    }
    expect(j['settings'], isNot(contains('familyNotesOn')));
  });

  // 匯出是家長在家長區按的，所以匯出檔也不能變成已讀回條（決策 I2）。
  test('the export file carries no "child read it" or "child turned it off" signal either', () async {
    await buildParentJson();
    final j = jsonDecode(await env.repo.exportJson()) as Map<String, Object?>;
    // 連名字換了的欄位也不行：留言裡沒有任何已讀之類的欄位，設定裡沒有任何跟留言有關的開關。
    final noteKeys = collectKeys(j['familyNotes']).map((k) => k.toLowerCase());
    for (final fragment in ['read', 'seen', 'opened']) {
      expect(noteKeys.where((k) => k.contains(fragment)), isEmpty, reason: 'family notes carry "$fragment"');
    }
    final settingKeys = collectKeys(j['settings']).map((k) => k.toLowerCase());
    expect(settingKeys.where((k) => k.contains('note')), isEmpty, reason: 'settings say whether notes are relayed');
    final notes = (j['familyNotes']! as List).cast<Map<String, Object?>>();
    expect(notes.map((n) => n['text']), containsAll(['我看到你自己把書包整理好了', '今天的晚餐有你喜歡的湯']),
        reason: 'the notes themselves are still exported in full');
  });

  test('month letters: the child\'s sentence only when the child wrote one; no story numbers', () async {
    final j = await buildParentJson();
    final letters = (j['monthLetters'] as List).cast<Map<String, Object?>>();
    expect(letters, [
      {'month': '2026-10', 'child': '謝謝你們陪我'},
      {'month': '2026-09', 'parent': '我看到你自己整理書包'},
    ]);
  });

  test('child-origin templates are not included', () async {
    final j = await buildParentJson();
    for (final listKey in ['taskTemplates', 'cueTemplates']) {
      final list = (j[listKey] as List).cast<Map<String, Object?>>();
      expect(list, isNotEmpty);
      expect(list.map((t) => t['origin']), isNot(contains(TemplateOrigin.child.name)), reason: listKey);
    }
    final texts = [for (final t in (j['taskTemplates'] as List).cast<Map<String, Object?>>()) t['text']];
    expect(texts, contains('家長建議的事'));
  });
}
