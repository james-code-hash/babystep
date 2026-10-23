import 'dart:convert';

import '../domain/models.dart';

/// 文案規則（來源：`shared/copy_rules.json`，同步到 `assets/copy_rules.json`）。
///
/// 純 Dart：App 執行期過濾、`tool/copy_lint.dart`、測試共用同一份實作。
class CopyRules {
  CopyRules._(this.maxChars, this.l1, this.l2, this.concise);

  factory CopyRules.fromJsonString(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    List<RegExp> compile(Object? list) =>
        [for (final p in (list as List).cast<String>()) RegExp(p)];
    final l1 = <String, List<RegExp>>{};
    for (final group in (j['l1'] as List).cast<Map<String, Object?>>()) {
      l1[group['id'] as String] = compile(group['patterns']);
    }
    return CopyRules._(
      j['maxChars'] as int,
      l1,
      compile((j['l2'] as Map<String, Object?>)['patterns']),
      compile((j['concise'] as Map<String, Object?>)['patterns']),
    );
  }

  final int maxChars;
  final Map<String, List<RegExp>> l1;
  final List<RegExp> l2;
  final List<RegExp> concise;

  /// 檢查一句話。
  ///
  /// - [tone] 是 concise 時，額外檢查幼稚詞。
  /// - [allowL2] 是靜態文案用 `// copy-allow:` 標記允許的 L2 詞；LLM 輸出永遠不傳。
  /// - [checkLength] 為 true 時檢查 [maxChars]（步步說的話）。
  List<CopyViolation> check(
    String text, {
    AgeTone? tone,
    Set<String> allowL2 = const {},
    bool checkLength = false,
  }) {
    final out = <CopyViolation>[];
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    void scan(String level, String id, List<RegExp> patterns) {
      for (final re in patterns) {
        for (final m in re.allMatches(normalized)) {
          out.add(CopyViolation(level, id, m.group(0)!));
        }
      }
    }

    l1.forEach((id, patterns) => scan('L1', id, patterns));
    for (final re in l2) {
      for (final m in re.allMatches(normalized)) {
        if (!allowL2.contains(m.group(0))) out.add(CopyViolation('L2', 'caution', m.group(0)!));
      }
    }
    if (tone == AgeTone.concise) scan('concise', 'childish', concise);
    if (checkLength && text.runes.length > maxChars) {
      out.add(CopyViolation('length', 'maxChars', '${text.runes.length}>$maxChars'));
    }
    return out;
  }

  /// LLM（或任何動態產生的）步步句子：L1、L2 全擋、語氣詞、字數。
  bool passesGenerated(String text, AgeTone tone) =>
      text.trim().isNotEmpty && check(text, tone: tone, checkLength: true).isEmpty;
}

class CopyViolation {
  const CopyViolation(this.level, this.ruleId, this.match);
  final String level;
  final String ruleId;
  final String match;

  @override
  String toString() => '[$level/$ruleId] 「$match」';
}
