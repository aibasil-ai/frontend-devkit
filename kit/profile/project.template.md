# frontend-devkit 專案設定檔（template）

> **這是範本**，由 `/frontend-devkit/init` 複製成專案的 `.opencode/frontend-devkit/project.md` 後填入實際值。
>
> 三態規則（不可混用）：
> - **實際值**＝已確認，當成事實使用。
> - **`無`**＝已確認本專案**沒有**該事物（例：真的沒有 lint gate）。該檢查跳過，**不適用、不擋 PASS**，但回報要寫「依設定檔：本專案無此項」，不得說成跑過。
> - **`TBD（未確認）`**＝不知道／沒掃到／還沒問。該檢查跳過，**不擋 PASS**，但必須在回報列「因 TBD 未覆蓋：X」，不得宣稱已覆蓋。
>
> **未知只寫在欄位值上，本檔不設總表**（總表與欄位值是兩個真相，必然漂移）。要清單就跑 `/frontend-devkit/inspect`，它掃全文彙整。
>
> 每個欄位附「誰填」：`偵測`＝init 自動填（會標來源）、`你答`＝init 用 `question` 請你確認、`你填`＝需要你判斷的專案知識。
>
> 範本內的範例值都是**中性佔位**（不帶任何特定專案的事實），填完請把範例整列改掉或刪掉。

## 識別

| 欄位 | 值 | 誰填 | 沒填／填錯的後果 |
|---|---|---|---|
| 專案名稱 | TBD（未確認） | 偵測 | 僅供回報標題；不影響判定 |
| 技術棧一行 | TBD（未確認） | 偵測 | reviewer 缺背景描述，仍會查，但建議措辭較泛 |
| shell | TBD（未確認） | 偵測（探針 `Get-Location`；`$`／括號形不可用） | 非 PowerShell 時 kit 的 worktree 程序會停止（主檔 §11） |
| 設定檔路徑 | TBD（未確認） | 偵測 | 無法定位 instructions／model 寫到哪；非法值（見白名單）會造成跨專案提權風險 |
| kitRoot | TBD（未確認） | 你答（依安裝方式） | compile／inspect 找不到源頭素材，無法重譯或比對 |
| worktreePolicy | ask | 你答（預設 `ask`） | 缺值視為 `ask`（每次都問） |
| depStrategy | TBD（未確認） | 偵測＋你確認 | 缺值時不建 worktree（安全側）；pnpm／workspace 誤填 `junction` 會破壞依賴連結 |
| worktree 目錄 | TBD（未確認） | 你答（建議 `.worktrees/`） | 缺值即無法定位隔離區；非法值可讓工作區落到專案外 |
| 分支前綴 | TBD（未確認） | 你答 | 缺值時用 kit 預設 `feature/`、`fix/`（並記錄是預設而非你指定） |
| worktree 名稱前綴 | TBD（未確認） | 你答 | 缺值時用 kit 預設 `review-` 與 `<類型>-<slug>` |
| 預設基準分支 | TBD（未確認） | 偵測 | 省略範圍的審核無法定義；`/frontend-devkit/review` 不帶範圍會被要求補 |
| 預設審核範圍 | TBD（未確認） | 偵測 | 同上 |
| 環境檔 | TBD（未確認） | 偵測 | worktree 內跑測試／build 可能因缺設定失敗；非法值有外洩風險 |

### 四欄白名單（`setup` 寫入前驗、`inspect` 每輪重驗，非法即停止）

| 欄位 | 合法 | 非法（實例） |
|---|---|---|
| 設定檔路徑 | `opencode.json`／`opencode.jsonc`／`.opencode/opencode.json`／`.opencode/opencode.jsonc` 四種字面相對形之一 | `~/.config/opencode/opencode.json`（會改到全域設定，波及全機所有專案）、`.git/config`、絕對路徑 |
| kitRoot | `~/.config/opencode/frontend-devkit` 或 `.opencode/frontend-devkit` | `/tmp/x`、其他 repo 的路徑（會掉包源頭比對基準） |
| worktree 目錄 | 專案內相對路徑，如 `.worktrees/` | `../out`（工作區與環境檔落到專案外）、`/abs`、`<盤符>:\…`（絕對路徑形）、`.git`、`.opencode` |
| 環境檔 | 單一檔名，可多檔逐檔列：`.env`、`.env.local` | `../secret.env`、`dir/.env`、`.env*`（萬用字元）、含 `:` 的任何形式 |

### 格式驗證欄（非白名單，值域固定）

- `worktreePolicy` ∈ ｛`ask`、`always`、`never`｝
- `depStrategy` ∈ ｛`junction`、`install-per-worktree`、`none`｝
- `shell` ∈ ｛`powershell`、`TBD（未確認）｝`
- `預設審核範圍` 必須是 `/frontend-devkit/review` 認得的語法之一：省略（用 `預設基準分支` 組出範圍）、`a..b`、單一 sha、`origin/<分支>`、`--working`

## 指令

| gate | 指令 | timeout | 備註 | 誰填 |
|---|---|---|---|---|
| test | TBD（未確認） | 600000 | 判定一律以**全部**測試為準；聚焦除錯可另跑單檔 | 偵測（`scripts.test`） |
| lint（單檔） | TBD（未確認） | 120000 | 只跑異動檔；**不得帶自動修正旗標** | 偵測＋你確認 |
| lint（全專案） | 無 | 300000 | 僅供參考，不據此判定 | 偵測 |
| build | TBD（未確認） | 600000 | build 失敗屬「嚴重」 | 偵測（`scripts.build`） |
| 依賴安裝（worktree 用） | TBD（未確認） | 600000 | 只准**不可變**安裝（依 lockfile 重建）；會改 lockfile 的一律拒絕 | 偵測（lockfile 型別） |

> 任一 gate 在本專案不存在時，該列填 `無`（例：純函式庫型專案常沒有 build）。**不得憑空假設一個指令。**
> 偵測到的指令會標來源，例：`npm test (偵測自 package.json scripts.test)`。

## 測試慣例

| 欄位 | 值 | 誰填 |
|---|---|---|
| 框架 | TBD（未確認） | 偵測（devDependencies） |
| 測試檔位置與命名 | TBD（未確認） | 偵測（樣板搜尋 `*.spec.*`／`*.test.*`／`__tests__/`） |
| 寫法慣例 | TBD（未確認） | 你答（例：元件級掛載驗執行期行為／用測試替身隔離網路） |
| 禁止選項 | TBD（未確認） | 你答（例：會把實際輸出寫回快照檔的那類旗標） |
| 已知豁免 | 無 | 你答（**每條都要寫成「具體檔案＋具體規則＋理由」三件套**） |

豁免的範圍上限（主檔 §5）：

- **不得**豁免任何 gate 的執行失敗（test／build 掛掉不是豁免能覆蓋的）。
- **不得**豁免「嚴重」級問題；不接受「全部 lint error 皆豁免」這類總括式寫法。
- `setup` 寫入時驗格式，`inspect` 列出豁免數量，reviewer 每次重算**豁免清單之外**的 error 數。

## 啟用規則

> 只能列 `kit/rules/registry.md` 存在的 id。啟用項裡**沒有任何 `security/*`** 時，需要你在流程啟動前二次確認（後果：只執行主體基本安全項，不含專案專屬清理器／白名單檢查）。

| id | status | 為什麼啟用 |
|---|---|---|
| TBD（未確認） | 未驗證 | TBD（未確認） |

## 回歸熱點

> 這一欄是 reviewer「建議手動回歸檢查」與影響範圍分析的專案來源。空著不會讓你 FAIL，但 reviewer 只能給泛泛建議（會標記未覆蓋）。

| 檔案／區域 | 被動到時要人工檢查什麼 | 誰填 |
|---|---|---|
| TBD（未確認） | TBD（未確認） | 你填 |

## 共用項目類別（要 grep 使用處的範圍）

> 描述「哪些類別算共用項目」，具體路徑寫在這一欄。reviewer 會逐類去查使用處。

TBD（未確認）

## 安全慣例

| 欄位 | 值 | 誰填 |
|---|---|---|
| 清理入口 | TBD（未確認） | 你答（偵測只會給候選，掃到不代表正確） |
| 應經流程 | TBD（未確認） | 你答（例：外部內容須經哪個函式才進渲染） |
| 既有危險點 | TBD（未確認） | 你填（哪些位置插入原始 HTML；新增此類位置時要同步加進來） |
| 不得放寬 | TBD（未確認） | 你填（白名單範圍、退路行為） |

> 通用危險模式（插入原始 HTML 的各形式、危險協定、敏感資料落地、新增依賴）**常駐主體**（主檔 §3 第 0 點），不靠 pack、也不得被本檔任何欄位取消。這裡只補「本專案的入口、白名單內容、既有位置」。

## 專案覆寫

| 欄位 | 值 | 理由 |
|---|---|---|
| 無 | 無 | 無 |

> 覆寫 pack 的欄位**必須附理由**，否則 reviewer 列「一般」。**`security/*` 與主體第 0 點的檢查項只能被覆寫成更嚴，不得取消或降級**；企圖取消時 reviewer 照樣查、引用本欄原文並列「嚴重」。

## 模型

不記錄於本檔。model 綁定的唯一真相是 `<設定檔路徑>` 的 `agents.<id>.model`（由 init 寫入、`inspect` 讀取顯示）。主體 agent 一律不寫 model；未設定時 subagent 繼承 session model。

## 額外 shell（選填，developer 的「詢問預期清單」）

| 指令模式 | 用途 |
|---|---|
| 無 | 無 |

> 方案 B 下這一欄**不是授權來源**（專案端不寫 shell 規則）。它的作用有二：① 讓你知道哪些指令會被問——首次執行時你選 `Allow always`，OpenCode 會存成專案級持久 allow，這是 developer 唯一合法的擴充路徑；② 給 `compile` 判斷哪些 gate 需要人工執行。
> **reviewer 不能靠這一欄擴張**可執行範圍（它的 shell 地板是 deny，而持久 allow 蓋不掉設定好的 deny）；要給 reviewer 新指令只能升級 kit、改主體靜態清單。
> 內容仍要過寫入性檢查：**含檔案系統寫刪或任意執行語意的條目一律拒絕**（例：自動修正類旗標、`rm`、`Remove-Item`、`Invoke-Expression`），否則這一欄就成了提權旁路。

## 安裝紀錄（`setup` 維護，`compile` 重譯時保留）

| 項目 | 值 |
|---|---|
| 上次 init／compile 日期與 kit 版本 | TBD（未確認） |
| 上次 `inspect [probe]` 日期／OpenCode 版本 | TBD（未確認） |
| probe 第 0 條 `Get-Location` 落點＝本專案？ | TBD（未確認） |
| probe 第 1 條（主體靜態清單 gate）／第 2 條（必被拒的寫入指令）結果 | TBD（未確認）／TBD（未確認） |
| 權限模式（A／B；現行預設 B） | TBD（未確認） |
