# frontend-devkit 設計文件

- 日期：2026-11-11
- 狀態：待使用者審核
- 目的：把 `TOS_Frontend` 專案已驗證的「協調者 → 開發者 → 審核者」三 agent 流程，重構為可重複安裝到其他前端專案的 kit（`frontend-devkit`）
- 硬性約束：**現有專案的 `.opencode/agents/`、`.opencode/commands/`、`.opencode/workflow-rules.md`、`.opencode/worktree-procedures.md` 一個字都不改**，舊流程照常使用

---

## 0. 檔案地圖（第 5 輪拆檔）

| 檔 | 內容 | 誰在什麼時候讀 |
|---|---|---|
| `specs/2026-11-11-frontend-devkit-design.md`（本檔） | §1–§11、§14、§15：目標、決策彙總、三層模型、檔案結構、profile 規格、pack 規格、角色邊界、指令規格、worktree 程序、流程行為、降級處理、交付順序、風險 | 任何人要理解或改動 kit 時的入口 |
| `docs/permission-spec.md` | 原主檔 §7.3：方案 A／B、官方事實八條、語法紀律（含**字面同形鐵律**）、規則鏈範例、跨來源紀律、allow 產生流程、model 策略 | **寫四個 agent 的 frontmatter、寫 `setup` 的比對器之前必讀** |
| `docs/migration-map.md` | 原主檔 §12：現行 agent 每一條規則搬到哪裡 | 實作步驟 4（抽 pack）、步驟 7（寫主體）的查核清單 |
| `docs/acceptance.md` | 原主檔 §13：關卡 0～8 | 驗收時逐關執行；每個關卡的通過條件就是定義 |
| `docs/experiments.md` | R1 八題實測數據、方法學警告、結案清單 | 質疑任何權限結論時的原始依據 |
| `docs/CHANGELOG.md` | 附錄 A（原主檔 §16 速查，權威已在 §2）＋附錄 B（第 1～5 輪審核與 R1 實測的修訂史） | 想知道「為什麼這樣寫」時；**非實作依據** |

> 閱讀順序：本檔 §1–§2（要能做什麼與決策）→ `permission-spec.md`（權限）→ 本檔 §5–§6（profile／pack）→ §7.1–§7.2＋§9–§11（角色與流程）→ `migration-map.md` → `acceptance.md`。

## 1. 目標與非目標

### 目標

1. 主體（流程與鐵則）只寫一次，可裝在全域 `~/.config/opencode/` 或專案 `.opencode/`，兩處內容相同。
2. 專案差異（指令、技術棧知識、熱點、安全入口、分支名、環境檔）全部外移到資料檔，不留在 agent 提示詞裡。
3. 新專案用一條指令完成設定檔產生，可立即跑開發／審核迴圈。
4. 保留現有設計裡真正有價值的部分：角色邊界、輪數控制、回歸防護五步、嚴重度判定、固定回報格式、worktree 安全順序、commit 前人工審核、絕不 push。

### 成功標準

| 項目 | 標準 |
|---|---|
| 新專案上手時間 | 跑 `/frontend-devkit/init` + 一次 `/frontend-devkit/dev` 全流程通畅，人工投入 ≤ 30 分鐘 |
| 主體升級成本 | 只改 kit repo；專案端最多重跑 `/frontend-devkit/init compile`，不需重寫任何欄位 |
| 現有專案零影響 | 本專案 `git status` 乾淨、舊 agent／指令檔 diff 為空、`/dev` 行為不變 |
| 判定誠實度 | 任何因設定檔缺失而沒做的檢查，都必須出現在回報裡（不可默認通過） |

### 非目標（本次明確不做）

1. 不做跨平台 worktree 程序（僅 PowerShell；`shell: bash` 時 kit 拒絕執行並告知）。
2. 不預寫未經真實專案驗證的 pack（React、Vitest、Tailwind 等留待對應專案出現才寫，見 §6.4）。
3. 不做 monorepo／workspace 的專案發現在內作業（只支援「一個 repo = 一個前端專案」；pnpm workspace 的依賴策略僅標示不支援 worktree 隔離）。
4. 不取代現有 agent、不做遷移本專案的動作。
5. 不做自動 push、自動開 PR、自動解決合併衝突。

---

## 2. 決策彙總

| # | 決定 | 理由 |
|---|---|---|
| D1 | 源頭是獨立 git repo `frontend-devkit`（本機開發位置範例：`C:\Users\vipjo\AI\frontend-devkit`；**這只是範例，不是 kit 執行期引用的路徑**，執行期一律 `git rev-parse --show-toplevel`，見 §9.1） | 不依附任何專案，換機器 clone 即用 |
| D2 | 命名空間資料夾一律 `frontend-devkit` | 與本專案裸名 agent 隔離，避免 V2「同名 agent 定義合併、permission 規則附加」造成的行為改變；指令與 agent ID 都自帶 frontend 字樣 |
| D3 | 方案 B-lite：主體 + 規則包（pack）+ 專案設定檔（profile）三層，初始僅 4 個 pack | pack 讓同類專案的知識可重用；只收已驗證知識，避免憑空推測變成審核依據 |
| D4 | 專案設定檔 `.opencode/frontend-devkit/project.md`，建議進該專案版控 | 同事 clone 就能用；絕對路徑一律不寫入 |
| D5 | 編譯式載入：`init` 把啟用的 pack 展開成 `resolved.md`，agent 只讀 `project.md` + `resolved.md` | 一次讀取、名稱錯誤在 init 就報、產物可 diff 可審 |
| D6 | `project.md` 與 `resolved.md` 由專案 `opencode.json` 的 `instructions` 註冊自動注入；主體保留「看不到就 read、還找不到就停止」的備援 | 確定性與零探索成本，同時不會因某專案沒註冊而靜默失去依據 |
| D7 | 通過標準：指令寫設定檔，**數字一律執行期動態量測**，不寫死 | 換專案不會拿到錯的 99 項、`ChatBox.vue:45` 這類舊事實 |
| D8 | `worktreePolicy: ask \| always \| never` 與 `depStrategy: junction \| install-per-worktree \| none` 寫進 profile | 小專案不必每次被問；pnpm／workspace 的 `node_modules` 不適用 junction |
| D9 | 新增第 4 個 agent `frontend-devkit/setup`，只負責 init／compile／inspect 的寫檔 | 三 agent 的「不寫設定檔／唯讀／只改工作區程式碼」邊界得以完整保留；可寫路徑用 V2 `edit` resource glob 鎖到最小 |
| D10 | 主體不寫死 model；要固定就由 init 寫進專案 `opencode.json` 的 `agents.<id>.model` | 換機器 provider 不同時不會報錯；未設定時 subagent 繼承 session model |
| D11 | kit 檔案採 OpenCode **V2** 格式（`permissions: [{action, resource, effect}]`、`model: provider/model#variant`、`subagent`） | 本機是 opencode v2.2.7；V1 `permission:` 地圖已標本但仍在讀，新檔不該再產生 |
| D12 | 驗證用 throwaway 專案跑關 1～7（關 0 是人工建置，關 8 是本專案零影響查核），本專案只跑「零影響查核」 | 測試必然會建 worktree、裝依賴、寫 commit，不該在真實專案上做 |
| D13 | ~~**權限次序無關設計**：主體 frontmatter 自成規則鏈＋專案端追加窄域 allow~~ → **實測後修正**：主體 `.md` 的規則排在設定檔之後，專案端 allow **不會生效**；因此 kit 改採**方案 B**（全部 shell 規則靜態寫在主體），專案端設定只留 `instructions` 註冊與 `model` 覆寫 | 官方只保證「lower-priority → global → agent rules，最後符合者勝」，**未記載同 agent 的 .md 與 jsonc 條目誰先附加**——實測答案出來了（`docs/experiments.md` 第 3 題），設計據此定稿，不再押在假設上 |
| D14 | 各 agent 的 shell 基礎效果：reviewer＝`deny`（全拒後再白名單放行）、orchestrator／developer＝`ask`（未列即詢問）。**尾巴依三段式（D20）**：第 1 段「真地板群」不可被任何 allow 覆寫；第 2 段可變依賴 deny **可以被第 3 段的不可變例外 allow 翻回** | 官方保證「最後符合者勝」：把真地板放最後就是不可覆寫的地板；但 frozen install 的例外必須排在 deny 家族之後才生效（第 3 輪 G11、第 4 輪指出 D14 原文「deny 一律排最後」與 D20 衝突，故限定為第 1 段）。developer 用 ask 而非 deny 是為了不卡在合法唯讀指令上 |
| D15 | 執行期唯一依據是 `project.md` + `resolved.md`（worktree 程序也經 compile 折進 `resolved.md`）；三個開發 agent 不讀 `kitRoot` | 全域安裝時程序檔在專案外，`external_directory` 預設 allow 但使用者可改成 ask，不能當保證；同時讓「本輪照哪一版規則審」可被 commit 稽核（§4.2.2） |
| D16 | `設定檔路徑` 進 profile 欄位；init 寫入專案現有形式的設定檔（根 `opencode.json` 或 `.opencode/opencode.json`），兩者並存時用 `question` 決定 | 官方：`.opencode` 內的設定**覆蓋**根目錄同名設定，且建議一棵樹只用一種形式；寫錯檔會造成兩份設定與讀取混亂 |
| D17 | probe 由 `setup` 派 `frontend-devkit/reviewer` 執行（setup 的 `subagent` 唯一起外），結果記在 `project.md` 的 `## 安裝紀錄` | 只有 setup 能寫設定檔與 `project.md`；被派者唯讀且不能再派工（第 2 輪 G4；第 3 輪確認 `subagent` 是 V2 正名、resource 為 agent ID、deny→allow 次序合法） |
| D18 | 安全檢查有**兩道封頂**：`## 專案覆寫` 不得取消／降級 `security/*`；`## 啟用規則` 若不含任何 `security/*` 需 `question` 二次確認 | 第 2 輪只堵了覆寫路徑，第 3 輪發現「整條停用 pack」可讓 XSS 審核線靜默消失（啟用清單仍一致、八關全過） |
| D19 | 專案端 allow **不得命中主體尾巴第 1、2 段 deny**（比對時排除 `resource:"*"` 地板），由 `setup` 寫入前與 `inspect` 雙重機械檢查 | 這是 D13「次序無關」成立的必要前提；但若把地板也算進比對，方案 A 會被自己封殺（第 3 輪 G3 修正） |
| D20 | shell 尾巴一律**三段式**：真地板群 → 可變依賴 deny 群 → 不可變例外 allow 群（`npm ci`、`pnpm/yarn install --frozen-lockfile`） | 「最後符合者勝」要求例外排最後，否則 §9.3 的 `install-per-worktree` 專案被自己翻回 deny（第 3 輪 G11） |
| D21 | 源頭一致性檢查：`inspect` 以 kitRoot 素材在上下文重建內文並**逐行**比對（比對範圍排除檔頭動態欄） | 只比 checksum 會被「保留原 hash」混過；但「逐行 diff」需要能寫暫存檔且時間戳會讓警告常亮——降調為誠實的 LLM 逐行比對（第 3 輪 G9a） |
| D22 | **主體常駐一份基本安全項清單**（危險 DOM 寫入、危險協定、敏感資料落地、新依賴），不屬於任何 pack | pack 化的代價是「停用 pack 就沒安全底線」；把最小清單留在主體才能讓 D18 有意義（第 3 輪嚴重項） |
| D23 | profile 的四個**值**屬白名單欄位（`設定檔路徑`、`kitRoot`、`worktree 目錄`、`環境檔`），`setup` 寫入前驗、`inspect` 每輪重驗，非法即停止 | 第 4 輪嚴重項：profile 依 §3 是「不可信輸入」，但先前只驗格式、不驗值 → 可借 setup 改寫**全域**設定、把 worktree 與 `.env` 放到專案外、或掉包 D21 的比對基準（§5.1.2） |
| D24 | developer 的 `edit` deny 加 **`*.git/*`**（含 `hooks/`） | 第 4 輪嚴重項：寫 `.git/hooks/post-commit` 後，你每次 commit 都以你的權限執行任意程式碼——與「改設定檔自我提權」同級，前三輪都漏了 |

> 兩輪獨立審核的「發現 → 修法」對照（第 1 輪 16 項＋簡化 4 項＋既有 2 項、第 2 輪 13 項＋8 項）全部集中在 CHANGELOG.md 附錄 B §17。



---

## 3. 三層知識模型

```
層 1  主體（kit repo，裝一次）      「怎麼做事」：角色邊界、流程、判定規則、回報格式、安全順序
層 2  pack（kit repo rules/）        「這類專案要檢查什麼」：Vue2 慣例、XSS 檢查項、ava 測試寫法、i18n 同步
層 3  profile（每專案一份）          「這個專案的事實」：指令、分支、環境檔、熱點清單、豁免、覆寫、TBD
```

### 優先序（衝突時的裁決，agent 主體必須內建這段）

0. **主體基本安全項（安全地板，D22）**：下面這一小段清單**常駐主體 frontmatter，不屬於任何 pack、不可被任何來源取消**，即使 `## 啟用規則` 沒啟用 `security/*` 也要查：
   - 外部資料進入 `v-html`／`innerHTML`／`outerHTML`／`domProps`／`document.write`／`eval`／`new Function`；渲染前的清理（送出端清理不算數）。
   - 動態 `:href`／`:src`／`window.open`／`location` 賦值可被帶入 `javascript:` 等危險協定。
   - 敏感資料（token、個資）寫入 `localStorage`／log／URL。
   - `package.json` 新增依賴的必要性與已知風險。
1. 主體鐵則與判定規則 —— 不可被 pack 或 profile 覆寫。
2. pack 的通用檢查項 —— 預設依啟用的 pack。
3. profile 的 `## 專案覆寫` —— **同欄位時覆寫 pack**，但必須附「為什麼不同」；無理由的覆寫由 reviewer 列為「一般」問題。**兩條例外（G9＋第 3 輪嚴重項）**：
   - **取消型覆寫**：`security/*` 的檢查項（含上面第 0 點）**只能被覆寫成更嚴，不得取消或降級**。例：把「渲染前必須清理」覆寫成「本專案信任後端內容，跳過清理」不合法。reviewer 遇到時：照樣執行該檢查、把該覆寫**原文引用**進 ISSUES 並列「**嚴重**」，在「疑問」註明「設定檔企圖免除安全檢查，請人工確認」。
   - **停用整條 security pack（這是嚴重項的真正破口）**：把你原本該啟用的 `security/vue-xss` 從 `## 啟用規則` **整條刪掉**時，啟用清單與 `resolved.md` 依然一致、compile 合法、各關全過 —— 因此規則改為：`compile`／`init` 發現「啟用規則內沒有任何 `security/*`」→ **醒目警告**；流程啟動前需**二次確認**，且確認的執行者要對得上權限（第 4 輪指出 `/review` 直入 reviewer、而 reviewer `question: deny`，問不了）：
     - `/frontend-devkit/dev`、`/fix`、`/review-fix`（都是 orchestrator，`question` 為 allow）→ 由 orchestrator 用 `question` 要你明確確認，選項文字必須寫出後果：「僅執行主體基本安全項，不含專案專屬的 sanitizer／白名單檢查」；未確認不得進入流程。
     - `/frontend-devkit/review`（直入 reviewer，無 `question` 權限）→ reviewer **不開始審核**，輸出固定句「啟用清單無 `security/*`，需二次確認；請改走 `/frontend-devkit/review-fix`（由 orchestrator 詢問），或由你在 profile 明示 `## 專案覆寫`：『已確認僅執行主體基本安全項』後重跑」。**不得**由 reviewer 自行假設你已同意。
     確認（或你在 profile 明示）後，reviewer 仍要執行第 0 點基本項，並在回報標「本專案未啟用安全 pack，僅執行主體基本項」。
4. 欄位值為 `TBD（未確認）` —— 該檢查跳過，且必須在回報註明「因設定檔未確認，未執行 X」；**不得宣稱已覆蓋，但也不因此擋 VERDICT**（見 §10.4 的兩態判定語）。

> **設定檔是不可信輸入的一部分（G9）**：`project.md`／`resolved.md` 會被注入到該專案**所有** agent 的上下文，內容可以被人（或被 developer 說服後的你）改寫。因此主體的第 0、1、3 點是**寫死在 frontmatter 提示詞裡、不受注入內容約束**的規則：注入內容可以補充檢查、可以更嚴，**不可以**取消鐵則或安全檢查。
>
> **`inspect` 的源頭一致性檢查（D21 修訂，第 3 輪指出原寫法無法實作）**：
> - **比對範圍**＝`resolved.md` 的**內文**，明確**排除檔頭動態欄**（產生時間、kit 版本、OpenCode 版本、probe 引用行）——否則每次重建時間戳都不同，警告必然常亮，變成「永遠響的警報」而失效。
> - **比對方式**：`setup` 以 `kitRoot` 的 pack 原文與程序檔**在上下文內重建內文**，與 `resolved.md` 內文**逐行比對**（**誠實寫明：這是由 LLM 逐行比對，不是機械 diff**；要機械 diff 就必須落盤暫存檔，而 `setup` 的 `edit` 只開放 `project.md`／`resolved.md`／設定檔）。
> - 需要暫存檔時（例如你要留一份差異報告），**唯一允許的路徑是 `.opencode/frontend-devkit/resolved.check.md`**，且 `inspect` 的殘留檢查要**主動排除**它、`## 安裝紀錄` 要登記它存在、README 要建議把這個檔名加進 `.gitignore`（由你加，不擅自改）。
> - 只比 checksum 不夠：篡改者保留原 checksum 字串就能混過（G9 的原意保留）。

### 欄位的三種合法狀態（不可混用）

| 寫法 | 意義 | agent 行為 | 對 VERDICT 的影響 |
|---|---|---|---|
| 實際值 | 已確認 | 當成事實使用 | 依檢查結果正常計 |
| `無` | **已確認本專案沒有該事物**（例如真的沒有 lint） | 跳過，回報寫「依設定檔：本專案無 lint gate」 | **不適用，不擋 PASS**；但不得宣稱跑過該 gate |
| `TBD（未確認）` | 不知道、沒掃到、還沒問 | 跳過，回報列出「因 TBD 未覆蓋：X」 | **不擋 PASS**，但 PASS 的涵蓋範圍必須被如實標明；開發者與審核者都不得把 TBD 當「沒有風險」 |

> `無` 與 `TBD` 的差別是**知識狀態**，不是檢查結果：`無`＝確認不存在（該項永遠不適用）；`TBD`＝確認不知道（本輪沒查）。兩者都不構成 FAIL，但 `TBD` 必須在回報中留下未覆蓋紀錄，讓你知道 PASS 的邊界在哪。

---

## 4. 檔案結構

### 4.1 源頭 repo（`frontend-devkit`）

```
frontend-devkit/
├─ README.md                       快速開始：装 kit → 到專案 init → 用指令
├─ docs/
│  ├─ specs/2026-11-11-frontend-devkit-design.md   ← 本檔
│  ├─ install.md                   全域安裝與專案安裝兩種做法、升級、衝突檢查
│  ├─ adding-a-project.md          init 的問答範例、profile 各欄位怎麼補
│  └─ writing-a-pack.md            pack 撰寫規範（同 kit/rules/_CONVENTION.md 的可讀版）
└─ kit/
   ├─ agents/frontend-devkit/
   │  ├─ orchestrator.md           協調者（primary）
   │  ├─ developer.md              開發者（subagent）
   │  ├─ reviewer.md               審核者（all，唯讀）
   │  └─ setup.md                  設定者（all，只寫設定檔）
   ├─ commands/frontend-devkit/
   │  ├─ dev.md  fix.md  review.md  review-fix.md  init.md  inspect.md
   ├─ rules/
   │  ├─ _CONVENTION.md
   │  ├─ stack/vue2-nuxt2.md
   │  ├─ testing/ava.md
   │  ├─ security/vue-xss.md
   │  ├─ i18n/vue-i18n-json.md
   │  └─ registry.md               pack 清單與 id 對照（init 驗證 id 存在性用）
   ├─ profile/
   │  └─ project.template.md       含每欄位說明、範例、TBD 規則
   └─ worktree.procedures.md       PowerShell worktree 程序（唯一出處）
```

### 4.2 安裝位置（二選一，內容相同）

| 方式 | 主體與指令 | 非 agent 素材（rules、profile 範本、worktree 程序檔） | 適用 |
|---|---|---|---|
| 全域 | `~/.config/opencode/agents/frontend-devkit/*.md`、`~/.config/opencode/commands/frontend-devkit/*.md` | `~/.config/opencode/frontend-devkit/{rules/,profile/,worktree.procedures.md}` | 多專案共用、主體升級一處生效 |
| 專案 | `<專案>/.opencode/agents/frontend-devkit/*.md`、`<專案>/.opencode/commands/frontend-devkit/*.md` | `<專案>/.opencode/frontend-devkit/{rules/,profile/,worktree.procedures.md}`（與該專案 profile 同資料夾） | 想把 kit 鎖在某專案、或同事不會裝全域 |

> **發現規則陷阱（實作必守）**：OpenCode 會把 `agents/` 與 `commands/` 底下的**所有** `.md` 當成 agent／指令來發現，巢狀路徑會變成 ID 的一部份（`agents/frontend-devkit/rules/vue2-nuxt2.md` 會冒出 `frontend-devkit/rules/vue2-nuxt2` 這個「agent」）。所以 **rules、profile 範本、程序檔一律放在 `agents/`、`commands/` 之外的 `frontend-devkit/` 資料夾**。acceptance.md §13 第 1 關必須驗證 agent 清單裡沒有多出來的條目。

安裝對應（源頭 → 位置，兩種裝法同則）：`kit/agents/frontend-devkit/*` → `<config>/agents/frontend-devkit/*`；`kit/commands/frontend-devkit/*` → `<config>/commands/frontend-devkit/*`；`kit/rules/`、`kit/profile/`、`kit/worktree.procedures.md` → `<config>/frontend-devkit/`（即 profile 記錄的 `kitRoot`）。`<config>` 全域裝法是 `~/.config/opencode`，專案裝法是 `<專案>/.opencode`。另：源頭 repo 本身也用 `kit/agents/frontend-devkit/` 的巢狀結構，目的是「複製過去時路徑形狀完全一致」，減少安裝出錯。

### 4.2.1 安裝紀律（寫進 README）

1. **同一專案不要同時有全域與專案兩份主體**（同名 agent 的 permission 規則會附加，行為難推理）。`/frontend-devkit/inspect` 會檢查並警告。
2. rules／程序檔的所在目錄由 profile 的 `kitRoot` 欄位記錄：全域裝法記 `~/.config/opencode/frontend-devkit`（用 `~` 寫法，不記錄 `C:\Users\...` 這種個人絕對路徑）；專案裝法記 `.opencode/frontend-devkit`。
3. **`kitRoot` 只有 `setup`（init／compile／inspect）會讀**。開發迴圈的三個 agent **不得**去 `kitRoot` 讀任何東西：官方文件雖寫明 `external_directory` 預設 allow，但那是「使用者沒改全域政策」時的狀態，不能當保證。因此 **`worktree.procedures.md` 是源頭素材，經 compile 參數化後折進 `resolved.md` 的「worktree 程序」段落**，成為執行期唯一依據（見 §9）。
4. 升級 = kit repo `git pull` → 覆蓋安裝位置 → 各專案 `/frontend-devkit/init compile`（重讀 pack 與程序檔、重譯 `resolved.md`）。

### 4.2.2 單一執行期依據（D15）

| 來源 | 誰讀 | 內容 |
|---|---|---|
| `project.md` | 四個 agent（經 instructions 注入） | 本專案的事實與你手工判斷 |
| `resolved.md` | 四個 agent（經 instructions 注入） | 啟用的 pack 檢查項 + **參數化後的 worktree 程序** + 啟用清單與 pack checksum 紀錄 |
| `kitRoot`（pack 原文、程序檔原文、範本） | 只有 `setup` | init／compile 的輸入、inspect 的比對基準 |

好處：執行期不需要任何專案外目錄的讀取權、不需要主體去猜 pack 路徑，而且「這一輪審核照哪一版規則做」會被 `resolved.md` 的產生時間與 pack checksum 記錄下來，可隨 commit 一起被稽核。

### 4.3 專案端（init 產生）

```
<專案>/.opencode/frontend-devkit/project.md      你維護（建議進版控）
<專案>/.opencode/frontend-devkit/resolved.md     init 產出（建議進版控，可 diff）
<專案>/<設定檔>                                  追加 instructions 與 model（既有欄位不覆蓋）。**方案 B 下不得在此寫 shell 規則**；`inspect` 若偵測到 `agents.<id>.permissions` 含 shell 條目 → 警告「與方案 B 矛盾，且依 experiments 第 3 題此類 allow 不會生效」
```

`<設定檔>` 有兩種合法形式（`opencode.json(c)` 於專案根，或 `.opencode/opencode.json(c)`），官方規則：`.opencode` 內的設定**覆蓋**根目錄的同名設定，且建議一棵樹只用一種。所以：

- init 必須先偵測專案現有用的是哪一種，把設定寫進**同一份**，並將該路徑記入 profile 的 `設定檔路徑` 欄（後續 compile／inspect 只認這一欄）。
- 兩者並存時用 `question` 請你選要寫哪一份，並如實告知「`.opencode` 那份會蓋掉根目錄那份」的優先序。
- 專案兩者都沒有時，預設建立 `.opencode/opencode.json`（跟 kit 素材同側，路徑一致性好）。

若該專案 `.gitignore` 排除了 `.opencode/`（本專案就是如此），init 會告知「設定檔不會進版控，同事需自行跑 init」，並詢問是否改為排除 `!.opencode/frontend-devkit/`；**不擅自改 .gitignore**。

---

## 5. profile 規格（`project.md`）

檔名固定 `project.md`，小節與欄位如下（缺欄位一律寫 `TBD（未確認）`，不可留空）。**未知只寫在欄位值上，本檔不另設「未知總表」**——總表與欄位值是兩個真相，必然漂移；要清單就跑 `/frontend-devkit/inspect`，它掃全文彙整（CHANGELOG.md 附錄 B §17.3 S-1）。

```md
# frontend-devkit 專案設定檔

## 識別
| 欄位 | 值 |
|---|---|
| 專案名稱 | CHT-ChatBot（TOS_Frontend） |
| 技術棧一行 | Vue 2 / Nuxt 2 / Vuetify 1.5 |
| shell | powershell |
| 設定檔路徑 | .opencode/opencode.json |
| kitRoot | ~/.config/opencode/frontend-devkit |
| worktreePolicy | ask |
| depStrategy | junction |
| worktree 目錄 | .worktrees/ |
| 分支前綴 | `feature/`（dev）、`fix/`（fix 與 review-fix） |
| worktree 名稱前綴 | `review-`（審核用，後接 sha7）；開發用為 `<類型>-<slug>` |
| 預設基準分支 | origin/main |
| 預設審核範圍 | HEAD..origin/main（省略範圍時） |
| 環境檔 | .env |

## 指令
| gate | 指令 | timeout | 備註 |
|---|---|---|---|
| test | npm test | 600000 | ava，全部測試；聚焦除錯可另用 `npx ava <檔>`，但判定以全測為準 |
| lint（單檔） | npx eslint --ext .js,.vue <檔案...> | 120000 | 只跑異動檔；禁止 `--fix` |
| lint（全專案） | npm run lint | 300000 | 僅供參考，不據此判定 |
| build | npm run build | 600000 | |
| 依賴安裝（worktree 用） | npm ci | 600000 | `depStrategy: install-per-worktree` 時用這條，例 `pnpm install --frozen-lockfile` |
> 注意：**任一 gate 在專案裡不存在時**（純函式庫型專案常沒有 build）在對應列寫 `無`，agent 就跳過該 gate 並在回報標明；**不得憑空假設一個指令**。未知的寫 `TBD（未確認）`——所有未知都寫在欄位值上，不另設總表（由 `inspect` 掃全文彙整）。

## 測試慣例
| 欄位 | 值 |
|---|---|
| 框架 | ava 2（`package.json` 的 `ava` 設定） |
| 測試檔位置與命名 | `test/specs/*.spec.js` |
| 寫法慣例 | `@vue/test-utils` 的 `mount` 驗證執行期行為；避免用 `fs` 讀原始碼比字串 |
| 禁止選項 | `npx ava --update-snapshots` |
| 已知豁免 | eslint：`ChatBox.vue:45` 的 `vue/no-v-html`（既有 warning，不影響 VERDICT；新增此 warning 須逐一說明）。**範圍上限（第 3 輪殘留漏洞 #2）**：豁免只能寫成「**具體檔案＋具體規則＋理由**」三件套；**不得**豁免任何 gate 的執行失敗（test／build 掛掉不是豁免能覆蓋的）、不得豁免「嚴重」級問題、不接受「全部 lint error 皆豁免」這類總括式寫法。`setup` 寫入時就要驗格式，`inspect` 列出豁免數量，reviewer 每次**重算豁免清單之外**的 error 數 |

## 啟用規則
- stack/vue2-nuxt2
- testing/ava
- security/vue-xss
- i18n/vue-i18n-json

## 回歸熱點
| 檔案／區域 | 被動到時要檢查什麼 |
|---|---|
| src/components/chatroom/chat/ChatWindow/ChatBox.vue | 機器人 Markdown、使用者訊息、連結新分頁、模板卡片 |
| src/components/chatroom/chat/ChatSendbox.vue | Enter 送出、按鈕送出、字型切換、格狀選單、語音 |
| src/assets/less/app.less | 桌面與手機版版面、各斷點、既有元件外觀 |

## 共用項目類別（要 grep 使用處的範圍）
元件 props／events／slots／ref／methods／computed／data、store 的 state／mutations／actions、`src/util/*.js` 匯出、`src/mixins/*`、`src/plugins/*`、`src/data/*`、`src/config`、全域樣式選擇器與 class、i18n 鍵、socket.io 事件名與 payload、後端 API 介面。

## 安全慣例
| 欄位 | 值 |
|---|---|
| 清理入口 | `@/util/sanitizer`（必須在渲染前，送出端清理不算數） |
| 既有危險點 | `ChatBox.vue:45` 唯一 `v-html`，資料來自 `@/util/markdown` 的 `renderMarkdown`（markdown-it + DOMPurify 白名單，無 img，協定限 http/https/mailto，DOMPurify 不可用時退回純文字轉義） |
| 不得放寬 | `renderMarkdown` 白名單、`sanitizeInput` 行為 |

## 專案覆寫
| 欄位 | 值 | 理由 |
|---|---|---|
|（無則寫「無」；覆寫 pack 的欄位要寫明依据與理由）|||

## 模型
不記錄於本檔。model 綁定的唯一真相是 `<設定檔路徑>` 的 `agents.<id>.model`（由 init 寫入、`inspect` 讀取顯示），避免同一設定存在兩處而不知哪個生效（§7.4）。

## 額外 shell（選填，developer／reviewer 常需的唯讀指令）
| 指令模式 | 用途 |
|---|---|
| `git ls-files *` | 查檔案清單 |
| `npx prettier --check *` | 格式檢查（**不可** `--write`） |

> 這一欄的存在理由：developer 的 shell 採「未列即詢問」（D14），合法但少見的唯讀指令要在這裡白名單化，否則你一直被問。**方案 B 下的定義（第 5 輪改正：這一欄不再是授權來源）**：① 它是 developer 的「詢問預期清單」——清單內指令首次執行時你選 `Allow always`，官方會存成專案級持久 allow（permission-spec.md §7.3.1 事實 7），這是 B 下 developer 唯一合法的擴充路徑；② 給 `compile` 判斷「哪些 gate 需人工執行」。**reviewer 不能靠這欄擴張**（它的地板是 deny，而持久 allow 蓋不掉設定 deny），需要新指令只能改 kit 主體清單並升級。寫進設定檔時一樣走 permission-spec.md §7.3.5 的寫入性檢查與逐條批准——**人填的條目也不得直接變成 allow**，否則這一欄會變成 I-2 的旁路（例：有人填 `npm install *`，而 developer 的第 2 段 deny 必須壓在它上面）。

## 安裝紀錄（setup 維護，compile 重譯時保留）
| 項目 | 值 |
|---|---|
| 上次 `probe` 日期／OpenCode 版本 | 2026-11-11／v2.2.7 |
| probe 第 0 條 `Get-Location` 落點＝本專案？ | 是 |
| probe 第 1 條（靜態清單 gate，如 `npm test`）／第 2 條（寫入指令）結果 | allow／deny |
```

### 5.1 init 的偵測對應（可機械偵測的欄位）

| 偵測方式 | 寫入欄位 |
|---|---|
| lockfile（`package-lock.json`／`pnpm-lock.yaml`／`yarn.lock`／`bun.lockb`） | 包管理器 → `依賴安裝` 指令、`depStrategy` 建議值 |
| `package.json` 的 `scripts.test`／`scripts.lint`／`scripts.build` | `## 指令` 各列；不存在就寫 `無` |
| `devDependencies`／`dependencies`（vitest／jest／ava／mocha／cypress／playwright／@testing-library） | `測試慣例` 框架、建議啟用的 `testing/*` pack |
| 測試檔樣板搜尋（`**/*.spec.*`、`**/*.test.*`、`test/`、`__tests__/`） | `測試慣例` 位置與命名 |
| `git symbolic-ref refs/remotes/origin/HEAD` 或 `git remote show origin` | `預設基準分支`、`預設審核範圍` |
| `.eslintrc*`／`eslint.config.*` 是否存在 | lint gate 與單檔指令 |
| `locales/`、`lang/`、`i18n/`、`*.json` 語系樣板 | `i18n` pack 建議、語系檔路徑 |
| 框架指標（`nuxt`、`vue`+`@vitejs/plugin-vue`、`next`、`react`） | 建議啟用的 `stack/*` pack |
| `.env*` 檔名 | `環境檔` |
| `$env:OS`／`$PSVersionTable` 這類含 `$` 的寫法**不可用**（第 8 題實測 DENIED）；探針用 `Get-Location` 精確形 | `shell`；主工作區用 `git rev-parse --show-toplevel` 取得但**只用作執行期變數，絕不落盤** |
| 既有 `dangerouslySetInnerHTML`／`v-html`／`innerHTML`／DOMPurify／sanitize 字串搜尋 | `安全慣例` 候選值（仍需你確認，掃到不代表正確） |

偵測結果一律標註來源：`(偵測自 package.json scripts.test)`，讓你分得清哪些是猜的、哪些是你答的。

### 5.1.1 五個偵測細節（第 1 輪審核補）

1. **`shell` 欄的循環問題**：不能用 `$env:OS` 或 `Get-Content` 之類去「判斷 shell 是什麼」，因為那些指令只有在目標 shell 已經成立時才跑得起來。kit 的定義：`shell` ＝ **OpenCode 的 shell 工具實際運行的環境**。**探針寫法依 `docs/experiments.md` 第 8 題定稿**：用 `Get-Location`（PowerShell 獨有 cmdlet，無 `$`、無括號；實測 EXECUTED 會回傳目前路徑）→ 成功回傳路徑形如 `Path ---- C:\...` 即記 `powershell`；若它「不是內部或外部命令」之類錯誤 → 記 `TBD` 並用 `question` 請你確認。可用 `cmd /c ver` 交叉確認 Windows（實測回 `Microsoft Windows [Version …]`）。**禁止**用 `Write-Output $PSVersionTable.PSVersion.ToString()` 這類含 `$` 變數成員存取或括號子運算式的寫法——**實測為 DENIED**（即使 `Write-Output *` 已在白名單。錯誤訊息當下未存檔，因此「被判為無法安全分析」或「括號內子指令未獲准」兩者哪一個是真正機制，屬**推定**，見 `experiments.md` 第 8 題與 CHANGELOG.md 附錄 B §17.11 的加值敘述更正）。非 PowerShell 時 kit 的 worktree 程序無法執行，流程停止（§11）。不承諾探測 POSIX（本次非目標），也不得用「假設是 Windows」瞞過去。
   > 附帶教訓（`experiments.md` 二.1）：`opencode run` 的 shell 在 **service 綁定的專案目錄**執行，不是呼叫端 cwd。所以 `Get-Location` 的回傳值不只用來判 shell，也要用來**確認實驗／操作真的落在預期專案**；對 profile 記錄而言只取「是否 PowerShell」這個結論，**路徑本身絕不落盤**。
2. **`設定檔路徑` 偵測**：檢查根 `opencode.json(c)` 與 `.opencode/opencode.json(c)` 是否存在；只有一個 → 用它；兩個都有 → `question` 請你選並說明「`.opencode` 蓋根目錄」；都沒有 → 預設 `.opencode/opencode.json`。
3. **gate 指令必須先展開再判定**（permission-spec.md §7.3.5）：`scripts.lint` 之類不能照字面 allow，`setup` 要讀出 script 本體（例 `eslint --ext .js,.vue --fix .`）逐條檢查有無寫入性選項，疑似可寫入者不自動 allow。
4. **worktree 目錄是否被 ignore**：用 `git check-ignore -q <worktree 目錄>` 檢查；未被 ignore 時要警告——`--working` 審核會把 worktree 內容（含複製進去、可能帶密鍵的 `.env`）混入未追蹤檔案清單，且容易誤 commit。建議值：把 `.worktrees/` 加進 `.gitignore`（**由你改，init 只建議**）。
5. **預設基準分支的降級**：`git symbolic-ref refs/remotes/origin/HEAD` 與 `git remote show origin` 都拿不到（含無遠端的情境）→ 記 `TBD` 並在 `## 識別` 標明「省略範圍時的審核基準未定義，`/frontend-devkit/review` 不帶範圍會被要求補」。

### 5.1.2 欄位**值**的合法性檢查（第 4 輪嚴重項：profile 是不可信輸入）

§3 已把 `project.md` 定位成「可被人（或被說服的你）改寫」的不可信輸入，但先前只驗**格式**、沒驗**值**。以下四個欄位屬**白名單驗證**，`setup` 在寫入／compile 前逐項驗，任一不合格**拒絕寫入並停止**（不得「先信了再說」）；`inspect` 每輪重驗：

| 欄位 | 唯一合法值形 | 非法時的後果（為什麼要擋） |
|---|---|---|
| `設定檔路徑` | 只能是四個字面相對形之一：`opencode.json`、`opencode.jsonc`、`.opencode/opencode.json`、`.opencode/opencode.jsonc` | 填 `~/.config/opencode/opencode.json` 之類 → setup 被拿去改**全域**設定，影響這台機器所有專案的 agent 權限（跨專案提權）；填 `.git/…` 或外部路徑 → 寫到不該寫的地方 |
| `kitRoot` | 只能是兩個合法安裝根：`~/.config/opencode/frontend-devkit` 或 `.opencode/frontend-devkit` | 指向別處 → D21 的「源頭素材比對基準」整個被掉包，逐行比對變成「拿對方準備的素材，去比對對方準備的產物」 |
| `worktree 目錄` | 專案內相對路徑；**不得**含 `..`、`~`、盤符（`C:`）、開頭 `/` 或 `\`；不得是 `.git` 或 `.opencode` 本身 | 填 `../x` → §9 程序折進 resolved 後，`git worktree add` 會在**專案外**建立工作區，並把可能含密鍵的 `.env` 複製到專案外（orchestrator 的 `git worktree add *` 本身不限前綴，所以只能靠這欄驗） |
| `環境檔` | 單一檔名（可多檔、逐檔列）；**不得**含 `/`、`\`、`:`、`..`、萬用字元 | 含路徑或外部檔 → `Copy-Item <環境檔> .worktrees/…` 變成「從任意來源複製任意檔」，可被用來把機密檔搬進工作區再讀取 |

另外四欄採**格式**驗證（非白名單）：`worktreePolicy` ∈｛`ask`,`always`,`never`｝、`depStrategy` ∈｛`junction`,`install-per-worktree`,`none`｝、`shell` ∈｛`powershell`,`TBD`｝；`預設審核範圍` 必須是 §8 認得的範圍語法之一。

> **同一輪也補齊 permission-spec.md §7.3.5#2 的「寫入性」清單（原本只有 `--fix` 類旗標）**：`## 指令` 或 `## 額外 shell` 若填 `rm *`、`del`、`Remove-Item`、`Move-Item`、`Rename-Item`、`Set-Content`、`New-Item`（非 junction 用）、`icacls`、`Invoke-Expression`、`iex` 這類**檔案系統寫刪／任意程式執行**指令，一律視為可寫入而**拒絕 allow**；reviewer 節點的專案端 allow 另加一句限定：「僅測試／lint／build／唯讀工具類」。

---

## 6. pack 規格與編譯

### 6.1 pack 能做與不能做

可以寫：這類技術棧要檢查什麼、常見地雷、寫法慣例、術語定義、與主體流程的對應（例：「Vue2 專案的 i18n 同步規則」）。

**禁止寫**：具體指令、timeout、測試項數、error 數、任何路徑與檔名（那些是 profile 的工作）、任何「本專案專屬」判斷。理由：pack 是跨專案共用，一旦開始假設指令，換 pnpm + vitest 的專案就會給出錯誤判定依據。

違反本節的 pack 在 code review 時必須退件。

### 6.2 pack 檔頭格式

```md
---
id: stack/vue2-nuxt2
title: Vue 2 / Nuxt 2 慣例
status: 已驗證
source: TOS_Frontend 現有 reviewer.md／developer.md 抽出
covers: Vue2 options API 慣例、Vuetify 1 屬性、Nuxt2 目錄、eslint standard 風格
---
```

- `status` 只有 `已驗證`／`未驗證` 兩個字面值（**不用方括號**：方括號在 YAML 是 flow sequence，`[未驗證]` 會被解析成陣列而非字串）。
- `covers` 是一行自由文字，寫明「本 pack 管哪些檢查主題」，給人看，也給 compile 做**主題重疊警告**用。
- 不設 `sections` 欄，也**不做 pack 間欄位級別的自動衝突偵測**——pack 本體是自由 markdown，機械比對「兩個 security pack 都定義清理規則」這種語意衝突無法實作（CHANGELOG.md 附錄 B §17 I-10）。改由：`covers` 重疊時 compile 印警告 + `writing-a-pack.md` 的人工退件紀律 + 你在 profile 的 `## 專案覆寫` 裁決。
- `status: 未驗證` 的 pack 被啟用時：compile 要把「本次啟用 N 個未驗證 pack」寫進 `resolved.md` 檔頭，reviewer 必須在輸出的「疑問」區註明「依據未驗證規則包 <id>」。

### 6.3 `resolved.md`（編譯產物）

由 `/frontend-devkit/init compile` 產生，內容為啟用 pack 的檢查項合併結果 **+ 參數化後的 worktree 程序段落**（D15），檔頭記錄：**權限模式（A／B；現行預設 B，permission-spec.md §7.3.0.1#4）**、profile 路徑、啟用清單、每個 pack 的 sha256 前 8 碼、產生時間、kit 版本（kit repo 的 `git rev-parse --short HEAD`）、OpenCode 版本、以及「上次 probe：日期／結果」的**引用行**（probe 本體記在 `project.md` 的 `## 安裝紀錄`，見 §8.2 第 4 點——產物檔不存會被重譯抹掉的資料）。

主體鐵則（**只用 `read` 就能執行，不要求 agent 會算雜湊**）：`resolved.md` 不存在，或其檔頭的「啟用清單」與 `project.md` 的 `## 啟用規則` 不一致 → **停止並提示重跑 compile**，不得靜默使用舊產物。

> checksum 的責任歸 `setup`：只有 `compile` 與 `inspect` 會用 `Get-FileHash` 重算 pack 雜湊並與 `resolved.md` 記錄比對（官方 scanner 會拒絕 `node -e` 這類動態求值，所以不能指望 agent 現算）。**代價（R3）**：有人手改 pack 卻沒重跑 compile 時，執行期抓不到，只能靠 `inspect` 與升級後的固定動作「各專案重跑 compile」補。

### 6.4 初始 pack（4 個，全部來自你現有 agent 的已驗證知識）

| id | 內容來源 | 提供什麼 |
|---|---|---|
| `stack/vue2-nuxt2` | reviewer.md §5、developer.md 專案慣例 | options API／Vuetify 1 屬性不可用 Vuetify 2 API／Nuxt2 目錄慣例／eslint standard 風格 |
| `testing/ava` | developer.md §3 特徵測試、reviewer.md §2 | 特徵測試四步驟、`mount` 驗證執行期行為、不可削弱斷言、禁 `--update-snapshots` |
| `security/vue-xss` | developer.md 專案慣例、reviewer.md §6 | **只承專案細項**：本專案的清理入口與應經流程、白名單範圍（哪些標籤／協定／屬性）、既有危險點位置、「不得放寬」的具體符號清單。**通用危險模式（`v-html`／`innerHTML`／`outerHTML`／`domProps`／`document.write`／`eval`、危險協定、敏感資料落地、新增依賴）以 §3 第 0 點為主體正典**，本 pack 不重複列舉（第 4 輪：兩份重疊真相會誘發同一發現雙重列報） |
| `i18n/vue-i18n-json` | developer.md／reviewer.md 的 i18n 條目 | 語系檔必須同步、刪鍵查引用、缺語系會顯示鍵名 |

其他棧（vue3-vite、react-next、vitest、playwright、tailwind）**本次不建立**，改由實際專案出現時再寫，並遵守 §6.1。

---

## 7. agent 規格

### 7.1 角色邊界（保留現行語意並補齊）

| agent | mode | `edit` | `shell` 基礎 | 其他工具 | 可起 subagent | 核心鐵則 |
|---|---|---|---|---|---|---|
| `frontend-devkit/orchestrator` | primary | `{"action":"edit","resource":"*","effect":"deny"}` | `ask` 起頭 → allow：`git status *`、`git diff *`、`git log *`、`git rev-parse *`、`git branch *`、`git worktree add *`、`git worktree list`、`git add *`、`Test-Path *`、**具名到 worktree 的寫入／刪除通道**：`New-Item -ItemType Junction -Path .worktrees/*`、`Resolve-Path node_modules`（精確形）、`Copy-Item * .worktrees/*`、`cmd /c rmdir .worktrees/*` → 再掛 `git commit *`、`git merge *`、`git worktree remove *`、`git branch -D *` 為 **ask** → **結尾三段式**（§7.1 定義：第 1 段真地板 `git push *`／`git rebase *`／`git reset *`／`git checkout *`／`git switch *`／`git clean *`／`git stash *`／`git worktree prune *`；第 2 段可變依賴家族；**第 3 段不可變例外 allow `npm ci *`、`pnpm install --frozen-lockfile *`、`yarn install --frozen-lockfile *`，必須排在第 2 段之後**，否則 §9.3 的 `install-per-worktree` 會被自己翻回 deny） | `question` allow；`skill` deny；`webfetch` deny | 僅 `frontend-devkit/developer`、`frontend-devkit/reviewer` | 不改檔、不寫 code、絕不 push、異常必回報、不確定就問 |
| `frontend-devkit/developer` | subagent | `{"action":"edit","resource":"*","effect":"allow"}` **緊接其後 deny（四條）**：`*opencode.json`、`*opencode.jsonc`、`*.opencode/*`、**`*.git/*`**（第 4 輪嚴重項：原本只封設定檔，漏了 `.git/hooks/post-commit`——寫一支 hook，之後**你每次 commit 都以你的權限執行任意程式碼**，與「改設定檔自我提權」同級。`*` 跨 `/`，一條 `*.git/*` 即涵蓋根形、`.git` 絕對形與 worktree 內的 `.git` 檔案形） | `ask` 起頭 → allow：**permission-spec.md §7.3.0.1 的主體靜態清單**（profile 的 gate 若不在清單內＝逐次彈窗問你；**不含「依賴安裝」那類**，developer 一律不裝依賴）；`## 額外 shell` 在方案 B 下只作「詢問預期清單」（靠 `Allow always` 持久化，permission-spec.md §7.3.1 事實 7，**不是寫規則**）、唯讀 git（`git status *`、`git diff *`、`git log *`、`git rev-parse *`、`git ls-files *`）→ **結尾走三段式，但第 3 段為空**（permission-spec.md §7.3.3：developer 連 `npm ci` 也 deny） | `question` deny（要提問經協調者）；`skill` deny；`webfetch` deny | deny | 只在指定工作目錄改檔；不 commit；**絕不碰任何設定檔、`.opencode/` 與 `.git/`**；改到 `package.json` 要醒目標報 |
| `frontend-devkit/reviewer` | all | `{"action":"edit","resource":"*","effect":"deny"}` | `deny *` 起頭（地板）→ allow 唯讀 git：`git diff *`、`git status *`、`git log *`、`git show *`、`git fetch`（精確形）、`git rev-parse *`、`git merge-base *`、`git ls-tree *`（**用途：比對「既有測試是否被刪改」需讀基準版檔案清單**）、`git cat-file *`（**同用途：取基準版內容**）、`git check-ignore *`、`git worktree list`（精確形）、`git branch --show-current`（精確形）、`git worktree add --detach .worktrees/review-*`、`git worktree remove --force .worktrees/review-*` → allow worktree 就緒（**全部具名到 `review-` 前綴**，第 4 輪：不該讓唯讀 reviewer 能動到開發 worktree）：`New-Item -ItemType Junction -Path .worktrees/review-*`、`Resolve-Path node_modules`（精確形）、`Copy-Item * .worktrees/review-*`、`Test-Path .worktrees/review-*`、`cmd /c rmdir .worktrees/review-*`（實測：反斜線的實際指令會被正規化後匹配同一條 allow，**不必並列兩形**，見下方反斜線結論）、`npm ci *`／`pnpm install --frozen-lockfile *`（**主體靜態清單內**的不可變安裝；profile 若改用別的不可變形，而它不在清單內 → reviewer 標「需人工執行」）→ allow gate：**permission-spec.md §7.3.0.1 的主體靜態清單**（`npm test *`、`npx vitest run *`… 逐條）。**方案 B 下專案端不寫 shell 規則**：profile `## 指令` 的角色是「告诉 agent 該跑哪條」與「compile 比對清單可行性」，不是授权來源；清單未涵蓋者一律走「需人工執行」降級（permission-spec.md §7.3.0.1#2）→ **結尾三段式**：第 1 段 `git push *`、`git commit *`、`git checkout *`、`git switch *`、`git reset *`、`git rebase *`、`git merge *`、`git clean *`、`git stash *`、`git worktree prune *`；第 2 段可變依賴家族；第 3 段不可變例外 allow（§7.1） | `webfetch` deny、`skill` deny、`question` deny | deny | 唯讀（唯一例外：審核 worktree 建立／清除與環境檔**進 worktree** 的複製）；必須獨立查證，不採信 developer 回報；**絕不嘗試白名單外指令** |
| `frontend-devkit/setup` | all | `deny *` 起頭 → **只 allow 四個具名檔＋四種設定檔字面形**：`*.opencode/frontend-devkit/project.md`、`*.opencode/frontend-devkit/resolved.md`、`*.opencode/frontend-devkit/resolved.check.md`（比對用暫存，§3）、`opencode.json`、`opencode.jsonc`、`.opencode/opencode.json`、`.opencode/opencode.jsonc`（**全部用字面相對形，不用 `<設定檔路徑>` 這種變數**——第 4 輪阻擋項 #4：主體是一份靜態 frontmatter，「依 profile 的某一路徑」不是合法 resource）。並**明文 deny 全域設定**：`~/.config/opencode/*`（`~` 由官方在 edit/read resource 上展開）——profile 是可被改寫的不可信輸入，若 allow 能指向全域路徑，等於借 setup 的手改到**這台機器所有專案**的 agent 權限。也**不得** allow 目錄通配 `*.opencode/frontend-devkit/*`（專案安裝法下那會涵蓋 pack 原文，比對基準可被掉包）與 `*.gitignore`（只能向你建議） | `deny *` 起頭 → allow：`git status *`、`git diff *`、`git log *`、`git rev-parse *`、`git check-ignore *`（§5.1.1#4 查 worktree 是否被 ignore）、`git symbolic-ref *`／`git remote show *`（§5.1.1#2 取基準分支）、`git worktree list`、`Get-FileHash *`（§6.3 checksum）、**探針兩條（第 5 輪阻擋項 #2 修正：`Write-Output` 那一形實測會被拒，探針必須用無 `$`、無括號的 cmdlet 精確形）**：`Get-Location`（§5.1.1#1 判 shell）、`cmd /c ver`（交叉驗證 Windows）；`Write-Output *` 可留但**不得再掛「shell 探針」標籤**；**用途標明**：`npm ls *`／`pnpm ls *`（§5.1 比對 lockfile 與已裝版本，非可有可無）、`npm view *`（選填，只在你要查套件安全性時）；讀 `package.json`／設定檔一律用 `read` 工具，不靠 `Get-Content` | `webfetch` allow（只在你要求查套件安全性時）；`skill` deny；`question` allow | **deny，唯一例外 allow `frontend-devkit/reviewer`**（D17：probe 要由「**唯一能寫 `project.md` 與設定檔的角色**」發起並落盤，而不是「能寫 resolved.md 的角色」——第 3 輪更正措辭，因為 probe 結果已改記在 `project.md` 的 `## 安裝紀錄`；被派的 reviewer 本身 `edit deny *`、`subagent deny`，風險被封在「執行一條指令並回報」的範圍內。不准派 developer／orchestrator） | 只寫上述具名檔；**不得**改專案程式碼、`package.json`、`.gitignore`、`.git/*`、全域設定、pack 原文或程序檔；寫設定檔前必須先 `read` 並保留既有欄位；跑完必呈現「寫了什麼、跳過了什麼」 |

> **尾巴三段式（權威定義；各 agent 的清單以本塊為正典）**
> 每個 agent 的 shell 陣列**結尾**固定切成三段，順序不可變：
> 1. **真地板群**（下列為**最小集**，各 agent 可再加分項，例如 developer／reviewer 另加 `git commit *`、developer 另加 `git restore *`／`git tag *`／`git apply *`／`git am *`／`git worktree *`，那是**更嚴**、不算偏離）：`git push *`、`git rebase *`、`git reset *`、`git checkout *`、`git switch *`、`git merge *`、`git clean *`、`git stash *`、`git worktree prune *`。**另含檔案系統寫刪與任意執行類**（第 4 輪新風險 #3，kit 的 gate 指令裡根本不該出現這些）：`rm *`、`del *`、`Remove-Item *`、`Move-Item *`、`Rename-Item *`、`Set-Content *`、`Out-File *`、`Add-Content *`、`Invoke-Expression *`、`iex *`、`icacls *`、`format *`、`rd *`、`erase *`。這些是**絕對地板**，任何 allow 都不准排在它們之後；`## 指令`／`## 額外 shell` 若出現同族指令，§5.1.2 與 permission-spec.md §7.3.5 必須先拒絕，再由本段地板兜住。
> 2. **可變依賴安裝 deny 群（正典＝以下併集，permission-spec.md §7.3.5#2 與 developer／reviewer／orchestrator 三列都引用本塊，不再各列一份）**：會改 `package.json`／lockfile／`node_modules` 者——`npm install *`、`npm i *`、`npm add *`、`npm rm *`、`npm remove *`、`npm uninstall *`、`npm update *`、`npm upgrade *`、`npm link *`、`npm unlink *`、`npm patch *`、`npm rebuild *`、`npm prune *`、`npm dedupe *`、`npm audit fix *`、`npm exec *`、`npm ci *`（**僅對 developer**：它無第 3 段例外，見 permission-spec.md §7.3.3）、`pnpm add *`、`pnpm i *`、`pnpm install *`、`pnpm ci *`、`pnpm rm *`、`pnpm remove *`、`pnpm uninstall *`、`pnpm update *`、`pnpm up *`、`pnpm link *`、`pnpm patch *`、`pnpm prune *`、`pnpm rebuild *`、`pnpm dlx *`、`pnpm exec *`、`yarn add *`、`yarn install *`、`yarn remove *`、`yarn upgrade *`、`yarn link *`、`yarn patch *`、`yarn dlx *`、`bun add *`、`bun install *`、`bun remove *`、`bun update *`、`bun link *`、`bun patch *`、繞道 `npx pnpm *`、`npx yarn *`、`npx bun *`、`corepack *`。
> 3. **不可變例外 allow 群（放最尾，才能翻回第 2 段；developer 無本段）**：`npm ci *`、`pnpm install --frozen-lockfile *`、`yarn install --frozen-lockfile *`。
>
> **為什麼第 3 段非獨立不可**：「最後符合者勝」意味著若把 frozen allow 排在 deny 家族**之前**，尾巴的 `pnpm install *` 會把它翻回 deny → `install-per-worktree` 專案在 §9.3 直接卡死。D14 的「任何 allow 蓋不掉」**僅指第 1 段**；第 2 段**可**被第 3 段翻回，這點必須寫明否則自相矛盾（第 4 輪指出 D14 原文未改到位）。
> **不可變／可變的判別**：會改 `package.json` 或 lockfile 者為可變；依 lockfile 原樣重建者為不可變。
> 這種「例外 allow」**只准許出現在主體自己的陣列裡**，專案端不准拿（permission-spec.md §7.3.4 第 6 點）。
> **反斜線結論（實測 `docs/experiments.md` 第 7／7b 題，撤銷第 4 輪「兩形並列」的妥協）**：shell 資源**會**把反斜線正規化為斜線 —— allow 寫 `cmd /c rmdir .worktrees/*` 就能匹配實際打的 `cmd /c rmdir .worktrees\<名稱>\node_modules`。但**程序檔的指令本身必須保留反斜線**：同一條路徑改成斜線後，`cmd` 會把 `/zztest2` 當旗標（實測報 `Invalid switch`）。所以規則是「**allow 用斜線形、程序檔給 cmd 的指令用反斜線形**」，兩者都對、不可混為一談。其餘非 cmd 的 PowerShell 指令（`Test-Path`、`Remove-Item` 等）用斜線沒問題。

> `developer` 那一列是**提權封堵**：工作目錄＝主工作區時，若 developer 能編輯設定檔，它就能替自己或替下一輪 reviewer 追加 allow，把「唯讀審核」變成可寫入執行。現行 `developer.md` 第 137 行有這條禁令，v1→kit 遷移時被漏掉（CHANGELOG.md 附錄 B §17 I-1）。

### 7.2 主體保留 vs 外移（內容分界）

**留在主體**（這才是可複用的價值）：**§3 第 0 點的基本安全項清單**、三（四）角色鐵則與邊界、**「bash 一律指定 `workdir`、不要用 `cd`」與「要問使用者一律用 `question` 工具」的全域紀律**、worktree 詢問時機（依 policy）、**同名 worktree／分支已存在時不硬蓋，改用 `question` 請你決定**、**清除 worktree 前先在該 worktree 跑 `git status --short` 檢查未 commit 殘留並告知（`--force` 會丟棄）**、開發前髒工作區檢查、輪數控制（最多 3 輪、格式異常與初次審核不計輪、追加一輪需再問）、每輪派新 reviewer、developer `task_id` 延續、ISSUES 逐項追蹤與「舊問題是否真的修好」、動態基準量測、回歸防護五步、嚴重度分級與 PASS/FAIL 判定、固定回報區段、commit 訊息先給你審、絕不 push、異常時回報 worktree 絕對路徑與分支、`rmdir` 先於 `worktree remove` 的保命順序、TBD 與 `無` 的差別處理、優先序裁決（§3）。

**reviewer 專屬、整段留在主體（不可被專案端稀釋）**：現行 `reviewer.md` 第 43–50 行的 **「bash 指令寫法限制」**——**理由要改寫（第 3 輪指出我引用了 V1 語意）**：V2 是 whole-value wildcard（permission-spec.md §7.3.1 事實 3），**不是**「字串開頭比對」，所以「照範例逐字寫」是**提示詞紀律，不是權限保證**；尾綴 ` *` 會吃掉任意延伸參數（`Test-Path .worktrees/a -LiteralPath b` 仍匹配 `Test-Path .worktrees/*`），因此機械把關落在 permission-spec.md §7.3.5（allow 產生時驗唯讀）與 reviewer 的 diff 檢查，不在白名單格式本身。紀律內容保留：檢查路徑一律寫成 `Test-Path .worktrees/...`、不加 `-LiteralPath`、同一指令不夾帶其他路徑；不用 `Get-ChildItem`／`Get-Content`／`Remove-Item`／`cd`（讀檔用 `read`，找檔用 `glob`／`grep`）；**禁止任何會寫入檔案或改動本機分支的選項**：`npx eslint` 與 `npm run lint` 不可帶 `--fix`；`git diff`／`git show`／`git log` 不可帶 `--output`／`--output-file`；`git fetch` 只更新遠端參照、不可帶 refspec 改本機分支；`npx ava` 不可帶 `--update-snapshots`。

**移往 pack**：技術棧慣例、測試框架寫法、i18n 同步規則、**XSS 的專案細項**（本專案的清理入口、白名單範圍、既有 v-html 位置）。**但「要查哪些危險模式」的最小清單留在主體（§3 第 0 點）**——第 3 輪的嚴重項正是因為我把整條安全清單搬進 pack，讓「停用 pack」能把審核線歸零。

**移往 profile**：指令與 timeout、額外 shell 白名單、基準分支與預設審核範圍、worktree 目錄與命名、環境檔、依賴策略、worktreePolicy、回歸熱點表、已知豁免、設定檔路徑、kitRoot。（model 不在 profile，見 D16／§7.4。）

### 7.3 權限規格（已外移）

> 本節全文移至 **`docs/permission-spec.md`**（第 5 輪拆檔）。內容含：方案 A／B 的取捨與實測結論、官方事實八條、語法紀律（含**字面同形鐵律**）、主體自給自足的規則鏈、跨來源紀律（現為方案 A 保留條款）、專案端 allow 產生流程、model 策略。
> 實作任何 frontmatter 前**必須先讀該附檔**；主檔其他章節提到「permission-spec.md §7.3.x」時，一律指該附檔對應小節。

### 7.4 model 策略

主體一律不寫 `model`（換機器 provider 不同會直接報錯；subagent 未設定時繼承父 session model）。要固定就在 init 時問一次、寫進 **profile `設定檔路徑` 所指的那份設定檔** 的 `agents.<id>.model`（D16）；`inspect` 會列出目前生效的 model 與其來源（主體／專案設定檔／繼承），並在根設定與 `.opencode` 設定並存時說明「後者蓋前者」的判定結果。

---

## 8. 指令規格

| 指令 | frontmatter `agent` | 本體傳給 agent 的內容 |
|---|---|---|
| `/frontend-devkit/dev <描述>` | `frontend-devkit/orchestrator` | `模式：dev`＋`任務：$ARGUMENTS`＋「先確認能看到 project.md 與 resolved.md」 |
| `/frontend-devkit/fix <描述>` | `frontend-devkit/orchestrator` | 同上，`模式：fix`（先重現找根因） |
| `/frontend-devkit/review [範圍]` | `frontend-devkit/reviewer`，`subagent: false` | `審核範圍：$ARGUMENTS`；省略時以 profile 的 `預設審核範圍` 為準；範圍空 → 「無可審核內容」且不得輸出 VERDICT；`git fetch` 失敗 → 如實註明「未能更新遠端」並以本機參照續審 |
| `/frontend-devkit/review-fix [範圍]` | `frontend-devkit/orchestrator` | `模式：review-fix`＋`範圍：$ARGUMENTS`，附流程提醒（先審、FAIL 才依 policy 決定工作方式） |
| `/frontend-devkit/init [auto\|compile\|diff]` | `frontend-devkit/setup` | 見 §8.1 |
| `/frontend-devkit/inspect [probe]` | `frontend-devkit/setup` | 見 permission-spec.md §8.2（生效 profile 摘要、啟用 pack 與 checksum、`resolved.md` 是否過期、全文 TBD 彙整、設定檔形式與跨檔優先序、全域／專案重複安裝警告、四個 agent 的 shell 規則「存在性」檢查、**`profile ## 指令` × 主體靜態清單的比對結果（清單外＝需人工執行，見 §7.3.0.1#2）**、**專案端設定是否含 shell 條目（方案 B 紀律，違反即警告）**、專案端 allow ∩ 主體尾巴 deny（僅在方案 A 啟用時才驗）、四欄白名單欄位值合法性（§5.1.2）、model 來源、`git worktree list` 殘留） |

### 8.1 init 的模式

> **六個指令檔的共同紀律（第 4 輪）**：一律**不得使用 `!`…` 的 shell 塊**（官方 Commands 頁明示：shell 塊在 OpenCode 評估指令時執行，**在 agent 的工具權限流程之外**，且警告不可放入不受信參數）。現行 kit 指令只把 `$ARGUMENTS` 當純文字交給 agent，符合此紀律；這條寫進 README 與 `writing-a-pack.md` 旁的「指令檔紀律」，防止日後有人「順手加一段 `!`git status`」繞過權限模型。

所有模式都是**冪等更新**：只覆蓋「偵測類欄位」，保留你手寫的內容與 `## 專案覆寫`；寫入前顯示差異，結束必跑 compile。

| 模式 | 行為 |
|---|---|
| 預設（無參數） | 偵測 → 填可決定的欄位 → 對掃不到的（熱點表、安全入口、豁免、worktreePolicy、depStrategy、額外 shell、model）用 `question` 問（一次一題）→ 依 permission-spec.md §7.3.5 逐條批准 allow → 寫 `project.md` → compile → `inspect [probe]` → 印出「寫入內容、TBD 彙整、下一步指令」 |
| `auto` | 只做偵測與寫檔，不問問題；掃不到寫 `TBD`；allow 只收「展開後不含寫入性選項」的指令（permission-spec.md §7.3.5 第 3 條），其餘留 TBD；結束逐條列出「每個 TBD 與每條未 allow 的指令會讓哪項檢查失效」。適合快速開跑 |
| `compile` | 只重譯 `resolved.md`：驗 id 存在與 status、算 pack checksum（`Get-FileHash`）、把 worktree 程序參數化折入、比對啟用清單 |
| `diff` | 不寫檔，只印「重跑偵測後會改變哪些欄位、你手寫的內容是否受影響」（取代原本的 `recheck`，簡化自 CHANGELOG.md 附錄 B §17 S-4） |

寫設定檔（`<設定檔路徑>`）的規則：先 `read` → 合併（`instructions` 陣列追加、`agents` 節點新增或更新對應鍵）→ **不動其他既有欄位**；已存在同鍵規則時顯示差異並用 `question` 請你選保留哪一份。

### 8.2 `inspect [probe]`（把未記載的次序變成實測）

**執行者（G4 定案）**：`setup`。它在 §7.1 的 `subagent` 是「deny，唯一例外 allow `frontend-devkit/reviewer`」——因為能被寫進設定檔的只有 setup，而 reviewer 本身唯讀、不能再派工，風險限於「執行一條指令並回報結果」。流程作為 init／compile 的最後一步，以及每次 kit 升級後的檢查：

1. **方案 B 下的定位（第 5 輪重定義）**：專案端已不寫 shell 規則，「判別跨來源次序」在 B 下**無物件可測**，因此 probe 改為**版本迴歸偵測**。**第 0 條必先是 `Get-Location`**（`experiments.md` 二.1：shell 落在 service 綁定的專案目錄，可能不是你以為的那個），用來確認落點就是本專案；第 1 條測「主體靜態清單內的 gate」（例 `npm test *`）→ 預期 allow。原本的「第 1 條必須只來自專案端 jsonc」判別力設計，**整段移入 permission-spec.md §7.3.0 的方案 A 復活檢測**。
2. 第 1 條（靜態清單 gate）→ 預期 allow；第 2 條（必被拒的寫入指令，例 `git commit --allow-empty -m probe`）→ 預期 deny。第 1 條若被拒＝清單與主體不同步或落點錯了（回到第 0 條查）。
3. 結果判讀：**第 0 條的落點必須就是本專案**（`experiments.md` 二.1 的教訓），否則整輪 probe 無效、先修操作環境再重測。第 1 條被拒 → 主體靜態清單與 profile 期望不同步（依 permission-spec.md §7.3.0.1#2 走「需人工執行」，並檢查是不是清單該升級）；第 2 條被放行 → **立即停用 kit**，屬提權漏洞，停止並等你處理，`setup` 要在回報裡引用那條規則的出處（哪個檔案、哪個陣列位置）。
4. probe 結果由 setup 寫進 **`project.md` 的 `## 安裝紀錄`**（含日期與 OpenCode 版本），**不寫進 `resolved.md`**——後者是 compile 每次重譯的產物，記錄放那裡會被抹掉（G4 的檔頭／檔尾矛盾就此消除；`resolved.md` 檔頭只留「上次 probe 於 <日期> 通過，詳見 project.md `## 安裝紀錄`」這一行引用）。

---

## 9. worktree 程序與安全

**源頭素材是 `kit/worktree.procedures.md`；執行期依據是 `resolved.md` 的「worktree 程序」段落**（D15：compile 時把程序檔按 profile 參數化——worktree 目錄、命名、環境檔、依賴策略——後折入，三個開發 agent 不去讀 `kitRoot`）。以下九條就是要被折進去的內容規格：

1. 主工作區一律執行期取得：`git rev-parse --show-toplevel`。**本節禁止項的適用範圍是 `kit/agents/`、`kit/commands/`、`kit/rules/`、`kit/profile/`、`kit/worktree.procedures.md` 與專案端 `project.md`／`resolved.md`**——kit 在這些檔案內不得出現個人絕對路徑（現行 orchestrator 第 60 行那種寫死屬禁止項）。本 spec 與 README 出於說明目的可引用「本機範例路徑」，但須標明是範例。
2. 建立開發 worktree：`git worktree add .worktrees/<名稱> -b <類型>/<slug> [<起點>]`；`<名稱>` 採 `<類型>-<slug>`，類型與目錄前綴取自 profile；`<slug>` 由任務描述產生（英文小寫連字號）。**同名目錄或分支已存在時不硬蓋**，改用 `question` 請你決定（換名稱或處理殘留）。
3. 依賴策略（profile `depStrategy`）：
   - `junction`：`New-Item -ItemType Junction -Path .worktrees/<名稱>/node_modules -Target (Resolve-Path node_modules).Path`，`-Target` 必須絕對路徑；建立後 `Test-Path .worktrees/<名稱>/<套件>/package.json` 驗證。
     **兩步寫法已是強制做法（實測：`New-Item … -Target (Resolve-Path …).Path` 會被 DENIED，因括號內的 `Resolve-Path .` 成為未被 allow 的子指令；見 `docs/experiments.md` 第 4 題）**：① 先執行 `Resolve-Path node_modules`（**這條要個別 allow**）取得絕對路徑字串；② 由 agent 把**上一步結果字面代入**第二條指令：`New-Item -ItemType Junction -Path .worktrees/<名稱>/node_modules -Target <步驟①回傳的字面路徑>`。**注入防護**：只有當步驟①的回傳值符合「盤符開頭＋`\` 或 `/` 分隔＋不含 `;`、`&&`、`|`、反引號、`$()`、換行、括號」時才准代入；不符即停止並回報（不得把未驗證字串拼進指令）。
     **字面同形鐵律（實測第 5 題）**：scanner 以**原始字串**逐字比對、不重組參數，所以 `X`、`X -Path Y`、`X Y` 是三條不同規則；程序檔裡「agent 實際要打出的字串」與 frontmatter 的 allow **必須逐字一致**（permission-spec.md §7.3.2）。也因scanner 會拆出括號內子指令，`-Target *` 這種通配並不能涵蓋「括號運算」的形式。
   - `install-per-worktree`：在 worktree 內依 profile 的依賴安裝指令執行（例 `npm ci`／`pnpm install --frozen-lockfile`），bash `workdir` 必須是 worktree 絕對路徑。
   - `none`：不建 worktree（配合 `worktreePolicy: never`）；此種專案的審核目標恆為 `--working`，且 §9.6 的兩步清除化為「無 worktree 可清」，但仍要在結束時檢查 `git worktree list` 有沒有前次殘留。
   - 偵測到 pnpm／yarn workspace 或 `node_modules` 非平面結構時，init 必須把預設值從 `junction` 改為 `install-per-worktree` 並說明原因。
4. 環境檔：依 profile 清單逐一 `Copy-Item` 進 worktree（現在只 `.env`，可擴充 `.env.local`）。複製前提醒：這些檔案含密鍵，**不得出現在回報或 commit 內容裡**；若 worktree 目錄未被 `.gitignore` 排除（§5.1.1 第 4 條的檢查），要先警告再複製。
5. 審核 worktree：detached、名 `review-<sha7>`（`git rev-parse --short=7`）、結束**必清**（含失敗與中途出錯）；先 `Test-Path .worktrees/review-<sha7>` 檢查殘留並比照處理。**目錄不存在但 `git worktree list` 已登記**時（`git worktree add` 會失敗）：如實回報並請你處理——reviewer 沒有 `git worktree prune` 權限，也不得嘗試白名單外指令。
6. **清除順序（保命鐵則，主體與程序檔都要標註，三種 depStrategy 一體適用）**：先 `cmd /c rmdir .worktrees\<名稱>\node_modules`（只移連結；對實體目錄或不存在路徑會失敗，失敗可忽略），**再** `git worktree remove --force .worktrees/<名稱>`。跳過第一步在 Windows 可能跟隨 junction 把主工作區 `node_modules` 一起刪除。**`install-per-worktree` 也不例外**：先 rmdir 一步對實體目錄會失敗但不會誤刪，保留這一步可以讓程序只有一種寫法、不會因策略不同而忘記。
7. **清除前必查未 commit 殘留**：在該 worktree 跑 `git status --short`，有未 commit 檔案（例如 developer 產生的暫物、複製进去的 `.env`）時**先告知你再清除**——`--force` 會把它們一起丟棄。
8. 依賴變更的處理：developer 回報「改了 `package.json`」且工作目錄是 junction worktree → 先告知你、先移 junction、再依 profile 指令裝依賴。裝依賴失敗（lockfile 不同步）**如實回報並用 `question` 請你決定**，不得自行改用 `install`、不得跳過直進審核。
9. 異常或中途結束的統一行為：已建立 worktree 時必須明確回報「絕對路徑 + 分支名 + 之後如何清除」。

---

## 10. 開發／審核流程行為規格（主體的規格，非提示詞細節）

### 10.1 dev／fix

1. 判斷任務與意圖；描述不像要實作什麼 → `question` 確認，你選否就結束。
2. 依 profile `worktreePolicy`：`ask` → 用 `question` 問（不可跳過，且必須在呼叫 developer 之前）；`always` → 直接依 §9 建立；`never` → 工作目錄＝主工作區、審核目標 `--working`。
3. 開發前檢查：`git status --short`，有無關未 commit 變更 → 告知 + `question` 確認是否續（`never` 時尤其重要，因為會混入 `--working`）。
4. 呼叫 `frontend-devkit/developer`：模式、任務描述（第 2 輪起改為 reviewer 的 ISSUES 清單 + 原描述）、工作目錄絕對路徑、`fix` 額外提醒先重現找根因。第一輪保留 `task_id`，之後各輪同一 `task_id`。
5. 收到回覆 → 檢查七個區段齊全（變更摘要、異動檔案清單、已執行驗證指令與結果、是否改動 package.json、影響範圍分析、回歸檢驗、建議手動回歸檢查，其中「回歸檢驗」須含動手前後兩組動態基準數字）；缺漏或可疑 → 同 `task_id` 要求補齊，不直接略過。
6. 呼叫**新的** `frontend-devkit/reviewer`（每輪都不延用舊 session）：工作目錄 + 比較基準（或 `--working`）、模式與原任務描述、developer 的三区段回歸資料（提醒必須獨立查證）、第 2 輪起附上一輪 ISSUES 與 developer 的處理結果（含不同意理由）並要求逐項確認舊問題是否真的修好。
7. 解析 `VERDICT`：PASS → §10.3；FAIL → 同 `task_id` 退回完整 ISSUES（「既有問題」不要求修，「疑問」要轉達）→ 回 6；無 VERDICT 行 → 區分「無可審核內容」（`question` 問你）與其他格式異常（重派新 reviewer，不計輪；再異常就停止如實回報）。
8. 輪數：第 3 輪仍 FAIL → 停止並 `question`（再修一輪／我自己處理／放棄並清除）；追加的一輪仍 FAIL 要再問，不自動續。

### 10.2 review-fix

1. 先審不問 worktree：範圍原樣交 reviewer 解析；省略範圍用 profile 的 `預設審核範圍` 字面值。初次審核不計輪。
2. PASS／無可審核內容 → 回報結束。FAIL → 依 `worktreePolicy`：範圍是 `--working` 時不提供 worktree 選項（未 commit 變更帶不进 worktree），只問「直接在主工作區修」或「取消」；其他範圍依 policy `ask/always/never` 決定，`never` 且 HEAD 不等於被審範圍最新 commit 時，先告知需自行 pull／merge，**不得自行切分支**並停止。
3. 建立 worktree 的起點 = 被審範圍最新 commit，比較基準 = 該 sha；`<slug>` 由 ISSUES 主題產生。
4. 之後沿用 §10.1 的 4～8（含 ISSUES 交接、重審計輪、PASS 後進 §10.3）。

### 10.3 PASS 之後

1. 整理摘要：`git status`、`git diff --stat` + developer 摘要，**必須包含**reviewer 最終輪的回歸檢驗（動態基準數字、影響範圍結論）與「建議手動回歸檢查」逐項清單（不影響 PASS，但要你人工確認），並附「因設定檔 TBD 而未覆蓋的檢查」。
2. 擬繁體中文 commit 訊息，把**完整訊息文字**放進 `question` 內容給你審（同意／修改／先不要 commit）。
3. 同意後才 commit：`git add <具體檔案>` 逐一加入（禁 `git add -A`／`.`）、`git commit -m "<繁中訊息>"`（ask 權限會再確認一次）、`git log -1 --stat` 覆核。
4. 有 worktree 再問：合併並清除／保留／直接丟棄。合併前確認目前分支與狀態、如實說明衝突風險；衝突不自行解決。清除依 §9.6 兩步，`git branch -d`／`-D` 前再確認。
5. **絕不 push**；結束提示你自行 push。

### 10.4 回報格式

developer 七區段、reviewer 固定輸出（`目標：`、`VERDICT: PASS|FAIL`、`ISSUES:`、`既有問題`、`疑問`、`回歸檢驗`、`建議手動回歸檢查`）與嚴重度分級表照現行規格保留，只把內容來源改為 profile／pack：

| 嚴重度 | 定義（參數化後） |
|---|---|
| 嚴重 | 安全漏洞、任一 gate 執行失敗（含 build）、資料遺失、明顯功能錯誤、既有功能因本次改動而壞掉（既有測試失敗、被改名／刪除的共用項目仍有使用處） |
| 一般 | 邏輯瑕疵、違反 profile／pack 慣例、缺測試（含缺特徵測試）、異動檔 lint error、測試被削弱、整檔換行字元轉換、與任務無關的改動、i18n 不同步、影響範圍分析有遺漏、覆寫未附理由 |
| 建議 | 可讀性、小優化 |

判定：有「嚴重」或「一般」→ FAIL；只有「建議」或無問題 → 才可 PASS；範圍為空 → 不得 PASS。

`無` 與 `TBD` 的判定語（不可混淆，§3）：gate 為 `無`＝該項**永遠不適用**，不擋 PASS、也不得寫成「已執行」；欄位為 `TBD`＝**本輪沒查**，不擋 PASS，但「回歸檢驗」區段必須列出未覆蓋項，讓你看清 PASS 的邊界。兩者都**不得**被 agent 敘述成「通過檢查」。

---

## 11. 降級與錯誤處理

| 狀況 | 行為 |
|---|---|
| `project.md` 不存在 | orchestrator 不開始流程，提示 `/frontend-devkit/init`；用 `question` 給第二條路：**「僅本次以口述 gate 繼續」**——由 orchestrator 一次問完最小集合（test／lint／build 各自的指令或「無」），**本次不套用任何 pack、也無需 profile**，回報須標「依據僅為口述，未做設定檔層級的檢查」。不得自己讀 `package.json` 猜（那是 `setup` 的職責，而 orchestrator 的 subagent 白名單只有 developer／reviewer，見 §7.1）。**豁免（G8）：選走這條時，§6.3 與下節「`resolved.md` 缺失即停止」的鐵則一併豁免**，但該輪所有回報與（若有的）產物都要標「無設定檔模式」，且不得聲稱做過 pack 層級檢查。**降級明細（第 5 輪改正：方案 B 下不是「全部跑不了」，而是三角色不同）**：① **reviewer**（`deny *` 起頭）——口述 gate 若正好是靜態清單內的指令（`npm test *`、`npx eslint *`…）**可執行**；清單外一律「需人工執行」，並在回報註明；② **developer**（`ask` 起頭）——清單外會**彈窗問你**，你准了才跑；③ **orchestrator**——它的白名單本就靜態內建，不受有無 profile 影響（只有 worktree／環境檔等參數需要 profile）。此輪的 VERDICT 只能基於「lint 未跑／測試未獨立重跑」的弱依據，回報必須在「回歸檢驗」寫「無設定檔模式：gate 由 developer 單方執行，reviewer 未獨立重跑」，且 `inspect`／README 都要提醒「此模式不建議用於要 commit 的任務」 |
| `resolved.md` 缺失／**檔頭啟用清單與 `project.md` 不一致** | 停止並提示 `/frontend-devkit/init compile`，不靜默用舊產物（執行期只比清單，checksum 驗算歸 `inspect`／`compile`，§6.3）。**例外**：上一列經使用者明確選「僅本次以口述 gate」時豁免 |
| `resolved.md` 與 `kitRoot` 源頭素材**不一致**（被手改、或 pack 改過沒重譯） | `inspect` 以源頭素材在上下文**重建內文**，與 `resolved.md` 內文**逐行**比對（**排除檔頭動態欄**，否則時間戳讓警告常亮；誠實標明這是 LLM 逐行比對而非機械 diff）。不是只比 checksum——保留原 checksum 字串就能混過（G9）；不一致即警告並停止審核，提示 `init compile`。需要落盤差異報告時只准寫 `.opencode/frontend-devkit/resolved.check.md`（§3） |
| **profile 欄位值不在白名單**（`設定檔路徑`／`kitRoot`／`worktree 目錄`／`環境檔`，§5.1.2） | `setup` 寫入前即拒絕並停止；已存在的非法值由 `inspect` 每輪檢出 → **停止流程並提示重跑 init**，不得「先信再跑」。這四種值會讓 setup 或 orchestrator 變成借刀寫全域設定、把 worktree／`.env` 放到專案外、或掉包 D21 的比對基準 |
| 有人企圖編輯 `.git/*`（含 `hooks/`） | developer 的 `edit` deny `*.git/*` → 直接被權限擋掉（不是提示詞約束）。README 要加一句：kit 不允許任何 agent 動 `.git/`，hook 類需求請你自己在專案外處理 |
| 專案端 allow **命中主體尾巴第 1、2 段 deny** | `setup` 寫入前比對即拒絕；已存在者由 `inspect` 檢出並要求移除（permission-spec.md §7.3.4 第 2、3 點）。這是 D13「次序無關」成立的前提，屬**嚴重**設定問題 |
| `## 專案覆寫` 企圖取消／降級 `security/*` 檢查項 | reviewer **照樣執行該檢查**、引用該覆寫原文並列「嚴重」（§3 優先序第 3 點例外） |
| 啟用了不存在的 pack id | init／compile 報錯並列 `registry.md` 可用 id；執行期才發現則停止回報 |
| 兩個 pack 的主題重疊（`covers` 有交集） | compile **印警告並繼續**（不阻擋）：列出重疊主題，請你在 profile 的 `## 專案覆寫` 裁決。真正的欄位級衝突無法機械偵測（§6.2），最終把關是 `writing-a-pack.md` 的人工退件紀律與 reviewer 的「覆寫未附理由 → 一般」規則 |
| profile 覆寫未附理由 | reviewer 列「一般」 |
| gate 為 `無` | 跳過並在回報註明「依設定檔：本專案無該 gate」；**不適用、不擋 PASS**（§3 三態表） |
| gate 為 `TBD` | 跳過並在回報列「因 TBD 未覆蓋：X」；不擋 PASS，但不得宣稱已覆蓋 |
| gate 指令存在但執行失敗（script 不存在、CLI 沒裝） | 「嚴重」FAIL + 疑似原因，不可當跳過 |
| 基準數字前後不一致 | 報「基準漂移」（例如開發中途有人並行 commit），停止並詢問，不假裝一致 |
| profile `shell` 非 powershell／是 `TBD` | 停止並告知「worktree 程序檔僅 PowerShell 版」，不硬試指令；`TBD` 時先依 §5.1.1 第 1 條探針取得結論再決定 |
| 非 git repo／無 `origin` | 預設審核基準失效：改用 `--working`、如實告知、建議補 profile |
| 主工作區髒 | 告知 + `question` 詢問是否續（§10.1 步驟 3） |
| 專案端 model 覆寫的 provider 不存在 | 報錯並建議移除覆寫改繼承 session model，不靜默降級 |
| **使用者沒跑 init 就做事**（第 3 輪指出我原威脅模型寫錯） | **不存在「無規則＝全開」的洞**：shell 規則在四個 agent 的 `.md` frontmatter 內、隨 agent 定義載入，叫得到 `frontend-devkit/reviewer` 就代表地板與放行群**已生效**；灌掉專案端 jsonc 的 `agents` 節點只是少了專案追加的窄 allow（偏嚴方向），不會讓未列指令變可用。真正的風險是另一件事：**使用者沒選 kit agent、逕用內建 `build` 跑任務**（`build` 沒有這套地板）——這擋不住，只能在 README 告警，並讓 `inspect` 檢查「本專案有無 profile／是否被其他 agent 動過」。誠實標明，不假稱有防堵 |
| **`## 啟用規則` 內沒有任何 `security/*`**（第 3 輪嚴重項） | `compile`／`init` 醒目警告；**orchestrator 的三條指令**（dev／fix／review-fix）啟動前必須 `question` **二次確認**（選項文字要寫出後果：「僅執行主體基本安全項，不含專案專屬 sanitizer／白名單檢查」），未確認不進入流程；**`/review` 例外**：reviewer 是 `question: deny`，問不了 → 改為**不開始審核**並輸出固定提示句（§3 第 3 點），不得假設你已同意。確認後 reviewer 仍執行 §3 第 0 點，並在回報標「未啟用安全 pack」。**規避不得**：把 pack 停用等同放棄安全檢查 |
| 口述 gate 模式（§11 第 1 列）下的 worktree 決策 | 一律按 `worktreePolicy: ask` 處理（沒有 profile 就假定要問），且 `depStrategy` 只能取 `junction` 或 `none` 二者由你選；不可默認 `install-per-worktree`（那需要 profile 裡的安裝指令） |
| **有人在 profile 裡放進「未批准的可寫入指令」**（如 `## 指令` 或 `## 額外 shell` 填入含 `--fix`、`rm`、`Invoke-Expression` 的條目） | **方案 B 下這類條目不會變成授權**（專案端不寫 shell 規則）：① `setup`／`compile` 依 permission-spec.md §7.3.5 的寫入性檢查標為 `疑似可寫入`，不列入可執行 gate；② 若 reviewer 在清單內找不到它 → 走「需人工執行」（permission-spec.md §7.3.0.1#2）；③ 若 developer 被要求跑它 → `ask` 彈窗**預覽展開後的原始命令字串**由你拒否；④ 已存進去的持久 allow（`Allow always`）若屬寫入性，`inspect` 要列出要你手動撤除。reviewer 一律不得因「設定檔這麼寫」就執行寫入性指令 |
| 全域與專案同時裝了同名 agent | `inspect` 警告（permission 規則會附加）；開發流程開始前 orchestrator 也要能用 `inspect` 的結論提示你 |
| 本專案（TOS_Frontend）誤用 kit | 行為可預期：沒有 `project.md` → 停止並提示 init；舊 `/dev` 流程與新指令互不干擾 |

---

## 12. 從現有 agent 遷移對照（已外移）

> 移至 **`docs/migration-map.md`**。實作步驟「抽 pack」與「寫主體提示詞」以該檔為查核清單，避免遷移時遺失現行 agent 的鐵則（歷輪審核有三次都是這一類失誤）。

## 13. 驗證方式（已外移）

> 移至 **`docs/acceptance.md`**（關卡 0～8）。每關的通過條件即驗收標準；關卡 1／2 已依 R1 實測結果調整，方案 A 的次序判別移入 `permission-spec.md` 的復活檢測。

## 14. 交付順序（給後續實作計畫的骨架）

1. **實驗先行（R1 八題，在寫任何 agent 檔之前）**：拿一個最小假裝的 kit（一個 subagent + 一份假 profile + 兩條規則）實測：` *` 尾綴匹配、尾巴三段式第 3 段能否翻回第 2 段、`.md` 與 jsonc 的附加次序、**含括號子運算式是否被 scanner 接受**、**scanner 比對用的是原始字串還是重組字串**、`*.opencode/*` 是否匹配點開頭的相對路徑、**shell 資源是否做反斜線正規化**。結論寫進 `docs/install.md`，據此確認 permission-spec.md §7.3 走方案 A 或 B、§9.3 是否改兩步寫法、§7.1 各條 resource 字面形是否要改。同一站也要驗：`tools/normalize-forms.ps1` 連跑兩次內容不變（冪等），並確認在 PS7 下不寫出 BOM。**本站已於 2026-11-11 完成**，結果見 `docs/experiments.md` 與 CHANGELOG.md 附錄 B §17.11：` *` 尾綴成立、三段式第 3 段可翻回第 2 段、**專案端追加 allow 實測無效 → 方案 A 停用、改方案 B**、括號子運算式與 `$` 變數存取會被拒（§9.3 改強制兩步）、scanner 用**原始字串**比對（字面同形鐵律）、`*.git/*` 等 pattern 全數驗證有效、反斜線會正規化但 `cmd /c` 指令須留反斜線。**尚未覆驗的一條**：真實專案＋TUI 形態下「專案端 config 能否追加 allow」（本機 CLI 找不到專案本地 agent，見 `experiments.md` 二.2）。
2. **批量改字後必經人工複核（CHANGELOG.md 附錄 B §17.6 的教訓，列為常設紀律）**：任何用腳本做的字形／空格批量替換，跑完必須**人工重讀被改動的行**（看 MISS 輸出＋隨機抽查＋全文再掃一次 `$suspects`），並確認換行字元未被整檔轉換（本 repo 以 `.gitattributes` 鎖 `eol=lf`）。第 3 輪我就是因為只看腳本輸出就宣稱「已清乾淨」，結果一邊修字形、一邊製造新問題，還把一句話替換壞成重複句（該事故記錄留在 CHANGELOG.md 附錄 B §17.6，不在此重複）。
3. repo 骨架與 docs/writing-a-pack.md（把 §6.1 的紀律與 §6.2 的 covers 退件清單寫成可執行步驟）。**拆檔常設紀律**：每次動過附檔（拆、改名、併節）都要跑一次 `grep -rn '§' docs`，把輸出與「0. 檔案地圖」逐行比對——本計畫已出現過三次「改一處忘三處」，引用斷裂是同一種病。
4. 抽 pack：從現有 agent 逐條搬到 4 個 pack（**先抽 pack 再改主體**，避免知識遺失）。
5. `worktree.procedures.md` 參數化（§9）。
6. `profile/project.template.md`（§5 + §5.1 偵測對照 + §5.1.1 五個偵測細節）。
7. 主體四 agent 改寫為 V2 frontmatter（規則鏈依 permission-spec.md §7.3.2 語法紀律逐條展開，且尾巴三段式與具名 allow 的字面形要依步驟 1 的 scanner 結論才定稿），並把 §3／§10／§11 的規則寫進提示詞（引用 profile／resolved 而非復述專案知識）。
8. `setup` agent + 六個指令（含 permission-spec.md §7.3.5 的 allow 產生流程與 §8.2 的 probe）。
9. README／install／adding-a-project：三條固定告警——①升級後各專案重跑 `init compile`；②**不要用內建 `build` 跑 kit 任務**（kit 的地板只存在於四個 `frontend-devkit/*` agent）；③**任何 agent 都不准動 `.git/`**（含 `hooks/`），hook 需求由你在專案外自行處理（對應 D24）。
10. acceptance.md §13 的關卡 0～8 逐關驗證（throwaway 專案）。
11. 本專案零影響查核。

---

## 15. 風險與取捨

| # | 風險 | 影響 | 對應做法 |
|---|---|---|---|
| R1 | ~~跨來源次序官方未記載~~ → **已實測（2026-11-11，`docs/experiments.md`）**：agent `.md` 規則排在設定檔之後，地板 deny 蓋掉專案端 allow；scanner 用**原始字串**逐字比對；括號子運算式與 `$` 變數成員存取會被拒（未 allow 的子指令使整案 DENIED；第 8 題只記錄到 DENIED，**原因未經錯誤訊息確認**）；反斜線**會**正規化 | 方案 A 失效 → kit 預設已改**方案 B**（permission-spec.md §7.3.0／permission-spec.md §7.3.0.1）；§9.3 junction 改**強制兩步**；§5.1.1#1 探針改 `Get-Location`；§7.1 allow 只寫斜線形、程序檔的 `cmd /c` 保留反斜線 | **剩一條待覆驗**：在真實專案＋TUI 安裝形態重驗第 3 題（專案端 config 能否追加 allow）。在此之前方案 A 停用。另 `opencode run` 的 shell 落在 **service 綁定的專案目錄**而非呼叫端 cwd（`experiments.md` 二.1），自動化實驗必須先 `Get-Location` 確認落點、涉及寫檔一律用絕對路徑 |
| R2 | pack 是「憑現有專案抽出」，換技術棧時 4 個 pack 都不適用 | 新專案只剩主體流程 + profile 的通用檢查 | init 在沒有任何適用 pack 時明確告知「本次只有通用檢查」，並把 profile 手寫知識的比重提高（熱點表、安全慣例必填） |
| R3 | `resolved.md` 是產物，可能被手改或忘記重譯；而**執行期無法算 checksum**（`node -e` 會被 scanner 拒、不該為此事擴張 reviewer 白名單） | 用了舊規則版還看不出來 | 執行期比「啟用清單＋關鍵識別欄」一致性（§6.3，純 `read` 可達）；checksum 交 `compile`／`inspect`（`Get-FileHash`）；README 把「升級 kit 後各專案重跑 compile」寫成固定步驟；**殘留風險如實標明，不宣稱已擋死** |
| R4 | `instructions` 注入會讓 profile 進入該專案**所有** agent 的上下文（含內建 build） | token 增加、可能干擾無關任務 | 控制在兩檔、目標單檔 ≤ 120 行（**超過即為警告而非阻斷**：`inspect` 提示「注入內容已達 N 行」，由你決定要不要把熱點表精簡或改用 §4.2.2 的「主體指示 read」備援路）；需要更精緻時改用「主體指示 read」的備援路（§4.2 D6 的後段） |
| R5 | junction 依賴策略對 pnpm／workspace 無效，甚至造成誤刪主工作區依賴 | 環境損毀 | init 依 lockfile 自動改 `install-per-worktree` 並說明；§9.6 的先 `rmdir` 鐵則保留；`none` 選項存在 |
| R6 | 換一台電腦時 `%APPDATA%` 路徑與 provider 名稱不同 | kit 裝了但跑不起來 | 主體不寫 model（D10）；kitRoot 用 `~` 寫法；install.md 有「新機器檢查清單」（provider 存在性、PowerShell 版本、git 版本） |
| R7 | 命名空間長（`/frontend-devkit/review-fix`）打字量大 | 使用摩擦 | 依賴 TUI 自動完成；`inspect` 印出指令對照表；不改名（命名是你的要求） |
| R8 | 現有 agent 與 kit 並存，可能出現「同一專案用兩套流程」的混亂 | 行為不一致 | README 明列：一個專案只用一套；本專案繼續用舊三 agent，kit 的首個試用場是 throwaway／新專案（acceptance.md §13 第 8 關） |
| R9 | 前綴式 deny 無法窮盡依賴變更的繞道（`npx --package pnpm pn add x`、自訂 alias、`node scripts/install.js`）；已在清單內的指令仍可被附加參數延伸（`npm run lint -- --fix`） | 護欄可被繞過 | 明文寫出「shell 規則只是護欄，不是保險」（permission-spec.md §7.3.3）；**四道牆**：①主體唯讀紀律（§7.2）②**主體靜態清單＋「清單外→需人工執行」**（方案 B 的第二道，取代舊的「profile 逐 script 具名 allow」）③`inspect [probe]` 的版本迴歸偵測（清單與實作不同步會在這裡露餡）④reviewer 必查 `package.json`／lockfile diff。不宣稱「已擋死」 |
| R10 | developer 的 shell 採「未列即 `ask`」，合法唯讀指令會不停跳出詢問（**方案 B 下這是設計內的結果，不是可修的缺陷**：專案端不寫 shell 規則，所以主體清單外的指令一律要問） | 使用摩擦、你被問到煩，煩到可能開始無腦准 | ①`## 額外 shell` 改為「**詢問預期清單**」：首次執行該指令時你選 `Allow always`，官方會存成專案級持久 allow（permission-spec.md §7.3.1 事實 7），這是 B 下 developer 唯一合法擴充路；② `inspect` 列出**已存下的持久 allow** 給你複核（只能你手動撤，agent 無權）；③ 若某條指令確實常需，走 kit 升級把它加進主體靜態清單——**不要企圖用 profile 繞過**（對 reviewer 的 deny 地板無效，只會造成「以為已授權」的錯覺） |

---

## 16.（已廢除）

> 第 5 輪拆檔時併入 **§2 決策彙總**（權威定義）；原速查表移至 **`docs/CHANGELOG.md` 附錄 A**。本節編號保留以維持既有引用不斷裂，內容不再維護。

## 17. 修訂紀錄（已外移）

> 第 1～5 輪獨立審核與 R1 實測的逐條「發現 → 落點」全數移至 **`docs/CHANGELOG.md` 附錄 B**。主檔只保留**現行設計**；要追「為什麼這樣寫」再翻該檔。

