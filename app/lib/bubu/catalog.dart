import '../copy/bubu.dart';
import '../copy/line.dart';

/// 一件可以裝扮的配件。所有配件一開始就全部可以選——沒有任何解鎖條件（底線 1、2）。
class Accessory {
  const Accessory(this.id, this.name);
  final String id;
  final Line name;
}

/// 裝扮目錄。全部一開始就能用，沒有條件、沒有價格、沒有「稀有」。
/// 刻意不放皇冠、獎牌、獎盃這類像「得獎」的東西。
abstract final class BubuCatalog {
  static const hats = <Accessory>[
    Accessory('none', BubuCopy.hatNone),
    Accessory('leaf', BubuCopy.hatLeaf),
    Accessory('flower', BubuCopy.hatFlower),
    Accessory('beanie', BubuCopy.hatBeanie),
    Accessory('straw', BubuCopy.hatStraw),
    Accessory('bucket', BubuCopy.hatBucket),
  ];

  static const necks = <Accessory>[
    Accessory('none', BubuCopy.neckNone),
    Accessory('scarf', BubuCopy.neckScarf),
    Accessory('bow', BubuCopy.neckBow),
    Accessory('bell', BubuCopy.neckBell),
    Accessory('bandana', BubuCopy.neckBandana),
  ];

  static const colors = <Accessory>[
    Accessory('cream', BubuCopy.colorCream),
    Accessory('peach', BubuCopy.colorPeach),
    Accessory('mint', BubuCopy.colorMint),
    Accessory('sky', BubuCopy.colorSky),
    Accessory('lavender', BubuCopy.colorLavender),
    Accessory('cocoa', BubuCopy.colorCocoa),
  ];
}
