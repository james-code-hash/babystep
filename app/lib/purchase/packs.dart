import '../copy/line.dart';

/// 家長在家長端買的一個插件包（決策 L2、L3）。
///
/// - 只有家長端看得到包、價格、購買按鈕；孩子端看不到錢，也看不到沒買的東西（底線 8）。
/// - **只賣家庭用的工具**（例如錯題的「再看一次口袋」），永遠不賣步步的衣服、外觀、驚喜盒內容，
///   也不賣孩子會想要、會去跟家長討的東西（決策 L3，有護欄測試）。所以這裡刻意沒有任何裝扮欄位。
/// - 一次買斷、永久擁有。
class AddOnPack {
  const AddOnPack({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
  });

  /// 本機紀錄用的 id。
  final String id;

  /// App Store Connect／Play Console 上的商品 id（非消耗型）。兩邊要建一樣的 id。
  final String productId;
  final Line name;
  final Line description;
}

abstract final class AddOnPacks {
  /// 目前上架的插件。第一個工具（再看一次口袋）在另一個 PR 加進來。
  static const all = <AddOnPack>[];

  static AddOnPack? byProductId(String productId, [List<AddOnPack> packs = all]) {
    for (final p in packs) {
      if (p.productId == productId) return p;
    }
    return null;
  }
}
