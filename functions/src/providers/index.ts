import { FAKE_BEHAVIOURS, FakeProvider, type FakeBehaviour } from './fake';
import type { LessonProvider } from './types';
import { VertexGeminiProvider } from './vertexGemini';

export * from './types';
export { FakeProvider } from './fake';
export { VertexGeminiProvider } from './vertexGemini';

/**
 * 依環境變數選 provider：
 * - LLM_PROVIDER=fake（預設）：確定性假模型；FAKE_BEHAVIOUR 可設成逗號分隔的行為序列（emulator 手測用）。
 * - LLM_PROVIDER=vertex-gemini：Vertex AI Gemini；GEMINI_MODEL、VERTEX_LOCATION 可調。
 * 不認得的值直接丟錯（呼叫端會退回範本），不會默默換成別的供應商。
 */
export function createProvider(env: NodeJS.ProcessEnv = process.env): LessonProvider {
  const kind = (env.LLM_PROVIDER ?? 'fake').trim() || 'fake';
  switch (kind) {
    case 'fake': {
      const behaviours = (env.FAKE_BEHAVIOUR ?? 'good')
        .split(',')
        .map((s) => s.trim())
        .filter((s): s is FakeBehaviour => (FAKE_BEHAVIOURS as readonly string[]).includes(s));
      return new FakeProvider({ behaviours });
    }
    case 'vertex-gemini':
      return new VertexGeminiProvider({
        model: env.GEMINI_MODEL,
        project: env.GOOGLE_CLOUD_PROJECT ?? env.GCLOUD_PROJECT,
        location: env.VERTEX_LOCATION,
      });
    default:
      throw new Error(`unknown LLM_PROVIDER: ${kind}`);
  }
}
