import 'line.dart';

/// 晚上回顧（文案庫 §4.7）。
///
/// 規則提醒：
/// - 三種回顧狀態的回應池一樣大（底線 4），「今天沒做」只有好奇、沒有遺憾或原諒。
/// - 不用 L2 詞（沒關係／可惜／明天再／很好），也不給「明天再來」的壓力。
abstract final class ReviewCopy {
  static const title = Line('晚上聊聊', '回顧');

  // ------------------------------------------------------------ 開場

  static const openings = LinePool([
    Line('今天過得怎麼樣呀？', '今天如何？'),
    Line('來看看今天吧～', '來看看今天。'),
    Line('嗨～我們來聊聊今天吧！', '來聊聊今天。'),
  ]);

  static const start = Line('來聊吧', '開始');

  /// 今天沒有計畫：平靜，不追問。
  static const noPlans = Line('今天沒有排事情，那就這樣過也可以喔。', '今天沒有排事情，這樣也可以。');

  /// 今天已經聊完了。
  static const alreadyEnded = Line('今天聊完了～我們已經說過晚安了。', '今天聊完了。');

  static const backHome = Line('回到首頁', '回首頁');

  // ------------------------------------------------------------ 每件事的回顧

  static const howDidItGo = Line('這件事今天怎麼樣？', '這件事呢？');

  static const outcomeDone = Line('做到了', '做到了');
  static const outcomePartly = Line('做了一部分', '做了一部分');
  static const outcomeNotToday = Line('今天沒做', '今天沒做');

  /// 情境 A：做到了。描述過程，不評價人。
  static const doneResponses = LinePool([
    Line('你照著自己想的計畫做了耶，那個時間點是你選的。', '你照自己的計畫做了。時間點是你選的。'),
    Line('做到了！你剛剛是怎麼開始的呀？', '做到了。你是怎麼開始的？'),
    Line('你自己排的順序，走起來挺順的耶～', '你排的順序，走起來挺順。'),
    Line('喔！你選的那個時間點派上用場了。', '你抓的那個時間點有用。'),
  ]);

  /// 情境 B：做了一部分。
  static const partlyResponses = LinePool([
    Line('有開始，就已經走過最難的那一段了耶。', '有開始，最難的那段就過了。'),
    Line('做了一部分也是做了喔。中間發生什麼事呀？', '做了一部分。中間發生什麼事？'),
    Line('停在哪裡呢？我好想知道～', '停在哪裡？'),
    Line('喔～做到一半的地方，常常藏著有趣的線索。', '做到一半的地方，常常有線索。'),
  ]);

  /// 情境 C：今天沒做。好奇、中性；不遺憾、不原諒、不推明天。
  static const notTodayResponses = LinePool([
    Line('喔～今天發生什麼事了？', '嗯，今天發生什麼事了？'),
    Line('好，我記下來了。今天是什麼樣的一天呢？', '好，記下來了。今天是什麼樣的一天？'),
    Line('沒做就是沒做～是時間點的關係，還是那天的關係？', '沒做就沒做。是計畫的問題，還是那天的問題？'),
    Line('嗯嗯，那個時間點會不會有點難呀？', '那個時間點會不會有點難？'),
  ]);

  // ------------------------------------------------------------ 歷程問題

  /// 不管做了沒都說得通的問題（全部「今天沒做」的日子只從這裡抽）。
  static const anyDayQuestions = LinePool([
    Line('今天是什麼樣的一天呀？', '今天是什麼樣的一天？'),
    Line('今天最好玩的是哪一段？', '今天最有意思的是哪一段？'),
    Line('今天有沒有什麼讓你笑出來的事？', '今天有什麼是你原本沒預料到的？'),
    Line('如果明天要再試一次，你會想換個什麼方法？', '如果再來一次，你會想換什麼方法？'),
  ]);

  /// 有動手做的日子才問的問題。
  static const didSomethingQuestions = LinePool([
    Line('今天有哪個地方本來以為會卡住，結果沒有？', '有哪裡本來以為會卡住，結果沒有？'),
    Line('有沒有哪件事，做起來比你想的快？', '有哪件事做起來比你想的快？'),
  ]);

  /// 短答案 chip：任何一天都可以。
  static const anyDayChips = [Line.same('沒有特別的'), Line('今天很滿', '今天很忙'), Line('有好玩的事', '有有趣的事')];

  /// 有動手做的日子多給的 chip。
  static const didSomethingChips = [Line.same('有一點卡住'), Line.same('比我想的快')];

  /// 有「今天沒做」的日子多給的 chip。
  static const notTodayChips = [Line('我想換個時間', '想換個時間'), Line('我想休息', '想休息')];

  static const skipQuestion = Line('先跳過', '跳過');
  static const writeOwn = Line('我自己說', '自己寫');
  static const answerHint = Line('想說什麼都可以～', '想寫什麼都可以');
  static const send = Line('說給步步聽', '送出');

  // ------------------------------------------------------------ 步步學到

  static const thinking = Line('讓我想一下⋯', '讓我想一下⋯');
  static const learnedTitle = Line('步步學到了：', '步步學到：');
  static const askSave = Line('要不要記進筆記本？', '要記進筆記本嗎？');
  static const saveYes = Line.same('記下來');
  static const saveNo = Line.same('不用');
  static const continueOn = Line('好', '好');

  // ------------------------------------------------------------ 結束

  static const ending = Line('今天就到這裡囉，掰掰！', 'OK，明天見。');

  /// 安全回應之後：不學東西，只道晚安。
  static const goodnight = Line('好，聊完了。晚安～', '好，聊完了。晚安。');

  static const endOk = Line.same('好');
}
