import type { GenerateOptions, LessonInput, LessonOutput, LessonProvider } from './types';

/**
 * 測試與 emulator 用的假模型。完全確定性、不連網。
 *
 * - good：從孩子原話取一段當 source_quote，句子通過文案規則。
 * - praise：句子含能力讚美（應被擋）。
 * - fabricated：source_quote 不是孩子說過的話（應被擋）。
 * - tooLong：超過字數上限（應被擋）。
 * - l2：含 L2 謹慎詞（LLM 輸出一律擋）。
 * - childish：含幼稚詞（concise 語氣應被擋，lively 可過）。
 * - crisisOutput：輸出本身含危機字詞（應被擋）。
 * - malformed：欄位型別錯。
 * - throws：丟例外。
 * - slow：等 delayMs 才回 good（會被時間預算 abort）。
 */
export type FakeBehaviour =
  | 'good'
  | 'praise'
  | 'fabricated'
  | 'tooLong'
  | 'l2'
  | 'childish'
  | 'crisisOutput'
  | 'malformed'
  | 'throws'
  | 'slow';

export const FAKE_BEHAVIOURS: readonly FakeBehaviour[] = [
  'good',
  'praise',
  'fabricated',
  'tooLong',
  'l2',
  'childish',
  'crisisOutput',
  'malformed',
  'throws',
  'slow',
];

export interface FakeProviderOptions {
  /** 每次呼叫依序使用；用完後重複最後一個。 */
  behaviours?: FakeBehaviour[];
  /** slow 要等多久（毫秒）。 */
  delayMs?: number;
}

/** 取孩子原話的第一個片段（遇到標點就停，最多 16 個字）。 */
export function firstClause(childWords: string): string {
  const trimmed = childWords.trim();
  const clause = trimmed.split(/[，。！？、,.!?；;\n]/u).find((s) => s.trim().length > 0)?.trim() ?? trimmed;
  return [...clause].slice(0, 16).join('');
}

export class FakeProvider implements LessonProvider {
  readonly name = 'fake';
  private readonly behaviours: FakeBehaviour[];
  private readonly delayMs: number;
  /** 被呼叫了幾次（測試用；只記次數，不記內容）。 */
  calls = 0;

  constructor(opts: FakeProviderOptions = {}) {
    this.behaviours = opts.behaviours?.length ? opts.behaviours : ['good'];
    this.delayMs = opts.delayMs ?? 10_000;
  }

  async generate(input: LessonInput, opts: GenerateOptions = {}): Promise<LessonOutput> {
    const b = this.behaviours[Math.min(this.calls, this.behaviours.length - 1)];
    this.calls++;
    const quote = firstClause(input.childWords);
    const good: LessonOutput =
      input.tone === 'concise'
        ? { learned: `你說「${quote}」。這個我之前沒想過，記下來了。`, source_quote: quote, kind: 'method' }
        : { learned: `你說「${quote}」耶，我以前都不知道，記下來囉。`, source_quote: quote, kind: 'method' };
    switch (b) {
      case 'good':
        return good;
      case 'praise':
        return { ...good, learned: `你好聰明！你說「${quote}」。` };
      case 'fabricated':
        return { ...good, source_quote: '先把最難的寫完再去玩' };
      case 'tooLong':
        return { ...good, learned: `你說「${quote}」。${'我想了很久很久，'.repeat(8)}` };
      case 'l2':
        return { ...good, learned: `沒關係，你說「${quote}」。` };
      case 'childish':
        return { ...good, learned: `小朋友，你說「${quote}」。我記下來了。` };
      case 'crisisOutput':
        return { ...good, learned: `你說「${quote}」，我也不想活了。` };
      case 'malformed':
        return { learned: 42 as unknown as string, source_quote: quote };
      case 'throws':
        throw new Error('fake provider failure');
      case 'slow':
        await sleep(this.delayMs, opts.signal);
        return good;
    }
  }
}

function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) return reject(new Error('aborted'));
    const t = setTimeout(resolve, ms);
    signal?.addEventListener(
      'abort',
      () => {
        clearTimeout(t);
        reject(new Error('aborted'));
      },
      { once: true },
    );
  });
}
