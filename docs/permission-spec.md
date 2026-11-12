# 權限規格（主檔 §7.3 的外移附檔）

> 本檔是實作 frontmatter 與 `setup` 檢查器的唯一權威來源。原 §16 已併入主檔 §2；審核史見 `CHANGELOG.md`。

> **本檔是 `specs/2026-11-11-frontend-devkit-design.md`（主檔）的附檔。**
> 章節編號沿用主檔original編號以維持引用穩定；文中 `§X` 若帶檔名前綴（如 `acceptance.md §13`）指附檔，**未帶前綴的 `§X` 一律指主檔**。
> 主檔頂端的「0. 檔案地圖」是全套檔案的入口。

> **本檔是 `specs/2026-11-11-frontend-devkit-design.md`（主檔）的附檔。**
> 章節編號沿用主檔original編號以維持引用穩定；文中 `§X` 若帶檔名前綴（如 `acceptance.md §13`）指附檔，**未帶前綴的 `§X` 一律指主檔**。
> 主檔頂端的「0. 檔案地圖」是全套檔案的入口。
### 7.3 權限規格（本 kit 最需要小心的部分）

#### 7.3.0 術語定義：方案 A / 方案 B（G12 補，之前全檔引用卻從未定義）

| | ~~**方案 A（原預設）**~~：**在本次測到的形態下不通過**（`docs/experiments.md` 第 3 題；專案端形態待覆驗，見 permission-spec.md §7.3.0 復活條件的先決步驟） | **方案 B：現在的預設** |
|---|---|---|
| shell 規則放哪 | 主體 frontmatter 放「地板＋通用唯讀指令」；專案端 `agents.<id>.permissions` 追加該專案特有的窄域 allow | **全部 shell 規則靜態寫進主體 frontmatter**，專案端完全不寫 shell 規則 |
| 白名單精準度 | （高，但**做不到的話是零**：實測顯示專案端 allow 不會生效） | 中（主體要容納各家管理器的 gate 變體，逐條列在 permission-spec.md §7.3.0.1） |
| 是否依賴未記載的跨來源次序 | 實測結論：agent `.md` 的規則**排在設定檔之後**，地板 deny 蓋掉專案端 allow → 方案 A 的 allow 機制在**本次測到的形態**（全域 `.md` agent × 全域 `opencode.json`）無效：地板 deny 蓋掉 jsonc allow。**專案端 config × 專案／全域 agent 的形態未驗**，且 `experiments.md` 二.2 的「找不到專案本地 agent」高度可能是我的服務綁定操作問題 | 完全不涉及 |
| 何時改用 | **復活條件**（先決步驟：先排除服務綁定因素）**：① 於目標專案啟 session，第一條先跑 `Get-Location` 確認服務真的綁在該專案；② 確認該專案 `.opencode/agents/` 的 agent 出現在可選清單；③ 才測「專案端 `opencode.json` 追加 allow」是否生效。**三步驟任一失敗先修操作、不下平台結論**；只有在綁定正確而 allow 仍失效時，方案 A 才判定停用 | 預設 |
| 代價 | 每次 init 要逐條批准 allow | 主體白名單變寬、升級時要跟著各專案指令改；profile 的 `## 指令` 與真實權限可能不一致（需 `inspect` 檢查） |

#### 7.3.0.1 方案 B 的具體規格（第 4 輪阻擋項 #2：原本只有取捨表，無法獨立實施）

方案 B 不是「把 allow 寫寬一點」，而是一套**可直接落地的主體白名單**＋一組**必要的配套**，缺任一條就不能啟用：

1. **主體 reviewer frontmatter 的 gate allow** 要包含（逐條、非通配）：`npm test *`、`npm run test *`、`npm run lint *`、`npm run build *`、`npx vitest run *`、`npx jest *`、`npx ava *`、`npx eslint *`、`pnpm test *`、`pnpm run test *`、`pnpm run lint *`、`pnpm run build *`、`yarn test *`、`yarn lint *`、`yarn build *`、`bun test *`。**仍不准** `npm run *`／`pnpm run *` 這種「一條涵蓋所有 script」的通配（permission-spec.md §7.3.5#4 的紅線在方案 B 一樣有效）。
2. **profile 的 `## 指令` 若含上述沒蓋到的自訂 script**（例 `npm run test:e2e`、`pnpm --filter web test`）→ 方案 B **無法執行該 gate**：主體是靜態 frontmatter，讀不到 profile 內容。因此方案 B 必須搭配一條明文行為：`setup` 在 compile 時把「profile gate 中**不在靜態清單**者」列為 `需人工執行`，reviewer 對該 gate 回報「因方案 B 白名單未含此指令，未獨立執行」，**不得**假稱跑過，也不得靠 `ask` 彈窗繞過（reviewer 起頭是 deny）。這正是方案 B 的代價，要在啟用前用 `question` 跟你說清楚。
3. **orchestrator／developer 在方案 B 下同樣改用靜態清單**（developer 是 ask 起頭，影響較小）。
4. 啟用方案 B 的專案，`resolved.md` 檔頭要記「權限模式：B」，`inspect` 與 acceptance.md §13 關卡 2 的判讀基準都要依此切換（否則 probe 判別力那套會誤判）。

#### 7.3.1 官方事實（本機 v2.2.7，文件頁 `/docs/permissions/`）

1. 每個 agent（**含自訂 agent**）的起點基底是 `{action:"*", resource:"*", effect:"allow"}`，只有 `read *.env`／`read *.env.*` 是 ask、`read *.env.example` allow。**沒有白名單並不等於受限，等於全開。**
2. 規則格式是 `{action, resource, effect}` 三個字串欄；`action` 用 V2 名稱：`shell`（不是 `bash`）、`subagent`（不是 `task`）、`edit`、`read`、`glob`、`grep`、`skill`、`question`、`webfetch`、`external_directory`。
3. **匹配是 whole-value wildcard：`*` 零個以上字元（含 `/`）、`?` 恰一字元、其他為字面。沒有 `|`、也沒有 regex。** 反斜線會正規化為斜線，Windows 上比對不分大小寫。
4. **最後符合者勝**；官方文件給的範例就是把特定 exceptions 接在寬規則之後。尾綴 ` *`（含空白）的 shell pattern **也會匹配無參數形式**（`"git status *"` 同時匹配 `git status` 與 `git status --short`）。
5. 組合順序：lower-priority config 先載入 → global rules 附加 → **agent rules 最後附加**；同一操作可能檢查多個 resource，**任一 deny 即 deny**，否則任一 ask 即 ask。
6. shell 走內建 scanner（支援 PowerShell）：複合指令與 `cd` 目標會被拆成多個 subcommand 資源逐一比對；**語法异常或動態求值（例 `node -e`）無法安全分析時直接 scanner error，不執行**。
7. `ask` 被客戶端選「Allow always」會存成**專案級的持久 allow**，但**永遠蓋不掉設定好的 deny**。
8. `external_directory` 預設 allow（專案外的絕對路徑讀寫不詢問），但使用者可加 `{"action":"external_directory","resource":"*","effect":"ask"}` 把它改成詢問——所以「agent 去 `~/.config/...` 讀 kit 素材」不能當設計前提（D15 的由來）。

#### 7.3.2 語法紀律（實作必守，違反就是死規則）

| 紀律 | 錯例（會一條都匹配不到或過寬） | 正確寫法 |
|---|---|---|
| 不用 `\|`、不用 regex | `{"resource":"git commit\|push"}` | 拆成兩條：`"git commit *"`、`"git push *"` |
| 一律用 `"cmd sub *"` 形，不用 `"cmd sub*"` | `"npm test*"` 會連 `npm testfoo`、`npm testing` 一起放行 | `"npm test *"`（匹配 `npm test` 與 `npm test --watch`） |
| 危險指令走**尾巴三段式**（見 §7.1 定義） | 把 `deny "npm ci *"` 寫在 allow 之前、或把 frozen allow 寫在可變 deny 之前 | 真地板群 → 可變依賴 deny 群 → **不可變例外 allow 群（最尾）**；只有第 1 段是「任何 allow 蓋不掉」的絕對地板 |
| 複合指令也要能擋 | `git status && npm ci` 只比整串 → 漏網 | 依賴 scanner 拆句（事實 6）；主體另外禁止用 `&&`／`;` 串接白名單外指令（提示詞紀律，現行 reviewer 已有） |
| 不靠 `node -e` 之類的動態求值做事 | `setup` 用 `node -e "…"` 算 checksum | 用 `Get-FileHash *` allow；`node -e` 一律列入「需實測、不採用」 |
| 要**最嚴**時可用無尾綴的精確形 | `git fetch *` 放行任何 refspec | `git fetch`（精確形、禁一切參數）是**比 ` *` 更嚴的合法選項**，用於 `git worktree list`、`git branch --show-current`、`git fetch` 這類「不該有參數也合理」的指令（第 3 輪 S4） |
| **字面同形鐵律**（第 5 輪補：先前只在 §9.3 出現，本表卻被引用為出處） | 程序檔寫 `Resolve-Path node_modules`、allow 寫 `Resolve-Path -Path node_modules` → 實測**互不匹配**（第 5 題：scanner 用原始字串逐字比對、不重組參數） | allow 的 resource 必須與「agent 實際要打出的字串」**逐字相同**；`X`、`X Y`、`X -Path Y` 視為三條不同規則。程序檔與 frontmatter 白名單要成對審（§9.3、acceptance.md §13 關卡 4） |
| **`$` 變數成員存取與括號子運算式屬高危形，程序檔不要這樣寫**（第 5 輪補引用） | 實測 `Write-Output $PSVersionTable.PSVersion.ToString()` 與 `Write-Output (Resolve-Path .).Path` 都 DENIED，即使 `Write-Output *` 已在白名單 | 程序檔一律用「無 `$`、無括號」的形式，需要中間值就走兩步（先取值、再把**已驗證的字面值**代入下一條，§9.3）。第 8 題只記錄到 DENIED、**未存錯誤訊息**，「無法安全分析／次指令」屬推定，關卡 4 要存 raw 輸出覆核 |

#### 7.3.3 主體自給自足的規則鏈（D13）

每個 agent 的 frontmatter 內都要是**完整可用的一條鏈**（地板 → 放行 → 尾巴三段式），不看任何別的來源也不會變危險。**格式注意（第 3 輪指出）**：agent 檔是 YAML frontmatter，行尾註解只能用 `#`，**不能用 `//`**（照抄會解析失敗）；下面範例用 YAML 清單而非 jsonc：

```yaml
# kit/agents/frontend-devkit/reviewer.md 的 frontmatter（節錄，完整清單見 §7.1）
permissions:
  # ── 地板（各 action）
  - { action: "shell",    resource: "*",                      effect: "deny" }
  - { action: "edit",     resource: "*",                      effect: "deny" }
  - { action: "subagent", resource: "*",                      effect: "deny" }
  - { action: "skill",    resource: "*",                      effect: "deny" }
  - { action: "webfetch", resource: "*",                      effect: "deny" }
  - { action: "question", resource: "*",                      effect: "deny" }
  # ── 放行（唯讀與 worktree 就緒；具名到工作目錄前綴，不給無限延伸）
  - { action: "shell",    resource: "git diff *",             effect: "allow" }
  - { action: "shell",    resource: "git status *",           effect: "allow" }
  - { action: "shell",    resource: "git fetch",              effect: "allow" }
  - { action: "shell",    resource: "git worktree add --detach .worktrees/review-*", effect: "allow" }
  - { action: "shell",    resource: "git worktree remove --force .worktrees/review-*", effect: "allow" }
  - { action: "shell",    resource: "cmd /c rmdir .worktrees/*", effect: "allow" }
  - { action: "shell",    resource: "Copy-Item * .worktrees/review-*", effect: "allow" }
  - { action: "shell",    resource: "New-Item -ItemType Junction -Path .worktrees/review-*", effect: "allow" }
  # （不給 reviewer Get-FileHash：checksum 驗算屬 setup／compile，§6.3）
  # ── 尾巴三段式
  - { action: "shell",    resource: "git push *",             effect: "deny" }   # 第 1 段：絕對地板
  - { action: "shell",    resource: "git checkout *",         effect: "deny" }
  - { action: "shell",    resource: "git worktree prune *",   effect: "deny" }
  - { action: "shell",    resource: "npm install *",          effect: "deny" }   # 第 2 段：可變依賴
  - { action: "shell",    resource: "pnpm install *",         effect: "deny" }
  - { action: "shell",    resource: "npm ci *",               effect: "allow" }  # 第 3 段：不可變例外（必須在最後）
  - { action: "shell",    resource: "pnpm install --frozen-lockfile *", effect: "allow" }
```

> 範例同時示範三件事：① `Get-FileHash` 不在 reviewer 白名單（S5：第 2 輪只改了表格沒改範例，故此處明確移除並留註解）；② 寫入／刪除通道要**具名到 worktree 前綴**（`cmd /c rmdir .worktrees/*`、`Copy-Item * .worktrees/review-*`），不能用 `Copy-Item *`／`cmd /c rmdir *` 這種任意路徑形——否則「唯讀、唯一例外」的自述會被自己發的權限推翻（第 3 輪一般項）；③ 第 3 段必須坐在第 2 段之後，否則 frozen install 會被翻回 deny。

developer 的尾巴群（逐條展開、**不含 pipe**；依 §7.1 三段式排列）。**注意 developer 的第 3 段是空的**：它不需要裝依賴（依賴操作一律由協調者處理，§9.8），所以連不可變的 `npm ci` 也 deny——這不是矛盾，是刻意比 orchestrator 更緊：

- **第 1 段（絕對地板，deny）**：`git commit *`、`git push *`、`git merge *`、`git rebase *`、`git reset *`、`git checkout *`、`git switch *`、`git restore *`、`git worktree *`、`git clean *`、`git stash *`、`git branch -D *`、`git tag *`、`git apply *`、`git am *`。
- **第 2 段（可變與安裝類，deny；developer 無第 3 段例外，故含不可變）**：`npm install *`、`npm i *`、`npm ci *`、`npm add *`、`npm rm *`、`npm remove *`、`npm uninstall *`、`npm update *`、`npm upgrade *`、`npm link *`、`npm unlink *`、`npm patch *`、`npm rebuild *`、`npm prune *`、`npm dedupe *`、`npm audit fix *`、`npm exec *`、`pnpm add *`、`pnpm i *`、`pnpm install *`、`pnpm ci *`、`pnpm rm *`、`pnpm remove *`、`pnpm uninstall *`、`pnpm update *`、`pnpm up *`、`pnpm link *`、`pnpm patch *`、`pnpm prune *`、`pnpm rebuild *`、`pnpm dlx *`、`pnpm exec *`、`yarn add *`、`yarn install *`、`yarn remove *`、`yarn upgrade *`、`yarn link *`、`yarn patch *`、`yarn dlx *`、`bun add *`、`bun install *`、`bun remove *`、`bun update *`、`bun link *`、`bun patch *`、`npx pnpm *`、`npx yarn *`、`npx bun *`、`corepack *`。

> **承認遮不住全部**（新增 R9）：前綴式白名單／黑名單無法窮盡繞道（例：`npx --package pnpm pn add x`、自訂 npm alias、`node scripts/install.js`）。所以 kit 的最終關卡不是 shell 規則，而是**既有兩道紀律**：developer 必須醒目標報「是否改動 `package.json`」、reviewer 必須用 `git diff` 檢查 `package.json`／lockfile 是否被動。主體提示詞要把這句寫明：「shell 規則只是護欄，不是保險」。

#### 7.3.4 跨來源紀律（**方案 A 的保留條款**）\n\n> **現況標記（第 5 輪）**：xperiments.md 第 3 題實測後，**方案 B 是現行預設**，本節第 1–6 點只有在「方案 A 依 permission-spec.md §7.3.0 先決步驟覆驗成功」後才會啟用；**第 7 點（設定檔與 .git/ 只准 setup 寫）是兩案通用的現行紀律**。另加一條 B 紀律：**專案端設定只准出現 instructions 與 model**，inspect 若偵測到 gents.<id>.permissions 含 shell 條目即警告（依實測它不會生效，留著只會誤導人以為已授權）。

1. **同一 `action` 的「地板」只能由主體 frontmatter 定義**。專案端 `opencode.json` 的 `agents.<id>.permissions` **僅准許**追加：更窄的 `allow`（該專案特有的 gate 指令，如 `pnpm --filter web test *`）或更嚴的 `deny`。不得在專案端追加 `{"resource":"*"}` 等級的規則。
2. **關鍵前提（G3＋第 3 輪修正：比對對象要明确排除地板，否則方案 A 被自己封殺）**：專案端追加的每一條 `allow`，**不得命中主體「尾巴三段式第 1、2 段」的任何 deny pattern**。注意**不含** `resource: "*"` 的那條地板 deny——若把地板也算進比對，任何窄域 allow 都命中 `*`，`setup` 會拒絕寫入**所有**專案端 allow，與本節第 1、4 點和 permission-spec.md §7.3.0 方案 A 直接矛盾。只有滿足這個前提，「兩種次序都不偏鬆」才成立：若次序是「jsonc 先、.md 後」且該 allow 命中第 1／2 段 deny，最後符合者勝就會**翻掉地板**。另需記得 D14 所稱「任何 allow 蓋不掉」的地板**僅指第 1 段**，第 2 段可被第 3 段例外翻回（§7.1）；而官方只保證「持久批准（`allow always` 存下的規則）蓋不掉設定的 deny」，並未保證 jsonc 規則蓋不掉 `.md` 的 deny。
3. 此前提**必須機械檢查，不能只靠提示詞**：`setup` 寫入任何 allow 前，逐條與「主體四個 agent 的 deny resource」做 wildcard 比對，命中即**拒絕寫入**並告知你該指令屬主體禁止範圍；`inspect` 重跑同一比對，把「專案端 allow ∩ 主體 deny 必須為空」列為檢查項（§8）。
4. 有了第 2、3 點，失配模式才真的只剩「偏嚴」一種：次序為「jsonc 先、 .md 後」時，專案端窄 allow 被主體地板 deny 蓋掉 → reviewer 少一條指令而卡住（可用性問題，非安全問題）；次序為「 .md 先、jsonc 後」時窄 allow 生效。**兩種次序的安全邊界一致**，這才叫次序無關。
5. **方案 B 已是現行預設**，所以本節第 1–6 點只在「方案 A 覆驗成功後」才適用（permission-spec.md §7.3.0 先決步驟）。`inspect [probe]` 在 B 下的職責改為**版本迴歸偵測**（§8.2）：第 0 條 `Get-Location` 確認落點、第 1 條測主體靜態清單內的 gate、第 2 條測必被拒的寫入指令。第 1 條被拒 → 清單與實作不同步或落點錯了；第 2 條被准 → **立即停用 kit**（提權漏洞，不是可用性問題），並引用該規則出自哪個檔案、哪個陣列位置。
6. 「例外 allow」（先 deny 家族、再 allow 例外，如 §7.1 的 `--frozen-lockfile` 寫法）**只准許出現在主體自己的陣列**；專案端拿它就違反第 2 點，`setup` 必須拒絕。
7. **設定檔與 `.git/` 的寫入權只屬於 `setup`**：orchestrator（`edit deny *`）、developer（deny `*opencode.json`、`*opencode.jsonc`、`*.opencode/*`、**`*.git/*`**）、reviewer（`edit deny *`）。developer 的 deny 必須排在它自己的 `allow *` 之後（permission-spec.md §7.3.1 事實 4、permission-spec.md §7.3.2），並**已由 `experiments.md` 第 6 題實測**：根相對、根絕對、`.opencode` 相對、worktree 內副本、`opencode.jsonc`、`.git\hooks\` **六種形全數被拒**；acceptance.md §13 關卡 1 由「首次驗證」降為「回歸抽驗」。

#### 7.3.5 專案端 allow 的產生流程（安全關鍵，第 2 條嚴重問題在此修掉）

`setup` **任何要寫進專案端的 shell allow**（不分是偵測得到的 script、還是你在 `## 額外 shell` 人填的條目）都不得照字面直接放行。順序固定：

1. 讀 `package.json` 的 `scripts` **展開成實際命令字串**（例如 `lint: "eslint --ext .js,.vue --fix ."`）。
2. 逐條做**寫入性檢查**：展開後的命令含 `--fix`、`-w`／`--write`、`--output`／`-o`、`--update-snapshots`、`--frozen-lockfile` 之外的 `install`／`i`／`add`／`rm`、**子命令式寫入**（`npm audit fix`、`pnpm prune`、`yarn policies set-version`、`codegen`／`generate` 之類會落地檔案的自訂 script）、`>`／`>>` 重導向、管道到 `Out-File`／`Set-Content`、`git ` 寫入子命令、`npm run` 遞迴到另一個會寫入的 script → 標為 `需人工確認（疑似可寫入）`，**不自動 allow**。**判別基準以 §7.1 尾巴三段式的第 2 段清單為唯一正典**，本節不另立一份清單（第 3 輪指出同一家族在全文重複 6 處、必然不同步）。
3. 對每一條要 allow 的指令，用 `question` 讓你看著展開後的實際命令逐條批准（`auto` 模式下：只 allow 「展開後不含任何寫入性選項」的指令，其餘留 `TBD` 並在結束時逐條列出）。
4. allow 一律採 `"實指令 子命令 *"` 形（permission-spec.md §7.3.2）；`npm run <script> *` 這類「一個 allow 涵蓋所有 script」的寫法**禁止**，要逐 script 展開（`npm run build *`、`npm run test:unit *`），否則 `npm run lint *` 會被附加 `-- --fix` 繞過。專案端追加的每一條還要過 permission-spec.md §7.3.4 第 2、3 點的「不得命中主體尾巴第 1、2 段」比對。
5. 仍需記得：即使指令被 allow，agent 仍可傳 `npm run lint -- --fix` 這種「參數延伸」——所以**主體的「白名單只放行唯讀用法」提示詞紀律（§7.2）是第一道牆**，`profile` 只 allow 具名 script 是第二道牆，`inspect [probe]` 與 reviewer 的 diff 檢查是第三道牆。三道牆都要寫進文件，不宣稱「權限已擋死」。
