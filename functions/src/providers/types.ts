import type { Tone } from '../rules';

export type Outcome = 'done' | 'partly' | 'notToday';

/** 對應 Dart `LessonKind`。 */
export const LESSON_KINDS = ['method', 'selfKnowledge', 'feeling', 'world', 'choice', 'plainDay'] as const;
export type LessonKind = (typeof LESSON_KINDS)[number];

/**
 * 送給模型的全部內容（B3）：只有這 4 個欄位。沒有名字、沒有歷史、沒有心情。
 */
export interface LessonInput {
  childWords: string;
  task: string;
  outcome: Outcome;
  tone: Tone;
}

export interface LessonOutput {
  learned: string;
  source_quote: string;
  kind?: string;
}

export interface GenerateOptions {
  /** 時間預算用完時會被 abort。 */
  signal?: AbortSignal;
  /** 第幾次嘗試（0 開始）。重試時 provider 可加一句更嚴格的提醒。 */
  attempt?: number;
}

export interface LessonProvider {
  readonly name: string;
  generate(input: LessonInput, opts?: GenerateOptions): Promise<LessonOutput>;
}
