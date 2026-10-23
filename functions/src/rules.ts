import rulesJson from './copy_rules.json';

/** 年齡語氣，對應 Dart `AgeTone`。 */
export type Tone = 'lively' | 'concise';

export interface CopyViolation {
  level: 'L1' | 'L2' | 'concise' | 'length';
  ruleId: string;
  match: string;
}

interface RulesSource {
  maxChars: number;
  l1: { id: string; patterns: string[] }[];
  l2: { patterns: string[] };
  concise: { patterns: string[] };
}

const WHITESPACE = /\s+/g;

/** 以 code point 計的長度（等同 Dart `String.runes.length`）。 */
export function codePointLength(text: string): number {
  return [...text].length;
}

/**
 * 文案規則。語意與 `app/lib/core/copy_rules.dart` 的 `CopyRules` 相同：
 * 去掉空白後比對 L1 各組、L2、（concise 語氣時）幼稚詞；字數以 code point 計。
 */
export class CopyRules {
  private constructor(
    readonly maxChars: number,
    private readonly l1: ReadonlyMap<string, RegExp[]>,
    private readonly l2: RegExp[],
    private readonly concise: RegExp[],
  ) {}

  static fromJson(source: RulesSource): CopyRules {
    const compile = (list: string[]) => list.map((p) => new RegExp(p, 'g'));
    const l1 = new Map<string, RegExp[]>();
    for (const group of source.l1) l1.set(group.id, compile(group.patterns));
    return new CopyRules(source.maxChars, l1, compile(source.l2.patterns), compile(source.concise.patterns));
  }

  check(
    text: string,
    opts: { tone?: Tone; allowL2?: ReadonlySet<string>; checkLength?: boolean } = {},
  ): CopyViolation[] {
    const out: CopyViolation[] = [];
    const normalized = text.replace(WHITESPACE, '');
    const scan = (level: CopyViolation['level'], ruleId: string, patterns: RegExp[], allow?: ReadonlySet<string>) => {
      for (const re of patterns) {
        for (const m of normalized.matchAll(re)) {
          if (allow?.has(m[0])) continue;
          out.push({ level, ruleId, match: m[0] });
        }
      }
    };
    for (const [id, patterns] of this.l1) scan('L1', id, patterns);
    scan('L2', 'caution', this.l2, opts.allowL2 ?? new Set());
    if (opts.tone === 'concise') scan('concise', 'childish', this.concise);
    if (opts.checkLength) {
      const len = codePointLength(text);
      if (len > this.maxChars) out.push({ level: 'length', ruleId: 'maxChars', match: `${len}>${this.maxChars}` });
    }
    return out;
  }

  /** 動態產生的步步句子：L1、L2 全擋、語氣詞、字數。 */
  passesGenerated(text: string, tone: Tone): boolean {
    return text.trim().length > 0 && this.check(text, { tone, checkLength: true }).length === 0;
  }
}

export const defaultRules: CopyRules = CopyRules.fromJson(rulesJson as RulesSource);
