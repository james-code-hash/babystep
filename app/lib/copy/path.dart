import 'line.dart';

/// 「我的小路」（C5）。只跟自己比：沒有平均、沒有「最好」、沒有連著幾天。
abstract final class PathCopy {
  static const title = Line('我的小路', '我的小路');

  /// 石頭下面的日期。
  static const stoneDate = Line.same('{m}/{d}');

  /// 石頭的語音標籤（螢幕閱讀器）。
  static const stoneSemantics = Line.same('{m}月{d}日，{task}');

  static const intro = Line(
    '每一天你想好要做什麼，小路就多一塊石頭。',
    '你想好要做什麼的日子，都會變成一塊石頭。',
  );

  static const empty = Line(
    '你想好第一件小事的那天，這裡就會冒出第一塊石頭喔。',
    '你想好第一件事的那天，這裡會出現第一塊石頭。',
  );

  static const insightsTitle = Line('步步發現', '一些發現');

  static const mostUsedCue = Line(
    '你最常用的開始信號是「{cue}」耶。',
    '你最常用的開始信號是「{cue}」。',
  );

  static const mostPlannedTask = Line(
    '你常給自己排的事是「{task}」。',
    '你常給自己排的事是「{task}」。',
  );

  static const daysThisMonth = Line(
    '這個月你自己想清楚了 {n} 天要做什麼耶。',
    '這個月你自己想清楚了 {n} 天要做什麼。',
  );

  /// 時間點都以「我」開頭（「我吃完晚飯」）；小路的句子裡只說「吃完晚飯」。
  static String cueWithoutMe(String cue) {
    final t = cue.trim();
    return t.startsWith('我') && t.length > 1 ? t.substring(1) : t;
  }
}
