import 'line.dart';

/// 月回顧「這個月的我」（J4，文案庫 §4.10、企劃書模組七）。用故事說，不用數據：沒有完成率、沒有比較、沒有斷點。
abstract final class MonthCopy {
  static const entry = Line('📖 這個月的我', '月回顧');
  static const title = Line('我的成長故事書', '月回顧');
  static const pageTitle = Line('{m}月的我', '{y}年{m}月的我');
  static const prev = Line('翻到上一個月', '上一個月');
  static const next = Line('翻到下一個月', '下一個月');

  static const days = Line('這個月，你有 {n} 天自己想清楚了要做什麼。', '這個月你自己想清楚了 {n} 天要做什麼。');
  static const topTask = Line('你最常給自己排的是「{task}」。', '你最常排的是「{task}」。');
  static const topCue = Line('而且常常是在「{cue}」之後開始的。', '常常在「{cue}」之後開始。');
  static const yours = Line('這些都是你自己排的。', '這些都是你自己決定的。');
  static const none = Line('這個月還沒有排過事。想排的時候再排就好。', '這個月還沒有排過事，想排的時候再排。');

  static const familyTitle = Line('這個月，家人想做的事', '家人這個月想做的事');
  static const familyItem = Line.same('{who}：{text}');

  static const lettersTitle = Line('💌 這個月的信', '這個月的信');
  static const childLabel = Line('我想跟家人說', '我給家人的一句話');
  static const childHint = Line('寫一句想跟家人說的話。家人在家長區看得到這一句。', '寫一句給家人的話，家人在家長區看得到。');
  static const childField = Line('想跟家人說的話', '給家人的一句話');
  static const childSave = Line('夾進這一頁', '放進去');
  static const childEdit = Line('改一下', '修改');
  static const childRemove = Line('拿掉', '拿掉');
  static const parentLabel = Line('家人寫給你的', '家人給你的一句話');
}

/// 家長區「這個月的信」。
abstract final class MonthParentCopy {
  static const title = Line.same('這個月的信');
  static const note = Line.same('孩子自己寫了給你的話，才會出現在這裡。你寫給孩子的一句話，會原封不動放在孩子的「這個月的我」裡。');
  static const childSaid = Line.same('孩子寫給你：');
  static const yourLetter = Line.same('你寫給孩子：');
  static const write = Line.same('寫一句給孩子');
  static const edit = Line.same('修改');
  static const field = Line.same('想跟孩子說的一句話');
  static const example = Line.same('例：我看到你這個月常常自己先把書包準備好。');
  static const empty = Line.same('這個月還沒有信。');
  static const earlier = Line.same('之前的信');
  static const monthLabel = Line.same('{y}/{m}');
}
