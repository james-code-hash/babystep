import 'line.dart';

/// 初次見面與取名字（文案庫 §4.1，決策 D6）。
///
/// 「步步」在顯示時會換成孩子取的名字；`{original}` 一律帶入原本的名字「步步」。
abstract final class OnboardingCopy {
  /// 第一次打開 App：步步自我介紹。先講清楚「你做不做事，我都在」（底線 2、3）。
  static const hello = LinePool([
    Line('嗨，我是步步。我不會教你做什麼，我只是想陪你。', '嗨，我是步步。我不會教你做什麼，只是想陪你。'),
    Line('嗨！我是步步。先講清楚喔：你做不做事，我都會在這裡。', '嗨，我是步步。先說清楚：你做不做事，我都在這裡。'),
  ]);

  static const helloReply = Line('嗨！', '嗨');

  static const nameAsk = Line('你想叫我什麼名字都可以喔。我原本叫{original}，你決定就好。', '想叫我什麼都可以。我原本叫{original}，你決定。');
  static const nameAskAgain = Line('想幫我換個名字嗎？叫什麼都可以喔。', '想換個名字嗎？叫什麼都可以。');
  static const nameHint = Line.same('幫我取個名字');
  static const nameUse = Line.same('用這個名字');

  /// 不取名字也可以：保留現在的名字（第一次就是「步步」）。
  static const nameKeep = Line.same('就叫步步');

  /// 已經取過名字，想換回原本的。
  static const nameBack = Line.same('換回{original}');

  /// 名字裡有規則不讓步步說出口的字（例如「天才」）：只說唸不出來，不說孩子錯。
  static const nameRetry = Line('這個名字我唸不太出來耶，換一個好嗎？', '這個名字我唸不出來，換一個？');

  static const nameDone = Line('好！以後我就叫步步了。', '好，以後我叫步步。');
  static const start = Line('開始吧', '開始');
}
