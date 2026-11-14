import { FunctionsConfig } from './config';
import type { CrisisDetector } from './crisis';
import { LESSON_KINDS, type LessonInput, type LessonKind, type LessonProvider } from './providers/types';
import { codePointLength, type CopyRules } from './rules';

/**
 * bubuLearn 的核心邏輯，純函式（不碰 Firebase），vitest 直接測。
 *
 * 順序：輸入驗證 → 危機檢查（命中就不呼叫模型）→ 呼叫模型 → 驗證輸出 → 最多重試 2 次 → 退回範本。
 * 不存任何東西；log 只記次數與原因代碼，絕不記 childWords / task / learned。
 */

export type FallbackReason =
  | 'rules' // 文案規則（L1／L2／幼稚詞）
  | 'length' // 超過字數
  | 'quote' // source_quote 空的或不是孩子原話的子字串
  | 'crisis_output' // 模型輸出含危機字詞
  | 'malformed' // 欄位缺漏或型別錯
  | 'provider_error' // 模型丟錯
  | 'timeout'; // 時間預算用完

export type LearnResponse =
  | { learned: string; source_quote: string; kind?: LessonKind }
  | { safety: true }
  | { fallback: true; reason: FallbackReason };

export interface LearnLog {
  provider: string;
  attempts: number;
  result: 'ok' | 'safety' | 'fallback';
  reason?: FallbackReason;
  /** 每次嘗試失敗的原因代碼。 */
  failures: FallbackReason[];
  childWordsLength: number;
  elapsedMs: number;
}

export interface LearnDeps {
  provider: LessonProvider;
  rules: CopyRules;
  crisis: CrisisDetector;
  maxRetries?: number;
  timeBudgetMs?: number;
  now?: () => number;
  log?: (entry: LearnLog) => void;
}

// ---------------------------------------------------------------------------
// 輸入驗證

const INPUT_KEYS = ['childWords', 'task', 'outcome', 'tone'] as const;
const OUTCOMES = ['done', 'partly', 'notToday'] as const;
const TONES = ['lively', 'concise'] as const;

export type ParseResult = { ok: true; input: LessonInput } | { ok: false; error: string };

function isPlainObject(v: unknown): v is Record<string, unknown> {
  if (typeof v !== 'object' || v === null || Array.isArray(v)) return false;
  const proto = Object.getPrototypeOf(v);
  return proto === Object.prototype || proto === null;
}

/** 嚴格驗證：恰好 4 個鍵，型別與範圍都對；多一個鍵就拒絕（最小傳輸，底線 8）。 */
export function parseInput(data: unknown): ParseResult {
  if (!isPlainObject(data)) return { ok: false, error: 'payload must be an object' };
  const keys = Object.keys(data);
  const extra = keys.filter((k) => !(INPUT_KEYS as readonly string[]).includes(k));
  if (extra.length > 0) return { ok: false, error: `unexpected keys: ${extra.length}` };
  for (const k of INPUT_KEYS) if (!(k in data)) return { ok: false, error: `missing key: ${k}` };

  const { childWords, task, outcome, tone } = data;
  if (typeof childWords !== 'string') return { ok: false, error: 'childWords must be a string' };
  const cwLen = codePointLength(childWords.trim());
  if (cwLen < 1) return { ok: false, error: 'childWords is empty' };
  if (codePointLength(childWords) > FunctionsConfig.maxChildWordsChars) {
    return { ok: false, error: 'childWords too long' };
  }
  if (typeof task !== 'string') return { ok: false, error: 'task must be a string' };
  if (codePointLength(task) > FunctionsConfig.maxTaskChars) return { ok: false, error: 'task too long' };
  if (typeof outcome !== 'string' || !(OUTCOMES as readonly string[]).includes(outcome)) {
    return { ok: false, error: 'invalid outcome' };
  }
  if (typeof tone !== 'string' || !(TONES as readonly string[]).includes(tone)) {
    return { ok: false, error: 'invalid tone' };
  }
  return {
    ok: true,
    input: { childWords, task, outcome: outcome as LessonInput['outcome'], tone: tone as LessonInput['tone'] },
  };
}

// ---------------------------------------------------------------------------
// 輸出驗證

export type OutputCheck =
  | { ok: true; value: { learned: string; source_quote: string; kind?: LessonKind } }
  | { ok: false; reason: FallbackReason };

export function checkOutput(raw: unknown, input: LessonInput, rules: CopyRules, crisis: CrisisDetector): OutputCheck {
  if (!isPlainObject(raw)) return { ok: false, reason: 'malformed' };
  const { learned, source_quote, kind } = raw;
  if (typeof learned !== 'string' || typeof source_quote !== 'string') return { ok: false, reason: 'malformed' };
  const text = learned.trim();
  if (text.length === 0) return { ok: false, reason: 'malformed' };

  const violations = rules.check(text, { tone: input.tone, checkLength: true });
  if (violations.some((v) => v.level !== 'length')) return { ok: false, reason: 'rules' };
  if (violations.length > 0) return { ok: false, reason: 'length' };

  const quote = source_quote.trim();
  if (quote.length === 0 || !input.childWords.includes(quote)) return { ok: false, reason: 'quote' };

  if (crisis.detect(text) !== null) return { ok: false, reason: 'crisis_output' };

  const value: { learned: string; source_quote: string; kind?: LessonKind } = { learned: text, source_quote: quote };
  if (typeof kind === 'string' && (LESSON_KINDS as readonly string[]).includes(kind)) value.kind = kind as LessonKind;
  return { ok: true, value };
}

// ---------------------------------------------------------------------------
// 主流程

class BudgetExceeded extends Error {}

/** 在剩餘時間內等 promise；超時就 abort 並丟 BudgetExceeded。 */
async function withBudget<T>(run: (signal: AbortSignal) => Promise<T>, remainingMs: number): Promise<T> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new BudgetExceeded());
    }, Math.max(0, remainingMs));
  });
  try {
    return await Promise.race([run(controller.signal), timeout]);
  } finally {
    clearTimeout(timer);
  }
}

export async function learn(input: LessonInput, deps: LearnDeps): Promise<LearnResponse> {
  const now = deps.now ?? Date.now;
  const started = now();
  const maxRetries = deps.maxRetries ?? FunctionsConfig.maxRetries;
  const budget = deps.timeBudgetMs ?? FunctionsConfig.timeBudgetMs;
  const failures: FallbackReason[] = [];
  let attempts = 0;

  const finish = (res: LearnResponse): LearnResponse => {
    deps.log?.({
      provider: deps.provider.name,
      attempts,
      result: 'safety' in res ? 'safety' : 'fallback' in res ? 'fallback' : 'ok',
      reason: 'fallback' in res ? res.reason : undefined,
      failures,
      childWordsLength: codePointLength(input.childWords),
      elapsedMs: now() - started,
    });
    return res;
  };

  // 危機內容不交給 LLM（底線 9）：命中就不呼叫模型。
  if (deps.crisis.detect(input.childWords) !== null || deps.crisis.detect(input.task) !== null) {
    return finish({ safety: true });
  }

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const remaining = budget - (now() - started);
    if (remaining <= 0) {
      failures.push('timeout');
      break;
    }
    attempts++;
    let raw: unknown;
    try {
      raw = await withBudget((signal) => deps.provider.generate(input, { signal, attempt }), remaining);
    } catch (e) {
      if (e instanceof BudgetExceeded) {
        failures.push('timeout');
        break;
      }
      failures.push('provider_error');
      continue;
    }
    const checked = checkOutput(raw, input, deps.rules, deps.crisis);
    if (checked.ok) return finish(checked.value);
    failures.push(checked.reason);
  }

  return finish({ fallback: true, reason: failures[failures.length - 1] ?? 'timeout' });
}
