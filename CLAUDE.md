# 小步 Little Steps — 給每個 session 的工作守則

給 6–12 歲孩子的成長 App：孩子自己決定今天 1–3 件小事 → 寫成「如果⋯我就⋯」→ 晚上誠實回顧 → 把經驗「教」給小寵物步步。
唯一嚴格規格是 `docs/HANDOFF.md`；`docs/reference/` 是背景，不是規格。決策紀錄在 `docs/decisions.md`。

## 九條底線（HANDOFF §2，碰到就停下來問人）

1. **沒有外部酬賞**：不做點數、金幣、徽章、等級、排行榜、streak、「完成 N 件解鎖 X」。沒有任何東西能用完成度兌換。
2. **步步的狀態不取決於孩子做了什麼**：不生病、不難過、不變弱、不消失；外觀只因孩子主動裝扮、時間、季節而變。
3. **不用罪惡感、不挽留**：沒有「我等你好久／好久沒來／不要走」，沒有 FOMO 推播。隔多久沒開，語氣都一樣（程式不讀「上次開啟」）。
4. **「今天沒做」完全中性**：視覺權重與「做到了」相同、零後果；這一天步步也學得到東西。
5. **只讚美過程，不評價人**：任何字串（含 LLM 輸出）不得出現聰明／好棒／厲害／天才、結果讚美、命令式提醒。
6. **計畫由孩子產生**：系統與步步只能提問、給選項，不代寫；家長建議孩子可以不選。
7. **家長不是監控者**：家長端不顯示完成率、使用時長、趨勢、心情，或孩子沒主動分享的內容。分享是孩子的動作，不是預設。
8. **兒童資料安全**：本地優先；無第三方追蹤／廣告 SDK、無內購誘導；可完整匯出與刪除；送 LLM 只送當次最小內容，供應商端不保留、不訓練。
9. **危機內容不交給 LLM**：自傷、受虐、嚴重困擾訊號 → 走預寫好的安全回應路徑。

## 護欄（每次改動都要全綠）

```bash
cd app && fvm flutter analyze && fvm flutter test        # 含 test/guardrails/ 底線測試
cd app && fvm dart run tool/copy_lint.dart               # 文案 lint：掃 lib/ 所有中文字串
cd functions && npm test                                  # LLM 後端的過濾與回溯測試
```

- 文案規則的唯一來源：`shared/copy_rules.json`（App 端執行期過濾、靜態 lint、Cloud Function 共用）。
- 新增使用者看得到的句子 → 放進 `app/lib/copy/`，跑 copy lint；過不了就改句子，不要改規則來放行。
- 寵物外觀／問候只能吃 (裝扮, 日期, 隨機)；不得 import plan/review 資料。家長端只能讀 `ParentView`。

## 慣例

- Flutter 用 fvm 釘版（`.fvmrc`），App 在 `app/`，Cloud Functions 在 `functions/`。
- 核心循環必須離線可跑；Firebase 只用於 LLM 代理（可關、會失敗退回範本）。不要加 analytics / crashlytics。
- 數字（每日上限、逾時秒數、字數上限⋯）放 `app/lib/core/config.dart`，不要寫死在畫面裡。
- 自己做決定，寫進 `docs/decisions.md`（選了什麼／替代方案／理由）。只有 HANDOFF §6 的情況才問人。
- 每完成一個可展示段落就 commit。
