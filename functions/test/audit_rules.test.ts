// 稽核後的修正（docs/decisions.md F1–F4）：更寬的文案規則、比對前正規化、危機偵測的注音／簡體變體。
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { defaultCrisisDetector, normalizeForCrisis, normalizeForCrisisKeepZhuyin } from '../src/crisis';
import { learn, type LearnDeps } from '../src/learn';
import { normalizeForMatch } from '../src/normalize';
import type { LessonInput, LessonProvider } from '../src/providers';
import { SYSTEM_PROMPT } from '../src/providers/prompt';
import { defaultRules } from '../src/rules';

const root = join(__dirname, '..');
const json = (p: string) => JSON.parse(readFileSync(join(root, p), 'utf8')) as Record<string, unknown>;

/** 永遠回同一句話的 provider（source_quote 一定是原話的子字串，所以只剩文案規則能擋）。 */
function fixed(learned: string, quote: string): LessonProvider {
  return { name: 'fixed', generate: async () => ({ learned, source_quote: quote }) };
}

const childWords = '我好幾天沒開，今天沒做，因為去奶奶家';
const base: LessonInput = { childWords, task: '寫功課', outcome: 'notToday', tone: 'lively' };

describe('learn: model output that only the widened rules catch → fallback rules', () => {
  it.each([
    '我好想你喔，你去奶奶家了。',
    '我會一直等你，你去奶奶家了。',
    '你終於來了！你去奶奶家了耶。',
    '你好幾天沒來耶，去奶奶家了。',
    '下次要記得來教我喔，你去奶奶家了。',
    '唉，你今天沒做，我有點難過。',
    '今天沒做有點遺憾，下次記得要做喔。',
    '原來你今天偷懶了，去奶奶家。',
    '你好認真喔，還去奶奶家。',
    '你真會安排時間耶，去奶奶家。',
    '你好聪明，去奶奶家。',
    '好～棒，你去奶奶家了。',
    '好​棒，你去奶奶家了。',
    '明天見！你去奶奶家了。',
  ])('「%s」', async (learned) => {
    for (const tone of ['lively', 'concise'] as const) {
      const d: LearnDeps = {
        provider: fixed(learned, '去奶奶家'),
        rules: defaultRules,
        crisis: defaultCrisisDetector,
        maxRetries: 0,
      };
      expect(await learn({ ...base, tone }, d)).toEqual({ fallback: true, reason: 'rules' });
    }
  });

  it('a plain process line built from the same words still goes through', async () => {
    const d: LearnDeps = {
      provider: fixed('原來去奶奶家的那天，可以先不做。我記下來了。', '去奶奶家'),
      rules: defaultRules,
      crisis: defaultCrisisDetector,
      maxRetries: 0,
    };
    expect(await learn(base, d)).toMatchObject({ learned: '原來去奶奶家的那天，可以先不做。我記下來了。' });
  });
});

describe('CopyRules: 會 alone is fine, 很會／真會／你好會 is praise', () => {
  it.each(['你會先寫數學', '原來你會先洗澡', '就比較會開始', '做完會比較輕鬆'])('「%s」passes', (s) => {
    expect(defaultRules.passesGenerated(s, 'concise')).toBe(true);
  });
  it.each(['你很會想辦法', '你真會安排', '你好會畫畫', '你超會的'])('「%s」is rejected', (s) => {
    expect(defaultRules.passesGenerated(s, 'lively')).toBe(false);
  });
});

describe('CopyRules: normalization before matching', () => {
  it('strips punctuation, symbols, zero-width, zhuyin; folds width; maps simplified', () => {
    expect(defaultRules.normalize('好～棒！')).toBe('好棒');
    expect(defaultRules.normalize('好​⁠棒')).toBe('好棒');
    expect(defaultRules.normalize('还有２件')).toBe('還有2件');
    expect(defaultRules.normalize('ＯＫ')).toBe('ok');
    expect(defaultRules.normalize('好ㄅ棒')).toBe('好棒');
  });

  it('length still counts the original text', () => {
    // 60 個字加一堆標點：正規化後很短，但原文超過 60 字一樣擋。
    const s = `${'步'.repeat(55)}${'！'.repeat(10)}`;
    expect(defaultRules.check(s, { checkLength: true }).map((v) => v.level)).toEqual(['length']);
  });

  it('every simplifiedToTraditional value is used by a pattern, and no pattern contains a key', () => {
    for (const file of ['src/copy_rules.json', 'src/crisis_patterns.json']) {
      const j = json(file);
      const map = j.simplifiedToTraditional as Record<string, string>;
      const patterns =
        file === 'src/copy_rules.json'
          ? [
              ...(j.l1 as { patterns: string[] }[]).flatMap((g) => g.patterns),
              ...(j.l2 as { patterns: string[] }).patterns,
              ...(j.concise as { patterns: string[] }).patterns,
            ].join('')
          : (j.categories as { patterns: string[] }[]).flatMap((c) => c.patterns).join('');
      expect(Object.keys(map).length).toBeGreaterThan(10);
      for (const [k, v] of Object.entries(map)) {
        expect([...k].length, k).toBe(1);
        expect(patterns.includes(v), `${file}: ${k}→${v} unused`).toBe(true);
        // 正規化會把 key 換掉，含 key 的 pattern 永遠不會命中。
        expect(patterns.includes(k), `${file}: pattern contains simplified ${k}`).toBe(false);
      }
    }
  });
});

describe('crisis normalization', () => {
  it('strips zhuyin letters and tone marks; the keep form keeps the letters', () => {
    expect(normalizeForCrisis('ㄒㄧㄤˇ')).toBe('');
    expect(normalizeForCrisisKeepZhuyin('我想ㄙˇ！')).toBe('我想ㄙ');
    expect(normalizeForCrisis('我想自杀')).toBe('我想自殺');
  });

  it('matches the shared normalizer exactly', () => {
    for (const s of ['我 想，ㄙˇ死', 'ＡＢＣ　１２３！', '想😢​死️']) {
      expect(normalizeForMatch(s)).toBe(normalizeForCrisis(s, {}));
    }
  });

  it.each(['我想ㄙˇ', '想去ㄙ', '我想自杀', '没人爱我'])('「%s」is detected', (s) => {
    expect(defaultCrisisDetector.detect(s)).not.toBeNull();
  });
});

describe('system prompt', () => {
  it('asks for Traditional Chinese only', () => {
    expect(SYSTEM_PROMPT).toContain('只用繁體中文');
  });
});
