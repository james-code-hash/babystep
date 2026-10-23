/**
 * 後端可調的數字（與 app/lib/core/config.dart 對應的值寫在註解裡）。
 * 都是起始值（docs/decisions.md C9），實測後再調。
 */
export const FunctionsConfig = {
  /** childWords 字數上限（以 code point 計）。對應 AppConfig.maxReflectionChars = 120。 */
  maxChildWordsChars: 120,
  /** task 字數上限（以 code point 計）。App 端是 AppConfig.maxTaskChars = 20，這裡留餘裕。 */
  maxTaskChars: 40,
  /** 驗證不過時最多重試幾次（不含第一次）。對應 AppConfig.llmMaxRetries = 2。 */
  maxRetries: 2,
  /**
   * 整個呼叫的時間預算（毫秒）。App 端 8 秒（AppConfig.llmTimeout）就退回範本，
   * 這裡要比它短，才來得及把 {fallback} 回給 App。
   */
  timeBudgetMs: 7000,
  /** 送給模型的 maxOutputTokens（步步一句話很短）。 */
  maxOutputTokens: 256,
} as const;

/** onCall 的區域（台灣）。 */
export const REGION = 'asia-east1';
