import '../domain/models.dart' show DressUp;
import 'catalog.dart';
import 'look.dart';

/// 裝扮放在步步身上的哪裡。
enum AccessorySlot { hat, neck, color }

/// 小店架子上的一樣東西：放在哪個位置＋目錄裡的哪一件。
class ShopItem {
  const ShopItem(this.slot, this.id);
  const ShopItem.hat(this.id) : slot = AccessorySlot.hat;
  const ShopItem.neck(this.id) : slot = AccessorySlot.neck;

  final AccessorySlot slot;
  final String id;

  Accessory get accessory => BubuShop.itemsFor(slot).firstWhere((a) => a.id == id);

  /// 把這一件換到 [current] 上，其他位置不動。
  DressUp wornOn(DressUp current) => switch (slot) {
        AccessorySlot.hat => current.copyWith(hat: id),
        AccessorySlot.neck => current.copyWith(neck: id),
        AccessorySlot.color => current.copyWith(color: id),
      };

  bool isWornIn(DressUp d) => switch (slot) {
        AccessorySlot.hat => d.hat == id,
        AccessorySlot.neck => d.neck == id,
        AccessorySlot.color => d.color == id,
      };

  @override
  bool operator ==(Object other) => other is ShopItem && other.slot == slot && other.id == id;

  @override
  int get hashCode => Object.hash(slot, id);
}

/// 步步的小店（決策 L1）。
///
/// - 每一樣都不用錢、沒有條件，直接就能拿去穿（底線 1）。這裡刻意沒有價格、數量、稀有度這些概念。
/// - 「這一季新來的」只是把當季的東西擺到最前面；季節過了東西還在店裡，不會收起來，
///   所以沒有「錯過就沒了」（底線 3）。
/// - 架子只看日期，不看孩子做了什麼（底線 2）。
abstract final class BubuShop {
  static const seasonal = <Season, List<ShopItem>>{
    Season.spring: [ShopItem.hat('sakura'), ShopItem.neck('daisy')],
    Season.summer: [ShopItem.hat('melon'), ShopItem.neck('shell')],
    Season.autumn: [ShopItem.hat('mushroom'), ShopItem.neck('acorn')],
    Season.winter: [ShopItem.hat('earmuffs'), ShopItem.neck('snowpin')],
  };

  static List<Accessory> itemsFor(AccessorySlot slot) => switch (slot) {
        AccessorySlot.hat => BubuCatalog.hats,
        AccessorySlot.neck => BubuCatalog.necks,
        AccessorySlot.color => BubuCatalog.colors,
      };

  /// 這一季擺在最前面的東西。只吃日期。
  static List<ShopItem> featured(DateTime now) => seasonal[seasonOf(now)] ?? const [];

  /// 店裡其他的東西（某個位置上、不在這一季架子上的；「不戴」這種空選項不擺上架）。
  static List<ShopItem> shelf(AccessorySlot slot, DateTime now) {
    final front = featured(now).toSet();
    return [
      for (final a in itemsFor(slot))
        if (a.id != 'none' && !front.contains(ShopItem(slot, a.id))) ShopItem(slot, a.id),
    ];
  }
}
