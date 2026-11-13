# CHANGELOG 與歷輪審核紀錄

本檔承接主檔拆檔時移出的兩段：**附錄 A**（原 §16 已決定事項，現行權威在主檔 §2 決策彙總，本附錄僅存速查）與**附錄 B**（第 1～5 輪獨立審核與 R1 實測的逐條修訂紀錄，屬歷史脈絡、非實作依據）。

> 主檔：`specs/2026-11-11-frontend-devkit-design.md`。章節引用規則同其他附檔：帶檔名前綴者指附檔，未帶前綴者指主檔。

## 第 6 站驗收（2026-11-11 ～ 11-13）

首次完整跑完 `acceptance.md` 的關卡 0～8，結果全部通過。這一段不是歷史附錄，而是**現行 kit 的來源**：驗收期間抓到 30 個缺陷（A～AH），每一條都改在規格或 agent 主體上，逐條紀錄在 `acceptance-findings.md`。

以下幾條值得記住（也是這份 CHANGELOG 存在的理由）：

| 缺陷 | 現象 | 為什麼危險 |
|---|---|---|
| **W** | `compile` 只把 pack 放成摘要表，沒折入正文 | 三個 agent 只讀 `resolved.md` → **啟用了 pack 卻看不到檢查清單**，安全檢查靜默失效，而八關全過 |
| **AA** | 一條規則少了兩格縮排 | 整份 YAML 失效 → opencode 跳過 agent → `Agent not found`（不是權限問題） |
| **AD** | `VERDICT` 的基準指紋指令 `git hash-object` 不在 allow 清單 | 規格要求一個跑不了的指令，等於要求無法執行 |
| V／Z／AD | 同一家族：規格寫了具體指令，allow 清單沒有 | 三次都靠實測才發現；日後改規格要先對權限清單 |
| J／K／M | D18 的確認是「對話內」授權，reviewer 看不到 | dev 放行、review 拒審；改為 `securityOverride` 標準列＋基準 sha |
| **I** | 「整節空白」與「誤刪」在檔案裡長得一樣 | 靜默當成 0 pack 會把誤刪固化 |

> 另外三個編號（L、AC、AE）在驗收中**未成立**，因此沒有對應修法；`acceptance.md` §13.1 有標註，避免日後誤以為修過。

---

## 附錄 A　原 §16 已決定事項（速查；衝突時以主檔 §2 為準）
## 16. 已決定事項

> **本節是索引摘要**：權威定義在 §2 決策彙總與各章節；同一件事兩處不同時，**以 §2 為準**（第 3 輪曾宣稱已有這句但當時沒落地，第 4 輪補上）。
> 措辭說明：**機制決策已全部定案**；尚未定的不是決策，而是「OpenCode 平台行為的實測結果」（R1），它會決定 permission-spec.md §7.3 走方案 A 還是方案 B——兩方案的行為差異已在本檔寫死，所以實測不會回頭改設計，只改選哪一支。
（本 spec 無未決欄位）

| 項目 | 決定 |
|---|---|
| 套用專案的多樣性 | 現代前端都可能（Vue2/Nuxt2、Vue3/Vite、React/Next），主體不假設框架 |
| 安裝方式 | 全域或專案內皆可，同一份內容；專案端需一份 profile |
| 平台 | 僅 Windows / PowerShell；非 Windows 時拒絕執行 worktree 程序 |
| 通過標準來源 | 指令在 profile，數字執行期量測 |
| 源頭 | 獨立 git repo `frontend-devkit` |
| 命名空間 | `frontend-devkit`（agents 與 commands 皆同） |
| 架構方案 | B-lite（主體 + 4 個已驗證 pack + profile + 編譯式 resolved.md） |
| profile 產生 | `/frontend-devkit/init`，預設偵測 + 問答；`auto` 純自動；`compile` 只重譯；`diff` 只看不寫（§8.1） |
| profile 版控 | 進該專案版控（建議）；`kit` 不寫絕對路徑 |
| worktree 詢問 | profile `worktreePolicy: ask \| always \| never`，預設 `ask` |
| agent 數量 | 4 個（三開發角色 + `setup` 設定專用） |
| probe 執行者 | `setup`（其 `subagent` 唯一例外是 allow `frontend-devkit/reviewer`，因只有 setup 能寫設定檔）；結果記在 `project.md` 的 `## 安裝紀錄`，不記在 `resolved.md`（D17） |
| 安全檢查封頂 | `security/*` pack 檢查項只能被覆寫成更嚴，不得取消／降級；企圖免除者 reviewer 照樣查 + 列「嚴重」（D18） |
| allow∩deny 必須為空（**方案 A 保留條款：僅在 permission-spec.md §7.3.0 覆驗成功、方案 A 啟用後才適用**） | 專案端 allow 不得命中主體尾巴第 1、2 段 deny（比對時**排除** `resource:"*"` 地板），`setup` 寫入前與 `inspect` 都機械比對（D19）。**實測後狀態**：方案 A 停用 → 本條轉為「未來若覆驗成功啟用方案 A，此檢查必須先存在」的保留要求；方案 B 下專案端不寫 shell 規則，故無此交集 |
| 依賴安裝分兩族 | 不可變（`npm ci`、`pnpm install --frozen-lockfile`、`yarn install --frozen-lockfile`）allow；可變（install／add／i）deny；「例外 allow」只准許出現在主體陣列內（D20，尾巴三段式） |
| 竄改偵測 | `inspect` 以 `kitRoot` 源頭素材**在上下文重建內文**、**排除檔頭動態欄**後**逐行**比對（誠實標明：LLM 逐行比對，非機械 diff），不只比 checksum（D21） |
| profile **值**的白名單（第 4 輪嚴重項） | `設定檔路徑`、`kitRoot`、`worktree 目錄`、`環境檔` 四欄只能取白名單值，`setup` 寫入前與 `inspect` 每輪都驗，非法即停止（D23，§5.1.2） |
| `.git/` 封鎖（第 4 輪嚴重項） | developer 的 `edit` deny 加 `*.git/*`；否則寫 `.git/hooks/post-commit` 等於在你每次 commit 時執行任意程式碼（D24） |

---


---

## 附錄 B　歷輪獨立審核與 R1 實測的修訂紀錄

## 17. 修訂紀錄

### 17.1 第 1 輪獨立審核（VERDICT: FAIL，2 嚴重／12 一般／4 建議）→ 採納情形

| # | 審核發現 | 修法 | 狀態 |
|---|---|---|---|
| I-1 | 【嚴重】developer 沒被禁止編輯 `.opencode/**`；工作目錄＝主工作區時可自我追加 allow、下一輪 reviewer 被提權（現行 `developer.md` 第 137 行禁令在遷移中遺失） | §7.1 developer 列改寫「`allow *` 後接 `deny *.opencode/*`、`*.opencode.json`、根 `opencode.json`」；permission-spec.md §7.3.4 第 4 點定為「寫設定檔的權限只屬 `setup`」；migration-map.md §12 補遷移列 | 已修 |
| I-2 | 【嚴重】init 照字面把 `scripts.lint` 寫成 allow，而現代專案常內含 `--fix` → 給唯讀 reviewer 可寫入指令；且現行 `reviewer.md` 43–50 行「bash 指令寫法限制」整段在 kit 裡無對應 | 新增 permission-spec.md §7.3.5 五步（展開 script 本體 → 寫入性檢查 → 逐條 `question` 批准 → 禁止 `npm run *` 通配、逐 script 具名 → 三道牆不宣稱擋死）；§7.2 該段升為不可稀釋的主體鐵則；§11 加「疑似違規 allow」的處置列；migration-map.md §12 補遷移列 | 已修 |
| I-3 | 【一般】`deny "git commit\|push"` 的 pipe 不是合法 V2 pattern；`"npm test*"` 過寬（會匹配 `npm testfoo`） | permission-spec.md §7.3.1 記錄官方事實 3／4（whole-value wildcard、` *` 尾綴亦匹配無參數）；permission-spec.md §7.3.2 語法紀律表；permission-spec.md §7.3.3 全部逐條展開為獨立規則 | 已修 |
| I-4 | 【一般】依賴寫入的 deny 列舉不全（`pnpm rm/up/link/patch`、`yarn upgrade/link/patch`、`npm link/patch/rebuild`、`bun link`、`npx pnpm add`、`corepack` 等繞道） | permission-spec.md §7.3.3 補完整清單（含四家 alias 與 `npx pnpm *`／`pnpm dlx *`／`corepack *`）；新增 R9 承認「護欄不是保險」，最終關卡是 package.json 醒目標報 +reviewer 查 lockfile diff | 已修 |
| I-5 | 【一般】§6.3「checksum 不符就停止」無執行主體：算 hash 要 shell，orchestrator 白名單沒有，`node -e` 又會被 scanner 拒 | §6.3 執行期鐵則降為「比啟用清單＋關鍵識別欄」（純 `read`）；checksum 歸 `compile`／`inspect`，`Get-FileHash` 列入 setup 白名單；R3 重寫為如實標明殘留風險 | 已修 |
| I-6 | 【一般】kitRoot「只供 compile/inspect」與「worktree.procedures.md 是唯一出處、主體要照它做」矛盾；全域安裝時程序檔在專案外，`external_directory` 預設 allow 不能當保證 | 新增 §4.2.2／D15：程序檔經 compile 參數化折進 `resolved.md`，三個開發 agent 一律不讀 kitRoot；§9 開頭改寫為「源頭素材 vs 執行期依據」；§11「未 init＝無規則＝全開」加防堵列 | 已修 |
| I-7 | 【一般】專案設定檔有根 `opencode.json` 與 `.opencode/opencode.json` 兩種形式（後者蓋前者），spec 死鎖在後者 | 新增 D16／§4.3／§5.1.1 第 2 條：profile 增 `設定檔路徑` 欄，init 偵測現有形式、並存時 `question`、皆無時建 `.opencode/opencode.json`；§7.4 model 也改寫到該檔 | 已修 |
| I-8 | 【一般】`無` 在 §3 寫「視同不適用」、在 §11 寫「不計為通過」→ 無 lint 的專案永遠無法 PASS，判定會隨機漂移 | §3 三態表增「對 VERDICT 的影響」欄並明定 `無` 不擋 PASS；§11 該列改為「不適用、不擋 PASS」；§10.4 補一段兩態判定語與「不得敘述成通過檢查」 | 已修 |
| I-9 | 【一般】「profile 不存在可臨時自動偵測繼續」無執行主體（orchestrator 只能叫 developer／reviewer，叫不到 setup） | §11 該列改為「**僅本次口述 gate**」：orchestrator 一次問完 test/lint/build 或「無」，不套 pack、不讀 package.json 猜，並明文寫出不得越權；acceptance.md §13 第 6 關補測此分支 | 已修 |
| I-10 | 【一般】「兩個 pack 同欄位矛盾 → compile 檢測」在自由 markdown 上機械不可實作；`sections` 欄若無機讀用途即為死欄 | §6.2 刪 `sections`，改 `covers` 一行自由文字 + compile 只印**主題重疊警告**不阻擋；§11 該列同步改寫；攔關移到 `writing-a-pack.md` 人工退件 +reviewer「覆寫未附理由→一般」 | 已修 |
| I-11 | 【一般】`shell` 欄的偵測是循環論證（用 `$env:OS` 判斷 shell，只在該 shell 已是 PowerShell 時才跑得起來） | §5.1.1 第 1 條明確定義「shell＝OpenCode shell 工具的實際環境」，用 PowerShell 探針成敗判定、失敗記 TBD 並問；§11 該列引用探針結果；不承諾探 POSIX（本次非目標） | 已修 |
| I-12 | 【一般】acceptance.md §13 要求 throwaway 專案卻沒說誰建、在哪建、要裝什麼 | 新增「關卡 0（人工，不屬於 kit 權限模型）」：`%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`，`npm create vite@latest app-a -- --template vue`；app-b 由 app-a 複製後砍 `project.md`；明文寫出 kit agent 不做這些 | 已修 |
| I-13 | 【一般】現行安全護欄在遷移中遺漏：同名 worktree 不硬蓋、清除前查未 commit 殘留（`--force` 會丟棄）、目錄不在但已登記的 prune 分岐、`workdir` 不用 `cd`、詢問一律用 `question`、reviewer 的 `webfetch`／`skill` deny | §7.2 保留清單逐條補上；§9 增第 2、5、7 條對應；§7.1 新增「其他工具」欄；migration-map.md §12 補 6 條遷移列。並依審核建議新增 §5.1.1 第 4 條：檢查 worktree 目錄是否被 `.gitignore` 排除，未排除則警告 `.env` 混入審核範圍 | 已修 |
| I-14 | 【建議】`security/vue-xss` 的 pack 清單漏了「敏感資料寫入 localStorage／log／URL」與「新增依賴漏洞」兩項，照表搬運會遺失 | §6.4 該列補兩項並註明出處 | 已修 |
| I-15 | 【建議】acceptance.md §13 第 5 關寫「四區段」與 §10.4reviewer 七區段不一致 | acceptance.md §13 第 5 關改為七個區段逐項列出 | 已修 |
| I-16 | 【建議】pack `status: [未驗證]` 的方括號是 YAML flow sequence，會被解析成陣列 | §6.2 改為 `已驗證`／`未驗證` 兩字面值並寫明理由 | 已修 |

### 17.2 第 1 輪「既有問題」與文字問題

| 項目 | 處理 |
|---|---|
| 全文簡繁混用（曾出現：現有、一條、危險、機械、之類、本應、違規、干擾、機制、字數、我們…），違反「一律繁體中文」 | 由 `tools/normalize-forms.ps1` 處理。**腳本現行三條規則，逐條對應**：① 確定詞的簡→繁替換（26 組，見腳本 `$pairs`）；② 漢字直接黏 `reviewer/developer/orchestrator/setup` 時補半形空格（regex）；③ 表格儲存格 `|` 後直接接檔名（`x.md`／`x.json`…）時補空格（regex）。**不碰**「內／制／裡」等台灣正字，也不做「刪空格」這類會傷文的操作（第 1 版曾有 `(' reviewer','reviewer')` 的刪空格規則，已移除）。跑完仍須人工複核，腳本自述的殘留字清單為 `$suspects` 字集 |
| CHANGELOG.md 附錄 A §16 標題與 R1「需實測」並陳像矛盾 | CHANGELOG.md 附錄 A §16 加措辭說明：機制決策已定，未定的是平台行為實測結果，且不影響設計走向 |

### 17.3 第 1 輪簡化建議的採納

| # | 建議 | 決定 |
|---|---|---|
| S-1 | 刪掉 profile 的 `## 未知（TBD）` 總表（TBD 已是欄位級標記，`inspect` 掃全文即可彙整，雙表會漂移成第二真相） | **採納**：模板移除該小節，改由 `inspect` 彙整；profile 開頭一句「所有未知都寫在欄位值上，不另設總表」 |
| S-2 | 刪 `inspect` 的「回報注入字數」 | **採納**：120 行上限＋產生時間已足夠；字數無行動配套 |
| S-3 | 刪 pack `sections` 檔頭欄 | **採納**（見 I-10） |
| S-4 | `init recheck` 與 `auto` 合併（冪等重掃、只更新偵測類欄位本來就該是預設） | **採納**：模式改為 預設／`auto`／`compile`／`diff`（`diff` 只印「重掃會改哪些欄」不寫檔）；§8.1、CHANGELOG.md 附錄 A §16 同步 |

### 17.4 第 2 輪獨立審核（VERDICT: FAIL，13 一般／8 建議）→ 採納情形

| # | 審核發現 | 修法 | 狀態 |
|---|---|---|---|
| G1 | CHANGELOG.md 附錄 B §17.3 宣稱 S-1 已採納，但 `project.md` 範本仍留 `## 未知（TBD）` 小節——**我的不實記載** | 刪除該小節，並在 §5 開頭加「未知只寫在欄位值上，不另設總表」；CHANGELOG.md 附錄 B §17.3 的敘述改與實際內容一致 | 已修（並承認是自己寫錯，不是 reviewer 誤判） |
| G2 | developer 的 `edit` deny 寫成 `*.opencode.json`／根 `opencode.json`：漏 `opencode.jsonc`、漏 worktree 內副本、字面根形匹配不到 | 改為 `*opencode.json`、`*opencode.jsonc`、`*.opencode/*`（`*` 跨 `/`）；acceptance.md §13 關卡 1 實測四種路徑形＋jsonc（連 D19 一起驗） | 已修 |
| G3 | 「兩種次序都不偏鬆」的論證缺前提：專案端窄 allow 若命中主體 deny，且 jsonc 排在後面，地板會被翻掉 | 新增 permission-spec.md §7.3.4 第 2、3、6 點（前提＋機械檢查＋「例外 allow 只准許在主體陣列」）與 D19；§11 加「allow∩deny 非空＝嚴重」 | 已修 |
| G4 | probe 執行者不成立（init／inspect 是 setup，而 setup `subagent deny` 派不到 reviewer），且記錄位置檔頭／檔尾互相矛盾、重譯會抹掉 | D17：setup 的 `subagent` 改為「deny，唯一例外 allow `frontend-devkit/reviewer`」；probe 結果寫進 `project.md` 的 `## 安裝紀錄`，`resolved.md` 檔頭只留引用行（§8.2 重寫） | 已修 |
| G5 | probe 第 1 條可用 `git rev-parse`（主體本就 allow）→ 零判別力；關卡 1 在尚未 init 時就跑 probe | §8.2 第 1 點定為「必須用只來自專案端 jsonc 的 gate 指令」；關卡 1 只驗地板方向，次序判別移到關卡 2 | 已修 |
| G6 | reviewer 白名單缺 `New-Item -ItemType Junction *`、`Resolve-Path *`、`npm ci *`、`git worktree remove --force .worktrees/review-*`、`git rev-parse／log／show／fetch／merge-base／ls-tree／cat-file／check-ignore`——程序檔折進 resolved 後，這些動作會全數被地板 deny 擋死 | §7.1 reviewer 列補齊整套（含 worktree 就緒組），並註明 `Get-FileHash` 不給 reviewer（歸 setup，見 S5） | 已修 |
| G7 | §5.1.1 的 shell 探針 `Write-Output $PSVersionTable...` 不在 setup 白名單，init 連偵測都會被拒 | setup 白名單加 `Write-Output *`；讀檔一律改用 `read` 工具而非 `Get-Content` | 已修；**但 R1 實測後該探針已被 `Get-Location` 取代（第 8 題），見 §17.11** |
| G8 | 「profile 不存在→口述 gate 繼續」與「resolved.md 缺失→停止」必然同時觸發，互相矛盾 | §11 兩列互加豁免與例外（選口述路線時 resolved 鐵則一併豁免，但全程標「無設定檔模式」） | 已修 |
| G9 | (a) resolved.md 被手改時偵測不到（保留原 checksum 即混過）；(b) `## 專案覆寫` 可把 `security/*` 檢查合法歸零 | (a) D21：`inspect` 以源頭素材重建暫存 resolved 逐行 diff；(b) D18：安全檢查項只能覆寫更嚴，不得取消——reviewer 照樣執行、引用原文並列「嚴重」（§3 優先序第 3 點、§11、§10.4 同步） | 已修 |
| G10 | 範本缺 `## 額外 shell`，而該欄的人填條目沒宣告要過寫入性檢查 → I-2 的旁路（有人可以填 `npm install *`） | 範本補該小節；permission-spec.md §7.3.5 開頭改成「**任何**要寫進專案端的 shell allow（不分偵測或人填）一律走第 1–4 步」 | 已修 |
| G11 | orchestrator「依賴寫入一律 deny」與 §9.3 需要 `pnpm install --frozen-lockfile`、permission-spec.md §7.3.5#2 已把 frozen-lockfile 排除在疑似可寫入之外，三處態度相反 | D20：不可變／可變分界寫進 §7.1 與 permission-spec.md §7.3.4 第 6 點；orchestrator 列明確 allow `npm ci *` 等三條 | 已修 |
| G12 | 「方案 A／B」被引用三次卻從未定義，且交叉引用指向 permission-spec.md §7.3.5（正解在 permission-spec.md §7.3.4#5） | 新增 permission-spec.md §7.3.0 對照表定義方案 A／B（含取捨與何時改用）；三處引用改為 permission-spec.md §7.3.0／permission-spec.md §7.3.4 | 已修 |
| G13 | permission-spec.md §7.3.4 承諾「由 acceptance.md §13 第 1 關實測路徑匹配」，但關卡 1 清單沒這條 | 關卡 1 通過條件補「四種路徑形＋`opencode.jsonc` 的編輯嘗試全數被拒」 | 已修 |
| S1 | `normalize-forms.ps1` 的 `(' reviewer','reviewer')` 是刪空格規則，造成全文約 15 處漢字黏 reviewer；「人工逐行複核」當時並未完成（還殘留四類簡體字形：處、試、這、沒 的簡寫） | 移除該規則，改為「漢字與 agent 名稱之間補空格」的正規化（`([\p{IsCJKUnifiedIdeographs}])(reviewer|developer|orchestrator|setup)` → 補空白）；四類殘留逐條改掉。**註**：本欄原本用「錯字→正字」的對照寫法保留簡體形做留痕，第 6 站跑全檔批次替換時，這些對照被一起「更正」成「處→處」「條→條」的廢話——我先前寫在 `tools/README.md` 的紀律（批量替換後必須人工重讀受影響行）自己又沒做到，現已把對照改寫為不含簡體形的描述。**教訓升級**：文件內凡要保留「錯字樣本」，一律用**註音／描述**而非原字，否則任何字形清洗都會自我吞掉 |
| S2 | 「雨條」錯字、「明示范例」不成詞、「讓你_commit_ 得下」語句不順 | 全數改寫（§8.2、permission-spec.md §7.3.1 事實 4、§4.2.2） | 已修 |
| S3 | 「四個偵測細節」實列 5 條；「以下八條」實列 9 條 | 計數改正（§5.1.1／§14／§9） | 已修 |
| S4 | 範本六個表格全缺 `|---|` 分隔列（GFM 不渲染，會被逐字寫進專案）；「dev gate」是孤詞 | 分隔列補齊；孤詞改為「任一 gate 在專案裡不存在時」 | 已修 |
| S5 | reviewer 白名單有 `Get-FileHash *` 卻與「checksum 只歸 compile／inspect」矛盾 | 從 reviewer 移除，保留在 setup | 已修 |
| S6 | `npm audit fix*` 違反自家「`cmd sub *`」格式 | 改 `npm audit fix *` | 已修 |
| S7 | 「第 1 輪審核後的 6 項對照」實際 22 項 | 改為「第 1 輪 16＋4＋2、第 2 輪 13＋8，全部集中 CHANGELOG.md 附錄 B §17」 | 已修 |
| S8 | R4 的「單檔 ≤ 120 行」與 resolved.md 體量（4 pack + 9 條程序）可能衝突 | R4 改為「超過即警告而非阻斷」，並給出取捨路徑 | 已修 |

### 17.5 第 2 輪「疑問」的決定

| 疑問 | 決定 |
|---|---|
| G4 兩個修法（setup 放行 reviewer vs 兩段式人工 probe） | 採 **setup 唯讀例外放行 reviewer**（D17）。理由：init 要能單趟跑完並落盤，而兩段式把判讀責任丟給人、實務上會被跳過 |
| G9(b) 是否收緊覆寫權限（security 不得取消） | **採納**（D18）。安全檢查被設定檔歸零，等同讓「可被審核對象影響的設定」決定審核範圍 |
| G2 是否連 `opencode.json5`／`opencode.json.bak` 一起 deny | `json5` 不支援（官方只有 json／jsonc），不虛晃；`*.bak` 不影響載入故不 deny，但 `*.opencode/*` 已涵蓋 `.opencode/` 內的任何變體名 |
| `normalize-forms.ps1` 重跑是否因 PowerShell 版本翻轉 BOM | **現況如實**：`normalize-forms.ps1` 與 `polish-pass3～5.ps1` 皆已改用 `-Encoding utf8NoBOM`；**冪等檢查的歸屬是 §14 步驟 1（實驗先行那一站）**，不是 acceptance.md §13 關卡 0（第 3 輪指出我原先寫錯位置，已改）。腳本路徑寫死本 spec，屬文件 hygiene 工具，與 throwaway 專案無關 |

### 17.6 第 3 輪獨立審核（VERDICT: FAIL，1 嚴重／15 一般／8 建議＋7 殘留漏洞＋6 瘦身項）→ 採納情形

依使用者裁決：四條「需使用者裁定」由我按**安全優先**自決；並同意**修完再開第 4 輪**（超出原訂 3 輪上限）。本表只記「發現 → 落點」，不再復述修法內容（採納瘦身建議 #4；完整脈絡見本檔 CHANGELOG.md 附錄 B §17 各輪紀錄與對應章節）。

| # | 發現 | 落點 |
|---|---|---|
| 嚴重 | 把 `security/*` 從 `## 啟用規則` 整條移除可讓 XSS 審核線靜默消失（啟用清單仍一致、各關全過），而 §7.2 已把 XSS 清單全搬進 pack | §3 新增第 0 點「主體常駐基本安全項」（D22）＋第 3 點「停用型破口」需 `question` 二次確認（D18 擴為兩道封頂）；§7.2 改為「危險模式最小清單留主體，pack 只放專案細項」；§11 新增一列；acceptance.md §13 新增第 7 關「安全地板關」 |
| G11' | 我第 2 輪的「先 deny 家族、緊接 allow 例外」與 §7.1 表格實際排序互相矛盾，照列實現會讓 `install-per-worktree` 卡死 | §7.1 改為**尾巴三段式**正典（D20）；permission-spec.md §7.3.2 紀律表、permission-spec.md §7.3.3 範例、developer／reviewer／orchestrator 三列同步；permission-spec.md §7.3.3 明定 developer 第 3 段為空（連 `npm ci` 都不給） |
| G3' | 「專案端 allow 不得命中主體**任何** deny」把 `resource:"*"` 地板也算進去 → `setup` 會拒絕所有 allow，方案 A 被自己封殺 | permission-spec.md §7.3.4#2 明確限定比對對象為「尾巴第 1、2 段」；D19 同步；§11 該列改寫 |
| G9a' | 「逐字元 diff 重建比對」無法照字實作：`setup` 沒有可寫暫存檔的路徑；檔頭時間戳使 diff 每次必報 → 警告永久失效 | D21 降調為「比對內文、排除檔頭動態欄、由 LLM **逐行**比對（誠實標明非機械 diff）」；需要暫存檔時唯一允許 `.opencode/frontend-devkit/resolved.check.md`；§3 註明 |
| G2' | migration-map.md §12 遷移表仍留 G2 修正**前**的舊 pattern（漏 `opencode.jsonc`），照它寫就復辟漏洞 | migration-map.md §12 該列改為 `*opencode.json`／`*opencode.jsonc`／`*.opencode/*` 並註明以本行為準 |
| G6'／S5' | permission-spec.md §7.3.3 範例仍用 `//` 註解（YAML 會解析失敗）、仍留 `Get-FileHash`（與「checksum 只歸 setup」矛盾） | 範例改 `yaml` 區塊＋`#` 註解、移除 `Get-FileHash` 並留註解、加「節錄，完整見 §7.1」 |
| 一般 | reviewer 白名單的 `Copy-Item *`／`cmd /c rmdir *`／`New-Item -ItemType Junction *`／`Resolve-Path *` 比現行 V1 更寬，與「唯讀、唯一例外」自述矛盾 | 全部收為**具名到 worktree 前綴**形（`Copy-Item * .worktrees/review-*`、`cmd /c rmdir .worktrees/*`…）；permission-spec.md §7.3.3 範例同步示範；orchestrator 同形 |
| 一般 | 「未 init＝官方基底全開」是錯誤威脅模型（規則在 agent 檔 frontmatter 內，隨 agent 載入） | §11 該列改寫：真正風險是「沒選 kit agent、逕用內建 build」，並誠實寫明「這擋不住，只能 README 告警」；acceptance.md §13 關卡 6 第三情境改測「拿掉 jsonc 後主體地板仍擋住非白名單指令」 |
| 一般 | `inspect --probe`／`inspect probe`／`inspect [probe]` 一名三寫；§9.2 說前綴「取自 profile」但範本無該欄；「四個偵測細節」實為五條 | 全檔統一為 `inspect [probe]`；§5 範本補「分支前綴」「worktree 名稱前綴」兩列；計數改正 |
| 一般 | `## 已知豁免` 無範圍上限（可寫成「所有 lint error 皆豁免」癱瘓判定）；`## 額外 shell` 未定寫進哪個 agent 節點（可把 reviewer 撐大） | 範本加**豁免三件套**限制（具體檔案＋具體規則＋理由；不得豁免 gate 失敗與「嚴重」級）；`## 額外 shell` **只追加到 developer**，reviewer 需求走 §8.1 |
| 一般 | setup 的 `edit` 用目錄通配 `*.opencode/frontend-devkit/*`，在專案安裝法下涵蓋 pack 原文與程序檔 → 可比對基準被掉包 | setup 的 `edit` 收為**四個具名檔**（`project.md`／`resolved.md`／`resolved.check.md`／`<設定檔路徑>`），明文禁止改 pack 與程序檔 |
| 一般 | §7.2「白名單以字串開頭比對」是 V1 語意，與 permission-spec.md §7.3.1 事實 3（V2 whole-value）自相矛盾 | 改寫理由：「照範例逐字寫」是**提示詞紀律、非權限保證**；機械把關落在 permission-spec.md §7.3.5 與 diff 檢查 |
| 一般 | permission-spec.md §7.3.5#2 寫入性清單漏「子命令式寫入」（`npm audit fix`、`pnpm prune`、codegen 類）；家族清單在全文重複 6 處 | permission-spec.md §7.3.5#2 補子命令式寫入，並**以 §7.1 第 2 段為唯一正典**（不再各處重列） |
| 一般 | 口述 gate 模式未定 worktreePolicy／depStrategy | §11 新增一列：該模式一律按 `ask`，`depStrategy` 只能 `junction` 或 `none` 由你選 |
| 一般 | 決策彙總只到 D16，D17–D21 散在他處成為孤懸引用；CHANGELOG.md 附錄 A §16 與 §2 重複約 14 列 | §2 補 D17–D22 六列；CHANGELOG.md 附錄 A §16 開頭加「本節是索引摘要，權威定義在 §2 與各節，衝突時以 §2 為準」（採納瘦身 #1 的低風險版本，保留 CHANGELOG.md 附錄 A §16 的速查價值） |
| 一般 | CHANGELOG.md 附錄 B §17.5④「已固定 utf8NoBOM」與「冪等檢查在關卡 0」不實（腳本當時仍是 `-Encoding UTF8`，且關卡 0 是建專案） | 腳本（含 pass3～5）改用 `utf8NoBOM`；CHANGELOG.md 附錄 B §17.5④ 改寫為現況如實＋冪等檢查歸 §14 步驟 1 |
| S1 | `normalize-forms.ps1` 的 `([^\x00-\x7F])(\.md)` 是我自己第 2 輪加的，既修不了 11 處表格黏連（`.md` 前是 ASCII）又會誤傷「`、.md` 後」這種合法內文；CHANGELOG.md 附錄 B §17.2 的自我描述再次與腳本行為不符 | 刪除該規則，改為「表格 `|` 後接檔名補空格」；CHANGELOG.md 附錄 B §17.2 改為**逐條對應**（①②③三條規則寫明）；殘留簡體字以「錯字→正字」對照形式保留痕跡 |
| S1'（自我承認） | **第 3 輪抓到的兩處簡體字，是我在修訂過程中自己新增的**（§3 的「兩條」當時誤打成簡體、§6.4 的「搬運」後誤接簡體「會」）；而本行的原始寫法又被我替換壞過一次（重複句）。老實說：我一邊修字形問題、一邊製造新的字形問題，而且一次修正還把句子疊重 | 已由 pass5／pass6 修正並重讀全句確認語意；CHANGELOG.md 附錄 B §17.2 記錄「腳本第 2、3 條規則是為了補救我自己造成的黏連與殘留」；教訓收進 §14：字形清洗後**必須人工重讀受影響的行**，不能只看腳本的 MISS 輸出 |
| 建議 | kit repo 內出現個人絕對路徑（D1、acceptance.md §13 關卡 0）與 §9.1 禁令字面衝突 | §9.1 明定禁令**適用範圍**（六類 kit 檔案與專案端兩檔）；D1 與關卡 0 的路徑標為「本機範例，非執行期引用」 |
| 疑問→定案 | scanner 拆句後用**原始字串**還是**重組字串**比對（`Resolve-Path node_modules` vs `Resolve-Path -Path node_modules`）——若是後者，我第 3 輪收回的具名 allow 一條都匹配不到 | 升為 **R1 第 5 題**，並明文「此題未定前 §7.1 各條具名 allow 一律視為**草稿**」；R1 從四題擴為六題（另含第 6 題：`*.opencode/*` 是否匹配點開頭相對路徑），§14 步驟 1 同步 |

### 17.7 四條使用者裁決（由我按安全優先決定）

| 疑點 | 我的裁定與理由 |
|---|---|
| probe 由誰派、gate allow 寫進哪個 agent 節點 | **（本決定已於 R1 後作廢：方案 B 下專案端不寫 shell 規則；保留原文供追溯）** 當時的寫法是：專案端 gate allow 一律寫進**被派者自己的節點**：reviewer 用的寫 `frontend-devkit/reviewer`，developer 用的寫 `frontend-devkit/developer`；派工文本（setup→reviewer 的 task prompt）要**明文授權該條指令**，否則 reviewer 的「絕不嘗試白名單外指令」鐵則會自己拒絕執行 probe |
| D14「deny 一律最後」vs D20「例外 allow 緊接 deny」的措辭衝突 | 採**三段式**（D20）並把 D14 限定為「**真地板群**不可被覆寫」；第 2 段是「可被第 3 段翻回」的，文字已分開寫，不再共用「deny 一律最後」一句話 |
| 主體是否常駐基本安全項（多約 5 行提示詞） | **採納**（D22）。理由：安全地板若能在「配置層」被取消，就不是地板；5 行成本相對極小，且這是唯一能擋住「停用 pack」的路徑 |
| `## 模型` 小節是否保留（「存在只為了宣告不存在」） | **保留**。它是給人的防呆（避免有人在 profile 裡綁 model 造成雙真相），成本一行；§7.4 已加交叉引用 |

### 17.8 第 4 輪獨立審核（VERDICT: FAIL，2 嚴重／9 一般／7 建議＋6 阻擋實作；我當時對你轉述為「15 一般／8 建議」，屬口徑灌水，以本表為準）→ 採納情形

| # | 發現 | 落點 |
|---|---|---|
| 嚴重 #1 | developer 的 `edit` deny 沒擋 `*.git/*` → 可寫 `.git/hooks/post-commit`，你每次 commit 都以你的權限執行任意程式碼（與 I-1 同級，前三輪全漏） | D24；§7.1 developer 列 deny 四條；§11 新列；acceptance.md §13 關卡 1 加 `.git/hooks/pre-commit`；README 加 hook 告警（§14 步驟 9） |
| 嚴重 #2 | profile 依 §3 屬不可信輸入，但**欄位值**無白名單：`設定檔路徑`→借刀改全域設定、`kitRoot`→掉包比對基準、`worktree 目錄`→`../` 逃出專案（且 orchestrator 的 `git worktree add *` 不限前綴）、`環境檔`→任意來源複製 | D23；新增 §5.1.2（四欄白名單＋三欄格式列舉）；§11 新列；acceptance.md §13 關卡 7 加 (d) 四種非法值實測 |
| 一般 #3 | D14 仍寫「危險 deny 一律排最後」，與 D20 三段式衝突；CHANGELOG.md 附錄 B §17.7 曾宣稱已限定為真地板群但**未執行** | D14 改寫（第 1 段絕對、第 2 段可被第 3 段翻回）；§7.1 定義塊同步 |
| 一般 #4 | CHANGELOG.md 附錄 A §16 仍寫「不得命中主體**任一** deny」（G3' 修正前的舊文，等於算進地板→方案 A 自我封殺）；且 CHANGELOG.md 附錄 A §16 的「索引摘要／衝突以 §2 為準」那句宣稱有、實際沒有 | CHANGELOG.md 附錄 A §16 該列改為「尾巴第 1、2 段，排除地板」；disclaimer 真的補進 CHANGELOG.md 附錄 A §16 開頭 |
| 一般 #5 | 「只准許許（許）」重聲 4 處：根因是 normalize 腳本用 `String.Replace` 做「只准→只准許」，**非冪等**，跑一次多一個「許」；這也預先證偽了 §14 步驟 1 的冪等待驗項 | 4 處清掉；該規則從腳本**移除**並留註解說明為何不能用擴充式 Replace；冪等驗證項保留 |
| 一般 #6 | `/frontend-devkit/review` 的「`question` 二次確認」不可執行：該指令直入 reviewer，而 reviewer `question: deny` | §3 第 3 點改為分流：orchestrator 三指令走 `question`；`/review` 由 reviewer **不開始審核**並輸出固定提示句（改走 review-fix 或在 profile 明示），明文禁止 reviewer 假設你已同意；acceptance.md §13 關卡 7(a) 依此驗 |
| 一般 #7 | 口述 gate 模式下 reviewer 跑不了任何 gate（無 profile→無專案端 allow，而它 `deny *` 起頭），「全測通過」的獨立查證物理上不可達 | §11 該列補「降級明細」：該模式 reviewer 不執行 gate，回報須標「gate 由 developer 單方執行」，不得虛報；關卡 6 驗得到 |
| 一般 #8 | 「§7.1 第 2 段為唯一正典」名實不符（缺 `pnpm prune`／`npm rm`／`unlink`／`exec`／`dlx`／`npx yarn`／`npx bun` 等）→ `pnpm dlx <套件>`（下載並執行）會被 permission-spec.md §7.3.5#2 判為非可寫入而 allow | §7.1 定義塊第 2 段改為**併集正典**（明言其他章節與三列都引用本塊）；第 1 段標「最小集，各 agent 可加分項（更嚴不算偏離）」 |
| 一般 #9 | 舊文未同步：acceptance.md §13 關卡 6 還用「無 shell 規則＝全開」的錯威脅模型語彙；§11／CHANGELOG.md 附錄 A §16 還寫「重建暫存 resolved 後逐行 diff」（D21 已定稿為上下文重建＋排除檔頭＋非機械 diff） | 三處同步；關卡 6 改測「移除專案端 agents 節點後，主體地板仍拒非白名單指令」 |
| 一般 #10 | §9.6 反斜線指令 vs 斜線 allow：官方「反斜線正規化」寫在通用 Matching，但同頁說 shell 是 raw text，是否適用 shell **未明示** | 具名 allow **兩形並列**（`*` 與 `\*`）；新增 **R1 第 7 題**；明文「定案前該 allow 屬草稿」，並要求程序素材與 spec 統一斜線寫法 |
| 一般 #11 | CHANGELOG.md 附錄 B §17.6 說「完整脈絡見 git log」不實——本 repo **0 個 commit** | 改為「見 CHANGELOG.md 附錄 B §17 各輪紀錄」；**版本基線另請你裁示**（依你的規則：commit 訊息先給你審） |
| 建議 7 項 | 「24 組」實為 26；reviewer 的 `Test-Path .worktrees/*`／`cmd /c rmdir .worktrees/*` 未收 `review-*`（能動到開發 worktree）；§6.4 與 §3 第 0 點重疊；指令檔未禁止 `!`…` 殼塊（官方明示它在 agent 權限流程**外**執行）；`git ls-tree`／`cat-file` 缺用途；`pass3` 有一條自我替換規則；D12「跑八關」計數含關 0／關 8 | 全數採納：計數改正、兩條收 `review-*`、§6.4 去重、§8 加「六個指令檔一律不得使用 shell 塊」、補用途（比對既有測試是否被刪改）、刪除無效規則、D12 改「關 1～7」 |
| 新風險 #3 | permission-spec.md §7.3.5#2 的寫入性清單只有「旗標類」，缺**檔案系統寫刪／任意執行**類（`rm`、`Remove-Item`、`Move-Item`、`Set-Content`、`Invoke-Expression`…）→ `## 指令` 填 `rm -rf *` 級條目時，寫入性檢查與 allow∩deny 比對**都放行**（主體 deny 無 rm 家族） | §5.1.2 末段補清單與「reviewer 節點 allow 僅限測試／lint／build／唯讀工具類」；實作時應把這類指令也加進主體第 1 段地板 |
| 阻擋 #2／#3 | 方案 B 只有取捨表、§9.3 兩步寫法只有半句話 → q3／q4 失敗時該分支等於空白 | 新增 **permission-spec.md §7.3.0.1**（方案 B 的逐條白名單、靜態清單涵蓋不到時的「需人工執行」行為、模式記錄）與 §9.3 **兩步降級寫法**（含回傳值的注入防護驗證） |

### 17.9 第 4 輪「拆檔／瘦身」建議：尚未執行，等你拍板

第 4 輪建議把本檔拆成主檔（≈550～600 行）＋ `docs/permission-spec.md`（permission-spec.md §7.3）、`docs/acceptance.md`（acceptance.md §13）、`docs/migration-map.md`（migration-map.md §12）、`docs/reviews/`＋`CHANGELOG.md`（CHANGELOG.md 附錄 B §17），並**刪除 CHANGELOG.md 附錄 A §16**（宣稱它是兩度不實記載的宿主）。

我的現況判斷（不做無你同意的大搬動）：
1. CHANGELOG.md 附錄 B §17 確實對「實作」近乎零價值、且已長到 4 輪共 ~110 行，**移到 `docs/reviews/`＋`CHANGELOG.md` 我同意**；但主檔要留一行索引，且 8 處「（CHANGELOG.md 附錄 B §17 …）」引用要逐一走——這屬於機械搬動，改錯會造新孤懸引用，建議列為實作計畫的獨立一項。
2. CHANGELOG.md 附錄 A §16 **不刪**：它現在是「索引摘要＋衝突以 §2 為準」，且 §2 已有 D17–D24；刪掉會損失速查。改為保留，並已明確標明權威在 §2（disclaimer 已補進 CHANGELOG.md 附錄 A §16 開頭）。
3. permission-spec.md §7.3／acceptance.md §13／migration-map.md §12 拆附檔：我傾向**拆**（developer 一次要讀的量確實過載），但拆檔需要「檔案地圖＋`grep '§'` 引用清冊」配套（第 4 輪也這麼提醒），所以放進實作計畫步驟 3 一起做，不在本輪動手。
4. 另外 10 個 `tools/polish-pass*.ps1` 與 `normalize-forms.ps1`、`scan-forms.ps1` 屬**一次性文件工具**，不屬於 kit：實作階段結束後應刪除或移到 `tools/oneoff/` 並在 README 註明「不參與 kit 執行」，否則會被誤當成 kit 元件（也違反 §6.1「素材要分清用途」的精神）。

### 17.10 R1 實測後的結案狀態（原本列兩項待實測）

1. **D21 的逐行比對誤報率：仍未解決**，老實標為「實作 `compile` 時的必決項」。R1 那輪測的是**權限匹配**，沒碰到這個；風險仍是：`compile` 若沒有**規範化輸出格式**（段落順序、欄位行模板、行尾空白），LLM 逐行比對會把排版差當竄改。
2. ~~R1 第 7 題（shell 反斜線正規化）~~ **已定案**（`docs/experiments.md` 第 7／7b 題）：allow 只需**斜線一形**（會被正規化）；但程序檔給 `cmd /c` 的指令**必須保留反斜線**，否則 cmd 把 `/xxx` 當旗標（實測 `Invalid switch`）。第 4 輪「兩形並列」與「程序一律改斜線」兩個指示一併撤銷。

### 17.11 R1 實測（2026-11-11）→ spec 的定稿動作

過程、數據與方法學警告全在 **`docs/experiments.md`**；此處只記「結論改了 spec 哪裡」：

| 實測結論 | 動作 |
|---|---|
| 第 3 題：專案端 jsonc 追加的 allow 被主體 `.md` 地板 deny 蓋掉（方案 A 不是偏嚴，是**全數失效**） | permission-spec.md §7.3.0 改為「方案 A 實測不通過／**方案 B 為預設**」；D13、D19、permission-spec.md §7.3.4 的專案端 allow 機制依方案 B 重寫；保留復活條件（真實專案＋TUI 形態覆驗） |
| 第 4 題：`Write-Output (Resolve-Path .).Path` 被拒（括號內指令成為次指令） | §9.3 兩步寫法由「降級備援」升為**強制**，且 `Resolve-Path node_modules` 要個別 allow |
| 第 5 題：scanner 以**原始字串**逐字比對、不重組參數 | 新增**字面同形鐵律**（permission-spec.md §7.3.2、§9.3）：`X`／`X Y`／`X -Path Y` 是三條規則；§7.1 的具名 allow 不再是草稿，但要與程序檔字面逐字對齊 |
| 第 6 題：六種路徑形（含 `.git\hooks\`、worktree 內 `opencode.json`、`opencode.jsonc`）全數被拒 | D24／G2 的 pattern 組**驗證通過**；acceptance.md §13 關卡 1 由「首次驗證」降為「回歸抽驗」 |
| 第 7／7b 題：反斜線會正規化，但 `cmd /c` 指令須留反斜線 | §7.1 結論塊與 reviewer 列改為「allow 斜線形、給 cmd 的指令反斜線形」，撤銷兩形並列 |
| 第 8 題（新測）：`$PSVersionTable.PSVersion.ToString()` 被拒，即使 `Write-Output *` 已 allow | §5.1.1#1 探針改 `Get-Location`（無 `$`、無括號）＋`cmd /c ver` 交叉驗證；permission-spec.md §7.3.2 補兩行紀律（字面同形、`$`／括號形禁用） |
| 方法學：`opencode run` 的 shell 落在 **service 綁定的專案目錄**（實測落在另一個真實專案）；新專案 `.opencode/agents/*.md` 用 `--agent` 找不到，同格式全域 agent 找得到 | 寫進 `docs/install.md` 的「自動化驗證注意」；acceptance.md §13 各關執行前先 `Get-Location` 確認落點、涉及寫檔一律用絕對路徑；第 3 題覆驗改用 TUI＋真實安裝形態。**本次已查核該被波及專案的未 commit 檔案 mtime 為 2026-11-04，確認非實驗造成，且實驗未對其寫入任何檔** |

### 17.12 第 5 輪獨立審核（VERDICT: FAIL，5 嚴重／8 一般／5 建議＋6 阻擋）→ 已修與**未修完的清單**

| # | 發現 | 狀態 |
|---|---|---|
| 阻擋 1／嚴重 | §7.1 權威角色表仍以方案 A 語彙寫 gate（「profile 各 gate」「專案端追加」） | **已修**：developer／reviewer 兩列改引用 permission-spec.md §7.3.0.1 靜態清單＋「清單外→需人工執行／逐次彈窗」 |
| 阻擋 2／嚴重 | setup 白名單沒有新探針（只有 `Write-Output *`，實測會被拒）→ init 的 shell 偵測必死 | **已修**：補 `Get-Location`、`cmd /c ver` 精確形，`Write-Output *` 去「探針」標籤 |
| 阻擋 3／嚴重 | §5.1 偵測表仍寫「`$PSVersionTable` 探針（唯一可行做法）」，與 §5.1.1#1 對打 | **已修**：該列改為「`$`／括號形不可用，探針用 `Get-Location`」 |
| 阻擋 4／嚴重 | CHANGELOG.md 附錄 B §17.11 與 experiments 的行動清單有 4 處「宣稱落地、實際沒落地」（D19、permission-spec.md §7.3.4、permission-spec.md §7.3.2 兩行） | **部分**：permission-spec.md §7.3.2 已補「字面同形鐵律」與「`$`／括號形禁用」兩行；D19 已加「方案 A 保留條款」前綴；permission-spec.md §7.3.4 已在節首加現況標記與 B 紀律。**代償**：同輪又出現 2 個 MISS（見下方未修 1、2），所以本表把未修項目老實列出來，不再宣稱全清 |
| 阻擋 5／嚴重 | probe 全鏈在方案 B 下不可執行（第 1 條「必須只來自專案端 jsonc」永無來源） | **已修**：§8.2 重定義為「版本迴歸偵測」（第 0 條 `Get-Location`、第 1 條靜態清單 gate、第 2 條地板）；permission-spec.md §7.3.4#5、acceptance.md §13 關卡 2、profile 範本 `## 安裝紀錄` 同步；次序判別整段移入 permission-spec.md §7.3.0 的方案 A 復活檢測 |
| 阻擋 6／嚴重 | migration-map.md §12 與 permission-spec.md §7.3.4#7 的 developer deny 仍只三條（缺 `*.git/*`） | **已修**：兩處補第四條，並改標「六種路徑形已由 experiments 第 6 題實測」、關卡 1 降為回歸抽驗 |
| 一般 | §11「未批准的可寫入指令寫進 allow」列、`/review` 二次確認與 §3 不同步、口述 gate 模式的降級敘述是方案 A 推論 | **部分**：§11 二次確認列已補 `/review` 例外（不開始審核＋固定句）；口述模式已改寫為**三角色分別降級**（reviewer 清單內可跑／developer 彈窗／orchestrator 不受影響）；**§11「寫進 allow」那列尚未改**（未修 3） |
| 一般 | §9.3 把「`New-Item … -Target (…)` 實測 DENIED」寫成事實，但實測只測過 `Write-Output` 形 | **已修**：改為「依第 4 題機制**推定**，尚未直接實測 `New-Item` 形，關卡 4 要實測」 |
| 一般 | permission-spec.md §7.3.3 範例與示範文字仍是 `cmd /c rmdir .worktrees/*`，未收 `review-*`（第 4 次同型錯誤：改了表格沒改範例） | **已修**：範例與說明都收 `review-*` |
| 一般 | 計數不實：R1「七題」（實八題）、§5.1.2「另外兩欄」（實四欄）、CHANGELOG.md 附錄 B §17.11「四種路徑形」（實六種）、CHANGELOG.md 附錄 B §17.8 表頭「10 一般」（報告實 9 一般） | **已修**：四處計數改正；並加入一條自我修正——我對你在第 4 輪口述的「15 一般／8 建議」是**口徑灌水**，以 CHANGELOG.md 附錄 B §17.8 表為準 |
| 一般 | 「方案 A 全數失效／永久停用」是全稱句，但實測只測過「全域 agent × 全域 config」；且「找不到專案本地 agent」高度可能是**我的 service 綁定操作問題** | **已修**：permission-spec.md §7.3.0 與 R1 措辭軟化為「本次形態不通過」；復活條件加入**三步先決檢測**（先 `Get-Location` 確認綁定、再確認專案 agent 出現在清單、才測 allow），並明文「三步驟任一失敗先修操作、不下平台結論」 |
| 建議 | resolved.md 檔頭缺「權限模式：B」；`inspect` 摘要缺兩項；CHANGELOG.md 附錄 B §17.8 落點引用錯一格（hook 告警在步驟 9 而非步驟 8）；migration-map.md §12 缺「回歸防護五步」遷移列；關卡 0 措辭 | **未全修**：見下方未修 4、5 |

#### 本輪**未修完**、留給下一輪或實作前清理的清單（不宣稱已修）

1. §8 `inspect` 的檢查摘要缺兩項：「profile `## 指令` × 主體靜態清單的比對結果」與「專案端設定不得含 shell 條目（方案 B 紀律）」——permission-spec.md §7.3.4 節首已寫這條紀律，但 `inspect` 清單還沒列，實作會漏做。
2. migration-map.md §12 遷移表缺「回歸防護五步（現行 `developer.md` §回歸防護）」對應列；全文兩度引用「五步」卻從未展開內容，抽主體時易漏。
3. CHANGELOG.md 附錄 B §17.8（第 4 輪表）有一格落點引用錯：宣稱「README hook 告警（§14 步驟 9）」，但步驟 9 現列的是 build 告警；hook 告警實際在 §11 的 `.git/` 列。
4. （已修，留此紀錄）`resolved.md` 檔頭已補「權限模式（A／B）」；§11 那整列「未批准的可寫入指令寫進 allow」已改寫為 B 的四道處置。
5. §15 R9／R10 仍用方案 A 語彙（「profile 逐 script 具名 allow」「提供 `## 額外 shell` 白名單」）：第二道牆應改「主體靜態清單＋需人工執行」，R10 應改「靠 `Allow always` 存成專案級持久 allow，並由 `inspect` 審查存下的規則」。
6. **方案 A 覆驗尚未做**：需要一個能正確綁定到探測專案的環境（本次 `opencode run`／`--standalone` 都把 shell 落在 service 的專案目錄）。這直接決定 permission-spec.md §7.3.0 是「停用」還是「作廢」，也決定 D19、permission-spec.md §7.3.4 第 1–6 點要不要整段刪除。**我不在你的機器上重啟共用 service**（會波及你正在跑的 session），所以這條留給你決定時機與方式。

### 17.13 第 6 站：拆檔、清理、以及上面那條「未修清單」的結案

依使用者裁決「收尾＋全部拆＋清理，交終審」執行。

**拆檔（全部拆）**：主檔由 955 行降到約 618 行，並新增四個附檔＋一個 CHANGELOG：

| 檔案 | 由主檔哪節搬出 | 定位 |
|---|---|---|
| `docs/permission-spec.md` | §7.3 全節（方案 A／B、八條官方事實、語法紀律、規則鏈範例、跨來源紀律、allow 產生流程、model 策略） | 寫 frontmatter 與 `setup` 比對器前的**必讀權威** |
| `docs/migration-map.md` | §12 遷移對照 | 實作「抽 pack／寫主體」的查核清單 |
| `docs/acceptance.md` | §13 驗證關卡 0～8 | 驗收標準 |
| `docs/CHANGELOG.md` | 附錄 A＝原 §16；附錄 B＝原 §17.1～17.12（本節） | 歷史脈絡，**非實作依據** |
| `docs/experiments.md`（第 6 站前已存在） | R1 八題實測 | 質疑權限結論時的原始數據 |

主檔保留 §1–§11、§14、§15，並在頂端新增「**0. 檔案地圖**」；§7.3／§12／§13／§16／§17 在原位留 stub 維持編號不斷裂，全文 `§` 引用已加檔名前綴（拆檔後跑過一次引用比對，主檔殘留未加前綴的已外移引用為 0）。拆檔用的腳本與一次性 `polish-pass*.ps1` **已刪除**，`tools/` 只留 `normalize-forms.ps1`、`scan-forms.ps1` 與說明其非 kit 身份的 `tools/README.md`；探測專案 `%USERPROFILE%\AI\r1-probe` 已整包刪除（全域設定先前已驗證與備份雜湊一致）。

**17.12 那張「未修清單」的結案狀態**（逐條，不籠統宣稱已修）：

| 原清單 | 現況 |
|---|---|
| 1　`inspect` 摘要缺兩項檢查 | **已修**：§8 的 `inspect` 列補「`profile ## 指令` × 主體靜態清單比對」與「專案端設定是否含 shell 條目」，並保留「allow∩deny（僅方案 A 啟用時）」 |
| 2　migration-map 缺「回歸防護五步」遷移列 | **已修**：該檔補一列，寫明五步各自去處（步 1 動態量測、步 2 類別進 profile、步 3 進 pack、步 5 來源是 `## 回歸熱點`），並標明**五步本身留主體提示詞** |
| 3　§17.8 落點引用錯（hook 告警） | **已修**：主檔 §14 步驟 9 現在列三條告警，第三條就是「任何 agent 都不准動 `.git/`（含 hooks）」，與 §11／D24 對齊 |
| 4　`resolved.md` 檔頭缺「權限模式（A／B）」；§11 那整列仍是方案 A 語彙 | **已修**（上一站）：檔頭已補模式欄；§11 該列改寫成 B 的四道處置（compile 標疑似可寫入→不入可執行 gate；清單外→需人工執行；developer 彈窗預覽原始命令；`inspect` 列出持久 allow 要你手動撤） |
| 5　R9／R10 仍用方案 A 語彙 | **已修**：R9 改「四道牆」，第二道改成「主體靜態清單＋清單外需人工執行」；R10 改寫為「B 下這是設計內結果」＋`Allow always` 持久化路徑＋`inspect` 審查存下的規則 |
| 6　方案 A 覆驗未做 | **仍未做**，如實保留。這是本份文件唯一還掛著的「可能推翻現行設計」的開放項：若覆驗證明專案端 config 的 allow 在正確綁定下生效，則 D19、permission-spec.md §7.3.4 第 1–6 點可復活、方案 A 可重新成為預設；若不生效，就該把那幾段整段刪除、只留一句「專案端不寫 shell 規則」 |

**我對自己的兩條更正**（寫進來，不藏在對話裡）：
1. 17.12 的原清單第 1、2、5 條曾引用檔中**已不存在**的字串（我拿舊字串當證據），實際早已修好。教訓：**列「未修清單」前要先 grep 現況**，否則清單本身就會變成下一輪要清的誤報。
2. 拆檔用的腳本內建「引用加前綴」規則時，我沒先想到自己寫的「檔案地圖」表格會被自己的規則改成「原 permission-spec.md §7.3」這種自指涉——已人工修回。這正是 §14 步驟 3 新增「拆檔後必跑 `grep '§'` 比對檔案地圖」的理由。

### 17.14 第 7 站：M1（步驟 3–6）落地，以及計畫檔的字元毀損

**發現**：要寫 M1 時做字元健全性檢查，發現已 commit 的 `implementation-plan.md`（`f06aa45`）內有 **28 處「一」被誤寫為「次」**（例：「一個步驟一交」變「次個步驟次交」、「做一次跨檔 grep」變「做次次跨檔 grep」、「一致」變「次致」），另有多處簡體字形（「這、沒、數、過、寫、審、換、檔、經、設」等十餘種）。更糟的是：我當時在對話裡對使用者敘述的措辭與檔內文字不一致——**這正是本計畫 §0.2／§0.5 要防的「宣稱與文件不一致」**，而它發生在寫下該紀律的同一份檔案裡。

**處理**：重寫 `implementation-plan.md`（比逐點補丁安全），並把檢查制度化：每個 markdown 產出在 commit 前跑「一／次 數量比對」＋兩批簡體字形掃描＋「回覆敘述與檔內文字抽樣逐字比對」。本轮另修：CHANGELOG 兩處、writing-a-pack 一處、三個 pack 與 templates 的簡體字共 9 處（逐條手改，未再用批次腳本——因第 6 站的批次腳本正是毀損來源之一）。

**M1 交付內容**：`kit/rules/`（4 個 pack ＋ registry）、`kit/worktree.procedures.md`（九條程序，佔位符化）、`kit/profile/project.template.md`（含四欄白名單的正／反例與三態說明）、`docs/writing-a-pack.md`（退件清單七條＋旗標界說＋§6.1 與 §6.4 衝突的裁決紀錄）。

**M1 驗收實測結果**（先跑檢查、再回報，不先宣稱）：

| 檢查 | 結果 |
|---|---|
| pack 內無完整指令列／timeout／項數／專案路徑（grep `npm \|pnpm \|npx \|timeout\|--fix\|99 項\|src/\|\.vue\|\.js`） | **0 命中** |
| 四個 pack 檔頭 `id`／`status`（`已驗證`）／`covers` 齊備 | 4/4 通過 |
| 模板表格分隔列：表頭數 10、`|---` 分隔列數 10 | 每表都有，無缺 |
| kit 素材內無個人絕對路徑（grep `C:`、`Users\<使用者>`） | **0**（原有一處是「非法範例」欄位的 `C:\…`，已改為 `<盤符>:\…` 以免與檢查互相干擾） |
| 簡體專屬字形掃描（`tools/scan-forms.ps1` 的字集約 50 字，皆為繁體不用的簡體形） | **0 命中** ✓ |
| 「一」/「次」數量比對（9 個新檔） | 「次」全部來自合法詞（一次、每次、首次、上次、該次、前次、兩次、二次確認），無「一→次」毀損 |

**尚未做、也不該瞞著的**：`kit/agents/` 與 `kit/commands/` 目錄此時是空的（git 不追蹤空目錄），所以主檔 §4.1 的目錄樹在 M2（步驟 7–8）之前無法用 `git ls-files` 驗「不缺不多」——這是**預期狀態而非通過**，到時才驗。

### 17.15 第 5 站（M2）：四個 agent 與六個指令落地，以及一次口誤的自我更正

**產出**：

| 檔案 | 內容 | 規則數 |
|---|---|---|
| `kit/agents/frontend-devkit/orchestrator.md` | 協調者：`ask` 起頭＋唯讀 git 與 worktree 具名 allow＋尾巴三段式（含第 3 段不可變例外）；`edit deny *`；只准派 developer／reviewer | 95 |
| `kit/agents/frontend-devkit/developer.md` | 開發者：`allow *` 後接四條 edit deny（`*opencode.json`、`*opencode.jsonc`、`*.opencode/*`、`*.git/*`）；尾巴第 3 段刻意為空（連 `npm ci` 都 deny）；七個回報區段、回歸防護五步、換行字元紀律 | 114 |
| `kit/agents/frontend-devkit/reviewer.md` | 審核者：`shell` 與 `edit` 雙地板；具名到 `review-*` 的 worktree 就緒通道；靜態 gate 清單；§0 寫明「白名單只放行唯讀用法」背後的真實機制（whole-value wildcard，逐字寫是提示詞紀律而非權限保證）；七區段輸出 | 122 |
| `kit/agents/frontend-devkit/setup.md` | 設定者：`edit` 僅四個具名檔與四種設定檔字面形，明確 deny 全域設定與 `*.git/*`；`subagent` 唯一例外是 reviewer（供 probe）；寫明「方案 B 下不得把 shell 規則寫進專案端」 | 30 |
| `kit/commands/frontend-devkit/*.md` | 六個指令：dev／fix／review（含 `subagent: false`）／review-fix／init／inspect。皆無 shell 塊、無「專案端追加 allow」語彙 | — |

**驗收**（`tools/check-structure.ps1` 實跑結果）：frontmatter 規則格式不符 0、雙斜線註解 0；主體混入專案專屬事實的 7 個樣本字全為 0；指令檔「專案端追加」殘留 0、shell 塊 0；三段式相對次序——orchestrator 與 reviewer 為「正確：allow 在 deny 之後」，developer 與 setup 為「無此對（N/A）」（developer 刻意沒有第 3 段，setup 不跑 gate）；字形掃描 0 命中、「一／次」數量正常。

**自我更正（要記，不可當成裝飾文字）**：我一度在對話中宣稱「檢查在 `developer.md` 抓到 allow 排在 deny 之前」，查證後發現**該檔根本沒有那行**（developer 依規格第 3 段為空），是我把工具輸出解讀錯了。這是本計畫 §0.2／§0.5 要防的同一類錯誤（宣稱先於查證），而且這次發生在**對你回報的當下**。定案紀律：凡「檢查抓到 X」的敘述，必須先把工具輸出原帖貼上，再下結論。

**M2 尚未做的兩件事**（不算通過）：

1. **實際載入測試**：「四個 agent 能被 OpenCode 辨識、且不會冒出 `rules/...` 之類假 agent」需要先在 `~/.config/opencode/agents/frontend-devkit/` 裝一次再查清單。這會碰你的全域設定目錄（跑 R1 時我也是這麼做、事後清掉），因此**等你同意時點**。
2. 目前 frontmatter 只經我寫的腳本做**格式**檢查，不是 YAML 解析器驗證；真正的載入錯誤要等上面第 1 項才會浮現。

### 17.16 第 5 站追加：全域載入測試與 reviewer 權限煙霧測試（已清理）

**做法**：把 `kit/agents/frontend-devkit/*` 複製到 `~/.config/opencode/agents/frontend-devkit/`，把 `rules/`、`profile/`、`worktree.procedures.md` 複製到 `~/.config/opencode/frontend-devkit/`（**沒有改動全域 `opencode.json`**），用 `opencode run --agent …` 實測，結束後兩個子資料夾都已刪除（`Test-Path` 皆 `False`，全域 agents 目錄只剩原本的 `security-auditor.md`，`opencode.json` 無 `agents` 鍵）。

| # | 實測項目 | 結果 |
|---|---|---|
| 1 | 四個 agent 可否被載入（orchestrator／reviewer／setup／developer） | **全部成功**（`mode: subagent` 的 developer 也能被 `--agent` 直接啟動，代表 CLI 不強制 subagent 只能被派工） |
| 2 | 負向：`--agent frontend-devkit/rules/vue-xss` | **Agent not found** ✓ → 印證 §4.2 的「發現規則陷阱」修法有效：rules 放 `agents/` 外不會被當成 agent |
| 3 | reviewer 跑 `git status --short`（白名單內） | **EXECUTED** ✓ |
| 4 | reviewer 跑 `git stash list`、`git tag`（尾巴第 1 段 deny，**無參數形**） | 兩者 **DENIED** ✓ → 同時印證「` *` 也匹配無參數形式」這條官方事實是真的，且 deny 排在 allow 之後確實壓得住 |
| 5 | reviewer 跑 `cmd /c rmdir .worktrees\review-zzz`（allow 寫斜線形、實際打反斜線） | **EXECUTED** ✓ → shell 反斜線正規化在真實 kit agent 上同樣成立（不必並列兩形） |
| 6 | reviewer 跑 `Test-Path .worktrees/review-zzz` | **EXECUTED** ✓ |
| 7 | reviewer 跑 `npm testxyz` | **DENIED** ✓ → `"npm test *"` 不會誤放 `npm testxyz`，§7.3.2 的「用 ` *` 形、不用 `test*`」有實質效果 |
| 8 | reviewer 跑 `Get-FileHash tools/scan-forms.ps1` | **DENIED** ✓ → 第 3 輪 S5 的修法落地：checksum 驗算只屬 `setup`／`compile`，reviewer 沒拿到該權限 |

**副作用查核**：第 5、6 條的 `rmdir`／`Test-Path` 目標都是不存在的名字（`review-zzz`），不會刪到東西；`git status` 為唯讀。被 service 綁定的那個真實專案（既有專案）的 `.worktrees\feature-font-size-toggle`（2026/11/6）與兩個未 commit 檔案（mtime 2026/11/4）**保持原狀**，未受本次測試影響。

**仍然未驗的**：六個指令檔的**斜線指令展開**（`/frontend-devkit/dev` 這類）需要在 TUI 或互動式 session 裡按出來看清單，headless 只驗證了 agent 端；另外 `init`／`compile`／`inspect` 的實際行為要等關卡 2（需要一個裝好 kit 的試寫專案）才算數。這兩項都留給 `acceptance.md` 的關卡處理，不在這裡宣稱通過。
