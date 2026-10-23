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
      // F1：更寬的規則
      '我好想你喔',
      '我會一直等你',
      '你終於來了',
      '你好幾天沒來耶',
      '下次要記得來教我',
      '唉，你今天沒做',
      '我有點難過',
      '步步好傷心',
      '下次記得要做喔',
      '明天要做完',
      '你應該要早點開始',
      '別忘了寫功課',
      '原來你偷懶了',
      '超棒的方法',
      '真讚耶',
      '你很乖',
      '你好認真喔',
      '你很努力耶',
      '你很會想辦法',
      '你真會安排時間',
      '你做得真不錯',
      '這樣不錯',
      '三件事都做完了',
      '全部都完成了',
      // F2：正規化
      '好～棒',
      '好\u200b棒',
      '你好聪明',
      '你真厉害',
      '还有２件',
      '明天見！',
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
      // 「會」本身不是讚美；「你會先⋯」是描述過程。
      '你會先把書包整理好，再去玩。',
      '原來你會先寫數學。',
      // 孩子自己的感覺可以被重述；只有步步自己難過才擋。
      '你說做之前很難過，做完就還好。',
      '你說做得好累，所以先休息。',
      '不想錯過卡通，所以先寫完一半。',
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
    expect(l2, containsAll(['可惜', '明天再', '明天見', '很好', '下次要', '等你']));
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

  test('normalize: punctuation, symbols, zero-width and zhuyin go; width folds; simplified maps', () {
    expect(rules.normalize('好～棒！'), '好棒');
    expect(rules.normalize('好\u200b\u2060棒'), '好棒');
    expect(rules.normalize('还有２件'), '還有2件');
    expect(rules.normalize('好ㄅ棒'), '好棒');
  });

  test('length is counted on the original text, not the normalized one', () {
    final s = '${'步' * 55}${'！' * 10}';
    expect(rules.check(s, checkLength: true).map((v) => v.level), ['length']);
  });

  test('every simplifiedToTraditional value is used by a pattern; no pattern contains a key', () {
    final map = (json['simplifiedToTraditional'] as Map).cast<String, String>();
    final joined = allPatterns.join();
    expect(map, isNotEmpty);
    map.forEach((k, v) {
      expect(k.runes.length, 1, reason: k);
      expect(joined.contains(v), isTrue, reason: '$k→$v is not used by any pattern');
      expect(joined.contains(k), isFalse, reason: 'a pattern contains simplified $k and can never match');
    });
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
