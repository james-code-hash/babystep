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

  group('normalize', () {
    test('full-width ASCII → half-width, lower-case, no whitespace/punct', () {
      expect(CrisisDetector.normalize('ＡＢＣ　１２３！'), 'abc123');
      expect(CrisisDetector.normalize('Hello, World.'), 'helloworld');
    });

    test('strips CJK punctuation, emoji, zero-width and tone marks; keeps hanzi and zhuyin', () {
      expect(CrisisDetector.normalize('想、死。「」『』（）～…⋯'), '想死');
      expect(CrisisDetector.normalize('想😢​‍死️'), '想死');
      expect(CrisisDetector.normalize('ㄒㄧㄤˇ'), 'ㄒㄧㄤ');
    });
  });

  test('helplines are loaded', () {
    expect(detector.helplines, isNotEmpty);
    expect(detector.helplines.map((h) => h.number), contains('113'));
  });
}
