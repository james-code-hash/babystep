import 'line.dart';

/// 早上排計畫的句子（文案庫 §4.3–4.5、§4.9）。步步只提問、給選項，不代寫（底線 6）。
abstract final class PlanCopy {
  static const title = Line('今天想做什麼', '排今天');

  // ------------------------------------------------------------ 如果⋯我就⋯

  /// `{cue}` 以「我」開頭（「我吃完晚飯」）。
  static const ifThen = Line.same('如果{cue}，我就{task}');
  static const ifSlot = Line.same('如果⋯');
  static const thenSlot = Line.same('我就⋯');

  static const _i = '我';

  /// 「我吃完晚飯」→「吃完晚飯」，給「你說吃完晚飯要⋯」這類句子用。
  static String cueBody(String cue) {
    final t = cue.trim();
    return t.startsWith(_i) ? t.substring(_i.length) : t;
  }

  // ------------------------------------------------------------ 1. 心情暖身（C2：不存）

  static const moodAsk = Line('早安！今天心情怎麼樣？', '今天心情怎麼樣？');
  static const moodHappy = Line.same('開心');
  static const moodOkay = Line.same('普通');
  static const moodTired = Line.same('累累的');
  static const moodLow = Line.same('不太好');
  static const moodSkip = Line.same('先不說');

  static const moodHappyReply = Line('開心的早上！來看看今天想做什麼。', '不錯。來看看今天想做什麼。');
  static const moodOkayReply = Line('普普通通的一天也可以呀。', '普通的一天也可以。');
  static const moodTiredReply = Line('有點累了呀。今天要不要就先不排事情？', '有點累。今天要不要就先不排事情？');
  static const moodLowReply = Line('聽起來今天不太好過。今天要不要就先不排事情？', '聽起來今天不太好過。今天要不要先不排事情？');
  static const moodSkipReply = Line('好，那我們直接來看看今天。', '好，直接來看今天。');

  /// 心情低時的兩個選項，份量相同。
  static const restToday = Line('今天先不排', '先不排');
  static const planAnyway = Line('想排一下', '還是排一下');

  // ------------------------------------------------------------ 2. 選 1–3 件事（§4.3）

  /// `{max}` 是每天最多幾件。
  static const chooseAsk = Line('今天你想做哪幾件事？最多 {max} 件就好，貪心會累。', '今天想做哪幾件事？最多 {max} 件。');
  static const sectionMine = Line('你自己寫過的', '自己寫過的');
  static const sectionPreset = Line('常見的事', '常見的事');
  static const sectionParent = Line('家長的建議，可以不選', '家長的建議，可以不選');
  static const chooseOne = Line('一件也可以，這樣比較不會趕。', '一件也可以，這樣比較不會趕。');
  static const chooseFull = Line('今天先排 {max} 件就好。想換的話，先取消一件。', '最多 {max} 件。想換的話，先取消一件。');

  static const customTaskHint = Line('你想做什麼？', '想做什麼？');
  static const customEmojiAsk = Line('幫它挑一個圖案', '挑一個圖案');
  static const addIt = Line.same('加進去');

  // ------------------------------------------------------------ 3. 如果⋯我就⋯（§4.4）

  static const cueAsk = LinePool([
    Line('那你打算什麼時候做呢？可以是「吃完晚飯」「洗完澡」這種。', '打算什麼時候做？講個具體的時間點。'),
    Line('有沒有一個每天都會發生的事，可以當作開始的信號？', '有沒有每天都會發生的事，可以當開始的信號？'),
  ]);
  static const customCueHint = Line('什麼時候？例如：我放學回到家', '什麼時候？例如：我放學回到家');
  static const useThis = Line.same('用這個');
  static const editTask = Line('想換個說法', '換個說法');
  static const editTaskHint = Line('我就⋯', '我就⋯');
  static const cueChosen = Line('這個時間點是你自己選的，等一下就靠它提醒你。', '時間點是你自己選的，到時候就靠它提醒你。');

  // ------------------------------------------------------------ 4. 為什麼（§4.5，可跳過）

  /// `{task}` 是這件事。
  static const whyAsk = Line('「{task}」，你自己覺得為什麼想做？不想說也可以。', '「{task}」，你為什麼想做？不想說也可以。');
  static const whyTry = Line.same('我想試試看');
  static const whyMine = Line.same('我自己想做');
  static const whyEasier = Line.same('做完會比較輕鬆');
  static const whyFamily = Line.same('家人希望我做，我也覺得可以');
  static const whyDontKnow = Line.same('不知道');
  static const whyCustomHint = Line('用自己的話說說看', '用自己的話說');
  static const whyDontKnowReply = Line('有時候就是還沒想到。先做做看，說不定做完就知道了。', '還沒想到也可以。做完說不定就知道了。');
  static const whyHeard = Line('嗯，步步記住你的想法了。', '嗯，知道了。');

  // ------------------------------------------------------------ 5. 確認（§4.4 完成時）

  static const confirmTitle = Line('好，寫下來了。這是你自己排的喔。', '好，寫下來了。這是你自己排的。');
  static const confirmSave = Line('就這樣排', '就這樣');
  static const confirmEdit = Line('回去改一下', '回去改');

  // ------------------------------------------------------------ 今天已經聊完

  static const dayEnded = Line('今天聊完了，計畫就留給下一天吧。', '今天聊完了。');
  static const backHome = Line('回到首頁', '回首頁');
}
