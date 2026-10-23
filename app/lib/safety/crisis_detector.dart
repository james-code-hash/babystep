import 'dart:convert';

import '../core/text_match.dart';

/// 危機訊號的三類（C6）。
enum CrisisCategory { selfHarm, abuse, severeDistress }

/// 求助專線（來源：`shared/crisis_patterns.json`）。
class Helpline {
  const Helpline({required this.id, required this.name, required this.number, required this.note});
  final String id;
  final String name;
  final String number;
  final String note;
}

/// 本機危機偵測。所有自由輸入送出前都要過這裡；命中就走安全回應，不呼叫 LLM、不存進筆記。
///
/// 字表在 `assets/crisis_patterns.json`（與 Cloud Function 共用）。比對前先 [normalize]，
/// 讓「想 死」「想、死」「想　死」「想😢死」「想ㄚ死」這種中間夾了空白、標點、表情、注音的寫法
/// 也抓得到；再用 [normalizeKeepingZhuyin] 比一次，抓「我想ㄙˇ」這種用注音代替字的寫法。
/// 原則是「寧可誤判也不漏判」；誤判的代價只是一頁溫和的安全回應。
///
/// ⏸ 字表需要兒童心理專業審核（docs/decisions.md C6）。
class CrisisDetector {
  CrisisDetector._(this._patterns, this.helplines, this.variants);

  factory CrisisDetector.fromJsonString(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    final patterns = <CrisisCategory, List<RegExp>>{};
    for (final c in (j['categories'] as List).cast<Map<String, Object?>>()) {
      final cat = CrisisCategory.values.byName(c['id'] as String);
      patterns[cat] = [for (final p in (c['patterns'] as List).cast<String>()) RegExp(p, caseSensitive: false)];
    }
    final helplines = [
      for (final h in (j['helplines'] as List).cast<Map<String, Object?>>())
        Helpline(
          id: h['id'] as String,
          name: h['name'] as String,
          number: h['number'] as String,
          note: h['note'] as String,
        ),
    ];
    return CrisisDetector._(patterns, helplines, readVariants(j['simplifiedToTraditional']));
  }

  final Map<CrisisCategory, List<RegExp>> _patterns;
  final List<Helpline> helplines;

  /// 比對前逐字換成繁體的簡體字（`simplifiedToTraditional`）。
  final Map<String, String> variants;

  /// 比對順序：自傷 → 受虐 → 嚴重困擾（同時命中時，回應最需要的那一類）。
  static const _priority = [CrisisCategory.selfHarm, CrisisCategory.abuse, CrisisCategory.severeDistress];

  /// 沒命中回傳 null。不會丟例外。
  CrisisCategory? detect(String? text) {
    if (text == null || text.isEmpty) return null;
    // 兩種寫法都比：去掉注音（「想ㄚ死」）與保留注音字母（「我想ㄙˇ」）。
    final forms = {normalize(text), normalizeKeepingZhuyin(text)}..remove('');
    if (forms.isEmpty) return null;
    for (final cat in _priority) {
      final list = _patterns[cat];
      if (list != null && list.any((re) => forms.any(re.hasMatch))) return cat;
    }
    return null;
  }

  /// 比對前的正規化（連注音字母也去掉）：見 [normalizeForMatch]。
  /// 與 `functions/src/crisis.ts` 的 `normalizeForCrisis` 相同。
  String normalize(String text) => normalizeForMatch(text, variants: variants);

  /// 保留注音字母的正規化：讓「我想ㄙˇ」這種用注音代替一個字的寫法比對得到。
  /// 與 `normalizeForCrisisKeepZhuyin` 相同。
  String normalizeKeepingZhuyin(String text) => normalizeForMatch(text, variants: variants, keepZhuyin: true);
}
