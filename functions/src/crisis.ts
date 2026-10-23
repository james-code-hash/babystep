import crisisJson from './crisis_patterns.json';

/** 對應 Dart `CrisisCategory`。 */
export type CrisisCategory = 'selfHarm' | 'abuse' | 'severeDistress';

interface CrisisSource {
  categories: { id: string; patterns: string[] }[];
}

/**
 * 比對前的正規化：
 * 1. NFKC：全形英數／標點轉半形、相容字元統一。
 * 2. 去掉空白、標點、符號、格式字元（零寬字元等）、注音符號——
 *    「想 死」「想，死」「想ㄚ死」「想​死」都要攔得到。寧可誤判也不漏判（C6）。
 */
export function normalizeForCrisis(text: string): string {
  return text
    .normalize('NFKC')
    .replace(/[\s\p{P}\p{S}\p{Cf}㄀-ㄯㆠ-ㆿˇˊˋ˙]/gu, '');
}

export class CrisisDetector {
  private constructor(private readonly patterns: ReadonlyArray<[CrisisCategory, RegExp[]]>) {}

  static fromJson(source: CrisisSource): CrisisDetector {
    const known: CrisisCategory[] = ['selfHarm', 'abuse', 'severeDistress'];
    const entries: [CrisisCategory, RegExp[]][] = source.categories.map((c) => {
      if (!known.includes(c.id as CrisisCategory)) throw new Error(`unknown crisis category ${c.id}`);
      return [c.id as CrisisCategory, c.patterns.map((p) => new RegExp(p))];
    });
    return new CrisisDetector(entries);
  }

  /** 沒命中回傳 null。 */
  detect(text: string): CrisisCategory | null {
    const t = normalizeForCrisis(text);
    for (const [cat, res] of this.patterns) {
      if (res.some((re) => re.test(t))) return cat;
    }
    return null;
  }
}

export const defaultCrisisDetector: CrisisDetector = CrisisDetector.fromJson(crisisJson as CrisisSource);
