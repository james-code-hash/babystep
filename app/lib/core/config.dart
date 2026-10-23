/// 所有可調的數字都在這裡（docs/decisions.md C9）。都是起始值，實測後再調。
/// 畫面與邏輯不要自己寫死這些數字。
abstract final class AppConfig {
  /// 每天最多計畫幾件事。
  static const int maxPlansPerDay = 3;

  /// 每天最少計畫幾件事（少於這個數字不能往下走）。
  static const int minPlansPerDay = 1;

  /// 探頭提醒卡每天最多出現幾次（只記在記憶體，不寫入資料庫）。
  static const int maxPeeksPerDay = 2;

  /// 步步一句話的字數上限（以字元計，含標點）。
  static const int maxBubuChars = 60;

  /// LLM 結果驗證不過時最多重試幾次（不含第一次）。
  static const int llmMaxRetries = 2;

  /// 等 LLM 超過這個時間，步步顯示「在想」。
  static const Duration llmThinkingAfter = Duration(seconds: 3);

  /// 等 LLM 超過這個時間，直接退回範本。
  static const Duration llmTimeout = Duration(seconds: 8);

  /// 孩子的話少於這個字數，視為「沒說話」，不呼叫 LLM。
  static const int minChildWordsForLlm = 2;

  /// 筆記本每天最多記幾則。
  static const int maxLessonsPerDay = 1;

  /// 自由輸入的字數上限（自訂事情、時間點、為什麼、反思）。
  static const int maxTaskChars = 20;
  static const int maxCueChars = 20;
  static const int maxWhyChars = 60;
  static const int maxReflectionChars = 120;

  /// 家長 PIN 的位數。
  static const int parentPinLength = 4;

  /// LLM 預設關閉；App 預設走範本模式（docs/decisions.md A3）。
  static const bool llmEnabledByDefault = false;

  /// 觸控目標最小尺寸（dp）。
  static const double minTapTarget = 48;

  /// Firebase Functions emulator（只在開發時用 --dart-define 帶入；沒帶就不碰 Firebase）。
  static const String functionsEmulatorHost =
      String.fromEnvironment('LLM_EMULATOR_HOST');
  static const int functionsEmulatorPort =
      int.fromEnvironment('LLM_EMULATOR_PORT', defaultValue: 5001);
  static const int authEmulatorPort =
      int.fromEnvironment('LLM_AUTH_EMULATOR_PORT', defaultValue: 9099);

  /// 範本引擎願意引用的孩子原話最短字數。
  static const int minQuoteChars = 2;
}

/// 步步的時段、動畫節奏。
abstract final class BubuConfig {
  /// 一天的四個時段（含起始小時，24 小時制）。
  static const int morningStartHour = 5;
  static const int dayStartHour = 11;
  static const int eveningStartHour = 17;
  static const int nightStartHour = 20;

  /// 問候時，抽到「季節句」而不是「時段句」的機率（0–1）。
  static const double seasonalGreetingChance = 0.3;

  /// 晚上的配色往夜色靠的比例（0–1），讓畫面柔和一點。
  static const double nightSoftening = 0.18;

  /// 「在想」三個點跑一輪的毫秒數。
  static const int thinkingCycleMs = 1200;

  /// 呼吸一輪的毫秒數（只在 `breathe: true` 時跑）。
  static const int breatheCycleMs = 3400;
}

/// 成長小路的版面與洞察門檻。
abstract final class PathConfig {
  /// 一塊石頭的直徑（dp）。
  static const double stoneSize = 72;

  /// 兩塊石頭之間的垂直距離（dp）。
  static const double stoneSpacing = 104;

  /// 小路左右擺動的幅度（佔可用寬度的比例）。
  static const double swayFraction = 0.26;

  /// 每塊石頭在擺動曲線上前進多少（弧度）。
  static const double swayStep = 1.1;

  /// 「最常用」的洞察至少要出現幾次才說（只出現一次就說「最常」很奇怪）。
  static const int insightMinRepeats = 2;
}

/// 家長區的預設值。
abstract final class ParentConfig {
  /// 新增提醒時段時預設的起訖（一天中的分鐘數）。
  static const int newSlotStartMinute = 16 * 60;
  static const int newSlotEndMinute = 17 * 60;
}
