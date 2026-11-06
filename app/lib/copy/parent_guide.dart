import 'line.dart';

/// 家長區的「陪伴小工具」：話術轉譯器與每週一則（企劃書 §9.3、§9.4）。給大人看，兩種語氣一樣。
///
/// 規則：
/// - 話術轉譯器只依「家長自己選的情境」給說法，**不讀孩子任何資料**——App 不會告訴家長孩子做了沒有（底線 7）。
/// - 「別這樣說」的例子也要過文案規則：不直接引用評價人的誇獎或威脅，改成描述那種說法。
/// - 每週一則依日期輪替，不記錄家長讀了沒有。

/// 一個情境的說法：承認感受＋提供選擇＋給理由（§9.4）。
class TalkScript {
  const TalkScript({
    required this.id,
    required this.situation,
    required this.avoid,
    required this.feeling,
    required this.choice,
    required this.reason,
    required this.why,
  });

  final String id;
  final Line situation;

  /// 「別這樣說」。
  final Line avoid;

  /// 承認感受。
  final Line feeling;

  /// 提供選擇。
  final Line choice;

  /// 給理由。
  final Line reason;

  /// 為什麼這樣說比較好。
  final Line why;

  List<Line> get lines => [situation, avoid, feeling, choice, reason, why];
}

/// 每週一則（約 2 分鐘）。
class ParentLesson {
  const ParentLesson({required this.id, required this.title, required this.paragraphs, required this.tryThis});
  final String id;
  final Line title;
  final List<Line> paragraphs;

  /// 這週可以試試的一件小事。
  final Line tryThis;

  List<Line> get lines => [title, ...paragraphs, tryThis];
}

abstract final class ParentGuideCopy {
  // ---------------------------------------------------------------- 家長區首頁的入口
  static const sectionTitle = Line.same('陪伴小工具');
  static const sectionNote = Line.same('給大人看的。不會讀取孩子的任何紀錄。');
  static const talkEntry = Line.same('想跟孩子說話的時候');
  static const talkEntryHint = Line.same('選一個情境，看看可以怎麼說');
  static const lessonsEntry = Line.same('每週一則');
  static const lessonsEntryHint = Line.same('兩分鐘讀完，這週是：{title}');

  // ---------------------------------------------------------------- 話術轉譯器
  static const talkTitle = Line.same('想跟孩子說話的時候');
  static const talkIntro = Line.same('這裡不會告訴你孩子做了沒有。選一個你自己遇到的情況，看看可以怎麼說。');
  static const avoidLabel = Line.same('別這樣說');
  static const feelingLabel = Line.same('先接住感受');
  static const choiceLabel = Line.same('給一個選擇');
  static const reasonLabel = Line.same('說出理由');
  static const whyLabel = Line.same('為什麼');

  static const scripts = <TalkScript>[
    TalkScript(
      id: 'not-done',
      situation: Line.same('我看到今天排的事沒有動'),
      avoid: Line.same('「你怎麼又沒做？說好的呢？」'),
      feeling: Line.same('「看起來今天的計畫沒有動，發生什麼事了嗎？」'),
      choice: Line.same('「你想今晚再找個時間，還是先放著，改天再排？兩個都可以。」'),
      reason: Line.same('「我問是想知道哪裡卡住了，不是要罵你。」'),
      why: Line.same('先理解再解決，孩子比較願意說實話，也保住「這是我自己的計畫」的感覺。'),
    ),
    TalkScript(
      id: 'give-up',
      situation: Line.same('孩子說想放棄'),
      avoid: Line.same('「才剛開始就要放棄？這樣什麼都做不成。」'),
      feeling: Line.same('「聽起來這件事現在讓你很煩。」'),
      choice: Line.same('「要不要先切成小一點的一步？還是先休息十分鐘再看看？」'),
      reason: Line.same('「很多事卡住，是因為一步太大，不是因為你不行。」'),
      why: Line.same('把卡住說成「步驟太大」而不是「人不行」，孩子比較會再試一次。'),
    ),
    TalkScript(
      id: 'suggest',
      situation: Line.same('我想建議孩子做一件事'),
      avoid: Line.same('「從今天開始，你每天都給我練琴。」'),
      feeling: Line.same('「我知道你每天已經排了不少事。」'),
      choice: Line.same('「我有一個想法，你想聽聽看嗎？聽完由你決定要不要放進計畫。」'),
      reason: Line.same('「我會這樣想，是因為⋯⋯」（說出你真正的理由）'),
      why: Line.same('留選擇、給理由，孩子比較能把家人的期待變成自己的想法。家長建議的事，孩子在 App 裡可以不選。'),
    ),
    TalkScript(
      id: 'did-it',
      situation: Line.same('孩子做到了，我想說些什麼'),
      avoid: Line.same('只說一句評價人的誇獎（像是誇孩子天生能幹），就結束了。'),
      feeling: Line.same('「你看起來對今天挺滿意的。」'),
      choice: Line.same('「你想跟我說說，你是怎麼開始的嗎？」'),
      reason: Line.same('「我好奇，是因為你用的方法說不定之後也用得上。」'),
      why: Line.same('描述過程、問方法，孩子會把功勞放在自己做的事上，而不是放在「被誇」這件事上。'),
    ),
    TalkScript(
      id: 'no-plan',
      situation: Line.same('孩子不想排計畫'),
      avoid: Line.same('「不排的話，你今天又會什麼都沒做。」'),
      feeling: Line.same('「今天不想排，好，我聽到了。」'),
      choice: Line.same('「要不要只挑一件很小的事？還是今天就先不排？兩個都可以。」'),
      reason: Line.same('「排計畫是幫你自己的工具，不是功課。」'),
      why: Line.same('能說「不」才是真的選擇。孩子知道可以不排，想排的時候才會真心排。'),
    ),
  ];

  // ---------------------------------------------------------------- 每週一則
  static const lessonsTitle = Line.same('每週一則');
  static const lessonsIntro = Line.same('每週換一則，兩分鐘讀完。想看其他週的，往下翻就有。');
  static const thisWeek = Line.same('這週');
  static const tryThisLabel = Line.same('這週可以試試');

  static const lessons = <ParentLesson>[
    ParentLesson(
      id: 'structure',
      title: Line.same('規則和自主，可以同時有'),
      paragraphs: [
        Line.same('清楚的期待（幾點睡、功課先寫）和讓孩子自己選，並不衝突。'),
        Line.same('有結構的做法是：規則講清楚、理由說出來、怎麼做讓孩子決定。控制的做法是：照我說的做，不要問。'),
        Line.same('研究（Grolnick 的三個面向：自主支持、結構、投入）發現，孩子最需要的是三者一起來，而不是只有規則或只有放手。'),
      ],
      tryThis: Line.same('挑一條家裡的規則，跟孩子說它的理由，再讓孩子決定一個執行的細節。'),
    ),
    ParentLesson(
      id: 'process-praise',
      title: Line.same('誇做法，不誇天分'),
      paragraphs: [
        Line.same('Mueller 與 Dweck（1998）的研究裡，被誇「天生能力」的孩子，遇到難題比較容易放棄；被描述方法和過程的孩子，比較願意挑戰。'),
        Line.same('描述的說法很簡單：說出你看到孩子「做了什麼」，或問他「怎麼想到的」。'),
        Line.same('例如：「你先把最難的那題圈起來，再回頭做。」比一句評價人的誇獎更有用。'),
      ],
      tryThis: Line.same('把一句誇獎換成一句描述：說出你看到他做了什麼。'),
    ),
    ParentLesson(
      id: 'psych-control',
      title: Line.same('心理控制的四種樣子'),
      paragraphs: [
        Line.same('心理控制不是打罵，而是用感情來推動孩子。常見的有四種：讓孩子覺得虧欠（「我為你做了這麼多」）、收回關心（冷戰、不理）、操弄（用條件交換感情）、過高的期待。'),
        Line.same('跨文化的研究（Bradshaw 等，2024）都發現，這些做法對孩子的動機和情緒有害，即使出發點是愛。'),
        Line.same('好消息是：只要察覺到，換一句話就能改。'),
      ],
      tryThis: Line.same('留意自己有沒有說過讓孩子覺得「做不到就不被愛」的話，換成「不管怎樣我都在」。'),
    ),
    ParentLesson(
      id: 'rationale',
      title: Line.same('多說一句「因為」'),
      paragraphs: [
        Line.same('孩子照做和孩子認同，是兩回事。差別常常只在有沒有說理由。'),
        Line.same('說出真正的理由（不是「因為我說的」），孩子比較能把家庭的期待變成自己的想法，做的時候也比較不需要人盯。'),
        Line.same('理由不用長，一句就夠：「先洗澡再玩，是因為太晚洗會睡不著。」'),
      ],
      tryThis: Line.same('請孩子做一件事的時候，多說一句「因為⋯⋯」。'),
    ),
    ParentLesson(
      id: 'step-back',
      title: Line.same('陪，不是替'),
      paragraphs: [
        Line.same('Wei、Pomerantz 等（2022）發現：家長協助功課，對小學生有幫助，對中學生則不一定。'),
        Line.same('關鍵在怎麼幫：陪孩子想下一步，比直接說出答案更有幫助；孩子越大，越要退到旁邊。'),
        Line.same('退一步不是不管，是把「決定怎麼做」還給孩子。'),
      ],
      tryThis: Line.same('孩子卡住時，先問一句：「你想要我幫哪一部分？」'),
    ),
    ParentLesson(
      id: 'family',
      title: Line.same('「我們家一起」'),
      paragraphs: [
        Line.same('研究（Bao 與 Lam，2008）發現，和家人感情好的時候，孩子比較不會把大人的安排當成壓力。'),
        Line.same('所以比起「你要⋯⋯」，「我們家一起⋯⋯」更容易被接受。大人也有自己想做到的事，孩子看得到。'),
        Line.same('在家長區的「全家一起」裡，你也可以寫下今天自己想做的一件事，步步會告訴孩子。'),
      ],
      tryThis: Line.same('寫下一件你今天自己想做的小事，讓孩子看到你也在練習。'),
    ),
  ];
}
