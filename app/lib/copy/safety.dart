import '../safety/crisis_detector.dart';
import 'line.dart';

/// 安全回應的預寫文案（docs/decisions.md C6）。
///
/// ⏸ 上線前需要兒童心理專業審核。原則：溫和、不驚嚇、不追問、不說教；謝謝孩子說出來，
/// 說清楚「不是你的錯」，引導去找信任的大人，附上專線。這裡的句子絕不交給 LLM 產生（底線 9）。
abstract final class SafetyCopy {
  /// 第一句：依類別。`null` 是伺服器端攔下（不知道哪一類）時用的通用版。
  static Line opening(CrisisCategory? category) => switch (category) {
        CrisisCategory.selfHarm => openingSelfHarm,
        CrisisCategory.abuse => openingAbuse,
        CrisisCategory.severeDistress => openingDistress,
        null => openingGeneral,
      };

  static const openingSelfHarm = Line(
    '謝謝你跟我說。你現在的感覺很重要，我想陪你一起找人幫忙。',
    '謝謝你說出來。你現在的感覺很重要，我們一起找人幫忙。',
  );
  static const openingAbuse = Line(
    '謝謝你告訴我。發生這樣的事，不是你的錯。',
    '謝謝你說出來。發生這種事，不是你的錯。',
  );
  static const openingDistress = Line(
    '謝謝你跟我說。聽起來你現在真的不好受。',
    '謝謝你說出來。聽起來你現在真的不好受。',
  );
  static const openingGeneral = Line(
    '謝謝你跟我說。這件事很重要。',
    '謝謝你說出來。這件事很重要。',
  );

  /// 第二句：步步是小小的伙伴，這件事要讓大人一起來。
  static Line bridge(CrisisCategory? category) => switch (category) {
        CrisisCategory.abuse => bridgeSafe,
        _ => bridgeTogether,
      };

  static const bridgeTogether = Line(
    '這件事很重要，我想請大人一起來陪你。',
    '這件事很重要，值得讓大人一起來陪你。',
  );
  static const bridgeSafe = Line(
    '你值得覺得安全。這件事可以讓大人來幫你。',
    '你值得覺得安全。這件事可以讓大人來幫你。',
  );

  static const trustedAdult = Line(
    '可以去找一個你信任的大人說說看，像是家人、老師，或是學校的輔導老師。',
    '可以找一個你信任的大人說，例如家人、老師，或學校的輔導老師。',
  );

  static const helplinesTitle = Line(
    '想打電話找人說的話，這些電話都可以打：',
    '也可以打這些電話：',
  );

  /// 沒有 url_launcher：只把號碼大大地列出來（可以長按複製）。
  static const howToCall = Line(
    '用電話按下面的號碼就可以了。',
    '用電話撥下面的號碼就可以。',
  );

  /// 讓孩子知道這段話不會被留下來。
  static const notSaved = Line(
    '你剛剛寫的這段話，我不會記進筆記本。',
    '剛剛寫的這段話不會存進筆記本。',
  );

  static const close = Line.same('我知道了');

  /// LLM 伺服器回 `{safety: true}` 時，「步步學到」那格放的句子（不存進筆記本）。
  static const lessonSafety = Line(
    '這件事很重要。可以跟你信任的大人說說看，像是家人或老師。',
    '這件事很重要，可以跟你信任的大人說，像是家人或老師。',
  );

  /// 螢幕閱讀器用：專線號碼的說明。
  static const callLabel = Line.same('電話');
}
