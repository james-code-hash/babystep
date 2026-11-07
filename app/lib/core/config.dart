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

  /// 孩子幫步步取的名字最多幾個字（D6）。
  static const int maxPetNameChars = 6;
  static const int maxWhyChars = 60;
  static const int maxReflectionChars = 120;

  /// 全家一起：「你是誰」、家人留言的字數上限（I2）。
  static const int maxFamilyWhoChars = 6;
  static const int maxFamilyNoteChars = 40;

  /// 月回顧的信（孩子或家人寫的一句話）最多幾個字。
  static const int maxLetterChars = 40;

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

/// 時間點範本大概落在一天的哪一段（從 0:00 算的分鐘，[start, end)）。
/// 探頭時只拿落在「現在」的時間點來問「現在方便嗎？」（README 已知問題 1）。
abstract final class CueTimeConfig {
  static const morning = (start: 5 * 60, end: 11 * 60);
  static const noon = (start: 11 * 60, end: 14 * 60);
  static const afterSchool = (start: 15 * 60, end: 19 * 60);
  static const dinner = (start: 18 * 60, end: 21 * 60 + 30);
  static const night = (start: 19 * 60, end: 23 * 60);
}

/// 朗讀（I6）：裝置內建語音的設定。
abstract final class ReadAloudConfig {
  static const language = 'zh-TW';

  /// 0–1；比預設慢一點，給剛開始識字的孩子。
  static const double rate = 0.42;
  static const double pitch = 1.05;
}

/// 分齡（I3）。lively ≈ 小樹苗（6–8 歲）、concise ≈ 小探險家（9–12 歲）；畫面上不標年齡（B5）。
abstract final class AgeConfig {
  /// 小樹苗建議一天 1–2 件（軟性提示；硬性上限仍是 [AppConfig.maxPlansPerDay]）。
  static const int sproutSuggestedPlans = 2;

  /// 小樹苗的字放大倍數（企劃書 §10.1「大字」）。家長區不放大。
  static const double sproutTextScale = 1.12;
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

/// 平板版面（docs/decisions.md E11）。手機的數字維持原本的樣子。
abstract final class LayoutConfig {
  /// 螢幕短邊（dp）至少這麼寬就當平板。
  static const double tabletMinShortestSide = 600;

  /// 單欄內容的最大寬度。
  static const double contentMaxWidthPhone = 560;
  static const double contentMaxWidthTablet = 720;

  /// 雙欄（步步在旁邊）或多欄筆記本整體的最大寬度。
  static const double wideMaxWidth = 1100;

  /// 可用寬度至少這麼寬才把步步放到旁邊（平板橫放）。
  static const double twoPaneMinWidth = 900;

  /// 兩欄之間的距離（舞台的寬度見 [stageFraction]）。
  static const double paneGap = 32;

  /// 內容外側再留的左右邊距（手機為 0，維持原本版面）。
  static const double frameGutterPhone = 0;
  static const double frameGutterTablet = 24;

  /// 步步的大小（手機／平板）。
  static const double bubuHeroPhone = 160;
  static const double bubuHeroTablet = 224;
  static const double bubuStepPhone = 88;
  static const double bubuStepTablet = 120;
  static const double bubuReviewPhone = 120;
  static const double bubuReviewTablet = 168;
  static const double bubuEmptyPhone = 140;
  static const double bubuEmptyTablet = 196;

  /// 步步在旁邊那一欄（舞台）時的大小。
  static const double bubuSidePane = 280;

  /// 平板橫放的「舞台」：步步那一欄佔可用寬度的比例，以及上下限（E12）。
  static const double stageFraction = 0.38;
  static const double stageMinWidth = 340;
  static const double stageMaxWidth = 460;

  /// 平板橫放時，主要內容那一欄的最大寬度。
  static const double stageMainMaxWidth = 600;

  /// 平板上整個畫面四周留的邊（舞台不貼螢幕邊）。
  static const double stageInset = 20;

  /// 平板直放時，步步在上方那條舞台的最大高度比例（其餘留給內容）。
  static const double bannerMaxHeightFraction = 0.4;

  /// 平板的按鈕與選項（比手機大一號，給手指和小孩的手）。
  static const double tabletButtonHeight = 64;
  static const double tabletButtonMinWidth = 260;

  /// 平板直放時，首頁上方舞台裡步步的大小。
  static const double bubuBannerTablet = 168;

  /// 平板首頁的入口卡片：一張至少這麼寬。
  static const double navTileMinWidth = 200;


  /// 筆記本：平板上一頁至少要這麼寬，最多排幾欄。
  static const double notebookColumnMinWidth = 340;
  static const int notebookMaxColumns = 3;

  /// 家長 PIN 畫面的最大寬度（鍵盤置中，不撐滿大螢幕）。
  static const double pinMaxWidth = 420;
}

/// 探索角（J1）。
abstract final class ExploreConfig {
  /// 塗鴉牆畫布高度（dp）。
  static const double canvasHeight = 320;

  /// 平板上的畫布高度（畫布在旁邊一欄，可以大一點）。
  static const double canvasHeightTablet = 460;

  /// 筆畫粗細（dp）。
  static const double strokeWidth = 6;
}

/// 驚喜盒（J2）。
abstract final class SurpriseConfig {
  /// 某一天探索角出現驚喜盒的機率（依日期決定，同一天都一樣）。
  static const double boxChance = 0.35;

  /// 首頁輕點步步後，小反應停留的毫秒數。
  static const int pokeMs = 2200;
}

/// 成長軌跡的另外兩種樣子（J3）：樹與星空。
abstract final class TrailConfig {
  /// 一片葉子的直徑（dp）。
  static const double leafSize = 44;

  /// 相鄰兩片葉子中心的距離（dp，蜂巢格）。
  static const double leafSpacing = 46;

  /// 樹幹的高度（dp）。
  static const double trunkHeight = 120;

  /// 星空一列幾顆星。
  static const int starsPerRow = 4;

  /// 星空一列的高度（dp）。
  static const double starRowHeight = 88;

  /// 一顆星的大小（dp）。
  static const double starSize = 40;

  /// 地圖一列幾個地方、一列多高、一個地方多大（dp）。
  static const int mapPerRow = 3;
  static const double mapRowHeight = 96;
  static const double mapPlaceSize = 48;

  /// 同一列裡上下起伏的幅度（一列高度的比例）與頻率。
  static const double mapWaveFraction = 0.12;
  static const double mapWaveStep = 1.7;

  /// 虛線的路：一段長、間隔（一段＋空白）、粗細。
  static const double mapDash = 7;
  static const double mapDashPeriod = 14;
  static const double mapRouteWidth = 3;

  /// 風景：每多少平方 dp 一個小山或小樹；小山的半寬與高、小樹的半徑。
  static const double mapSceneryArea = 9000;
  static const double mapHillHalfWidth = 14;
  static const double mapHillHeight = 12;
  static const double mapTreeRadius = 5;
}

/// 步步的小店（決策 L1）。這裡只有版面數字，沒有價格。
abstract final class ShopConfig {
  /// 架子上每一格的寬度與格子裡小步步的大小。
  static const double tileWidth = 112;
  static const double tileBubu = 76;
}
