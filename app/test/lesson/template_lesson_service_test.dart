import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/lessons.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/lesson/template_lesson_service.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

const sampleTasks = ['寫數學作業', '練習樂器', '動一動身體', '整理書包整理書包整理書包整理書包整理'];
const sampleQuotes = [
  '先寫最討厭的',
  '我太累了所以先休息',
  '我先做了一半，剩下的明天',
  '洗完澡之後比較坐得住，然後我就寫完了，其實沒有想像中那麼難，下次我還要先洗澡再寫功課看看會不會一樣',
  '嗯',
  'abc',
];

void main() {
  late CopyRules rules;
  setUpAll(() => rules = loadCopyRules());

  TemplateLessonService service([int seed = 1]) => TemplateLessonService(rules: rules, random: Random(seed));

  LessonRequest req(Outcome o, {String? words, AgeTone tone = AgeTone.lively, String task = '寫數學作業'}) =>
      LessonRequest(outcomes: [o], tasks: [task], tone: tone, childWords: words);

  group('pools', () {
    test('three outcome pools are the same size (silent and quoted)', () {
      final pools = Outcome.values.map(LessonCopy.poolsFor).toList();
      expect(pools.map((p) => p.silent.length).toSet(), hasLength(1));
      expect(pools.map((p) => p.quoted.length).toSet(), hasLength(1));
      expect(pools.first.silent, isNotEmpty);
      expect(pools.first.quoted, isNotEmpty);
    });

    test('every notToday line is a "learned from the choice" line', () {
      for (final l in [...LessonCopy.notToday.silent, ...LessonCopy.notToday.quoted]) {
        expect(l.kind, LessonKind.choice, reason: l.line.lively);
      }
    });

    test('done / partly lines are about method or self-knowledge', () {
      for (final p in [LessonCopy.done, LessonCopy.partly]) {
        for (final l in [...p.silent, ...p.quoted]) {
          expect(l.kind, anyOf(LessonKind.method, LessonKind.selfKnowledge), reason: l.line.lively);
        }
      }
    });

    test('quoted lines contain {quote}; silent lines never do', () {
      for (final o in Outcome.values) {
        final p = LessonCopy.poolsFor(o);
        for (final l in p.quoted) {
          for (final t in AgeTone.values) {
            expect(l.line.of(t), contains('{quote}'));
          }
        }
        for (final l in p.silent) {
          for (final t in AgeTone.values) {
            expect(l.line.of(t), isNot(contains('{quote}')));
          }
        }
      }
    });

    test('plain day line', () {
      expect(LessonCopy.plainDay.kind, LessonKind.plainDay);
      expect(LessonCopy.plainDay.line.lively, '今天沒什麼特別要記的，就是普通的一天。這樣也不錯。');
    });

    test('every template line, both tones, filled with sample tasks/quotes, passes rules and ≤ max chars', () {
      final all = [
        for (final o in Outcome.values) ...[...LessonCopy.poolsFor(o).silent, ...LessonCopy.poolsFor(o).quoted],
        LessonCopy.plainDay,
      ];
      for (final l in all) {
        for (final tone in AgeTone.values) {
          // 原樣（佔位符換成最短的字）也要過。
          final bare = l.line.of(tone).replaceAll('{task}', '看書').replaceAll('{quote}', '先寫');
          expect(rules.check(bare, tone: tone, checkLength: true), isEmpty, reason: bare);
          for (final task in sampleTasks.take(3)) {
            final s = l.line.of(tone).replaceAll('{task}', task).replaceAll('{quote}', '先寫最討厭的');
            expect(rules.passesGenerated(s, tone), isTrue, reason: s);
          }
        }
      }
    });
  });

  group('learn', () {
    test('silent: one line per outcome and tone, from the right pool, passes rules', () async {
      for (final o in Outcome.values) {
        for (final tone in AgeTone.values) {
          for (var seed = 0; seed < 20; seed++) {
            final r = await service(seed).learn(req(o, tone: tone));
            expect(r.source, LessonSource.template);
            expect(r.sourceQuote, isNull);
            expect(rules.passesGenerated(r.text, tone), isTrue, reason: r.text);
            expect(r.text, isNot(contains('{')));
            if (o == Outcome.notToday) expect(r.kind, LessonKind.choice);
          }
        }
      }
    });

    test('child spoke: quote is a substring of the child words, sentence ≤ max chars', () async {
      for (final o in Outcome.values) {
        for (final tone in AgeTone.values) {
          for (final words in sampleQuotes) {
            for (var seed = 0; seed < 10; seed++) {
              final r = await service(seed).learn(req(o, words: words, tone: tone));
              expect(rules.passesGenerated(r.text, tone), isTrue, reason: r.text);
              expect(r.text.runes.length, lessThanOrEqualTo(AppConfig.maxBubuChars));
              if (r.sourceQuote != null) {
                expect(words.contains(r.sourceQuote!), isTrue, reason: '${r.sourceQuote} ⊄ $words');
                expect(r.sourceQuote!.runes.length, greaterThanOrEqualTo(TemplateLessonService.minQuoteChars));
              }
              if (o == Outcome.notToday) expect(r.kind, LessonKind.choice);
            }
          }
        }
      }
    });

    test('short child words are quoted whole', () async {
      final r = await service().learn(req(Outcome.done, words: '  先寫最討厭的。 '));
      expect(r.sourceQuote, '先寫最討厭的');
      expect(r.text, contains('先寫最討厭的'));
    });

    test('long child words are cut sensibly and still fit', () async {
      final long = sampleQuotes[3];
      final r = await service().learn(req(Outcome.partly, words: long));
      expect(r.sourceQuote, isNotNull);
      expect(long.contains(r.sourceQuote!), isTrue);
      expect(r.text.runes.length, lessThanOrEqualTo(AppConfig.maxBubuChars));
    });

    test('one huge word without punctuation is truncated with an ellipsis', () async {
      final huge = '我' * 200;
      final r = await service().learn(req(Outcome.done, words: huge));
      expect(r.sourceQuote, isNotNull);
      expect(huge.contains(r.sourceQuote!), isTrue);
      expect(r.text, contains('⋯'));
      expect(r.text.runes.length, lessThanOrEqualTo(AppConfig.maxBubuChars));
    });

    test('child words that break the copy rules are not quoted (falls back to a non-quote line)', () async {
      for (var seed = 0; seed < 10; seed++) {
        final r = await service(seed).learn(req(Outcome.done, words: '我覺得我好棒'));
        expect(r.sourceQuote, isNull);
        expect(r.text, isNot(contains('好棒')));
        expect(rules.passesGenerated(r.text, AgeTone.lively), isTrue);
      }
    });

    test('a task name that breaks the rules is never put in a sentence', () async {
      for (var seed = 0; seed < 20; seed++) {
        final r = await service(seed).learn(req(Outcome.done, task: '拿滿分'));
        expect(r.text, isNot(contains('滿分')));
      }
    });

    test('an overlong task name is skipped, never overflows', () async {
      for (var seed = 0; seed < 20; seed++) {
        final r = await service(seed).learn(req(Outcome.partly, task: '很長的事情' * 12));
        expect(r.text.runes.length, lessThanOrEqualTo(AppConfig.maxBubuChars));
      }
    });

    test('same seed → same output; different seeds give variety', () async {
      for (final o in Outcome.values) {
        final a = await service(42).learn(req(o, words: '我先休息一下'));
        final b = await service(42).learn(req(o, words: '我先休息一下'));
        expect(a.text, b.text);
        expect(a.kind, b.kind);
        expect(a.sourceQuote, b.sourceQuote);
      }
      final texts = {
        for (var seed = 0; seed < 30; seed++) (await service(seed).learn(req(Outcome.done))).text,
      };
      expect(texts.length, greaterThan(1));
    });

    test('multiple plans: the first plan drives; all-notToday still learns something (choice)', () async {
      final r = await service().learn(const LessonRequest(
        outcomes: [Outcome.notToday, Outcome.notToday, Outcome.notToday],
        tasks: ['寫數學作業', '看一本書', '練習樂器'],
        tone: AgeTone.concise,
      ));
      expect(r.kind, LessonKind.choice);
      expect(r.text, isNot(LessonCopy.plainDay.line.concise));

      final first = await service(3).learn(const LessonRequest(
        outcomes: [Outcome.notToday, Outcome.done],
        tasks: ['寫數學作業', '看一本書'],
        tone: AgeTone.lively,
      ));
      expect(first.kind, LessonKind.choice);
    });

    test('no plans → plain day; never throws on odd input', () async {
      final r = await service().learn(const LessonRequest(outcomes: [], tasks: [], tone: AgeTone.lively));
      expect(r.kind, LessonKind.plainDay);
      expect(r.text, LessonCopy.plainDay.line.lively);

      final odd = await service().learn(const LessonRequest(
        outcomes: [Outcome.done],
        tasks: [],
        tone: AgeTone.concise,
        childWords: '{quote}{task}',
      ));
      expect(odd.text, isNot(contains('{')));
      expect(rules.passesGenerated(odd.text, AgeTone.concise), isTrue);
    });
  });

  group('pickQuote', () {
    test('returns substrings only', () {
      for (final w in sampleQuotes) {
        for (final budget in [2, 5, 10, 30]) {
          final q = TemplateLessonService.pickQuote(w, budget);
          if (q == null) continue;
          expect(w.contains(q.quote), isTrue);
          expect(q.display.runes.length, lessThanOrEqualTo(budget));
        }
      }
    });

    test('too short → null', () {
      expect(TemplateLessonService.pickQuote('嗯', 20), isNull);
      expect(TemplateLessonService.pickQuote('   ', 20), isNull);
    });
  });
}
