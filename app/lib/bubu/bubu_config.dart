/// 步步自己用的數字。整合時請搬進 `core/config.dart`（列在 neededChanges）。
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
