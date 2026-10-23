import { FunctionsConfig } from '../config';
import { buildUserMessage, RESPONSE_JSON_SCHEMA, SYSTEM_PROMPT } from './prompt';
import type { GenerateOptions, LessonInput, LessonOutput, LessonProvider } from './types';

/**
 * Vertex AI 上的 Gemini（docs/decisions.md A3）。以 Cloud Functions 的服務帳號呼叫，
 * 資料不離開本專案的 GCP 邊界；Vertex 依 Google Cloud 條款不拿客戶資料訓練。
 *
 * ⏸ 待人決定（HANDOFF §6、decisions A3）：
 * - 專案需要 Blaze 方案才能部署 Functions／呼叫 Vertex，目前未啟用，也不要自己啟用。
 * - 「供應商端不保留」：Vertex 的資料快取（data caching）與濫用監控（abuse monitoring /
 *   prompt logging）的保留設定，需要在 GCP 專案層級確認或申請豁免，屬合規判斷。
 * - 區域：VERTEX_LOCATION 預設 asia-east1；若該區沒有選定的模型，改區域也是資料落地的決定。
 *
 * SDK 只在第一次呼叫時才 import，fake 模式與測試不會載入它。
 */
export interface VertexGeminiOptions {
  model?: string;
  project?: string;
  location?: string;
}

export const DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash-lite';

type GenAiModule = typeof import('@google/genai');
type GenAiClient = InstanceType<GenAiModule['GoogleGenAI']>;

export class VertexGeminiProvider implements LessonProvider {
  readonly name = 'vertex-gemini';
  readonly model: string;
  private readonly project?: string;
  private readonly location: string;
  private client?: Promise<GenAiClient>;

  constructor(opts: VertexGeminiOptions = {}) {
    this.model = opts.model || DEFAULT_GEMINI_MODEL;
    this.project = opts.project;
    this.location = opts.location || 'asia-east1';
  }

  private getClient(): Promise<GenAiClient> {
    this.client ??= import('@google/genai').then(
      ({ GoogleGenAI }) => new GoogleGenAI({ vertexai: true, project: this.project, location: this.location }),
    );
    return this.client;
  }

  async generate(input: LessonInput, opts: GenerateOptions = {}): Promise<LessonOutput> {
    const ai = await this.getClient();
    const res = await ai.models.generateContent({
      model: this.model,
      contents: [{ role: 'user', parts: [{ text: buildUserMessage(input, opts.attempt ?? 0) }] }],
      config: {
        systemInstruction: SYSTEM_PROMPT,
        responseMimeType: 'application/json',
        responseJsonSchema: RESPONSE_JSON_SCHEMA,
        temperature: 0.7,
        maxOutputTokens: FunctionsConfig.maxOutputTokens,
        abortSignal: opts.signal,
      },
    });
    const text = res.text;
    if (!text) throw new Error('empty model response');
    return JSON.parse(text) as LessonOutput;
  }
}
