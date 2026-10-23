import 'line.dart';

/// 孩子自己的「我的設定」與裝扮。
abstract final class SettingsCopy {
  static const title = Line('我的設定', '我的設定');

  static const toneTitle = Line('步步說話的方式', '步步說話的方式');
  static const toneHint = Line('你喜歡哪一種，就選哪一種。隨時都可以換。', '選你喜歡的，隨時可以換。');

  /// 不標年齡（B5）。
  static const toneLively = Line.same('活潑');
  static const toneConcise = Line.same('簡潔');

  /// 每種說話方式各示範一句（預覽一律用自己那一種語氣顯示）。
  static const previewLively = Line.same('嗨～我是步步！今天想做點什麼呢？');
  static const previewConcise = Line.same('嗨，我是步步。今天想做什麼？');

  static const dressUpEntry = Line('幫步步換裝扮', '幫步步換裝扮');
  static const dressUpEntryHint = Line('帽子、圍巾、顏色，都可以隨你挑。', '帽子、脖子上的東西、顏色，隨你挑。');

  static const dressUpTitle = Line('步步的裝扮', '步步的裝扮');
  static const dressUpIntro = Line('想讓步步今天穿什麼？每一樣都可以試試看。', '每一樣都可以選，換幾次都行。');
  static const hats = Line.same('頭上');
  static const necks = Line.same('脖子');
  static const colors = Line.same('顏色');

  /// 配件沒有名字時的標籤：「第 2 個」。
  static const unnamedOption = Line.same('第 {n} 個');
}
