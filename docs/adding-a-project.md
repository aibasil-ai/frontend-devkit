# 把 kit 裝進一個新專案

> 前置：已依 [`install.md`](install.md) 完成安裝，且**重啟過 TUI 進程**（agent 定義是進程啟動時載入）。

## 1. 跑 `init`

```text
/frontend-devkit/init
```

它會做五件事：偵測 → 對掃不到的欄位逐題問你 → 驗證四個白名單欄位的**值** → 寫 `project.md` → `compile` 出 `resolved.md` → `inspect [probe]`。

### `init` 的五個模式

| 指令 | 行為 |
|---|---|
| `/frontend-devkit/init` | 預設：偵測 + 問答（建議） |
| `/frontend-devkit/init auto` | 只偵測、不問；掃不到就寫 `TBD` |
| `/frontend-devkit/init compile` | 只重譯 `resolved.md`（改完 profile 後跑這個） |
| `/frontend-devkit/init diff` | 只顯示「重跑偵測會改哪些欄位」，不寫檔 |
| `/frontend-devkit/inspect [probe]` | 健檢；`probe` 會派 reviewer 實跑三條權限探針 |

## 2. `init` 會問你什麼（實際問題與建議答案）

以下是實測時的問法與決策依據。

### 2a. `worktreePolicy`（要不要用 worktree）

| 值 | 什麼時候選 |
|---|---|
| `ask`（預設，建議） | 不確定時的最佳解：每次要建前先問你，最不容易留下殘留 |
| `always` | 團隊流程固定、能接受多一點清理工作 |
| `never` | 小專案、單人、不想處理 worktree；審核目標會固定是 `--working` |

### 2b. `depStrategy`（worktree 內的依賴怎麼來）

| 值 | 條件 |
|---|---|
| `junction` | 主工作區**已有** `node_modules`；worktree 連結回主工作區（Windows junction） |
| `install-per-worktree` | 沒有 `node_modules`，或 lockfile 需要可重現安裝（`npm ci`） |
| `none` | 不建 worktree，或不需要依賴 |

**先驗規則**：主工作區沒有 `node_modules` 時**不要**選 `junction`——`Resolve-Path node_modules` 取不到，會在 worktree 建好之後才失敗。

### 2c. `## 啟用規則`（要套哪些 pack）

| pack | 適用訊號 |
|---|---|
| `security/vue-xss` | 任何會插入原始 HTML 的 Vue 專案（**現在沒有 `v-html` 也建議啟用**：它管的是「未來新增插入點要先登記清理入口」） |
| `stack/vue2-nuxt2` | Vue 2 / Nuxt 2 |
| `testing/ava` | 用 ava 當測試框架 |
| `i18n/vue-i18n-json` | 用 vue-i18n 且語系是 JSON |

不要把「不相關」的 pack 一起啟用：reviewer 會拿錯標準去判。

> 若清單裡**一個 `security/*` 都沒有**，流程啟動時會觸發 **D18 二次確認**（見 §3）。

### 2d. `## 回歸熱點` 與 `## 共用項目類別`

- **回歸熱點**：被動到就要人工看一遍的檔案。除了頁面組裝與主要元件，**別忘了全域樣式表**（例如 `src/style.css`）：很多專案把樣式集中在那裡，漏掉它等於漏掉一半回歸面。
- **共用項目類別**：reviewer 要 grep 使用處的範圍。建議包含「元件 ＋ 全域 CSS 類別／CSS 變數」——只寫元件會漏掉 `.counter`、`--text-h` 這類跨檔契約。

### 2e. `## 安全慣例` 四欄

| 欄位 | 本專案沒有時的填法 |
|---|---|
| 清理入口 | `無`（並註明「全專案 grep `v-html`／`innerHTML` 零命中，日後新增插入點須回來補」） |
| 應經流程 | `無` |
| 既有危險點 | `無`（同上註明掃描日期與範圍） |
| 不得放寬 | `無` |

**不要**硬填一個不存在的清理入口：reviewer 會以為有入口可查，反而放過未清理的插入點。

### 2f. `## 已知豁免`

只能寫成「**具體檔案＋具體規則＋理由**」三件套，例如：

```text
src/components/Example.vue：vue/no-v-html（既有 warning，短期內不改；檔案已列入 § 既有危險點）
```

**不接受**「所有 lint error 皆豁免」這種總括式寫法——`inspect` 會標超限。

## 3. D18：沒有任何 `security/*` 時會發生什麼

如果你把 `security/vue-xss` 這一列刪掉：

1. `compile` **仍然會成功**（0 個 pack 是合法狀態），但會在 `resolved.md` 寫警告；
2. `dev`／`fix`／`review-fix` 會用 `question` 問你，**只有三個選項**：①確認僅主體基本安全項繼續 ②我先去補設定（**立即停止**）③取消；
3. `/review` 直接進 reviewer（它沒有 `question` 權限）→ **不開始審核**，要你在 `## 專案覆寫` 加一列：

```text
| securityOverride | 僅主體基本安全項 | 已確認僅執行主體基本安全項（YYYY-MM-DD；理由） |
```

**只有這一列**算授權。寫在別處的文字（包含 `resolved.md` 檔頭那句警告本身）都不算。

## 4. TBD 怎麼補

`TBD（未確認）` 不是錯誤，但它會讓某些檢查變成「未覆蓋」。常見的三個：

| 欄位 | 影響 | 建議值 |
|---|---|---|
| `預設審核範圍` | 不帶範圍的 `/review` 會被要求補範圍 | 有 origin：`origin/main`；沒有：`--working` |
| `測試慣例 › 寫法慣例` | reviewer 對測試寫法只能給泛泛建議 | 例「vitest + 元件測試用 @vue/test-utils」 |
| `測試慣例 › 禁止選項` | 無法主動攔「會寫回快照檔」的旗標 | 例「禁止 `-u`／`--updateSnapshot`」 |

補完跑 `/frontend-devkit/init compile`（或 `/frontend-devkit/init` 讓它逐題問）。

## 5. 第一個任務

```text
/frontend-devkit/dev 在 App.vue 加一個切換深色按鈕＋測試
```

你應該看到：

1. 先確認 profile／`resolved.md` 一致（不一致會要你 `compile`）；
2. 問你要不要 worktree（`worktreePolicy: ask`）；
3. 建 worktree＋處理依賴（`depStrategy`）；
4. `developer` 用**七個區段**回報（變更摘要／異動檔案／驗證指令／是否改 `package.json`／影響範圍／回歸檢驗／手動回歸清單）；
5. `reviewer` **自己重跑** gate（不是引用 developer 的數字），輸出 `VERDICT`；
6. 要 commit 前，**先把訊息給你看**，你同意才 commit（而且**永不 push**）。

## 6. 常見卡點

| 症狀 | 原因與處理 |
|---|---|
| `init` 說找不到 `project.md` | 正常（第一次本來就沒有）；照問答走完就會產生 |
| `compile` 成功但 reviewer 說看不到 pack 內容 | 檢查 `resolved.md` 是否含 `## 啟用 pack 正文`；只有摘要表就是舊版 kit（缺陷 W） |
| `dev` 一直要你 `compile` | `project.md` 的 `## 啟用規則` 與 `resolved.md` 檔頭不一致 → 跑 `compile` |
| worktree 建了但測試跑不起來 | 主工作區沒有 `node_modules` 卻選了 `junction` → 改 `install-per-worktree` |
| `--working` 審核看到 `.opencode/` | 尚未把 kit 設定納入版控（commit 一次即可），或請 agent 明確排除 |
| 回報說「某指令沒權限」 | 先讓它拆成單條重試；複合指令被拒不代表單條不可用 |
