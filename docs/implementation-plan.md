# frontend-devkit 實作計畫

- 日期：2026-11-12
- 依據：`docs/specs/2026-11-11-frontend-devkit-design.md`（主檔）＋ `permission-spec.md`／`migration-map.md`／`acceptance.md`／`experiments.md`
- 狀態：**待使用者審核**（未經同意不開始實作、不 commit）
- 產物性質：kit 是**純 markdown 元件**（四個 agent、六個指令、四個 pack、profile 範本、worktree 程序檔）＋安裝文件。**不新增 npm 依賴、不附執行腳本**（字形工具在 `tools/`，與 kit 無關）

## 0. 全程適用的紀律（從歷輪失誤反推出來的硬規則）

1. **每步一個 commit**，commit 前先把繁體中文訊息給你審，你點頭才提交；一律不 push。
2. **宣稱「已修」之前先 grep 回查**：本計畫每一步的驗收條件都寫成「可 grep／可執行」的形式，不接受「我確認過了」。
3. **批量文字替換後必人工重讀受影響行**（`tools/README.md` 的教訓）；涉及字形清洗時跑 `tools/scan-forms.ps1` 再人工看過。
4. **改動引用就重跑引用比對**：`grep -rn '§' docs` 輸出與主檔「0. 檔案地圖」逐行核對（歷輪出现過 4 次「改一處忘三處」）。
5. **不碰 `TOS_Frontend_Fia/.opencode/`**：那是另一套要繼續使用的 agent；讀它只為了抽 pack／遷移對照（唯讀）。
6. 新檔案一律 LF（`.gitattributes` 已鎖），不產生整檔換行轉換。

## 1. 已完成的前置（不用再做）

| 步驟 | 狀態 | 產物 |
|---|---|---|
| 步驟 1 實驗先行（R1） | **已完成**（2026-11-11） | `experiments.md` 八題數據；已據此定「方案 B 為預設」 |
| 步驟 2 批量改字人工複合紀律 | **已完成**（列為常設） | `tools/README.md` §使用紀律、主檔 §14 步驟 2 |

**遺留一項不擋實作**：方案 A 的三步先決覆驗（`experiments.md` 二.2 怀疑是我当时的服務綁定操作問題）。它只影響「要不要把 `permission-spec.md` §7.3.4 第 1–6 點整段刪掉」，不影響任何功能正確性 → 排到步驟 12（文件清尾）作為可選動作。

## 2. 工作項目（依依賴順序）

### 步驟 3　repo 骨架與 pack 撰寫規範

**做**：建目錄樹（`kit/agents/frontend-devkit/`、`kit/commands/frontend-devkit/`、`kit/rules/{stack,testing,security,i18n}/`、`kit/rules/registry.md`、`kit/profile/project.template.md`、`kit/worktree.procedures.md`）＋ `docs/writing-a-pack.md`。

**驗收**：
- 目錄樹與主檔 §4.1 逐項一致（用 `git ls-files` 對照，不缺不多）。
- `writing-a-pack.md` 內含 §6.1 的「禁止寫」清單（指令／timeout／項數／error 數／路徑檔名／專案專屬判斷）與 §6.2 的 `status` 兩字面值、`covers` 一行、YAML 不可用方括號的說明，並附「退件範例」三個。
- 此步驟**不含任何 agent 內容**，只立骨架與規範。

### 步驟 4　抽 pack（4 個，全部來自現行 agent 已驗證知識）

**做**：依 `migration-map.md` 逐條搬，寫 `rules/stack/vue2-nuxt2.md`、`rules/testing/ava.md`、`rules/security/vue-xss.md`、`rules/i18n/vue-i18n-json.md` ＋ `registry.md`（id 清單與 status）。

**驗收**：
- 每個 pack 檔頭含 `id/title/status: 已驗證/source/covers`。
- 四個 pack 內**不得出現** `npm test`、`npx eslint`、`99 項`、`test/specs` 以外的具體指令與數字（grep `npm |pnpm |yarn |npx |99 項|timeout` 於 `rules/` 應為 0 命中；`test/specs` 這種「位置慣例」屬允許內容，但改為寫成「依 profile `測試檔位置` 欄」的引用式敘述）。
- `security/vue-xss` 只寫專案細項（清理入口引用 profile、白名單範圍、既有危險點），通用危險模式**不重複列**（主檔 §3 第 0 點是正典）。
- 與現行 `reviewer.md`／`developer.md` 逐條對照：`migration-map.md` 每一列都能指出落到哪個檔案的哪個小節（做一張「來源行 → 落點」核對表放進 commit 訊息內文）。

### 步驟 5　`worktree.procedures.md` 參數化

**做**：主檔 §9 九條程序 → 參數化寫成源頭素材（佔位符由 profile 提供：worktree 目錄、分支前綴、名稱前綴、環境檔、depStrategy）。

**驗收**：
- 檔內**無個人絕對路徑**（grep `C:\\Users` 為 0），主工作區一律 `git rev-parse --show-toplevel`。
- 清除順序「先 `cmd /c rmdir .worktrees\<名稱>\node_modules`、再 `git worktree remove --force`」在** junction／install-per-worktree／none 三種策略下都寫到**，並保留「跳過第一步會連主工作區 `node_modules` 一起刪掉」的警告原文。
- `cmd /c` 開頭的指令**保留反斜線形**（`experiments.md` 第 7b 題：斜線會被 cmd 當旗標）。

### 步驟 6　`profile/project.template.md`

**做**：主檔 §5 範本 ＋ §5.1／§5.1.1／§5.1.2 的欄位說明、偵測來源標註、四欄白名單、三個合法狀態（值／`無`／`TBD（未確認）`）的撰寫指引。

**驗收**：
- 八個表格都有 `|---|` 分隔列（GFM 可渲染）。
- 不含 `## 未知（TBD）` 總表（S-1）；`## 模型` 只宣告「不記錄於本檔」。
- 每個欄位附「誰填（偵測／你答）＋沒填會怎樣」。
- 範本內範例值一律用**中性佔位**（不出現 ChatBox.vue 這類本專案專屬值，避免被當成 kit 預設）。

### 步驟 7　四個 agent 主體（V2 frontmatter）

**做**：`kit/agents/frontend-devkit/{orchestrator,developer,reviewer,setup}.md`。frontmatter 依 `permission-spec.md`（尾巴三段式、字面同形、具名 allow、`edit` 四條 deny 含 `*.git/*`、setup 四個具名檔、setup 的 `subagent` 唯一起外放 reviewer）；提示詞寫入主檔 §3 第 0 點安全地板、§10 流程行為、§11 降級表，**引用** profile／`resolved.md` 而非復述專案知識。

**驗收**：
- 四個檔的 frontmatter 是合法 YAML（`#` 註解，無 `//`；無方括號 value），並用 OpenCode 載入實測：`opencode` 能列出 `frontend-devkit/*` 四個 agent、沒有多出 `frontend-devkit/rules/...` 之類條目（`acceptance.md` 關卡 1 前半）。
- 主體提示詞**不含**任何專案專屬事實（grep `ChatBox|ava|99 項|zh-TW.json` 於 `kit/agents/` 為 0）。
- `§3 第 0 點`、三段式尾巴、TBD／`無` 語意、`rmdir` 先於 `worktree remove`、異常時回報 worktree 絕對路徑與分支——五項在四個檔的出現處彼此一致（做一次跨檔 grep 核對，結果寫進 commit 訊息）。
- `setup` 的 `edit` 只 allow 四個具名檔＋四種設定檔字面形，並 deny 全域設定路徑。

### 步驟 8　六個指令

**做**：`kit/commands/frontend-devkit/{dev,fix,review,review-fix,init,inspect}.md`。`init` 的四種模式（預設／`auto`／`compile`／`diff`）、gate 可行性判定（`permission-spec.md` §7.3.5 改寫版）、`inspect [probe]` 的 B 版三條（第 0 條 `Get-Location` 落點）。

**驗收**：
- 六個指令檔**不得使用 `` !`…` `` shell 塊**（grep 為 0）。
- `/frontend-devkit/review` 的 `agent: frontend-devkit/reviewer`＋`subagent: false`；`dev/fix/review-fix` 指向 orchestrator；`init/inspect` 指向 setup。
- 範圍省略語意寫死為 profile 的 `預設審核範圍` 字面值（不傳空字串、不傳「省略」），並保留「範圍為空不得輸出 VERDICT: PASS」。

### 步驟 9　README 與安裝／上手上路文件

**做**：`README.md`（快速開始）、`docs/install.md`（全域／專案兩種裝法、升級步驟、`kitRoot`、重複安裝警告、`opencode run` 落點注意）、`docs/adding-a-project.md`（init 問答範例、四欄白名單怎麼填、TBD 怎麼補）。

**驗收**：三條告警齊備（①升級後各專案重跑 `init compile`；②不要用內建 `build` 跑 kit 任務；③任何 agent 都不准動 `.git/`，hook 需求自行在專案外處理）；`install.md` 記錄「shell 資源比對用原始字串、字面同形」與「方案 A 覆驗的三步先決」。

### 步驟 10　關卡 0～8 驗證

**做**：依 `acceptance.md` 逐關跑。關卡 0（人工建兩個 Vite+Vue3 試寫專案，放 `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`）由**你我在殼層手動**做，kit agent 無此權限也不該有。

**驗收**：八關全過才算這步完成；任何一關失敗都把現象與根因寫進 `docs/acceptance-findings.md`（新建），修完重跑該關；**不得**為過關而放寬斷言（同 kit 給 reviewer 的規矩）。特別盯：
- 關卡 1：`probe` 第 0 條落點必須是試寫專案，否則整關作重跑（`experiments.md` 二.1 的教訓）。
- 關卡 7(a)(b)(c)(d)：安全地板的四種企圖都要被擋。
- 關卡 4：`New-Item … -Target <字面路徑>` 兩步寫法要**實際跑過**（R1 只測了 `Write-Output` 形，`New-Item` 形目前是推定）。

### 步驟 11　本專案零影響查核

**做**：在 `TOS_Frontend_Fia` 跑 `git status --short`（應乾淨）、`git diff --stat -- .opencode/`（應為空），並實際用舊 `/dev` 抽測一次流程可跑。

**驗收**：三個舊 agent、四個舊指令、兩份規則檔 diff 為空；kit 的安裝與實驗全程未寫入該專案。

### 步驟 12　文件清尾（可選）

方案 A 三步先決覆驗 → 依結果刪掉或保留 `permission-spec.md` §7.3.4 第 1–6 點；並把 `## 額外 shell` 的「詢問預期清單」語意回頭校對 §5／R10。

## 3. 里程碑與對外可見的完成定義

| 里程碑 | 內容 | 完成定義 |
|---|---|---|
| M1 骨架與知識就緒 | 步驟 3–6 | 目錄齊、4 個 pack＋程序檔＋範本落地，且「無專案專屬事實／無絕對路徑」兩項 grep 通過 |
| M2 元件就緒 | 步驟 7–9 | 四 agent 可被 OpenCode 載入、六指令可選取、文件三告警齊 |
| M3 可用 | 步驟 10–11 | 關卡 0～8 全過＋本專案零影響 |
| M4 收尾 | 步驟 12 | 方案 A 有結論（覆驗成功→保留並標『已驗證可用』；失敗→刪除該段並改一句紀律） |

## 4. 風險與停損點

| 風險 | 觸發訊號 | 停損做法 |
|---|---|---|
| `permission-spec.md` 的具名 allow 字面與實際指令不匹配（字面同形鐵律） | 關卡 1／4 出現「該跑的 gate 被 deny」 | 依實測輸出改 allow 條目或改程序檔字面；**不得**改用寬通配繞過（`npm run *` 是紅線） |
| 抽 pack 時遺漏現行 agent 的鐵則 | 步驟 4 核對表有來源列找不到落點 | 回到 `migration-map.md` 補列，再搬；不許「先求有再補」 |
| 方案 B 下 profile gate 不在主體靜態清單 → 新專案常要「人工執行」 | 關卡 2／4 的 `需人工執行` 標記过多 | 把常用者升進主體清單（走 kit 升級，一次改一處並重跑 probe），**不得**開 `npm run *` 通配 |
| 我又宣稱已修而其實沒修 | 任何驗收條件的 grep 結果與 commit 訊息不符 | 驗收條件先跑、貼輸出、再寫訊息；順序不可倒 |

## 5. 我需要你先拍的三個小決定

1. 步驟 3–6（M1）是否一次做完再給你驗，還是**一個步驟一交**（我建议一個步驟一交，便于你在早期就抓住方向錯誤）。
2. 關卡 0 的試寫專案：我列在 `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`，或你指定別的位置？
3. 試寫專案要 `npm create vite@latest`（要網路）還是用離線範本？若你的網路環境跑不了 scaffold，我把關卡 0 改成「你手動準備好後我再繼續」。
