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
/// TODO(build-c): 完整實作（正規化、全形／注音干擾、測試）。目前是 Foundation 的最小版本。
class CrisisDetector {
  CrisisDetector._(this._patterns, this.helplines);

  factory CrisisDetector.fromJsonString(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    final patterns = <CrisisCategory, List<RegExp>>{};
    for (final c in (j['categories'] as List).cast<Map<String, Object?>>()) {
      final cat = CrisisCategory.values.byName(c['id'] as String);
      patterns[cat] = [for (final p in (c['patterns'] as List).cast<String>()) RegExp(p)];
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

  /// 沒命中回傳 null。
  CrisisCategory? detect(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), '');
    for (final e in _patterns.entries) {
      if (e.value.any((re) => re.hasMatch(t))) return e.key;
    }
    return null;
  }
}
