import '../domain/models.dart';
import 'line.dart';

/// 「步步學到」範本引擎用的一句話：句子＋它屬於哪一類（LLM 規格 §5.2）。
class LessonLine {
  const LessonLine(this.line, this.kind);
  final Line line;
  final LessonKind kind;
}

/// 一種回顧狀態的兩個句子池：孩子沒說話時用 [silent]；孩子說了話時先試 [quoted]
/// （有 `{quote}`，帶入孩子原話的一段），帶不進去再退回 [silent]。
class LessonPools {
  const LessonPools({required this.silent, required this.quoted});
  final List<LessonLine> silent;
  final List<LessonLine> quoted;
}

/// 範本引擎的所有句子（docs/decisions.md C3）。
///
/// 規則：
/// - 三種狀態的池一樣大（測試會檢查）——「沒做」不是比較少話可說的一天（底線 4）。
/// - 「做到了」「一部分」只說方法與過程，不讚美人、不讚美結果（底線 5）。
/// - 「沒做」每一句都是「從孩子的選擇學到」（[LessonKind.choice]），不暗示失望、不約明天。
/// - `{task}` 是今天第一件事的名稱、`{quote}` 是孩子原話的一段；帶入後整句仍要過文案規則與字數上限，
///   過不了的句子引擎會跳過。
abstract final class LessonCopy {
  static const done = LessonPools(
    silent: [
      LessonLine(
        Line('你先想好什麼時候做，時間到了就去做。原來先想好時間點，開始會比較容易耶。',
            '你先決定什麼時候做，時間到就開始。原來先想好時間點，比較容易開始。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('今天你自己選了{task}，也自己開始了。我記下來了：先選好一件事，就知道從哪裡開始。',
            '你自己選了{task}，也自己開始。我記下來：先選好一件事，就知道從哪裡開始。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('原來心裡有一個想好的時間點，就比較不會忘記。這一招我也想學。', '原來有想好的時間點，就比較不會忘記。這招我記下來了。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('一次只排一件小事，好像比較好開始耶。我把這個記下來了。', '一次排一件小事，比較好開始。這個我記下來了。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('原來把「如果⋯我就⋯」先想好，做的時候就不用一直想。我記下來了。', '先把「如果⋯我就⋯」想好，做的時候就不用一直想。我記下來了。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('做{task}之前先有一個開始的信號，這個方法我要記起來。', '先有一個開始的信號再做{task}，這個方法我記下來了。'),
        LessonKind.method,
      ),
    ],
    quoted: [
      LessonLine(
        Line('你說『{quote}』，我記下來了。原來可以這樣做耶。', '你說『{quote}』。我記下來了，原來可以這樣做。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('『{quote}』——這個我沒想過耶，我要記起來。', '『{quote}』，這個我沒想過，記下來了。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('你說『{quote}』。原來你做事的時候是這樣想的，我記下來了。', '你說『{quote}』。原來你是這樣想的，我記下來了。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('我把你說的『{quote}』記下來了。下次我也想試試看。', '我記下你說的『{quote}』，下次我也想試試。'),
        LessonKind.method,
      ),
    ],
  );

  static const partly = LessonPools(
    silent: [
      LessonLine(
        Line('今天你先做了一部分。我學到：事情可以先做一小段，再看看接下來怎麼做。', '今天你先做了一部分。我學到：可以先做一小段，再決定接下來怎麼做。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('原來做到一半的時候，就會知道哪裡比較難。這個我記下來了。', '做到一半，就會知道哪裡比較卡。這個我記下來了。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('事情可以分成好幾段來做耶。今天你做了其中一段，我記下來了。', '事情可以分段做。今天你做了其中一段，我記下來了。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('做了一部分{task}之後，就比較知道它要花多少力氣。我記下來了。', '做了一部分{task}，就比較知道它要花多少力氣。我記下來了。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('原來停在一半也可以，下次就知道要從哪裡接著做。我學到了。', '停在一半也可以，下次就知道從哪裡接。我學到了。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('原來計畫可以邊做邊調整。今天你調整了一下，我記下來了。', '計畫可以邊做邊調整。今天你調整了，我記下來了。'),
        LessonKind.method,
      ),
    ],
    quoted: [
      LessonLine(
        Line('你說『{quote}』。原來做到一半的時候是這樣，我記下來了。', '你說『{quote}』。原來做到一半是這樣，我記下來了。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('你說『{quote}』，我記下來了。原來事情可以分段來做耶。', '你說『{quote}』，我記下來了。原來事情可以分段做。'),
        LessonKind.method,
      ),
      LessonLine(
        Line('『{quote}』——原來你會注意到這個，我沒想過耶。', '『{quote}』，原來你會注意到這個，我沒想過。'),
        LessonKind.selfKnowledge,
      ),
      LessonLine(
        Line('我把『{quote}』記下來了。做一部分的時候，也有東西可以學耶。', '我記下了『{quote}』。做一部分的時候，也有東西可以學。'),
        LessonKind.method,
      ),
    ],
  );

  static const notToday = LessonPools(
    silent: [
      LessonLine(
        Line('今天你選了先休息，我記下來了：累的時候可以先停一下。', '今天你選了先休息。我記下來了：累的時候可以先停一下。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('今天你決定先不做，這也是一種決定耶。我記下來了：要不要做，可以自己決定。', '今天你決定先不做，這也是一種決定。我記下來：要不要做，可以自己決定。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('今天你把時間留給別的事了。我學到：一天裡有很多事，可以自己排順序。', '今天你把時間留給別的事。我學到：一天有很多事，可以自己排順序。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('原來計畫跟真實的一天對不上的時候，可以換個做法。我記下來了。', '計畫和真實的一天對不上時，可以換個做法。我記下來了。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('今天你照實說了沒做。我學到：照實說出來，事情就看得比較清楚。', '你照實說了今天沒做。我學到：照實說，事情會看得比較清楚。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('今天你聽了自己的感覺，先不做。我記下來了：自己的感覺也很重要。', '今天你照自己的感覺，先不做。我記下來：自己的感覺也算數。'),
        LessonKind.choice,
      ),
    ],
    quoted: [
      LessonLine(
        Line('你說『{quote}』，所以今天先不做。我記下來了：這也是一種決定。', '你說『{quote}』，所以今天先不做。我記下來：這也是一種決定。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('你說『{quote}』。原來你是這樣決定的，我記下來了。', '你說『{quote}』。原來你是這樣決定的，記下來了。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('『{quote}』——所以你選了先停下來。我學到：可以照自己的狀況來選。', '『{quote}』，所以你選了先停。我學到：可以照自己的狀況選。'),
        LessonKind.choice,
      ),
      LessonLine(
        Line('你說『{quote}』。我記下來了：計畫可以配合真實的一天。', '你說『{quote}』。我記下來：計畫可以配合真實的一天。'),
        LessonKind.choice,
      ),
    ],
  );

  /// 平淡的一天（LLM 規格 §5.4）。沒有計畫可回顧時，或其他句子都帶不進去時用。
  static const plainDay = LessonLine(
    Line.same('今天沒什麼特別要記的，就是普通的一天。'),
    LessonKind.plainDay,
  );

  /// 引用孩子原話被截短時，接在後面的省略號。
  static const quoteEllipsis = Line.same('⋯');

  static LessonPools poolsFor(Outcome outcome) => switch (outcome) {
        Outcome.done => done,
        Outcome.partly => partly,
        Outcome.notToday => notToday,
      };
}
