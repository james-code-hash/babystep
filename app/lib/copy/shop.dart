import 'line.dart';

/// 步步的小店（決策 L1）。不寫價格、不寫「免費」「限時」「快沒了」，只說可以試、可以拿。
abstract final class ShopCopy {
  static const entry = Line.same('步步的小店');
  static const entryHint = Line('逛逛看，喜歡哪一樣就拿去給步步穿。', '逛逛看，喜歡的就拿去穿。');

  static const title = Line.same('步步的小店');
  static const intro = Line('每一樣都可以先試穿，喜歡再穿上。', '點一下就能試穿，喜歡再穿上。');

  /// 這一季擺在最前面的架子。季節過了，東西還在店裡。
  static const seasonShelf = Line.same('{season}新來的');
  static const seasonShelfHint = Line('換季的時候，這個架子會擺上新東西。', '換季時這裡會擺上新東西。');
  static const spring = Line.same('春天');
  static const summer = Line.same('夏天');
  static const autumn = Line.same('秋天');
  static const winter = Line.same('冬天');

  static const hats = Line('頭上戴的', '頭上');
  static const necks = Line('脖子上的', '脖子');
  static const colors = Line('身體的顏色', '顏色');

  static const trying = Line('正在試穿：{item}', '試穿：{item}');
  static const wear = Line.same('穿上');
  static const putBack = Line.same('放回去');
  static const worn = Line.same('穿著');
}
