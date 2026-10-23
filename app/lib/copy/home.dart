import 'line.dart';

/// 首頁的句子。問候在 `copy/bubu.dart`（只吃語氣、時間、隨機）。
///
/// 首頁一次只有一個主要按鈕；句子都是邀請，孩子可以不理。
abstract final class HomeCopy {
  // ------------------------------------------------------------ 三種狀態

  /// 今天還沒排：邀請（可以不理）。
  static const planInvite = Line.same('想想今天要做什麼');
  static const planInviteHint = Line('想排的時候再點就好～', '想排的時候再點。');

  /// 今天有計畫：標題與晚上的邀請。
  static const todayTitle = Line('今天你想做的事', '今天的計畫');
  static const reviewInvite = Line.same('來聊聊今天');
  static const replan = Line('想改一下計畫', '改一下計畫');

  /// 今天聊完了：沒有任何行動呼籲。
  static const dayEnded = Line.same('今天聊完了');
  static const dayEndedBubu = Line('步步在旁邊放鬆一下～', '步步在旁邊休息。');

  // ------------------------------------------------------------ 探頭提醒（B1／C7／D4）

  /// `{cue}` 是去掉開頭「我」的時間點（例如「吃完晚飯」），`{task}` 是事情。
  static const peek = LinePool([
    Line('你說{cue}要{task}，現在方便嗎？', '你說{cue}要{task}。現在方便嗎？'),
    Line('嗨～只是提一下：你說{cue}要{task}。', '只是提一下：你說{cue}要{task}。'),
  ]);

  static const peekGo = Line.same('去做');
  static const peekLater = Line.same('等一下');
  static const peekNotToday = Line.same('今天算了');

  /// 三個選項各自只換成一句步步的話；都不寫入資料庫。
  static const peekGoReply = Line('好，去吧！步步在這裡。', '好，去吧。');
  static const peekLaterReply = Line('好喔，你決定什麼時候。', 'OK，你決定。');
  static const peekNotTodayReply = Line('好，今天就先這樣。', '好，知道了。');

  // ------------------------------------------------------------ 次要導覽（不帶任何數字或小紅點）

  static const notebook = Line('步步的筆記本', '筆記本');
  static const path = Line.same('我的小路');
  static const settings = Line.same('我的設定');
  static const parent = Line.same('家長區');
}
