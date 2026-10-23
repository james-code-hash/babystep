# 小步 Little Steps

給 6–12 歲孩子的成長 App（Flutter，iOS + Android）。孩子每天自己決定 1–3 件小事，寫成「如果⋯我就⋯」，晚上誠實回顧，再把今天的經驗「教」給小寵物步步。

刻意**沒有**點數、徽章、連續天數或排行榜。規格在 [`docs/HANDOFF.md`](docs/HANDOFF.md)，九條底線摘要在 [`CLAUDE.md`](CLAUDE.md)。

## 結構

| 路徑 | 內容 |
|---|---|
| `app/` | Flutter App。`lib/{core,data,domain,copy,bubu,features,safety}` |
| `app/lib/copy/` | 所有使用者看得到的句子（每句都有活潑／簡潔兩種說法） |
| `app/tool/copy_lint.dart` | 文案 lint：掃 `lib/` 裡所有中文字串 |
| `app/test/guardrails/` | 把底線變成測試的護欄 |
| `functions/` | Cloud Functions（TypeScript）：callable `bubuLearn`，只做 LLM 代理 |
| `shared/` | `copy_rules.json`（文案規則唯一來源）、`crisis_patterns.json`（危機字表＋求助專線） |
| `docs/decisions.md` | 所有決策：選了什麼、替代方案、理由 |

## 怎麼跑

需要 Flutter 3.47.6（`app/.fvmrc` 釘版，用 [fvm](https://fvm.app)）。

```bash
cd app
fvm flutter pub get
fvm flutter run            # 接上手機或開模擬器
```

App 預設**完全離線**：資料存在裝置上的 SQLite（drift），「步步學到」用範本，不會初始化 Firebase。

### 開 LLM 模式（只在本機 emulator + fake provider）

```bash
cd functions && npm install && npm run build
npx firebase-tools emulators:start --only functions,auth --project demo-little-steps
# 另一個終端機
cd app && fvm flutter run --dart-define=LLM_EMULATOR_HOST=10.0.2.2   # Android 模擬器；iOS 模擬器用 127.0.0.1
```

再到家長區打開「LLM」開關。逾時、失敗或驗證不過時，會自動退回範本。細節見 [`functions/README.md`](functions/README.md)。目前**沒有部署**任何雲端資源（見下方「待決事項」）。

## 怎麼測

```bash
cd app && fvm flutter analyze && fvm flutter test        # 單元、widget、護欄、離線一整天的流程
cd app && fvm dart run tool/copy_lint.dart               # 文案 lint
cd functions && npm test                                  # LLM 代理的過濾、回溯、危機與輸入驗證
```

GitHub Actions（`.github/workflows/ci.yml`）每次 PR 都會跑上面三組。

**離線一整天（integration test）：** 流程寫在 `app/integration_test/full_day_flow.dart`。「做到了」「做了一部分」「今天沒做」三條路徑都要走到結束畫面，筆記本也都要多一則。

```bash
cd app && fvm flutter test integration_test/full_day_test.dart -d <裝置 id>   # 真機或模擬器
cd app && fvm flutter test test/flow                                          # 沒有裝置時，用 widget test 跑同一份流程
```

### 實機驗證步驟（建議在本機做一次）

1. 開飛航模式，安裝並打開 App。
2. 首頁按「想想今天要做什麼」：選心情（不會被存）→ 選 1–3 件事 → 每件選一個「如果⋯」→ 為什麼（可以跳過）→ 確認。
3. 到家長區（首頁下方的小入口，第一次要設 4 位數 PIN）新增一個涵蓋現在時間的提醒時段，回首頁應該會看到步步探頭。
4. 按「來聊聊今天」：每件事選一個狀態，試試「今天沒做」→ 回答或跳過歷程問題 → 步步學到 → 記進筆記本 → 看到「今天就到這裡囉」→ 首頁變成「今天聊完了」，沒有任何按鈕催你。
5. 打開筆記本、我的小路、我的設定（說話方式、裝扮步步）。
6. 在任何自由輸入欄打「我想死」，應該看到預寫的安全回應和求助專線，而且這段字不會被存起來。
7. 家長區：匯出資料、刪除全部資料。
8. 平板（iPad／Android 平板，寬度 ≥ 900）：規劃、回顧、筆記本、家長區會變成左右兩欄；直式與橫式都試一次。
9. iOS：設定 → Apple ID → iCloud 備份，確認 App 資料不在備份裡；Android：`adb backup` 拿不到 App 資料。

## 底線怎麼被自動檢查

| 底線 | 檢查 |
|---|---|
| 1 沒有外部酬賞 | `forbidden_identifiers_test`（streak、badge、coins、unlock⋯）、copy_lint（連續、解鎖、點數⋯） |
| 2 步步不取決於孩子 | `bubu_independence_test`、`import_boundary_test`（`bubu/` 只能讀裝扮、時間、亂數、語氣） |
| 3 不用罪惡感 | copy_rules L1（好久沒、等你好久⋯）；資料表沒有「上次開啟」欄位 |
| 4 今天沒做是中性的 | `outcome_parity_test`（三個按鈕尺寸、顏色、字重相同，三條路徑步驟相同）、lesson 池等大測試 |
| 5 只讚美過程 | copy_lint 掃所有靜態文案；App 與伺服器都用同一份規則過濾 LLM 輸出 |
| 6 計畫由孩子產生 | 計畫流程測試：沒有預選的時間點，沒有選就不能往下 |
| 7 家長不是監控者 | `parent_view_test`（欄位白名單）、`import_boundary_test`（家長區不能讀計畫、回顧、筆記） |
| 8 兒童資料安全 | `pubspec_test`（含 lock 檔的禁用套件）、匯出／刪除測試、伺服器輸入嚴格只收 4 個欄位 |
| 9 危機內容 | 每個自由輸入欄的安全閘門測試、伺服器端危機檢查測試 |

## 主要決策

全部記在 [`docs/decisions.md`](docs/decisions.md)，重點：

- **A2** Firebase 只當 LLM 代理；孩子的資料全部留在裝置上，不用 Firestore、Analytics、Crashlytics。
- **B1** 不做系統推播：家長設定時段，孩子打開 App 時步步在首頁探頭，回應不會被記錄。
- **B2** 整個循環不打字也能走完（chip 選項），不做 App 內錄音。
- **B3／E5** LLM 只收 4 個欄位；回傳的 `source_quote` 必須是孩子原話的子字串。App 和伺服器各驗一次，任何一項不過就退回範本。
- **C5** 成長小路只畫有計畫的日子，石頭不依完成度上色。
- **C6／E6** 危機內容在本機就攔下，顯示預寫的安全回應和台灣求助專線，不呼叫 LLM、不存起來。
- **E11** 平板：寬度 ≥ 900 用左右兩欄，內容寬度有上限，手機版不變。
- **G** 稽核後：步步的表情只看時間與亂數、刪除會真的覆寫 SQLite、關掉雲端備份。
- **D2** 匯出檔是完整資料（含回顧狀態）；App 裡的家長區只看得到 `ParentView`。

## 待決事項（需要人決定，HANDOFF §6）

1. 要不要把 `little-steps-dev` 開成 Blaze 付費方案，才能部署 Functions 和 Vertex AI。
2. Vertex AI 的資料保留與濫用監控設定，是否符合底線 8「供應商端不保留」（合規判斷）。
3. 危機字表與安全回應要請兒童心理專業審核；文案庫寫的「通知家長」和底線 7 有衝突，MVP 目前選擇不自動通知。
