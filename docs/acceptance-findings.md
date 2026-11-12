# acceptance 執行情形與發現

依 `acceptance.md` 逐關記錄實際做過的事與結果。**沒做過的關卡一律標「未驗」**，不用推定充數。

## 關卡 0　建置（人工）— 已完成 ✓

| 項目 | 結果 |
|---|---|
| 位置 | `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\` |
| app-a | `npx --yes create-vite@latest app-a --template vue`（create-vite 9.3.4，無互動提示）。`npm install` 35 套件、0 漏洞；`npm test` 通過（vitest 5.1.0，1 passed）；`npm run build` 通過（vite 8.3.8，1.76s）。commit `ae6a5e8`＋`ed9221e`，工作區乾淨 |
| app-b | 複製 app-a（排除 `node_modules`／`dist`／`.git`），`git init` ＋ commit `eca0e0e`，工作區乾淨（尚未裝依賴，關卡 6 只需它當「無 profile」的殼） |
| `.gitignore` | 兩邊都已含 `.worktrees/`（對應 profile 預設 worktree 目錄）；**由我這個人工建置步驟加，不是 kit 改的** |
| Node 環境 | 機器預設 `node` 是 **v12.22.12**（nvm 預設，TOS 專案用的）。Vite 8 需 Node 18+，故每次呼叫把 `installs\v24.15.0` 塞進該次程序 PATH，**未更動 nvm 預設** |
| 刻意留的鉤子 | app-a 的 `lint` script 是 `node -e "console.log(1)"`，用來驗 `setup` 的寫入性檢查是否會把它標成「疑似可寫入／任意執行」而非放進可執行 gate |

## 關卡 1　載入關 — 部分完成（權限與載入 ✓，四種編輯路徑屬回歸抽驗）

用 `~/.config/opencode/agents/frontend-devkit/` 暫裝四個 agent（跑完刪除），實測：

| # | 項目 | 結果 |
|---|---|---|
| 1 | 四個 agent 可被載入（含 `mode: subagent` 的 developer） | 全部成功 |
| 2 | 負向：`--agent frontend-devkit/rules/vue-xss` | `Agent not found` ✓ → `rules/` 放 `agents/` 外不會被當成 agent（§4.2 那條陷阱修法有效） |
| 3 | reviewer：`git status --short`（白名單內） | EXECUTED ✓ |
| 4 | reviewer：`git stash list`、`git tag`（尾巴第 1 段 deny，**無參數形**） | DENIED ✓ →「` *` 也匹配無參數」對 deny 同樣成立 |
| 5 | reviewer：`cmd /c rmdir .worktrees\review-zzz`（allow 寫斜線、實際打反斜線） | EXECUTED ✓ 反斜線正規化在真實 kit agent 上成立 |
| 6 | reviewer：`Test-Path .worktrees/review-zzz` | EXECUTED ✓ |
| 7 | reviewer：`npm testxyz` | DENIED ✓ `"npm test *"` 不會誤放 `npm testxyz` |
| 8 | reviewer：`Get-FileHash …` | DENIED ✓ checksum 只屬 `setup`（第 3 輪 S5 落地） |
| 9 | `edit` 的四種路徑形（根／`.opencode`／worktree 內／`opencode.jsonc`）＋ `.git/hooks` | **未驗**（R1 第 6 題已驗過 pattern 組，此處降為回歸抽驗） |
| 10 | 六個 slash 指令能否展開 | **未驗**：headless 不觸發 slash 展開，需在 TUI 看 |

附帶記一個**我的誤判**：第一次測落點時用 reviewer 跑 `Get-Location` 得到 DENIED，我一度以為工具壞了；其實 `Get-Location` 依設計只在 `setup` 的白名單內，**deny 是正確行為**。屬「測錯對象」而非缺陷，記錄下來免得以後又誤報。

## 阻塞 M3 的發現：無法把 agent 的 shell 落點改到 app-a

關卡 2～7 需要 agent 在 app-a 裡建 worktree、改檔案、跑指令。實測證明**目前的驅動方式做不到**：

| 嘗試 | shell 的 `Get-Location` 結果 | 判讀 |
|---|---|---|
| 共用 service＋`opencode run`（工作目錄設 app-a） | `TOS_Frontend`（另一個真實專案） | shell 落點不等於呼叫端 cwd |
| `--standalone`（工作目錄 app-a 或 r1-probe） | 同上（`TOS_Frontend`） | 沒有改用私服務綁定的目錄 |
| 在 app-a 起 `opencode serve --port 29401`，再 `opencode run --server http://127.0.0.1:29401`（密碼走 `OPENCODE_SERVER_PASSWORD`，連線成功、agent 正常回應） | **`TOS_Frontend_Fia`（這個對話的專案）** | `--server` 也沒改落點；shell 跟著 service 註冊的 location 走 |

**結論**：`opencode` 的 shell 工具在 **service 綁定的 location** 執行，`--server`／`--standalone` 與呼叫端 cwd 都改變不了它。因此關卡 2～7 若由我自動驅動，agent 會去改**你正在用的專案**，這不可接受 → 我停在這裡，沒有讓它寫任何東西到 app-a 之外（本節所有測試都是唯讀或權限被拒）。

**過程中也澄清一件事**：我曾以「找不到含 29401 的 `node.exe`」判定 server 已停，但 `Invoke-WebRequest` 回 200——實情是它跑在編譯後的 `opencode.exe`（PID 1956）。改停該程序後連線才被拒、`Get-NetTCPConnection` 顯示 0 個持有者。教訓：**「已清理」的斷言要用功能探測證明，不能只看程序名**。共用 service（28894）全程未受影響。

## 剩下的可行驅動方式（等你選）

1. **你在 TUI 手動跑**：在 app-a 開一個 OpenCode session（`Get-Location` 會是 app-a），依 `acceptance.md` 的關卡 2～7 逐項執行，把輸出貼給我判讀與記錄。這是**唯一不需要動到你環境**的做法，也同時會驗到 slash 指令展開（關卡 1 第 10 項）。
2. **重啟共用 service 讓它綁 app-a**：`opencode service restart` 之類會中斷這個對話；之後要回到 TOS 專案工作時還得再重啟一次。
3. **接受「關卡 2～7 延後」**：先以關卡 0/1 的實測與 R1 八題實驗作為 M3 的部分通過，把 2～7 列為上線前必驗項，寫進 README 的上手檢查清單。

（尚未開始：關卡 2～8；`kit/` 的全域安裝已清空，暫評專案 `app-a`／`app-b` 原樣留在 `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`。）

## 關卡 2（使用者在 app-a 的 TUI 手動跑 `init`）— 部分通過，抓出 4 個真缺陷

使用者回報「init 完成」，並附一句 `OpenCode 版本（opencode --version 不在白名單，實測被拒）` 問是否正常。我查證實際產出（`project.md` 12.1KB、`resolved.md` 15.0KB、`## 安裝紀錄` 與檔頭皆有內容）後判定：

### 通過的項目（逐項查證，非採信自稱）

| 項目 | 證據 |
|---|---|
| 落點正確 | `## 安裝紀錄` probe 第 0 條＝app-a |
| **lint 鉤子被抓** | `scripts.lint` 展開為 `node -e "console.log(1)"` → 標「任意執行族，不列入可執行 gate」，並經使用者答「無」定案。這是我最想驗的一項，行為正確 |
| gate 判定與來源標註 | test＝`npm test`（展開 `vitest run`）可執行；build＝`npm run build` 可執行；依賴＝`npm ci` 不可變可執行；皆標 `偵測自 package.json …` |
| probe 三條 | 第 1 條 `npm test` 真的跑過（vitest 5.1.0，1/1 通過）；第 2 條 `git commit --allow-empty -m probe` 被拒且 `git log` 仍只有我建的 2 個 commit（無殘留）；`.worktrees` 未產生、`git worktree list` 只剩主工作區 |
| 檔頭欄位 | 權限模式 B、啟用清單、pack checksum（`security/vue-xss`＝DBEFB238、程序檔＝9E09C3AA）、covers、警告欄齊備 |
| 誠實性 | 兩處取不到（OpenCode 版本、kit 版本）都寫「無法取得（原因）」，**沒有猜值** |

### 抓出的缺陷與對應修法（已落地）

| # | 缺陷 | 根因 | 修法 |
|---|---|---|---|
| A | **`.opencode/opencode.json` 沒建立**，`instructions` 未註冊；agent 還把「本檔目前尚未建立」寫進 profile 就回報完成 | 規格少了「init 完成定義」，沒要求收尾驗證必要寫檔動作 | `setup.md` §1#3 加「不論哪種情況都要寫 instructions」；§2 新增第 6 點**收尾自我檢查**（`project.md`／`resolved.md`／設定檔＋instructions 兩筆／安裝紀錄，缺一即回報「未完成」與原因）；主檔 §8.1 預設模式同步 |
| B | **`預設審核範圍` 被寫成「省略」**——違反 §5.1.2 格式驗證，且「省略」正是指令檔明令不准傳的保留詞；app-a 無 `origin` 遠端，正確值應是 `TBD（未確認）` | 規格只說「必須是範圍語法之一」，沒列**非法保留詞**，也沒說偵測不到時怎麼寫 | 主檔 §5.1.2 新增「保留詞」段（`省略`／`預設`／`default`／`無`／空字串）；`project.template.md` 該列補非法值與後果；`setup.md` §1 第 3 點加值域驗證 |
| C | 檔頭要求記 `OpenCode 版本`，但 `setup` 白名單沒有取用途徑 → 老實寫「無法取得」= **行為正確、規格有洞** | 規格未配對「需要記的資料」與「取得它的合法指令」 | `setup.md` 白名單加 `opencode --version`（精確形、純讀） |
| D | `kit 版本` 在**專案區安裝**形態下必然取不到（kitRoot 不是獨立 git repo） | 規格假設 kit 一定來自獨立 repo | `setup.md` §4 與主檔 §6.3 明定：寫「無法取得（原因）」＋以 pack／程序檔 checksum 作次級源頭識別＋`inspect` 列為追蹤缺口，且不構成失敗 |

### 修補後的同步

`kit/` 的修補已重新複製進 `app-a` 與 `app-b` 的 `.opencode/`（驗證：兩邊 `setup.md` 皆含 `opencode --version` 與「收尾自我檢查」）。**舊的 `app-a/.opencode/frontend-devkit/project.md` 仍帶著缺陷 A／B 的值**（`設定檔路徑` 註「尚未建立」、`預設審核範圍` 為「省略」）→ 需重跑一次 `init` 讓新規則生效，這正是下一節關卡 2b 要驗的東西。

## 關卡 2b（修補後重跑 `init`）— 通過，並抓出我自己留下的範本矛盾

使用者在 app-a 的 TUI 重跑 `/frontend-devkit/init`，我逐項查證實際產物（不採信回覆）：

| 修補項 | 實測證據 | 判定 |
|---|---|---|
| A｜`instructions` 未註冊 | `.opencode/opencode.json` 已建立，內容只有 `instructions` 兩筆（`project.md`、`resolved.md`）；無 `permissions`／`shell` 字樣（方案 B 紀律未破）；根目錄沒有第二份設定檔 | 已修 ✓ |
| A｜profile 內「尚未建立」 | `設定檔路徑` 改成「…→取預設值並**已建立**；`instructions` 已註冊…」 | 已修 ✓ |
| B｜保留詞當值 | `預設審核範圍` 現值 `TBD（未確認）`，附「repo 無 `origin` 遠端」與後果，並標明舊值已修正 | 已修 ✓ |
| C｜OpenCode 版本 | 檔頭 `opencode v2.2.7`；安裝紀錄寫「`opencode --version` 執行成功」 | 已修 ✓ |
| D｜kit 版本取不到 | 「無法取得（kitRoot 非獨立 git repo）」＋以 `security/vue-xss`＝`DBEFB238`、程序檔＝`9E09C3AA` 作次級識別，本輪 `Get-FileHash` 實測一致 | 如規格 ✓ |
| probe 三條 | 第 0 條落點＝`...\app-a`（不是別棵樹）；第 1 條 `npm test` 退出碼 0（vitest 1/1）；第 2 條 `git commit --allow-empty -m probe` 被拒且 `git log` 仍只有我建的 2 個 commit | ✓ |
| compile | 檔頭「第 3 次重譯」、權限模式 B、警告欄「無」 | ✓ |

**唯一無法從檔案查證的**：收尾自我檢查的「逐項列出」只出現在 agent 回覆，不在檔案 → 待回覆末段貼回才認定，不先宣稱通過。

### 缺陷 E（這輪新增）：值域的權威定義與範本互相矛盾

`app-a/.opencode/frontend-devkit/project.md` 第 44 行（實例自 `project.template.md`）寫：「`預設審核範圍` 必須是…語法之一：**省略（用 `預設基準分支` 組出範圍）**、`a..b`…」。而同一份檔案下面寫「不得填『省略』」。**我把缺陷 B 的成因留在範本裡**——agent 當初填「省略」正是照那行做的。修了值域驗證卻沒改枚舉的出處，屬 reviewer 歷輪點名的「改一處忘三處」。

已落地修法：
1. 範本該行改為**只列四種實際語法**，並明說「使用者呼叫時不帶範圍」是**呼叫情境、不是可存的值**。
2. 主檔 §5.1.2 新增規條：**值域只能有一處權威定義**（§5.1.2 本節）；範本、agent 提示詞、實例 `project.md` 只能列允許值或引用本節，不得另立含保留詞的清單；`inspect` 要比對兩者是否一致，不一致即警告。
3. 同步範本進 app-a／app-b，並**就地修正 app-a 的 `project.md`**（實例不會自愈）。查證：`kit` 範本、app-a 的 `project.md` 與兩份範本共四處，舊行「省略（用」命中皆為 0、新行存在；app-b 仍無 `project.md`（關卡 6 需要該狀態）。

## 關卡 3(a)（第一次嘗試，使用者手動）— 測到的是「空 id 壞列」，不是「0 pack」

**使用者動作**：依 checklist 第 2 步「刪掉 `- security/vue-xss` 這一行」，實際在 app-a 把表格的 **id 欄清空**（留下 `| `` | 已驗證 | 防禦性啟用… |`），compile 詢問時選「保持現狀」。

**agent 回覆的行為**（逐項查證，非採信）：落點 app-a ✓；中止 compile 並報「id 是空字串、不在 registry 的 4 個 id 內」✓；`resolved.md` 未重譯（mtime 13:25、檔頭仍「第 3 次重譯」）✓；`project.md` 未動 ✓；`git status` 僅 `?? .opencode/` ✓；registry 確為那 4 個 id ✓。**結論：agent 的事實與判斷都正確**——空字串既不是 `無` 也不是合法 id，拒絕猜測、徵詢使用者、不擅自改檔，完全符合三態紀律（這是正面案例，應保留）。

**但這一測沒測到規格要的東西**，原因兩個都是我的：

| # | 缺陷 | 根因 | 已落地修法 |
|---|---|---|---|
| F | checklist 寫「刪掉 `- security/vue-xss` 這一行」，那是**舊的 bullet 寫法**；app-a 的啟用規則是**表格**，照字面刪會留下「空 id 壞列」，走不到 D18 那條路 | 我寫清單時沒對照實際 profile 的資料形狀 | checklist 改為「刪掉**整個資料列**」，並新增 2b（可選）專門驗「空 id → 錯誤＋恢復指令」這條 |
| G | **規格從未定義「0 個 pack 是合法狀態」**。照現行 §11，任何沒有適用 pack 的專案會永遠 compile 不過；更嚴重的是 **D18 的二次確認路徑永遠觸發不到**（compile 在更早的 id 驗證就掛掉） | 我把「0 pack」與「壞列」混為同一類錯誤 | 主檔 §11 新增「0 個 pack」列（合法：照樣產出 `resolved.md`，啟用清單／checksum／covers 寫 `（無）`、警告「只剩主體檢查」、並觸發 D18）；§6.3 補「零個 pack 的產物」；`setup.md` §4 compile 與 §5 inspect 都改成**區分三態**（0 列＝合法、空 id＝錯誤＋恢復指令、不存在 id＝錯誤＋列可用 id） |

**app-a 的現況**（不擅自修）：`## 啟用規則` 仍是空 id 壞列；`resolved.md` 仍是舊產物。下一步由使用者二選一：**整列刪除**（走 0 pack 路徑，才是 3(a) 原意）或**補回 `security/vue-xss`**，然後跑 `init compile`。已寫進 checklist 的「app-a 當前狀態」註記。

## 關卡 3 第 4 步（使用者恢復 id 後重譯）— 通過，但抓到一次假陽性與一次格式偏差

使用者把 id 補回 `security/vue-xss` 並跑 `/frontend-devkit/init compile`（回報「第 4 次重譯」）。我逐項查證：

| 它說的 | 實測 | 判定 |
|---|---|---|
| 第 4 次重譯、只寫 `resolved.md` | `resolved.md` mtime 13:46:50（晚於使用者修 id 的 13:46:20）；`project.md` 停在 13:46:20、`opencode.json` 停在 13:24；`git status` 僅 `?? .opencode/` | ✅ |
| checksum `DBEFB238`／`9E09C3AA`、模式 B、OpenCode v2.2.7、kit 版本「無法取得（專案區安裝）」 | 檔頭逐字一致 | ✅ |
| security/* 存在 → 不需二次確認 | 啟用清單 1 個 pack 且為 `security/vue-xss` | ✅ |
| TBD 只有 3 項 | `project.md` 的 TBD **欄位值**正好 3 處（L27 `預設審核範圍`、L65 `寫法慣例`、L66 `禁止選項`）；其餘 TBD 字樣是範本的規則說明 | ✅ 清單完整 |
| **「範本第 48 行仍把『省略』列為合法值，建議由 kit 維護者修」** | **不成立**：第 48 行已是「只能列四種實際範圍語法…」；全檔「省略」只剩 L30「省略**範圍的審核**無法定義」與 L31 的**禁用清單**，皆為正常語意 | ❌ **假陽性** |
| `產生時間` 欄寫入「因 id 空值中止兩次…恢復後重譯」 | 檔頭確實如此 | ⚠️ **格式偏差**（破壞「每欄一行模板」的規範化） |

### 對策（已落地）

1. `setup.md` 新增 **§8 回報紀律（查證先於斷言）**：任何檔案缺陷必須附「路徑＋行號＋該行原文逐字引用」，且引用須來自剛才 `read` 的實際輸出；看不到原文就降級為「疑問」；「未變動」的斷言也必須先比對 mtime／`git status`。並明定「**沒有貼出原文的缺陷指控，視同幻覺**」、主動撤回不扣分。
2. `setup.md` §4#8 與主檔 §6.3：`產生時間` 只能寫「ISO 時間＋compile 序號」，中止／恢復歷史一律記在 `project.md` 的 `## 安裝紀錄`。

這兩點都是「報告品質」而非 compile 判定邏輯，修完不影響已通過的關卡 3 步驟。

## 關卡 3 第 3 步（改 pack 一個字、不重譯 → `inspect`）— **通過**，並暴露我上一節的誤判與一個安裝缺陷

使用者把 `rules/security/vue-xss.md` 的 title 刪掉一個「專」字（`Vue 專案` → `Vue 案`）、不重譯，跑 `/frontend-devkit/inspect`。逐項查證：

| inspect 的指控 | 實測 | 判定 |
|---|---|---|
| 源頭 checksum 已變、`resolved.md` 是舊的 | 源頭 `BDFFE20B…`；`resolved.md` 記錄 `DBEFB238` | ✅ **正是本步要抓的漂移** |
| title 差一個「專」字 | 源頭 L3 `Vue 案的 XSS…`；`resolved.md` L167 `Vue 專案的 XSS…` | ✅ |
| `worktree.procedures.md` checksum 相符 | 實測 `9E09C3AA` | ✅ |
| 逐行比對：除 title 外正文全同、程序段除佔位符外無差異 | 行數 38／resolved L165–202 對得上；未見其他差異 | ✅ 可信 |
| 巢狀重複 `rules/rules/`、`profile/profile/`，且巢狀 `vue-xss` 是舊版 `DBEFB238` | 兩組都存在；巢狀檔實測確為 `DBEFB238` | ✅ **真缺陷（H）** |
| 主動更正上一輪「正文未變動」的說法 | 合理：上一輪 compile 只改檔頭，之後源頭被改，漂移留在產物裡 | ✅ 誠實 |
| 「範本第 48 行仍把『省略』列為合法值」 | **主路徑** L48 已是新文；**巢狀那份** `profile/profile/project.template.md` L48 才是舊文 | ⚠️ 內容屬實、**路徑標錯** |

### 缺陷 H：巢狀安裝（我的腳本造成）

`Copy-Item <來源目錄> <已存在的同名目錄> -Recurse` 在 PowerShell 會把來源放**進**目標，於是第二、三次同步產生了 `rules/rules/`、`profile/profile/`。巢狀副本是舊版，**比雜亂更危險的是**：若哪天被當成源頭折入，`resolved.md` 的 checksum 會「對得上」，源頭比對形同失效（它這次就明確指出了這個風險）。

已落地修法：
1. 清掉 app-a／app-b 的 `rules/rules/`、`profile/profile/`（查證：巢狀皆 False、`rules` 檔數恢復為 5、範本 L48 已是新文）。
2. 重同步改用「**先刪目標子目錄、再整包複製**」，並在 `setup.md` §5 新增 7b：`inspect` 必須檢查 `kitRoot` 內的巢狀重複、列出完整路徑並要求使用者刪除（agent 不可自行刪，那不在它的可寫範圍）。
3. 主檔 §4.2.1 安裝紀律第 5 條：明文禁止「複製目錄到既有目錄」的寫法。

### 我更正自己的誤判（重要）

上一節把「範本第 48 行仍寫『省略』」判為**假陽性／幻覺**——**這個判定太重且不完整**：那份舊文確實存在，只是在巢狀副本裡，它把路徑寫成主路徑。所以它是「引用不精確」，不是憑空編造；而我當時只查主路徑就結案，等於**只驗了對自己有利的一半**。正式更正該節結論：**改判為「內容屬實、路徑錯誤」，並將『引用必須附完整路徑（含是否位於巢狀目錄）＋原文』補進 `setup.md` §8 回報紀律。** 我沒有在 §8 明文加這句的，現在補上。

## 關卡 3 第 4 步（compile 修漂移）— 通過，但 agent 的「後續建議」是 stale（反向案例）

使用者先把手改的 pack 還原（title 恢復含「專」字），再跑 `/frontend-devkit/init compile`（回報「第 5 次重譯」）。逐項查證：

| 它說的 | 實測 | 判定 |
|---|---|---|
| 源頭 hash `DBEFB238`、title 含「專」字 | 相符 | ✅ |
| `resolved.md` 記錄與正文 title 一致 | L8／L167 皆 `DBEFB238`／「Vue 專案」 | ✅ |
| `產生時間` 無敘事、只留日期＋序號 | `2026-11-12（compile 第 5 次重譯）` | ✅ |
| 只動 `resolved.md` 與 `project.md` 的安裝紀錄一列 | mtime 14:03:28／14:03:46；`git status` 僅 `?? .opencode/` | ✅ |
| 安裝紀錄首列更新為第 5 次 | L136 相符 | ✅ |
| **「巢狀 `rules/rules`、`profile/profile` 仍存在，且與 canonical 同 hash」** | 實測兩者皆 **False**（上一輪已清） | ❌ **stale** |
| **「建議修 `profile/project.template.md:48` 的『省略』措辭」** | L48 已是新文，舊措辭命中 False | ❌ **stale** |

### 這是「反向」的報告紀律問題

上一輪它把**已修好**的東西說成有問題（路徑標錯），這一輪它把**已清掉**的殘留說成還在。共同根因：**把上一輪的結論當成本輪現況**。修法（已落地）：

1. `setup.md` §8 新增第 5 點：任何「建議仍要處理」的項目，回報前必須**重新驗證**（存在性、`Get-FileHash`、行號原文），並標「本輪重驗」；沒重驗就標「未重驗（沿用上輪）」，**不得**寫成「仍存在／仍未修」。
2. `產生時間` 規則與實作對齊：允許「日期」或「ISO 時間」＋compile 序號（`setup.md` 與主檔 §6.3 同步改寫，避免規格與行為再互相矛盾——這是缺陷 E 的同型風險）。

## 關卡 3(a)（0 個 pack）— 通過，但測到「未定義形態」（缺陷 I）

使用者把 `## 啟用規則` 的**整張表（含表頭）**刪掉後跑 `/frontend-devkit/init compile`（回報「第 6 次重譯、啟用 0 個 pack」）。逐項查證：

| 它說的 | 實測 | 判定 |
|---|---|---|
| 仍產出 `resolved.md`、不是錯誤 | 檔頭：啟用清單 `（無）`、checksum `（無 pack）`＋程序檔 `9E09C3AA`、covers `（無）` | ✅ 正是缺陷 G 修法要的行為 |
| 警告欄寫出「只剩主體檢查」與二次確認 | L14 完整寫出，並說明 reviewer 會拒審、要 `## 專案覆寫` 明示或走 review-fix | ✅ |
| pack 正文換成「（無）」並說明主體第 0 點仍生效 | L163–165 相符；`DBEFB238` 已不在檔內；行數 202→165 | ✅ |
| 只動 `resolved.md` 與安裝紀錄 | mtime 14:09:34／14:09:41；`git status` 僅 `?? .opencode/`；`## 專案覆寫` 仍 `無/無/無` | ✅ |
| 自行指出「整節空白與有意刪除難分」並詢問是否誤刪 | — | ✅ 這正是缺陷 I 的觸發點 |

### 缺陷 I：規格只定義「保留表頭的 0 列」，沒定義「整節空白」

實際狀態是**連表頭都沒有**（`## 啟用規則` 只剩引言＋空行），而「與誤刪難分」。agent 這次按「有意＝0 pack」處理算合理，但換一個 agent 可能報錯、也可能把它當成未初始化——同一份檔案有兩種合法解讀就是規格漏洞。

已落地修法：
1. 主檔 §11：明定 0 pack 的**標準形**（保留表頭與分隔列、無資料列；或表頭下單列 `（無）`），並新增一列「整節空白＝未定義形態」。
2. `setup.md` §4：整節空白 → **補回表頭**（純格式、不塞 id）並明說「補了格式、未改你的啟用決定」；補寫失敗就停止要求手動補。**不得靜默當成 0 pack**。
3. `setup.md` §5：`inspect` 的狀態判定由三態改為**四態**（0 列／整節空白／空 id／不存在 id）。

> 尚未驗的兩步（屬 3(a) 的行為面）：`/frontend-devkit/dev` 是否跳 D18 二次確認、`/frontend-devkit/review --working` 是否**不開始審核**並輸出固定句。等使用者跑完再記錄，不先宣稱通過。

## 關卡 3(a) 行為面（使用者跑 dev 再 review）— reviewer 正確；dev 也正確，破口是「授權傳遞」

> 標題與初判已更正：使用者貼回問卷後確認 **dev 有問 D18、使用者選「同意」**，「疑似繞過」不成立。真正的缺陷是 orchestrator 與 reviewer 的 gate 沒有共用狀態（見下）。

使用者先跑 `/frontend-devkit/dev 加一個 hello 按鈕`（在專案目錄開發出功能），再跑 `/frontend-devkit/review --working`。查證：

| 項目 | 實測 | 判定 |
|---|---|---|
| reviewer：不開始審核、不輸出 VERDICT | 回覆明說不跑 git 讀取／test／build、不建 worktree、不輸出 VERDICT | ✅ 符合 D18 的拒絕路徑 |
| reviewer：正確區分「`resolved.md` 那句是 kit 的警告，不是你的授權」 | `project.md` 的明示字串 0 命中；唯一命中在 `resolved.md` L14 | ✅ 這是 §8 紀律生效的實例 |
| reviewer：`## 專案覆寫` 仍是 `無/無/無` | 相符 | ✅ |
| dev：工作區產出 | `M src/App.vue`（+39）、`?? src/composables/useHelloToggle.js`、`?? test/app-hello.test.js`、`?? .opencode/` | 功能確實做了；且有補測試與 aria 屬性 |
| dev：設定檔未被動 | `project.md`／`resolved.md` mtime 皆停在 14:09（早於 dev 的 14:21／14:29） | ✅ |
| dev：無 worktree 殘留 | `.worktrees` 不存在、`git worktree list` 只有主工作區 | ✅ 且問卷第二題確實問了「要在哪裡進行」，使用者選「直接在主工作區」 |
| **dev：D18 未滿足卻仍進入開發** | 問卷確實問了 D18 且使用者選「同意，僅跑主體基本安全項」 | ✅ **不是繞過**（我上一輪的 A／B 推測兩者皆錯）；真缺陷在「授權無法傳遞給 reviewer」 |

### J 的真正結論：dev 沒錯，破口在「授權的傳遞」

使用者貼回的問卷有兩題：D18（選「同意，僅跑主體基本安全項」）＋ worktree（選「直接在主工作區進行」）。所以：

- 不是（A）混合選項——它問的選項是「同意」本身；
- 也不是（B）沒問——它問了，而且選項文字把後果（不含專案專屬清理器／白名單檢查）寫出來了；
- 依當時的規格（orchestrator 以 `question` 取得明確同意即可進入流程），**它照規則做，且做對了**。

真正的破口是我上一輪剛補的規則自己製造的：orchestrator 的 `edit` 是 **deny**（實測 frontmatter 第 5 行 `{ action: "edit", resource: "*", effect: "deny" }`），它**不能**寫 `project.md`。於是「問卷同意」只存在於對話裡，reviewer（`question: deny`、只認檔案）看不到 → **dev 放行、review 拒審，兩邊都照規則做卻互相矛盾**。而我新加的「派工前必須看到 `securityOverride` 列」會讓「你已同意」的情境**永遠卡死**——這是缺陷 E／F 的同型（規格自我矛盾）。

已改寫為一致的設計（三處同步）：

1. 派工 gate 改為「**滿足任一**即可」：(a) `## 專案覆寫` 有 `securityOverride` 列且理由非空；或 (b) **本次呼叫**的 D18 `question` 已選①同意。**跨呼叫一律重問**，不得沿用上一次的同意。
2. orchestrator 選①的那一回合**必須立即印出**要貼的那一列，並明說「`/review` 前要貼，否則 reviewer 會拒審」——因為它自己不能代寫。
3. reviewer 的 gate 不變（只認檔案那一列），維持 fail-safe。

> 問卷本身還有一個小缺口：只有兩個選項，缺「我去補設定／取消」這條路。三選項規則已寫進 orchestrator，下一輪會驗。

## 關卡 4（worktree＋dev／review 迴圈）— **通過**，並測出 M、N、O 三個缺陷

完整迴圈都跑到了：`worktreePolicy=ask` → 建 `feature-dark-mode-toggle` → junction（`LinkType=Junction`）→ dev 第 1 輪 → reviewer 回 8 個 ISSUES＋3 條裁決 → dev 第 2 輪逐項修正 → review 第 2 輪 `VERDICT: PASS`（5 條建議、0 阻擋）→ 使用者審 commit 訊息 → orchestrator commit `938bc49`（developer 的 `git commit` 是 deny，所以只能由 orchestrator 做）→ fast-forward 併回 `main` → 清 worktree。

### 我獨立複驗的（不採信自述）

| 宣稱 | 實測 |
|---|---|
| 基準測試未動 | `git diff ed9221e..938bc49 -- test/baseline.test.js` 為空 ✅ |
| `style.css` 只新增 | `53 新增 / 0 刪除` ✅ |
| 無 phantom dependency | 只剩 `from 'vue/server-renderer'`；`vue` 自身相依 `@vue/server-renderer@3.5.45` ✅ |
| `toggleLabel` 已移除 | `git grep` 0 命中 ✅ |
| 特異性 (1,2,0) > (1,1,0) | 算得對 ✅ |
| 「watchEffect 沒跑斷言必失敗」 | 成立：`documentStub.dataset` 只有那一個寫入者，`toBe('light')` 能過就證明寫入真的發生 ✅ |
| 7 tests／build／CSS 5.41 kB／JS 67.11 kB | 我自己跑，數字完全一致 ✅ |
| 清 worktree 沒傷到主工作區 | `.worktrees` 空、`worktree list` 只剩主工作區、`node_modules` 40 項且 vue／vitest 都在（＝有先 `rmdir`）✅ |
| 合併後主線健康 | `7 passed`、`build` 成功 ✅ |

審核品質是這輪最高的：reviewer **自己**跑了 `--sequence.shuffle`（developer 沒做）、讀 `dist` 的 CSS 輸出順序驗四種組合、`git check-ignore` 驗 `dist`、`--ignore-cr-at-eol` 驗換行；「疑問」段還主動承認**無法機械驗證** developer 的「動手前 7 tests」，沒有因此放水。

### 缺陷 M：`VERDICT` 不可追溯（審核目標沒有 sha／指紋）

review 是在 commit **之前**對工作目錄跑的（依 §9 不建審核 worktree，合理），但輸出只寫「未 commit 改動」。commit 之後就沒有任何機械方法證明「被審內容＝commit 內容」——這次是我用 `+258/−1`、`App.vue +61/−1`、`style.css +53`、`test 105`、`composable 40` 逐項對上才敢說沒漂移，**屬僥倖**。

修法：`目標：` 必須含型態＋基準 sha＋範圍；審未 commit 變更時加記 `git diff <基準> | git hash-object --stdin` 指紋（已寫進 `reviewer.md` §1／§6 與主檔 §10.4）。

### 缺陷 N：行號與數量「憑印象」

| 誰 | 錯什麼 |
|---|---|
| developer | `useDarkMode.js:15-20`（實為 18-20）、`:33`（實為 30）——都偏 3 行；「本檔 7 個測試」實為 **6**（7 是含 baseline 的總數） |
| reviewer | `.app-shell` 的 `min-height` 引為 `App.vue:48`（實為 `:39`，48 是 `padding`） |

兩者的**實質判斷都正確**，只有引用不精確；但 reviewer 的行號正是下一輪 developer 的施工依據，錯一處就多一輪。修法：`setup.md` §8 那條「行號必須來自本次 `read`」目前只管 setup → 已同步加進 `developer.md` §10 與 `reviewer.md` §1／§6。

> 順帶：這是「引用不精確」第三次出現（前兩次是關卡 3 的路徑標錯與反向 stale）。共同根因都是**用記憶代替重讀**，不是說謊。

### 缺陷 O：`.env` 沒被 `.gitignore` 忽略

`git check-ignore -v .env` 退出碼 **1**（app-a 的 `.gitignore` 沒有任何 `.env` 規則）。本例 `<ENV_FILES>`＝無，所以還沒有東西會被複製，**目前無風險**；但 profile 一旦列了環境檔，`compile` 之後它就會進 worktree 並處於「可被 commit」的狀態。修法：`setup.md` §4 新增 2b、主檔 §9 第 4 條補述——`compile`／`inspect` 要對每個環境檔驗 `git check-ignore`，未忽略就醒目警告（kit 不改專案 `.gitignore`）。

### 未阻擋但值得記的 5 條 reviewer 建議

`:root` transition 缺 `prefers-reduced-motion` 保護、只有底色／文字過渡（框線與 `--social-bg` 仍瞬切）、`min-height: 100svh` 在 `App.vue:39` 與 `style.css:218` 重複、`@click` 的真 DOM 綁定無自動化覆蓋（需新增 jsdom／test-utils）、`useDarkMode` 非單例（目前僅一處呼叫）。全部屬建議級，已在 app-a 留下紀錄。

