import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { FunctionsConfig, REGION } from './config';
import { defaultCrisisDetector } from './crisis';
import { learn, parseInput, type LearnDeps, type LearnLog, type LearnResponse } from './learn';
import { createProvider } from './providers';
import type { LessonProvider } from './providers/types';
import { defaultRules } from './rules';

const isEmulator = () => process.env.FUNCTIONS_EMULATOR === 'true';

/** 只記次數與原因代碼（底線 8：不記孩子說的話，也不記步步的句子）。 */
function logLearn(entry: LearnLog): void {
  logger.info('bubuLearn', {
    provider: entry.provider,
    attempts: entry.attempts,
    result: entry.result,
    reason: entry.reason,
    failures: entry.failures,
    childWordsLength: entry.childWordsLength,
    elapsedMs: entry.elapsedMs,
  });
}

export interface HandleOptions {
  /** 驗證通過的使用者（匿名也可以）。emulator 以外沒有就拒絕。 */
  authed: boolean;
  emulator: boolean;
  deps: LearnDeps | (() => LearnDeps);
}

/**
 * callable 的本體（不依賴 onCall 的 runtime，方便測試）。
 * 輸入錯誤 → HttpsError('invalid-argument')；其餘情況一律回 {learned}／{safety}／{fallback}，不丟錯。
 */
export async function handleBubuLearn(data: unknown, opts: HandleOptions): Promise<LearnResponse> {
  if (!opts.authed && !opts.emulator) {
    throw new HttpsError('unauthenticated', 'sign-in required');
  }
  const parsed = parseInput(data);
  if (!parsed.ok) {
    logger.warn('bubuLearn invalid input', { error: parsed.error });
    throw new HttpsError('invalid-argument', parsed.error);
  }
  let deps: LearnDeps;
  try {
    deps = typeof opts.deps === 'function' ? opts.deps() : opts.deps;
  } catch (e) {
    // provider 設定錯（例如 LLM_PROVIDER 打錯字）：退回範本，不讓 App 看到錯誤。
    logger.error('bubuLearn provider config error', { message: e instanceof Error ? e.message : 'unknown' });
    return { fallback: true, reason: 'provider_error' };
  }
  return learn(parsed.input, deps);
}

let cachedProvider: LessonProvider | undefined;
function defaultDeps(): LearnDeps {
  cachedProvider ??= createProvider();
  return {
    provider: cachedProvider,
    rules: defaultRules,
    crisis: defaultCrisisDetector,
    maxRetries: FunctionsConfig.maxRetries,
    timeBudgetMs: FunctionsConfig.timeBudgetMs,
    log: logLearn,
  };
}

export const bubuLearn = onCall(
  {
    region: REGION,
    enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
    consumeAppCheckToken: false,
    timeoutSeconds: 15,
    memory: '256MiB',
    maxInstances: 5,
  },
  (request) => handleBubuLearn(request.data, { authed: !!request.auth, emulator: isEmulator(), deps: defaultDeps }),
);
