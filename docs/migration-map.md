# 從現有 agent 遷移對照（主檔 §12 的外移附檔）

> 實作步驟 4「抽 pack」與步驟 7「寫主體提示詞」都以此檔為查核清單。

> 本檔是 `specs/2026-11-11-frontend-devkit-design.md`（主檔）的附檔。章節編號沿用主檔原編號以維持引用穩定；文中 `§X` 若帶檔名前綴（如 `acceptance.md §13`）指附檔，**未帶前綴的 `§X` 一律指主檔**。主檔頂端的「0. 檔案地圖」是全套檔案的入口。

## 12. 從現有 agent 遷移對照（內容搬到哪裡）

| 現有位置 | -kit 的去處 |
|---|---|
| orchestrator.md 第 60 行主工作區絕對路徑 | 刪除，改執行期 `git rev-parse --show-toplevel`（§9.1） |
| 三 agent 開頭「TOS_Frontend（Nuxt 2／Vue 2／Vuetify 1.5／Node v12）」 | profile `## 識別` 技術棧一行 |
| 「99 項全數通過」「0 error／1 warning」等數字 | 刪除，改動態量測（D7）；`ChatBox.vue:45` warning 進 profile `## 測試慣例` 的已知豁免 |
| `npm test`／`npx eslint`／`npm run build`／`npm ci` 指令與 timeout | profile `## 指令`；專案端 `opencode.json` 的 allow 規則（permission-spec.md §7.3） |
| developer.md 專案慣例（Vue2/Vuetify1/eslint standard） | pack `stack/vue2-nuxt2` |
| developer.md 特徵測試寫法（ava、`@vue/test-utils`、禁 `fs` 比字串） | pack `testing/ava` |
| developer.md「## 回歸防護」整節五步（基準線→影響範圍分析→特徵測試→不可削弱既有測試→完成後全測＋手動建議清單；約 66–110 行） | **主體規則**（留在 `developer.md` 主體提示詞，非 pack：它是流程不是專案知識）。步 1 的「記下通過／失敗項數」改**執行期動態量測**（D7，不寫死 99 項）；步 2 的「共用項目」類別進 profile `## 共用項目類別`、具體元件清單進 `## 回歸熱點`；步 3 的測試框架寫法進 pack `testing/ava`；步 5 的「建議手動回歸檢查」來源是 profile `## 回歸熱點` 右欄 |
| developer.md「必須先經 `@/util/sanitizer`」 | 檢查項 → pack `security/vue-xss`；入口路徑 → profile `## 安全慣例` |
| reviewer.md §1 lint 基準線細節 | profile（豁免）+ 主體（「異動檔 0 error」的規則本身） |
| reviewer.md §2.1 共用項目清單與重點元件 | 類別 → profile `## 共用項目類別`；具體元件 → profile `## 回歸熱點` |
| reviewer.md §2.2 手動回歸對照表（元件 → 操作） | profile `## 回歸熱點`（表格右欄就是「要檢查什麼」） |
| reviewer.md §5 Vue／Vuetify 慣例審查 | pack `stack/vue2-nuxt2` |
| reviewer.md §6 XSS 清單與 DOMPurify 白名單背景 | 清單 → pack `security/vue-xss`；本專案實例 → profile |
| i18n 檔名 `zh-TW.json`／`en.json` 與同步規則 | 規則 → pack `i18n/vue-i18n-json`；路徑 → profile |
| `HEAD..origin/main`、`.worktrees/`、`review-<sha7>`、Node v12 約 20 秒等 | profile `## 識別`／`## 指令`；命名規則留主體並由 profile 覆寫前綴 |
| workflow-rules.md 的「實作前必問 worktree」 | 主體 + profile `worktreePolicy`（D8） |
| workflow-rules.md §3 四條通過標準 | 主體規則 + profile `## 指令`（gate 清單） |
| worktree-procedures.md 全文 | `kit/worktree.procedures.md`（§9，內容參數化；執行期由 compile 折進 `resolved.md`） |
| developer.md 第 137 行「不要修改 `.opencode/` 內的設定檔」 | 主體規則（§7.1 developer 列、permission-spec.md §7.3.4 第 7 點）：`allow *` 之後 deny `*opencode.json`、`*opencode.jsonc`、`*.opencode/*`、**`*.git/*`**（第 5 輪補 `.git`，四條；六種路徑形已由 `experiments.md` 第 6 題實測全拒）——**v1 遷移時被我弄丟的提權封堵**（CHANGELOG.md 附錄 B §17 I-1；第 2 輪 G2 指出舊寫法 `*.opencode.json`／根 `opencode.json` 會漏掉 `opencode.jsonc` 與 worktree 內副本，故以本行為準） |
| reviewer.md 第 43–50 行「bash 指令寫法限制」整段（禁 `--fix`、禁 `--output`、`git fetch` 不可帶 refspec、`Test-Path` 前綴紀律、不用 `Get-ChildItem`／`Get-Content`／`Remove-Item`／`cd`） | 升為**主體鐵則**（§7.2 末段），並在 permission-spec.md §7.3.5 變成「allow 產生時就要驗唯讀」的機械步驟 |
| orchestrator.md 第 87 行（同名 worktree／分支已存在 → 不硬蓋，`question` 請使用者決定） | §9.2，主體保留 |
| orchestrator.md 第 170 行（清除前在 worktree 跑 `git status --short` 檢查未 commit 殘留並告知，因 `--force` 會丟棄） | §9.7，主體保留（**丢資料防護**，v1 遷移時我原本只剩「合併前確認狀態」） |
| orchestrator.md 第 45 行（bash 一律 `workdir`、不用 `cd`；要詢問一律用 `question` 工具） | §7.2 主體保留的全域紀律 |
| reviewer.md 第 81 行（目錄不在但 `git worktree list` 已登記 → 如實回報，無 `prune` 權限不得使用白名單外指令） | §9.5，主體保留 |
| reviewer.md／commands 的 `webfetch: deny`、`skill: deny`、`question` 權限差異 | §7.1「其他工具」欄明確列出四個 agent 的 `webfetch`／`skill`／`question` 取捨 |

---
