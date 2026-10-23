// 稽核後改過的句子（docs/decisions.md F5、F6）不要再漂回去。
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/lessons.dart';
import 'package:little_steps/copy/line.dart';
import 'package:little_steps/copy/parent.dart';
import 'package:little_steps/copy/plan.dart';
import 'package:little_steps/copy/review.dart';
import 'package:little_steps/domain/models.dart';

List<String> both(Line l) => [l.lively, l.concise];

void main() {
  group('notToday responses: plain curiosity, no "problem" framing (底線 4)', () {
    final lines = ReviewCopy.notTodayResponses.lines.expand(both).toList();

    test('same pool size as done and partly', () {
      expect(ReviewCopy.notTodayResponses.length, ReviewCopy.doneResponses.length);
      expect(ReviewCopy.notTodayResponses.length, ReviewCopy.partlyResponses.length);
    });

    for (final s in lines) {
      test('「$s」', () {
        for (final w in ['問題', '沒做就', '難', '為什麼沒', '原因', '怪']) {
          expect(s.contains(w), isFalse, reason: 'contains $w');
        }
        expect(s.contains('？'), isTrue, reason: 'should be a curious question');
      });
    }
  });

  test('chooseAsk does not label wanting more as 貪心', () {
    for (final s in both(PlanCopy.chooseAsk)) {
      expect(s.contains('貪心'), isFalse, reason: s);
    }
  });

  test('moodHappyReply does not rate the mood', () {
    for (final s in both(PlanCopy.moodHappyReply)) {
      expect(s.contains('不錯'), isFalse, reason: s);
    }
  });

  test('plainDay has no closing judgement', () {
    expect(LessonCopy.plainDay.line.lively, LessonCopy.plainDay.line.concise);
    expect(LessonCopy.plainDay.line.of(AgeTone.lively).contains('不錯'), isFalse);
  });

  test('the ending is a goodbye that does not presume tomorrow', () {
    for (final s in both(ReviewCopy.ending)) {
      expect(s.contains('明天'), isFalse, reason: s);
      expect(s.contains('掰掰'), isTrue, reason: s);
    }
  });

  test('the LLM switch does not promise what the provider does (decisions A3 is pending)', () {
    final s = ParentCopy.llmOn.lively;
    expect(s.contains('供應商不保留'), isFalse);
    expect(s.contains('不拿去訓練'), isFalse);
    expect(s.contains('確認中'), isTrue);
    expect(s.contains('伺服器'), isTrue);
    expect(ParentCopy.llmDevOnly.lively.contains('模擬環境'), isTrue);
  });
}
