import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/catalog.dart';
import 'package:little_steps/bubu/look.dart';
import 'package:little_steps/bubu/shop.dart';
import 'package:little_steps/domain/models.dart';

void main() {
  test('every season has its own shelf, and every item on it is a real catalog item', () {
    for (final season in Season.values) {
      final items = BubuShop.seasonal[season]!;
      expect(items, isNotEmpty, reason: '$season');
      for (final item in items) {
        expect(BubuShop.itemsFor(item.slot).map((a) => a.id), contains(item.id), reason: '${item.slot} ${item.id}');
      }
    }
  });

  test('the front shelf follows the date only', () {
    expect(BubuShop.featured(DateTime(2026, 4, 1)), BubuShop.seasonal[Season.spring]);
    expect(BubuShop.featured(DateTime(2026, 7, 1)), BubuShop.seasonal[Season.summer]);
    expect(BubuShop.featured(DateTime(2026, 10, 1)), BubuShop.seasonal[Season.autumn]);
    expect(BubuShop.featured(DateTime(2027, 1, 1)), BubuShop.seasonal[Season.winter]);
  });

  test('nothing leaves the shop when the season changes (底線 3：沒有錯過就沒了)', () {
    for (final month in List.generate(12, (i) => i + 1)) {
      final now = DateTime(2026, month, 15);
      for (final slot in AccessorySlot.values) {
        final onShelves = {
          ...BubuShop.featured(now).where((i) => i.slot == slot).map((i) => i.id),
          ...BubuShop.shelf(slot, now).map((i) => i.id),
        };
        final all = BubuShop.itemsFor(slot).map((a) => a.id).where((id) => id != 'none').toSet();
        expect(onShelves, all, reason: 'month $month $slot');
      }
    }
  });

  test('seasonal items are never shown twice on the same day', () {
    final now = DateTime(2026, 11, 7);
    for (final slot in AccessorySlot.values) {
      final rest = BubuShop.shelf(slot, now);
      for (final f in BubuShop.featured(now)) {
        expect(rest, isNot(contains(f)));
      }
    }
  });

  test('wearing an item changes only its own slot', () {
    const start = DressUp(hat: 'leaf', neck: 'bow', color: 'mint');
    expect(const ShopItem.hat('melon').wornOn(start), const DressUp(hat: 'melon', neck: 'bow', color: 'mint'));
    expect(const ShopItem.neck('acorn').wornOn(start), const DressUp(hat: 'leaf', neck: 'acorn', color: 'mint'));
    expect(const ShopItem(AccessorySlot.color, 'sky').wornOn(start), const DressUp(hat: 'leaf', neck: 'bow', color: 'sky'));
    expect(const ShopItem.neck('bow').isWornIn(start), isTrue);
  });

  test('every new seasonal item is drawn on Bubu (look keeps it)', () {
    for (final items in BubuShop.seasonal.values) {
      for (final item in items) {
        final l = look(item.wornOn(DressUp.initial), DateTime(2026, 11, 7, 10));
        switch (item.slot) {
          case AccessorySlot.hat:
            expect(l.hat, item.id);
          case AccessorySlot.neck:
            expect(l.neck, item.id);
          case AccessorySlot.color:
            expect(BubuCatalog.colors.map((a) => a.id), contains(item.id));
        }
      }
    }
  });
}
