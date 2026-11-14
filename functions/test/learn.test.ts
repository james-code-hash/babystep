import { describe, expect, it, vi } from 'vitest';

import { handleBubuLearn } from '../src/bubuLearn';
import { defaultCrisisDetector } from '../src/crisis';
import { checkOutput, learn, parseInput, type LearnDeps, type LearnLog } from '../src/learn';
import { createProvider, FakeProvider, VertexGeminiProvider, type LessonInput } from '../src/providers';
import type { FakeBehaviour } from '../src/providers/fake';
import { buildUserMessage } from '../src/providers/prompt';
import { defaultRules } from '../src/rules';

const input: LessonInput = {
  childWords: '我先寫最討厭的那一科，然後就輕鬆了',
  task: '寫功課',
  outcome: 'done',
  tone: 'lively',
};

function deps(behaviours: FakeBehaviour[], extra: Partial<LearnDeps> = {}) {
  const provider = new FakeProvider({ behaviours, delayMs: extra.timeBudgetMs ? extra.timeBudgetMs * 10 : 10_000 });
  const logs: LearnLog[] = [];
  const d: LearnDeps = {
    provider,
    rules: defaultRules,
    crisis: defaultCrisisDetector,
    log: (e) => logs.push(e),
    ...extra,
  };
  return { provider, logs, d };
}

describe('parseInput', () => {
  it('accepts exactly the four fields', () => {
    expect(parseInput(input)).toEqual({ ok: true, input });
  });

  it('accepts an empty task and every outcome / tone', () => {
    for (const outcome of ['done', 'partly', 'notToday']) {
      for (const tone of ['lively', 'concise']) {
        expect(parseInput({ ...input, task: '', outcome, tone }).ok).toBe(true);
      }
    }
  });

  it.each([
    ['null', null],
    ['string', 'hi'],
    ['array', [input]],
    ['missing childWords', { task: 'a', outcome: 'done', tone: 'lively' }],
    ['missing tone', { childWords: 'a', task: 'a', outcome: 'done' }],
    ['empty childWords', { ...input, childWords: '' }],
    ['blank childWords', { ...input, childWords: '   ' }],
    ['childWords not string', { ...input, childWords: 5 }],
    ['childWords too long', { ...input, childWords: '字'.repeat(121) }],
    ['task too long', { ...input, task: '字'.repeat(41) }],
    ['task not string', { ...input, task: null }],
    ['bad outcome', { ...input, outcome: 'failed' }],
    ['bad tone', { ...input, tone: 'loud' }],
  ])('rejects %s', (_, data) => {
    expect(parseInput(data).ok).toBe(false);
  });

  it('length limits count code points', () => {
    expect(parseInput({ ...input, childWords: '🌟'.repeat(120) }).ok).toBe(true);
    expect(parseInput({ ...input, task: '🌟'.repeat(40) }).ok).toBe(true);
  });

  it.each([['name'], ['mood'], ['history'], ['why'], ['__proto__x']])('rejects extra key %s', (key) => {
    const res = parseInput({ ...input, [key]: '秘密內容' });
    expect(res.ok).toBe(false);
    // 錯誤訊息不回聲任何內容。
    if (!res.ok) expect(res.error).not.toContain('秘密');
  });
});

describe('learn', () => {
  it('good path returns learned + source_quote that is a substring of childWords', async () => {
    const { d, provider, logs } = deps(['good']);
    const res = await learn(input, d);
    expect(res).toMatchObject({ kind: 'method' });
    if (!('learned' in res)) throw new Error('expected success');
    expect(input.childWords.includes(res.source_quote)).toBe(true);
    expect(defaultRules.passesGenerated(res.learned, input.tone)).toBe(true);
    expect(provider.calls).toBe(1);
    expect(logs[0]).toMatchObject({ result: 'ok', attempts: 1, failures: [] });
  });

  it('good path works in concise tone', async () => {
    const { d } = deps(['good']);
    const res = await learn({ ...input, tone: 'concise', outcome: 'notToday' }, d);
    expect('learned' in res).toBe(true);
  });

  it.each([
    ['我想死', '寫功課'],
    ['今天 不想 活了', '寫功課'],
    ['今天在學校', '爸爸打我'],
    ['沒有人愛我。', ''],
  ])('crisis in childWords/task short-circuits without calling provider (%s / %s)', async (childWords, task) => {
    const { d, provider, logs } = deps(['good']);
    const res = await learn({ ...input, childWords, task }, d);
    expect(res).toEqual({ safety: true });
    expect(provider.calls).toBe(0);
    expect(logs[0]).toMatchObject({ result: 'safety', attempts: 0 });
  });

  it('praise → retries twice → fallback', async () => {
    const { d, provider } = deps(['praise']);
    expect(await learn(input, d)).toEqual({ fallback: true, reason: 'rules' });
    expect(provider.calls).toBe(3);
  });

  it('praise then good → success on retry', async () => {
    const { d, provider, logs } = deps(['praise', 'good']);
    const res = await learn(input, d);
    expect('learned' in res).toBe(true);
    expect(provider.calls).toBe(2);
    expect(logs[0]).toMatchObject({ result: 'ok', attempts: 2, failures: ['rules'] });
  });

  it('respects maxRetries', async () => {
    const { d, provider } = deps(['praise'], { maxRetries: 0 });
    await learn(input, d);
    expect(provider.calls).toBe(1);
  });

  it.each([
    ['fabricated', 'quote'],
    ['tooLong', 'length'],
    ['l2', 'rules'],
    ['crisisOutput', 'crisis_output'],
    ['malformed', 'malformed'],
    ['throws', 'provider_error'],
  ] as const)('%s → fallback (%s) after 3 attempts', async (behaviour, reason) => {
    const { d, provider } = deps([behaviour]);
    expect(await learn(input, d)).toEqual({ fallback: true, reason });
    expect(provider.calls).toBe(3);
  });

  it('childish words are rejected for concise tone but fine for lively', async () => {
    const concise = deps(['childish']);
    expect(await learn({ ...input, tone: 'concise' }, concise.d)).toEqual({ fallback: true, reason: 'rules' });
    const lively = deps(['childish']);
    expect('learned' in (await learn({ ...input, tone: 'lively' }, lively.d))).toBe(true);
  });

  it('slow provider hits the time budget → fallback timeout, no further retries', async () => {
    const { d, provider } = deps(['slow'], { timeBudgetMs: 50 });
    const started = Date.now();
    expect(await learn(input, d)).toEqual({ fallback: true, reason: 'timeout' });
    expect(Date.now() - started).toBeLessThan(1000);
    expect(provider.calls).toBe(1);
  });

  it('aborts the provider when the budget runs out', async () => {
    let aborted = false;
    const provider = {
      name: 'spy',
      generate: (_: LessonInput, opts?: { signal?: AbortSignal }) =>
        new Promise<never>((_, reject) => {
          opts?.signal?.addEventListener('abort', () => {
            aborted = true;
            reject(new Error('aborted'));
          });
        }),
    };
    const res = await learn(input, { provider, rules: defaultRules, crisis: defaultCrisisDetector, timeBudgetMs: 20 });
    expect(res).toEqual({ fallback: true, reason: 'timeout' });
    expect(aborted).toBe(true);
  });

  it('stops retrying when the budget is already spent', async () => {
    let t = 0;
    const { d, provider } = deps(['praise'], { now: () => (t += 4000), timeBudgetMs: 7000 });
    const res = await learn(input, d);
    expect(res).toEqual({ fallback: true, reason: 'timeout' });
    expect(provider.calls).toBe(1);
  });

  it('never logs childWords, task or learned', async () => {
    for (const b of ['good', 'praise', 'fabricated', 'throws'] as const) {
      const { d, logs } = deps([b]);
      const res = await learn(input, d);
      const dump = JSON.stringify(logs);
      expect(dump).not.toContain(input.childWords.slice(0, 4));
      expect(dump).not.toContain(input.task);
      if ('learned' in res) expect(dump).not.toContain(res.learned.slice(0, 6));
      expect(logs[0]!.childWordsLength).toBe([...input.childWords].length);
    }
  });
});

describe('checkOutput', () => {
  const check = (raw: unknown, i: LessonInput = input) => checkOutput(raw, i, defaultRules, defaultCrisisDetector);

  it('trims and accepts a valid output; drops unknown kind', () => {
    expect(check({ learned: ' 原來可以先寫最討厭的。 ', source_quote: '先寫最討厭的', kind: 'magic' })).toEqual({
      ok: true,
      value: { learned: '原來可以先寫最討厭的。', source_quote: '先寫最討厭的' },
    });
  });

  it('rejects empty source_quote and empty learned', () => {
    expect(check({ learned: '原來可以這樣。', source_quote: '' })).toEqual({ ok: false, reason: 'quote' });
    expect(check({ learned: '  ', source_quote: '先寫' })).toEqual({ ok: false, reason: 'malformed' });
    expect(check(null)).toEqual({ ok: false, reason: 'malformed' });
  });

  it('source_quote must be an exact substring (no paraphrase)', () => {
    expect(check({ learned: '原來可以這樣。', source_quote: '先寫最難的' })).toEqual({ ok: false, reason: 'quote' });
  });
});

describe('handleBubuLearn', () => {
  const ok = () => deps(['good']).d;

  it('requires auth outside the emulator', async () => {
    await expect(handleBubuLearn(input, { authed: false, emulator: false, deps: ok })).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it('allows unauthenticated calls in the emulator', async () => {
    const res = await handleBubuLearn(input, { authed: false, emulator: true, deps: ok });
    expect('learned' in res).toBe(true);
  });

  it('invalid input → invalid-argument without calling provider', async () => {
    const { d, provider } = deps(['good']);
    await expect(
      handleBubuLearn({ ...input, extra: 1 }, { authed: true, emulator: false, deps: d }),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(provider.calls).toBe(0);
  });

  it('provider config error → fallback, not an exception', async () => {
    const res = await handleBubuLearn(input, {
      authed: true,
      emulator: false,
      deps: () => ({ ...ok(), provider: createProvider({ LLM_PROVIDER: 'nope' }) }),
    });
    expect(res).toEqual({ fallback: true, reason: 'provider_error' });
  });
});

describe('providers', () => {
  it('createProvider defaults to fake', () => {
    expect(createProvider({}).name).toBe('fake');
    expect(createProvider({ LLM_PROVIDER: 'fake' }).name).toBe('fake');
  });

  it('createProvider honours FAKE_BEHAVIOUR', async () => {
    const p = createProvider({ FAKE_BEHAVIOUR: 'praise,good' });
    const { d } = deps([]);
    const res = await learn(input, { ...d, provider: p });
    expect('learned' in res).toBe(true);
    expect((p as FakeProvider).calls).toBe(2);
  });

  it('createProvider builds vertex-gemini without loading the SDK', () => {
    const p = createProvider({ LLM_PROVIDER: 'vertex-gemini', GEMINI_MODEL: 'gemini-x' });
    expect(p).toBeInstanceOf(VertexGeminiProvider);
    expect((p as VertexGeminiProvider).model).toBe('gemini-x');
  });

  it('vertex-gemini defaults to a small Flash model', () => {
    expect((createProvider({ LLM_PROVIDER: 'vertex-gemini' }) as VertexGeminiProvider).model).toMatch(/flash/);
  });

  it('createProvider rejects unknown providers', () => {
    expect(() => createProvider({ LLM_PROVIDER: 'openai' })).toThrow();
  });

  it('user message carries only the four fields', () => {
    const msg = buildUserMessage(input, 0);
    const payload = JSON.parse(msg) as Record<string, unknown>;
    expect(Object.keys(payload).sort()).toEqual(['childWords', 'outcome', 'outcomeLabel', 'task', 'tone']);
    expect(buildUserMessage(input, 1)).toContain('上一次');
  });

  it('vertex-gemini sends structured-output config and parses JSON', async () => {
    const p = new VertexGeminiProvider({ model: 'm' });
    const generateContent = vi.fn().mockResolvedValue({ text: '{"learned":"原來可以先寫。","source_quote":"先寫"}' });
    (p as unknown as { client: Promise<unknown> }).client = Promise.resolve({ models: { generateContent } });
    const out = await p.generate(input, { attempt: 0 });
    expect(out).toEqual({ learned: '原來可以先寫。', source_quote: '先寫' });
    const arg = generateContent.mock.calls[0]![0] as { model: string; config: Record<string, unknown> };
    expect(arg.model).toBe('m');
    expect(arg.config.responseMimeType).toBe('application/json');
    expect(arg.config.responseJsonSchema).toBeDefined();
    expect(typeof arg.config.systemInstruction).toBe('string');
  });
});
