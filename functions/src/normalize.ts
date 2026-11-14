/**
 * 比對字表前的正規化（文案規則與危機偵測共用；docs/decisions.md F2）。
 *
 * 與 `app/lib/core/text_match.dart` 的 `normalizeForMatch` 同義：兩邊都跑
 * `test/parity_samples.json` 與 `test/crisis_samples.json`。
 *
 * 1. NFKC，再做一次寬度折疊（全形 U+FF01–FF5E → 半形、U+3000 → 空白）。Dart 沒有內建 NFKC，
 *    只做寬度折疊；兩邊在孩子會打的字上結果相同。
 * 2. 小寫。
 * 3. `variants`：逐字把簡體換成繁體。
 * 4. 去掉空白、標點、符號／emoji、格式字元（零寬）、組合記號、注音聲調；
 *    `keepZhuyin` 為 false 時連注音字母（U+3100–312F、U+31A0–31BF）也去掉。
 */
const BASE = '\\s\\p{P}\\p{S}\\p{Cf}\\p{M}\\u02CA\\u02C7\\u02CB\\u02D9';
const NOISE = new RegExp(`[${BASE}\\u3100-\\u312F\\u31A0-\\u31BF]`, 'gu');
const NOISE_KEEP_ZHUYIN = new RegExp(`[${BASE}]`, 'gu');

export function normalizeForMatch(
  text: string,
  opts: { variants?: Readonly<Record<string, string>>; keepZhuyin?: boolean } = {},
): string {
  const variants = opts.variants ?? {};
  let out = '';
  for (const ch of text.normalize('NFKC')) {
    let c = ch.codePointAt(0)!;
    if (c >= 0xff01 && c <= 0xff5e) c -= 0xfee0;
    else if (c === 0x3000) c = 0x20;
    const lower = String.fromCodePoint(c).toLowerCase();
    out += variants[lower] ?? lower;
  }
  return out.replace(opts.keepZhuyin ? NOISE_KEEP_ZHUYIN : NOISE, '');
}
