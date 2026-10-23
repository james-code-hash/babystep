import 'look.dart' show DayPart, dayPartOf;

/// 步步的表情只有這六種（C10）。沒有難過、生病、虛弱。
enum BubuExpression { happy, curious, caring, calm, surprised, relaxed }

/// 步步「平常待著」的表情（首頁）。**只看時段**——不看今天有沒有計畫、有沒有聊完（底線 2）。
/// 早上開心、白天與傍晚平靜、晚上放鬆；每個孩子、每一天都一樣。
BubuExpression restingExpression(DateTime now) => switch (dayPartOf(now)) {
      DayPart.morning => BubuExpression.happy,
      DayPart.day => BubuExpression.calm,
      DayPart.evening => BubuExpression.calm,
      DayPart.night => BubuExpression.relaxed,
    };

/// 對話裡步步問了一個問題：還沒回答時歪頭想（好奇），聽到回答後溫柔地看著你（關心）。
/// **不管孩子回答了什麼**都是同一個表情：只吃「回答了沒」這一個 bool（底線 2、4）。
BubuExpression listeningExpression({required bool answered}) =>
    answered ? BubuExpression.caring : BubuExpression.curious;
