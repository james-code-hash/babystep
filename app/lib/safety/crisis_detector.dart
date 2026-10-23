import 'dart:convert';

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
/// 讓「想 死」「想、死」「想　死」「想😢死」這種中間夾了空白、標點、表情的寫法也抓得到。
/// 原則是「寧可誤判也不漏判」；誤判的代價只是一頁溫和的安全回應。
///
/// ⏸ 字表需要兒童心理專業審核（docs/decisions.md C6）。
class CrisisDetector {
  CrisisDetector._(this._patterns, this.helplines);

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
    return CrisisDetector._(patterns, helplines);
  }

  final Map<CrisisCategory, List<RegExp>> _patterns;
  final List<Helpline> helplines;

  /// 比對順序：自傷 → 受虐 → 嚴重困擾（同時命中時，回應最需要的那一類）。
  static const _priority = [CrisisCategory.selfHarm, CrisisCategory.abuse, CrisisCategory.severeDistress];

  /// 沒命中回傳 null。不會丟例外。
  CrisisCategory? detect(String? text) {
    if (text == null || text.isEmpty) return null;
    final t = normalize(text);
    if (t.isEmpty) return null;
    for (final cat in _priority) {
      final list = _patterns[cat];
      if (list != null && list.any((re) => re.hasMatch(t))) return cat;
    }
    return null;
  }

  /// 全形英數與全形空白 → 半形。
  static String _toHalfWidth(String s) {
    final out = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0xFF01 && r <= 0xFF5E) {
        out.writeCharCode(r - 0xFEE0);
      } else if (r == 0x3000) {
        out.writeCharCode(0x20);
      } else {
        out.writeCharCode(r);
      }
    }
    return out.toString();
  }

  /// 空白、標點、符號、表情、零寬字元、注音聲調符號。
  ///
  /// 用 Unicode 類別：`\s`（含全形空白）、`\p{P}`（所有標點，含全形與中文標點）、`\p{S}`（符號，
  /// 含表情）、`\p{Cf}`（零寬字元等格式字元）、
  /// `\p{M}`（變體選擇符、組合記號），加上注音的聲調 ˊˇˋ˙。中文字、注音字母、英數不會被拿掉。
  static final RegExp _noise = RegExp(
    r'[\s\p{P}\p{S}\p{Cf}\p{M}\u02CA\u02C7\u02CB\u02D9]',
    unicode: true,
  );

  /// 比對前的正規化：全形轉半形 → 小寫 → 去掉空白、標點、符號、表情、零寬字元。
  static String normalize(String text) => _toHalfWidth(text).toLowerCase().replaceAll(_noise, '');
}
