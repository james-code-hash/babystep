# functions — LLM 代理（callable `bubuLearn`）

Firebase 在這個專案只做一件事：把「步步學到」的那一句交給 LLM，並在伺服器端再過一次濾（docs/decisions.md A2、A3、B3、C3）。
不用 Firestore、不存孩子資料、不放 analytics；log 只記次數與原因代碼，絕不記 `childWords`／`task`／`learned`。

## 介面

輸入（恰好 4 個鍵，多一個就 `invalid-argument`）：

| 鍵 | 型別 |
|---|---|
| `childWords` | 字串，1–120 字（code point） |
| `task` | 字串，0–40 字 |
| `outcome` | `done` \| `partly` \| `notToday` |
| `tone` | `lively` \| `concise` |

輸出（三選一，除了輸入錯誤與未登入，其他情況都不丟錯）：

- `{learned, source_quote, kind?}`：通過文案規則（L1、L2、concise 幼稚詞、60 字）、`source_quote` 是 `childWords` 的子字串、輸出沒有危機字詞。
- `{safety: true}`：`childWords` 或 `task` 命中危機字表 → 沒有呼叫模型，App 走預寫的安全回應。
- `{fallback: true, reason}`：驗證不過重試 2 次仍失敗、模型丟錯或超過 7 秒 → App 用範本。`reason` ∈ `rules | length | quote | crisis_output | malformed | provider_error | timeout`。

核心邏輯在 `src/learn.ts`（純函式），`src/bubuLearn.ts` 只負責 auth、App Check 與 HttpsError。

## 規則來源

`src/copy_rules.json`、`src/crisis_patterns.json` 是 `shared/*.json` 的逐位元組複本，測試會檢查。改規則時改 `shared/`，再：

```bash
cp ../shared/copy_rules.json ../shared/crisis_patterns.json src/
```

`test/parity_samples.json`（文案規則）與 `test/crisis_samples.json`（危機偵測）是跨語言對照樣本，Dart 端可以讀同一份檔確認判定一致。

## 指令

```bash
npm install
npm run build   # tsc → lib/
npm test        # 型別檢查 + vitest
```

## 本機 emulator（fake provider）

不用登入、不用帳單。用 `demo-` 開頭的專案 id，emulator 就不會碰任何真的雲端資源：

```bash
npm run build
npx firebase-tools emulators:start --only functions,auth --project demo-little-steps
# App：--dart-define=LLM_EMULATOR_HOST=10.0.2.2（Android 模擬器）或 127.0.0.1
```

一次性煙霧測試：

```bash
npx firebase-tools emulators:exec --only functions --project demo-little-steps \
  'curl -s -X POST -H "Content-Type: application/json" \
   -d "{\"data\":{\"childWords\":\"我先寫最討厭的那一科\",\"task\":\"寫功課\",\"outcome\":\"done\",\"tone\":\"lively\"}}" \
   http://127.0.0.1:5001/demo-little-steps/asia-east1/bubuLearn'
```

在 emulator 裡：不檢查 App Check，也允許未登入呼叫。部署後兩者都強制（匿名登入即可）。

## Provider（環境變數）

| 變數 | 說明 |
|---|---|
| `LLM_PROVIDER` | `fake`（預設）或 `vertex-gemini`；其他值 → 一律 `{fallback, reason: provider_error}` |
| `FAKE_BEHAVIOUR` | fake 的行為序列，逗號分隔：`good,praise,fabricated,tooLong,l2,childish,crisisOutput,malformed,throws,slow` |
| `GEMINI_MODEL` | 預設 `gemini-2.5-flash-lite` |
| `VERTEX_LOCATION` | 預設 `asia-east1` |

可以把這些寫在 `functions/.env.local`（不進版控）給 emulator 用。

## ⏸ 還沒做、需要人決定的事

- **不要部署、不要啟用帳單。** Functions 與 Vertex 都需要 Blaze 方案（HANDOFF §6、decisions A3）。
- Vertex 的資料快取與濫用監控（prompt logging）保留設定，要在 GCP 專案層級確認或申請豁免，才能說「供應商端不保留」。
- 危機字表需要兒童心理專業審核（decisions C6）。
