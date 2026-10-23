// 底線 5、1、2、3：shared/copy_rules.json 本身的測試（App 執行期過濾 LLM 輸出也用這份）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

void main() {
  late CopyRules rules;
  setUpAll(() => rules = loadCopyRules());

  final json = jsonDecode(File('assets/copy_rules.json').readAsStringSync()) as Map<String, Object?>;
  final allPatterns = <String>[
    for (final g in (json['l1'] as List).cast<Map<String, Object?>>()) ...(g['patterns'] as List).cast<String>(),
    ...((json['l2'] as Map<String, Object?>)['patterns'] as List).cast<String>(),
    ...((json['concise'] as Map<String, Object?>)['patterns'] as List).cast<String>(),
  ];

  test('every pattern compiles and is JS-compatible', () {
    expect(allPatterns, isNotEmpty);
    for (final pattern in allPatterns) {
      // Dart 的 RegExp 是 lazy 編譯，要真的跑一次才會丟錯。
      expect(() => RegExp(pattern).hasMatch('測試'), returnsNormally, reason: pattern);
      expect(pattern.contains('(?<'), isFalse, reason: 'no lookbehind / named groups (JS compat): $pattern');
      expect(RegExp(pattern).hasMatch(''), isFalse, reason: 'pattern matches empty string: $pattern');
    }
  });

  test('every L1 group has an id, a why and patterns', () {
    for (final g in (json['l1'] as List).cast<Map<String, Object?>>()) {
      expect(g['id'], isA<String>());
      expect(g['why'], isA<String>());
      expect((g['patterns'] as List), isNotEmpty, reason: '${g['id']}');
    }
  });

  group('generated text: rejected', () {
    const bad = [
      '你好聰明！',
      '你真是天才',
      '好棒喔，你做到了',
      '你好厲害',
      '你今天全部完成了',
      '繼續保持！',
      '加油！',
      '還有 2 件沒做喔',
      '還有兩項',
      '你已經連續三天了',
      '再做一件就解鎖新帽子',
      '你得到 3 個金幣',
      '步步等你好久了',
      '你好久沒來了',
      '不要走嘛',
      '步步生病了',
      '步步好餓',
      '你比別人快',
      '快來做計畫',
      '你一定要做完',
    ];
    for (final s in bad) {
      test(s, () {
        expect(rules.passesGenerated(s, AgeTone.lively), isFalse);
        expect(rules.passesGenerated(s, AgeTone.concise), isFalse);
      });
    }

    test('whitespace does not sneak words past the filter', () {
      expect(rules.passesGenerated('你好 聰 明', AgeTone.lively), isFalse);
      expect(rules.passesGenerated('加\n油', AgeTone.lively), isFalse);
    });
  });

  group('generated text: process praise passes', () {
    const good = [
      '原來先寫最難的那題，後面就比較輕鬆。',
      '你先把書包整理好才去玩，步步記下來了。',
      '累的時候先休息一下，也是一種選擇。',
      '你說你邊聽音樂邊寫，步步也想試試看。',
      '今天你自己決定不做，步步學到可以先停下來。',
      '你試了兩種方法，步步看到你一直在找辦法。',
      '吃完晚飯就去練琴，這個順序你自己想的。',
      '原來心裡有點緊張的時候，深呼吸會有幫助。',
    ];
    for (final s in good) {
      test(s, () {
        expect(rules.check(s, tone: AgeTone.concise, checkLength: true), isEmpty);
        expect(rules.passesGenerated(s, AgeTone.lively), isTrue);
        expect(rules.passesGenerated(s, AgeTone.concise), isTrue);
      });
    }
  });

  test('L2 is always rejected for generated text', () {
    final l2 = ((json['l2'] as Map<String, Object?>)['patterns'] as List).cast<String>();
    expect(l2, containsAll(['沒關係', '可惜', '明天再', '很好']));
    for (final w in l2) {
      final s = '步步覺得$w。';
      expect(rules.passesGenerated(s, AgeTone.lively), isFalse, reason: s);
      expect(rules.passesGenerated(s, AgeTone.concise), isFalse, reason: s);
    }
  });

  test('allowL2 only lifts the named word, only for static copy', () {
    expect(rules.check('沒關係', allowL2: {'沒關係'}), isEmpty);
    expect(rules.check('沒關係，很好', allowL2: {'沒關係'}), hasLength(1));
  });

  test('concise-only words', () {
    for (final s in ['小朋友你好', '寶貝你回來了', '好乖']) {
      expect(rules.passesGenerated(s, AgeTone.concise), isFalse, reason: s);
    }
    expect(rules.passesGenerated('小朋友你好', AgeTone.lively), isTrue);
  });

  test('longer than maxChars is rejected', () {
    expect(rules.maxChars, 60);
    final ok = '步' * rules.maxChars;
    final tooLong = '步' * (rules.maxChars + 1);
    expect(rules.passesGenerated(ok, AgeTone.lively), isTrue);
    expect(rules.passesGenerated(tooLong, AgeTone.lively), isFalse);
    expect(rules.passesGenerated(tooLong, AgeTone.concise), isFalse);
  });

  test('empty generated text is rejected', () {
    expect(rules.passesGenerated('', AgeTone.lively), isFalse);
    expect(rules.passesGenerated('   ', AgeTone.concise), isFalse);
  });
}
