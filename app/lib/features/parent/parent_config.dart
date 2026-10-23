/// 家長區的數字。TODO(integrator): 搬進 `core/config.dart`（已列在 neededChanges）。
abstract final class ParentConfig {
  /// 新增提醒時段時預設的起訖（一天中的分鐘數）。
  static const int newSlotStartMinute = 16 * 60;
  static const int newSlotEndMinute = 17 * 60;
}
