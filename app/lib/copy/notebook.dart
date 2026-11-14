import 'line.dart';

/// 步步的筆記本（C4）。不顯示數量、沒有目標、沒有進度。
abstract final class NotebookCopy {
  static const title = Line('步步的筆記本', '筆記本');

  static const empty = Line('筆記本現在空空的～步步學到想記的事，就會寫在這裡。', '這裡還是空的。步步學到想記的事，會寫在這裡。');

  static const favoritesOnly = Line('只看愛心', '只看愛心');
  static const emptyFavorites = Line('這裡還沒有畫愛心的那一頁喔。', '還沒有畫愛心的頁面。');

  static const favoriteOn = Line('畫上愛心', '加愛心');
  static const favoriteOff = Line('拿掉愛心', '拿掉愛心');

  static const shareWithParent = Line.same('給家長看');
  static const shareExplain = Line('打開的話，家長只會看到這一句話。', '打開的話，家長只看得到這一句。');

  static const quote = Line('你說：「{quote}」', '你說：「{quote}」');
}
