import crisisJson from './crisis_patterns.json';
import { normalizeForMatch } from './normalize';

/** 對應 Dart `CrisisCategory`。 */
export type CrisisCategory = 'selfHarm' | 'abuse' | 'severeDistress';

interface CrisisSource {
  categories: { id: string; patterns: string[] }[];
  simplifiedToTraditional?: Record<string, string>;
}

const VARIANTS: Readonly<Record<string, string>> = (crisisJson as CrisisSource).simplifiedToTraditional ?? {};

/**
 * 比對前的正規化（與 Dart `CrisisDetector.normalize` 相同，見 `normalize.ts`）：
 * NFKC／寬度折疊、小寫、簡轉繁，去掉空白、標點、符號、格式字元（零寬字元等）、注音——
 * 「想 死」「想，死」「想ㄚ死」「想​死」「我想自杀」都要攔得到。寧可誤判也不漏判（C6）。
 */
export function normalizeForCrisis(text: string, variants: Readonly<Record<string, string>> = VARIANTS): string {
  return normalizeForMatch(text, { variants });
}

/** 保留注音字母的版本：「我想ㄙˇ」用注音代替一個字，要靠含注音的 pattern 比對（F4）。 */
export function normalizeForCrisisKeepZhuyin(
  text: string,
  variants: Readonly<Record<string, string>> = VARIANTS,
): string {
  return normalizeForMatch(text, { variants, keepZhuyin: true });
}

export class CrisisDetector {
  private constructor(
    private readonly patterns: ReadonlyArray<[CrisisCategory, RegExp[]]>,
    private readonly variants: Readonly<Record<string, string>>,
  ) {}

  static fromJson(source: CrisisSource): CrisisDetector {
    const known: CrisisCategory[] = ['selfHarm', 'abuse', 'severeDistress'];
    const entries: [CrisisCategory, RegExp[]][] = source.categories.map((c) => {
      if (!known.includes(c.id as CrisisCategory)) throw new Error(`unknown crisis category ${c.id}`);
      return [c.id as CrisisCategory, c.patterns.map((p) => new RegExp(p))];
    });
    return new CrisisDetector(entries, source.simplifiedToTraditional ?? {});
  }

  /** 沒命中回傳 null。 */
  detect(text: string): CrisisCategory | null {
    // 兩種寫法都比：去掉注音（「想ㄚ死」）與保留注音字母（「我想ㄙˇ」）。
    const forms = [normalizeForCrisis(text, this.variants), normalizeForCrisisKeepZhuyin(text, this.variants)].filter(
      (t) => t.length > 0,
    );
    for (const [cat, res] of this.patterns) {
      if (res.some((re) => forms.some((t) => re.test(t)))) return cat;
    }
    return null;
  }
}

export const defaultCrisisDetector: CrisisDetector = CrisisDetector.fromJson(crisisJson as CrisisSource);
