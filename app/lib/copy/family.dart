import 'line.dart';

/// 全家一起（企劃書 §9.5、文案庫 §4.11、§4.12）。
///
/// 規則：
/// - 家人的「今天的我」只是讓孩子看到大人也在練習；沒有做到了沒、沒有「全家幾個人都想好了」這種計數。
/// - 家人的留言由步步**原封不動**轉達，步步不加評論、不替家長加碼（§4.11）。
/// - 家長端看不到孩子看過了沒，也看不到孩子有沒有關掉轉達。
abstract final class FamilyCopy {
  // ---------------------------------------------------------------- 家長區
  static const sectionTitle = Line.same('全家一起');
  static const sectionNote = Line.same('步步屬於全家。你也可以寫下今天自己想做的一件事，或留一句話給孩子，由步步轉達。');

  static const todayTitle = Line.same('大人的「今天的我」');
  static const todayNote = Line.same('寫一件你今天自己想做的小事，孩子會在首頁看到。這裡不記錄做到了沒有。');
  static const todayEmpty = Line.same('今天還沒有寫。');
  static const todayAdd = Line.same('寫一件');
  static const whoLabel = Line.same('你是誰（例如：媽媽）');
  static const todayTextLabel = Line.same('今天想做的事');

  /// 「你是誰」的快速選項。
  static const whoPresets = [
    Line.same('爸爸'),
    Line.same('媽媽'),
    Line.same('阿公'),
    Line.same('阿嬤'),
    Line.same('外公'),
    Line.same('外婆'),
  ];

  static const notesTitle = Line.same('留一句話給孩子');
  static const notesNote = Line.same(
      '步步會原封不動轉達，不加評論。只轉達鼓勵：評價、催促或要求的話會被擋下來。孩子可以在自己的設定裡關掉轉達。');
  static const notesEmpty = Line.same('還沒有留話。');
  static const noteAdd = Line.same('寫一句');
  static const noteTextLabel = Line.same('想對孩子說的話');
  static const noteExample = Line.same('例如：我看到你今天自己把書包整理好了。');

  /// `{word}` 是被擋下來的那幾個字。
  static const blocked = Line.same('這句話裡有「{word}」。步步只轉達鼓勵，不轉達評價或催促，換個說法試試？');
  static const entryDate = Line.same('{m}月{d}日');

  // ---------------------------------------------------------------- 孩子的首頁
  static const homeTitle = Line('家人今天想做的事', '家人今天想做的事');
  static const homeItem = Line.same('{who}：{text}');

  static const noteInvite = Line('{who}有留話給你喔，要看嗎？', '{who}留了一句話給你，要看嗎？');
  static const noteOpen = Line('看看', '看');
  static const noteLater = Line.same('等一下');
  static const noteFrom = Line.same('{who}說：');
  static const noteClose = Line.same('好');

  // ---------------------------------------------------------------- 孩子的設定
  static const settingTitle = Line('家人的留言', '家人的留言');
  static const settingHint = Line('打開的話，家人留給你的話會由步步轉達。', '打開時，步步會轉達家人留給你的話。');
}
