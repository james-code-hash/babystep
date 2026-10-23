import '../copy/line.dart';

/// 一件可以裝扮的配件。所有配件一開始就全部可以選——沒有任何解鎖條件（底線 1、2）。
class Accessory {
  const Accessory(this.id, this.name);
  final String id;
  final Line name;
}

/// 裝扮目錄。TODO(build-b): 補齊配件與名稱（名稱放 `copy/bubu.dart`）。
abstract final class BubuCatalog {
  static const hats = <Accessory>[Accessory('none', Line.same(''))];
  static const necks = <Accessory>[Accessory('none', Line.same(''))];
  static const colors = <Accessory>[Accessory('cream', Line.same(''))];
}
