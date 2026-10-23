/// 比對字表前的正規化（文案規則與危機偵測共用；docs/decisions.md F2）。
///
/// 與 `functions/src/normalize.ts` 的 `normalizeForMatch` 必須一字不差地同義：
/// 兩邊都跑 `functions/test/parity_samples.json` 與 `crisis_samples.json`。
///
/// 步驟：
/// 1. 寬度折疊（NFKC 中與孩子輸入有關的部分）：全形英數與符號 U+FF01–FF5E → 半形、
///    全形空白 U+3000 → 空白。伺服器端另外先跑完整 NFKC，結果在這些字上相同。
/// 2. 小寫。
/// 3. [variants]：逐字把簡體換成繁體（只收「只會出現在簡體」的字，表在各自的 JSON）。
/// 4. 去掉空白、標點（`\p{P}`）、符號與 emoji（`\p{S}`）、格式字元（`\p{Cf}`，含零寬空白）、
///    組合記號與變體選擇符（`\p{M}`）、注音聲調 ˊˇˋ˙；[keepZhuyin] 為 false 時連注音字母
///    （U+3100–312F、U+31A0–31BF）也去掉。
///
/// 去掉標點與注音，讓「好～棒」「好​棒」「想ㄚ死」這種夾字的寫法也比對得到。
/// 「我想ㄙˇ」這種用注音代替一個字的寫法，危機偵測另外用 `keepZhuyin: true` 的版本比對。
String normalizeForMatch(
  String text, {
  Map<String, String> variants = const {},
  bool keepZhuyin = false,
}) {
  final out = StringBuffer();
  for (final r in text.runes) {
    var c = r;
    if (c >= 0xFF01 && c <= 0xFF5E) {
      c -= 0xFEE0;
    } else if (c == 0x3000) {
      c = 0x20;
    }
    var ch = String.fromCharCode(c).toLowerCase();
    ch = variants[ch] ?? ch;
    out.write(ch);
  }
  return out.toString().replaceAll(keepZhuyin ? _noiseKeepZhuyin : _noise, '');
}

const _base = r'\s\p{P}\p{S}\p{Cf}\p{M}\u02CA\u02C7\u02CB\u02D9';
final RegExp _noise = RegExp('[$_base\\u3100-\\u312F\\u31A0-\\u31BF]', unicode: true);
final RegExp _noiseKeepZhuyin = RegExp('[$_base]', unicode: true);

/// 從 JSON 讀出的簡轉繁對照表（`{"聪": "聰"}`）。缺少時回傳空表。
Map<String, String> readVariants(Object? json) => json is Map
    ? {for (final e in json.entries) e.key as String: e.value as String}
    : const {};
