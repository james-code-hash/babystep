import 'line.dart';

/// 步步自己說的話（問候、表情旁白）與裝扮名稱。
///
/// 問候的規則（底線 2、3）：
/// - 只依時段、季節抽，不論隔多久沒開，句子都一樣；絕不提「多久沒來」。
/// - 只打招呼、提問、分享步步自己看到的東西；不催、不命令、不評價。
abstract final class BubuCopy {
  /// 通用問候（任何時段都可以用）。
  static const greetings = LinePool([
    Line('嗨～步步在這裡！', '嗨。今天如何？'),
    Line('你來了！今天過得怎麼樣？', '你來了。今天怎麼樣？'),
  ]);

  static const greetingsMorning = LinePool([
    Line('早安～步步在這裡！', '早。今天如何？'),
    Line('早安！今天想做什麼呀？', '早安。今天有什麼想做的？'),
    Line('早～我剛剛在想事情耶。', '早。我剛剛在想事情。'),
    Line('嗨！早上的空氣香香的～', '嗨。早上的空氣滿清爽的。'),
  ]);

  static const greetingsDay = LinePool([
    Line('嗨～步步在這裡！', '嗨。今天如何？'),
    Line('你來了！今天過得怎麼樣？', '你來了。今天怎麼樣？'),
    Line('嗨！今天你想安排什麼呀？', '嗨。今天想安排什麼？'),
    Line('午安～我在曬太陽耶。', '午安。我在曬太陽。'),
  ]);

  static const greetingsEvening = LinePool([
    Line('傍晚了～天空變橘色了耶！', '傍晚了，天空變成橘色。'),
    Line('嗨～今天過得怎麼樣呀？', '嗨。今天過得怎樣？'),
    Line('晚上好！想聊聊今天嗎？', '晚上好。想聊聊今天嗎？'),
  ]);

  static const greetingsNight = LinePool([
    Line('晚上好～月亮出來了耶。', '晚上好。月亮出來了。'),
    Line('嗨～晚上好安靜喔。', '嗨。晚上滿安靜的。'),
    Line('睡覺前，想跟我聊聊嗎？', '睡前想聊一下嗎？'),
  ]);

  static const greetingsSpring = LinePool([
    Line('春天到了，花開了耶～', '春天了，外面的花開了。'),
    Line('有花瓣飄過來耶！', '外面有花瓣在飄。'),
  ]);

  static const greetingsSummer = LinePool([
    Line('夏天的太陽亮晶晶～', '夏天了，太陽好亮。'),
    Line('我聽到蟬在叫耶！', '外面有蟬在叫。'),
  ]);

  static const greetingsAutumn = LinePool([
    Line('秋天了，葉子變黃了耶。', '秋天了，葉子變黃了。'),
    Line('我撿到一片葉子喔！', '我撿到一片葉子。'),
  ]);

  static const greetingsWinter = LinePool([
    Line('冬天了，有點冷喔～', '冬天了，有點冷。'),
    Line('呼～我吐出白白的氣耶！', '天冷，呼出來的氣是白的。'),
  ]);

  // ── 讀螢幕用的描述（Semantics）。只描述步步的樣子，不提孩子做了什麼。
  static const semanticsHappy = Line('步步笑咪咪的', '步步在笑');
  static const semanticsCurious = Line('步步歪著頭在想', '步步歪著頭在想');
  static const semanticsCaring = Line('步步溫柔地看著你', '步步在關心你');
  static const semanticsCalm = Line('步步安安靜靜地陪著你', '步步在旁邊陪你');
  static const semanticsSurprised = Line('步步眼睛睜得圓圓的', '步步有點驚訝');
  static const semanticsRelaxed = Line('步步舒服地瞇著眼', '步步很放鬆');
  static const semanticsThinking = Line.same('步步在想事情');

  // ── 裝扮名稱。全部一開始就能選。
  static const hatNone = Line.same('不戴帽子');
  static const hatLeaf = Line('小葉子', '葉子');
  static const hatFlower = Line('小花', '花');
  static const hatBeanie = Line.same('毛線帽');
  static const hatStraw = Line.same('草帽');
  static const hatBucket = Line.same('漁夫帽');

  static const neckNone = Line.same('脖子空空');
  static const neckScarf = Line.same('圍巾');
  static const neckBow = Line.same('蝴蝶結');
  static const neckBell = Line('小鈴鐺', '鈴鐺');
  static const neckBandana = Line.same('領巾');

  static const colorCream = Line.same('奶油色');
  static const colorPeach = Line.same('蜜桃色');
  static const colorMint = Line.same('薄荷綠');
  static const colorSky = Line.same('天空藍');
  static const colorLavender = Line.same('薰衣草紫');
  static const colorCocoa = Line.same('可可色');
}
