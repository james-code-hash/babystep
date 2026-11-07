import 'line.dart';

/// 家長端的「加購」（決策 L2）。只在家長端出現；孩子端的文案不得提到買、價格（有護欄測試）。
/// 家長端一律用簡潔語氣顯示。
abstract final class ParentAddOnsCopy {
  static const sectionTitle = Line.same('加購插件包');
  static const sectionNote = Line.same(
    '一次買斷，買了就一直有。孩子那邊不會看到價格、沒買的東西，也不會有請你買的按鈕；買好之後，東西會直接出現在孩子的小店裡。',
  );

  static const seasonsName = Line.same('四季配件包');
  static const seasonsDescription = Line.same('春夏秋冬各兩件配件。小店最前面的架子會跟著季節換。');

  static const buy = Line.same('購買 {price}');
  static const owned = Line.same('已擁有');
  static const restore = Line.same('恢復購買');
  static const restoreNote = Line.same('換手機、重新安裝，或刪除全部資料之後，按這裡把買過的包找回來。');
  static const storeUnavailable = Line.same('現在連不到商店，晚點再試。');
  static const pending = Line.same('等待商店確認中⋯');
  static const failed = Line.same('購買沒有完成，可以再試一次。');
}
