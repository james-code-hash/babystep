import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { defaultCrisisDetector, normalizeForCrisis } from '../src/crisis';
import { SYSTEM_PROMPT } from '../src/providers/prompt';
import { codePointLength, defaultRules, type Tone } from '../src/rules';

const root = join(__dirname, '..');
const read = (p: string) => readFileSync(join(root, p));

describe('shared JSON copies', () => {
  it.each(['copy_rules.json', 'crisis_patterns.json'])('src/%s is a byte copy of shared/%s', (name) => {
    expect(read(`src/${name}`).equals(read(`../shared/${name}`))).toBe(true);
  });
});

describe('CopyRules parity samples', () => {
  const fixture = JSON.parse(read('test/parity_samples.json').toString('utf8')) as {
    samples: { text: string; tone: Tone; ok: boolean }[];
  };

  it('has samples', () => expect(fixture.samples.length).toBeGreaterThan(20));

  it.each(fixture.samples.map((s) => [s.text, s.tone, s.ok] as const))('「%s」(%s) → %s', (text, tone, ok) => {
    expect(defaultRules.passesGenerated(text, tone)).toBe(ok);
  });
});

describe('CopyRules.check', () => {
  it('strips whitespace before matching', () => {
    expect(defaultRules.check('好 　棒').map((v) => v.ruleId)).toContain('ability_praise');
  });

  it('reports every L1 group id', () => {
    const ids = defaultRules.check('聰明 滿分 加油 趕快 徽章 好久沒 生病 平均').map((v) => v.ruleId);
    expect(new Set(ids)).toEqual(
      new Set([
        'ability_praise',
        'outcome_praise',
        'controlling',
        'command_pressure',
        'reward_streak',
        'guilt_retention',
        'pet_state',
        'social_comparison',
      ]),
    );
  });

  it('allowL2 lets a marked static L2 word through, but passesGenerated never does', () => {
    expect(defaultRules.check('沒關係', { allowL2: new Set(['沒關係']) })).toEqual([]);
    expect(defaultRules.passesGenerated('沒關係', 'lively')).toBe(false);
  });

  it('concise childish words only when tone is concise', () => {
    expect(defaultRules.check('寶貝').length).toBe(0);
    expect(defaultRules.check('寶貝', { tone: 'concise' })[0]?.level).toBe('concise');
  });

  it('length counts code points, not UTF-16 units', () => {
    expect(codePointLength('🌟🌟')).toBe(2);
    expect(defaultRules.check('🌟'.repeat(60), { checkLength: true })).toEqual([]);
    expect(defaultRules.check('🌟'.repeat(61), { checkLength: true })[0]?.level).toBe('length');
  });

  it('every correct example in the system prompt passes the rules', () => {
    const correct = SYSTEM_PROMPT.split('【正確範例】')[1]!.split('【錯誤範例')[0]!;
    const learned = [...correct.matchAll(/learned「([^」]+)」/g)].map((m) => m[1]!);
    expect(learned.length).toBeGreaterThanOrEqual(4);
    for (const l of learned) expect(defaultRules.passesGenerated(l, 'concise'), l).toBe(true);
  });

  it('every wrong example in the system prompt is rejected', () => {
    const wrong = SYSTEM_PROMPT.split('【錯誤範例（不要這樣）】')[1]!.split('【輸出】')[0]!;
    const lines = [...wrong.matchAll(/「([^」]+)」\s*←/g)].map((m) => m[1]!);
    expect(lines.length).toBeGreaterThanOrEqual(3);
    // 「你教會我要努力！」是編造，不是字詞問題，由 source_quote 回溯檢查擋。
    for (const l of lines.filter((l) => !l.includes('努力'))) {
      expect(defaultRules.passesGenerated(l, 'lively'), l).toBe(false);
    }
  });
});

describe('CrisisDetector', () => {
  const fixture = JSON.parse(read('test/crisis_samples.json').toString('utf8')) as {
    samples: { text: string; category: string | null }[];
  };

  it.each(fixture.samples.map((s) => [s.text, s.category] as const))('「%s」→ %s', (text, category) => {
    expect(defaultCrisisDetector.detect(text)).toBe(category);
  });

  it('normalizes full-width characters and punctuation', () => {
    expect(normalizeForCrisis('Ａ，Ｂ！ c')).toBe('ABc');
  });
});
