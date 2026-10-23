/// 小路畫面的數字。TODO(integrator): 搬進 `core/config.dart`（已列在 neededChanges）。
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
