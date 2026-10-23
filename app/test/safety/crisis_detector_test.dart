import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/safety/crisis_detector.dart';

import '../helpers/test_app.dart';

void main() {
  late CrisisDetector detector;
  setUpAll(() => detector = loadCrisisDetector());

  const examples = <CrisisCategory, List<String>>{
    CrisisCategory.selfHarm: [
      '我好想死',
      '我 好 想 死',
      '想、死',
      '想。死。',
      '不想　活了', // 全形空白
      '我想😢死',
      '自​殺', // 零寬空白
      '我想 傷害 自己！！！',
      '活著，好累…',
      '我想消失⋯⋯',
      '想-死',
      '想（死）',
    ],
    CrisisCategory.abuse: [
      '爸爸會 打 我',
      '我被，揍了',
      '他 摸 我 的 身 體',
      '這是秘密，不能 跟別人說',
      '被 打 了',
      '叔叔叫我、脫衣服',
      '我在學校被欺負',
      '他們用皮帶！',
      '被 關 在 廁所',
    ],
    CrisisCategory.severeDistress: [
      '沒有人 愛我',
      '大家…都討厭我',
      '我好～絕望',
      '我 每天都在哭',
      '好害怕回家。',
      '我是，廢物',
      '撐 不 下 去 了',
    ],
  };

  group('detects each category even with spaces / punctuation / emoji inserted', () {
    examples.forEach((cat, list) {
      for (final text in list) {
        test('$cat ← 「$text」', () => expect(detector.detect(text), cat));
      }
    });
  });

  group('false positives are not detected', () {
    for (final text in [
      '被打擾',
      '我今天一直被打擾，所以寫比較慢',
      '把電視關起來',
      '我把電視關起來再寫作業',
      '我們去打球',
      '被打針好痛',
      '先寫最討厭的',
      '我很開心',
      '洗完澡比較坐得住',
      '我太累了所以先休息',
      '',
      '   ',
    ]) {
      test('「$text」', () => expect(detector.detect(text), isNull));
    }
  });

  test('null input → null', () => expect(detector.detect(null), isNull));

  test('self-harm takes priority when several categories match', () {
    expect(detector.detect('他打我，我好想死'), CrisisCategory.selfHarm);
  });

  group('normalize (same as functions/src/crisis.ts normalizeForCrisis)', () {
    test('full-width ASCII → half-width, lower-case, no whitespace/punct', () {
      expect(detector.normalize('ＡＢＣ　１２３！'), 'abc123');
      expect(detector.normalize('Hello, World.'), 'helloworld');
      expect(detector.normalize('Ａ，Ｂ！ c'), 'abc');
    });

    test('strips CJK punctuation, emoji, zero-width, tone marks and zhuyin letters', () {
      expect(detector.normalize('想、死。「」『』（）～…⋯'), '想死');
      expect(detector.normalize('想😢​‍死️'), '想死');
      expect(detector.normalize('ㄒㄧㄤˇ'), '');
      expect(detector.normalize('想ㄚ死'), '想死');
    });

    test('the keep-zhuyin form keeps zhuyin letters but drops tone marks', () {
      expect(detector.normalizeKeepingZhuyin('我想ㄙˇ！'), '我想ㄙ');
      expect(detector.normalizeKeepingZhuyin('ㄒㄧㄤˇ'), 'ㄒㄧㄤ');
    });

    test('simplified characters used by the patterns are mapped to traditional', () {
      expect(detector.normalize('我想自杀'), '我想自殺');
      expect(detector.normalize('没人爱我'), '沒人愛我');
    });
  });

  group('zhuyin standing in for a character is still detected (F4)', () {
    const cases = {
      '我想ㄙˇ': CrisisCategory.selfHarm,
      '我想ㄙ': CrisisCategory.selfHarm,
      '想去ㄙ。': CrisisCategory.selfHarm,
      'ㄒㄧㄤˇ ㄙˇ': CrisisCategory.selfHarm,
      '我想自ㄕㄚ': CrisisCategory.selfHarm,
      '想ㄚ死': CrisisCategory.selfHarm,
      '爸爸打ㄨㄛˇ': CrisisCategory.abuse,
      '沒人ㄞˋ我': CrisisCategory.severeDistress,
    };
    cases.forEach((text, cat) => test('「$text」→ ${cat.name}', () => expect(detector.detect(text), cat)));

    for (final text in ['我想ㄙㄨㄟˋ覺了', '我想ㄙㄢ點再寫', '我想送ㄙㄨㄥˋ給媽媽', 'ㄅㄆㄇ']) {
      test('「$text」is not detected', () => expect(detector.detect(text), isNull));
    }
  });

  test('helplines are loaded', () {
    expect(detector.helplines, isNotEmpty);
    expect(detector.helplines.map((h) => h.number), contains('113'));
  });
}
