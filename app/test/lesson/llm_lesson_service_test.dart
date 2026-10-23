import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/safety.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/lesson/llm_lesson_service.dart';
import 'package:little_steps/domain/lesson/template_lesson_service.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

/// 依序回傳 [responses]（用完就重複最後一個）；元素可以是 Map、Exception 或 Future。
class FakeClient implements LessonLlmClient {
  FakeClient(this.responses);
  final List<Object> responses;
  final payloads = <Map<String, Object?>>[];

  int get calls => payloads.length;

  @override
  Future<Map<String, Object?>> bubuLearn(Map<String, Object?> payload) async {
    payloads.add(payload);
    final r = responses[min(payloads.length - 1, responses.length - 1)];
    if (r is Exception) throw r;
    if (r is Future<Map<String, Object?>>) return r;
    return r as Map<String, Object?>;
  }
}

const words = '我先寫最討厭的，然後就比較輕鬆';
const goodLearned = '你說先寫最討厭的，我以前都想說要照順序耶。';
Map<String, Object?> good({String learned = goodLearned, String quote = '先寫最討厭的', String? kind = 'method'}) =>
    {'learned': learned, 'source_quote': quote, 'kind': ?kind};

void main() {
  late CopyRules rules;
  setUpAll(() => rules = loadCopyRules());

  LlmLessonService service(LessonLlmClient client, {Duration? timeout, bool detector = true}) => LlmLessonService(
        client: client,
        fallback: TemplateLessonService(rules: rules, random: Random(1)),
        rules: rules,
        crisisDetector: detector ? loadCrisisDetector() : null,
        timeout: timeout ?? AppConfig.llmTimeout,
      );

  LessonRequest req({String? childWords = words, Outcome outcome = Outcome.done, AgeTone tone = AgeTone.lively}) =>
      LessonRequest(
        outcomes: [outcome, Outcome.notToday],
        tasks: const ['寫數學作業', '看一本書'],
        tone: tone,
        childWords: childWords,
      );

  test('valid output is accepted: source llm, sourceQuote kept', () async {
    final c = FakeClient([good()]);
    final r = await service(c).learn(req());
    expect(c.calls, 1);
    expect(r.source, LessonSource.llm);
    expect(r.text, goodLearned);
    expect(r.sourceQuote, '先寫最討厭的');
    expect(r.kind, LessonKind.method);
  });

  test('missing / unknown kind defaults to selfKnowledge', () async {
    final r = await service(FakeClient([good(kind: null)])).learn(req());
    expect(r.source, LessonSource.llm);
    expect(r.kind, LessonKind.selfKnowledge);
  });

  test('payload has exactly {childWords, task, outcome, tone}, minimal content', () async {
    final c = FakeClient([good()]);
    await service(c).learn(req(childWords: '  $words  ', tone: AgeTone.concise));
    final p = c.payloads.single;
    expect(p.keys.toSet(), {'childWords', 'task', 'outcome', 'tone'});
    expect(p, {
      'childWords': words,
      'task': '寫數學作業',
      'outcome': 'done',
      'tone': 'concise',
    });
  });

  group('no LLM call', () {
    test('childWords null → client never called, template result', () async {
      final c = FakeClient([good()]);
      final r = await service(c).learn(req(childWords: null));
      expect(c.calls, 0);
      expect(r.source, LessonSource.template);
    });

    test('blank / too short childWords → client never called', () async {
      for (final w in ['', '   ', '嗯']) {
        final c = FakeClient([good()]);
        final r = await service(c).learn(req(childWords: w));
        expect(c.calls, 0, reason: w);
        expect(r.source, LessonSource.template);
      }
    });

    test('crisis words (defensive) → client never called, template result', () async {
      final c = FakeClient([good()]);
      final r = await service(c).learn(req(childWords: '我 好 想 死'));
      expect(c.calls, 0);
      expect(r.source, LessonSource.template);
    });

    test('no plans → client never called', () async {
      final c = FakeClient([good()]);
      final r = await service(c).learn(const LessonRequest(outcomes: [], tasks: [], tone: AgeTone.lively, childWords: words));
      expect(c.calls, 0);
      expect(r.kind, LessonKind.plainDay);
    });
  });

  group('validation → retry → fallback', () {
    final attempts = 1 + AppConfig.llmMaxRetries;

    Future<void> expectFallback(Map<String, Object?> bad, {AgeTone tone = AgeTone.lively}) async {
      final c = FakeClient([bad]);
      final r = await service(c).learn(req(tone: tone));
      expect(c.calls, attempts, reason: '$bad');
      expect(r.source, LessonSource.template, reason: '$bad');
      expect(rules.passesGenerated(r.text, tone), isTrue);
    }

    test('fabricated source_quote → retries then template', () => expectFallback(good(quote: '我最喜歡數學')));
    test('empty source_quote → template', () => expectFallback(good(quote: '  ')));
    test('missing source_quote → template', () => expectFallback({'learned': goodLearned}));
    test('empty learned → template', () => expectFallback(good(learned: ' ')));
    test('non-string learned → template', () => expectFallback({'learned': 3, 'source_quote': '先寫最討厭的'}));
    test('praise ("你好棒") → template', () => expectFallback(good(learned: '你好棒！先寫最討厭的真是好方法。')));
    test('L2 ("沒關係") → template', () => expectFallback(good(learned: '沒關係，先寫最討厭的也可以。')));
    test('concise childish word → template', () =>
        expectFallback(good(learned: '小朋友，你說先寫最討厭的。'), tone: AgeTone.concise));
    test('> 60 chars → template', () => expectFallback(good(learned: '你說先寫最討厭的，${'我記下來了' * 12}')));
    test('crisis words in learned → template', () => expectFallback(good(learned: '你說先寫最討厭的，不然會想死。')));
    test('exception every time → template', () async {
      final c = FakeClient([Exception('network')]);
      final r = await service(c).learn(req());
      expect(c.calls, attempts);
      expect(r.source, LessonSource.template);
    });

    test('bad then good → accepted on retry', () async {
      final c = FakeClient([good(quote: '編造的'), Exception('flaky'), good()]);
      final r = await service(c).learn(req());
      expect(c.calls, 3);
      expect(r.source, LessonSource.llm);
      expect(r.sourceQuote, '先寫最討厭的');
    });
  });

  group('server flags', () {
    test('{fallback: true} → template immediately, no retry', () async {
      final c = FakeClient([
        {'fallback': true},
        good(),
      ]);
      final r = await service(c).learn(req());
      expect(c.calls, 1);
      expect(r.source, LessonSource.template);
    });

    test('{safety: true} → safety result with pre-written copy', () async {
      for (final tone in AgeTone.values) {
        final c = FakeClient([
          {'safety': true},
        ]);
        final r = await service(c).learn(req(tone: tone));
        expect(c.calls, 1);
        expect(r.source, LessonSource.safety);
        expect(r.text, SafetyCopy.lessonSafety.of(tone));
        expect(r.sourceQuote, isNull);
      }
    });

    test('kind plainDay → our own plain day line, not the model text', () async {
      final c = FakeClient([
        {'learned': '隨便說說', 'source_quote': '', 'kind': 'plainDay'},
      ]);
      final r = await service(c).learn(req());
      expect(c.calls, 1);
      expect(r.kind, LessonKind.plainDay);
      expect(r.text, TemplateLessonService.plainDay(AgeTone.lively).text);
    });
  });

  group('timeout', () {
    test('slow client beyond the timeout → template', () async {
      final never = Completer<Map<String, Object?>>();
      final c = FakeClient([never.future]);
      final sw = Stopwatch()..start();
      final r = await service(c, timeout: const Duration(milliseconds: 80)).learn(req());
      expect(r.source, LessonSource.template);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('timeout is shared across all attempts', () async {
      // 每次 50ms、回應都不合格；總時限 120ms → 第三次還沒回來就退回範本，而且不會再打第四次。
      final c = _SlowBadClient(const Duration(milliseconds: 50));
      final r = await service(c, timeout: const Duration(milliseconds: 120)).learn(req());
      expect(r.source, LessonSource.template);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(c.calls, lessThanOrEqualTo(3));
    });

    test('default timeout is AppConfig.llmTimeout', () {
      final s = service(FakeClient([good()]));
      expect(s.timeout, AppConfig.llmTimeout);
      expect(s.maxRetries, AppConfig.llmMaxRetries);
    });
  });

  test('never throws even if the fallback throws', () async {
    final s = LlmLessonService(
      client: FakeClient([Exception('x')]),
      fallback: _ThrowingService(),
      rules: rules,
    );
    final r = await s.learn(req());
    expect(r.kind, LessonKind.plainDay);
  });
}

class _SlowBadClient implements LessonLlmClient {
  _SlowBadClient(this.delay);
  final Duration delay;
  int calls = 0;

  @override
  Future<Map<String, Object?>> bubuLearn(Map<String, Object?> payload) async {
    calls++;
    await Future<void>.delayed(delay);
    return {'learned': '你好棒', 'source_quote': '先寫'};
  }
}

class _ThrowingService implements LessonService {
  @override
  Future<LessonResult> learn(LessonRequest request) => throw StateError('boom');
}
