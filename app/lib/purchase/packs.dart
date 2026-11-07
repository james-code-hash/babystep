import '../bubu/shop.dart';
import '../copy/line.dart';
import '../copy/parent_add_ons.dart';

/// 家長在家長端買的一個插件包（決策 L2）。
///
/// - 只有家長端看得到包、價格、購買按鈕；孩子端只會看到「已經有的東西」（底線 8 改寫後的版本）。
/// - 包裡只有樣子或玩法，不放核心循環、安全功能，也不跟孩子做了什麼有關（底線 1、2）。
/// - 一次買斷、永久擁有：不會因為過期把步步身上的東西拿走（底線 2）。
class AddOnPack {
  const AddOnPack({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
    required this.items,
  });

  /// 本機紀錄用的 id。
  final String id;

  /// App Store Connect／Play Console 上的商品 id（非消耗型）。兩邊要建一樣的 id。
  final String productId;
  final Line name;
  final Line description;

  /// 這個包帶來的裝扮。
  final List<ShopItem> items;
}

abstract final class AddOnPacks {
  static const seasons = AddOnPack(
    id: 'seasons',
    productId: 'little_steps.pack.seasons',
    name: ParentAddOnsCopy.seasonsName,
    description: ParentAddOnsCopy.seasonsDescription,
    items: [
      ShopItem.hat('sakura'),
      ShopItem.neck('daisy'),
      ShopItem.hat('melon'),
      ShopItem.neck('shell'),
      ShopItem.hat('mushroom'),
      ShopItem.neck('acorn'),
      ShopItem.hat('earmuffs'),
      ShopItem.neck('snowpin'),
    ],
  );

  static const all = <AddOnPack>[seasons];

  static AddOnPack? byProductId(String productId) {
    for (final p in all) {
      if (p.productId == productId) return p;
    }
    return null;
  }

  /// 還沒買的包裡的東西：孩子端整個不顯示（不出現上鎖的格子，避免孩子去纏家長）。
  static Set<ShopItem> notOwnedItems(Set<String> ownedPackIds) => {
        for (final p in all)
          if (!ownedPackIds.contains(p.id)) ...p.items,
      };
}
