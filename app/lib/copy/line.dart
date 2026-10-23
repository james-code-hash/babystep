import 'dart:math';

import '../domain/models.dart';

/// 一句使用者看得到的話，有活潑（lively）與簡潔（concise）兩種說法。
///
/// 規則：
/// - 所有使用者看得到的中文句子都放在 `lib/copy/`，用 [Line] 或 [LinePool] 包起來。
/// - 可以有 `{task}`、`{cue}`、`{quote}` 這類佔位符，用 [fill] 帶入。
/// - L2 詞（沒關係、很好⋯）要在同一行或上一行寫 `// copy-allow: <詞>` 才能過 copy_lint。
class Line {
  const Line(this.lively, this.concise);

  /// 兩種語氣說法一樣。
  const Line.same(String text)
      : lively = text,
        concise = text;

  final String lively;
  final String concise;

  String of(AgeTone tone) => tone == AgeTone.lively ? lively : concise;

  String fill(AgeTone tone, Map<String, String> values) {
    var s = of(tone);
    values.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}

/// 一組可以隨機抽的說法（維持新鮮感）。
class LinePool {
  const LinePool(this.lines);
  final List<Line> lines;

  int get length => lines.length;

  Line pickLine(Random random) => lines[random.nextInt(lines.length)];

  String pick(AgeTone tone, Random random) => pickLine(random).of(tone);
}
