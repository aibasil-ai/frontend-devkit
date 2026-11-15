# worktree 程序（Windows PowerShell／macOS POSIX 雙平台）

> **本檔是源頭素材。** 執行期不是由 agent 直接讀本檔：`/frontend-devkit/init compile` 會把下列佔位符按專案 `project.md` 的值代入，並依 profile `shell` **只折入對應的平台段落**（`shell: powershell` → 折入 `## 2. 平台段落 powershell`；`shell: posix` → 折入 `## 3. 平台段落 posix`；二擇一，**不得兩段並列**），再折進該專案 `resolved.md` 的「worktree 程序」段落（主檔 D15）。開發迴圈的四個 agent 只讀 `project.md` ＋ `resolved.md`，不讀 `kitRoot`。
>
> **佔位符**（值一律來自 profile `## 識別`）：
> - `<BR_PREFIX_DEV>`／`<BR_PREFIX_FIX>` 分支前綴（例：`feature/`、`fix/`）
> - `<ENV_FILES>` 環境檔清單（逐檔，例：`.env`）
> - `<DEP_INSTALL>` 不可變依賴安裝指令（例：`npm ci`、`pnpm install --frozen-lockfile`）
>
> **固定值**（不再是佔位符；其他值 `init`／`inspect` 一律拒絕，P11）：
> - worktree 目錄：`.worktrees/`（唯一合法值）
> - 審核 worktree 名稱前綴：`review-`（唯一合法值）
>
> **禁止項**：本檔與 kit 任何素材內**不得出現個人絕對路徑**。主工作區一律執行期以 `git rev-parse --show-toplevel` 取得；需要絕對路徑的場合（Windows junction 的 `-Target`）由該次執行結果代入，不落盤。macOS 的 symlink 目標固定相對路徑 `../../node_modules`（P4），不代入任何路徑。

## 1. 共用規則（兩平台一致）

### 1.1 主工作區與基準

- 主工作區：`git rev-parse --show-toplevel`（在專案根執行）。
- 比較基準：建立 worktree 時的起點 sha（`git rev-parse HEAD` 或指定的起點 commit）。
- 所有 shell 指令一律以工具的 `workdir` 參數指定目錄，**不要用 `cd`**；需要詢問使用者時一律用 `question` 工具。
- `.worktrees/<名稱>` 一律指 worktree 目錄內的該 worktree；目錄固定 `.worktrees/`、審核前綴固定 `review-`（P11）。
- 依 profile `shell` 的平台別，使用對應平台段落的指令（P6）；平台段落不得互相混用。

### 1.2 建立開發 worktree

1. 依任務產生 `<類型>-<slug>`（slug 為英文小寫連字號）與分支 `<BR_PREFIX_DEV 或 BR_PREFIX_FIX><slug>`。
2. 先取起點 sha 記為比較基準。
3. 建立（`<起點>` 可省略，預設目前 HEAD）：

   ```
   git worktree add .worktrees/<名稱> -b <分支> [<起點>]
   ```

4. **同名目錄或分支已存在時不硬蓋**：改用 `question` 請使用者決定（換名稱，或先處理殘留）。
5. 若 `.worktrees/` 未被 `.gitignore` 排除（`git check-ignore -q .worktrees/` 為非 0）→ **先警告再繼續**：`--working` 審核會把 worktree 內容（含下一步複製進去、可能帶密鍵的環境檔）混入未追蹤檔案清單，且容易誤 commit。建議由使用者自行把 `.worktrees/` 加入 `.gitignore`（kit 不擅自改 `.gitignore`）。

### 1.3 依賴處理（profile `depStrategy`）

- `junction`（npm 型、平面 `node_modules` 的專案）：worktree 的 `node_modules` 是**主工作區 `node_modules` 的連結**——Windows 用 junction、macOS 用相對 symlink（目標固定 `../../node_modules`）。建立與驗證指令見平台段落的「建立連結」「驗證連結」；不在 worktree 內重新安裝。
- `install-per-worktree`（pnpm／yarn workspace、`node_modules` 非平面結構的專案）：在該 worktree 內執行 profile 的 `<DEP_INSTALL>`，`workdir` 必須是該 worktree 的**絕對路徑**，timeout 依 profile（建議 600000）。
  - **只准用不可變安裝**（依 lockfile 重建，例如 `npm ci`、`pnpm install --frozen-lockfile`、`yarn install --frozen-lockfile`）。會改 lockfile 的可變安裝（`npm install`、`pnpm add` 等）一律由協調者之外處理，developer 不可執行。
  - 安裝失敗（例如 lockfile 與 `package.json` 不同步）→ **如實回報並用 `question` 請使用者決定**；不得自行改採可變安裝、不得跳過安裝直接進入審核。
- `none`：不建立 worktree（搭配 `worktreePolicy: never`）。審核目標恆為 `--working`；仍在結束時跑一次 `git worktree list` 確認沒有前次殘留。

### 1.4 環境檔複製

依 profile `<ENV_FILES>` 清單逐檔複製進 worktree（指令見平台段落的「複製環境檔」）。

- 這些檔案可能含密鍵：**不得**出現在任何回報、commit 內容或 diff 摘要中。
- 檔名必須是單一檔名（無 `/`、`\`、`:`、`..`、萬用字元）——這是 profile 欄位白名單驗證的一環（主檔 §5.1.2），非法值 `setup` 拒絕寫入、`inspect` 每輪重驗。

### 1.5 審核用 worktree（reviewer 專用，detached）

1. 名稱 `review-<sha7>`，`sha7` 取範圍最新 commit 的短 sha：`git rev-parse --short=7 <commit>`。
2. 先查殘留：用平台段落的「存在性檢查」看目錄是否存在，並用 `git worktree list` 看是否已登記。
   - 目錄存在（上次中斷的殘留）→ **先按第 1.6 節清除，再建立**，不可報錯停擺。
   - 目錄不存在但 `git worktree list` 已登記 → `git worktree add` 會失敗：**如實回報並請使用者處理**。reviewer 沒有 `git worktree prune` 權限，也不得嘗試白名單以外的指令。
3. 建立：

   ```
   git worktree add --detach .worktrees/review-<sha7> <commit>
   ```

4. 依賴：範圍內改動過 `package.json`／lockfile → 依 1.3 的 `install-per-worktree` 在該 worktree 內 `<DEP_INSTALL>`；否則依 `junction` 建立連結（平台段落的「建立連結」）。
5. 複製環境檔（依第 1.4 節）。
6. lint／build／測試都在**這個 worktree 內**執行（`workdir` 指向它）。

### 1.6 清除 worktree（三種 depStrategy 一體適用，不可跳過第一步）

> **警告**：若 `node_modules` 是連結（Windows junction／macOS symlink），直接 `git worktree remove --force` 在 Windows 可能跟隨 junction，**把主工作區 `node_modules` 的內容一併刪除**。第一步不可省略。清除一律「先移除連結、再 `git worktree remove --force`」；**不可**直接 `rm -rf` worktree 的 `node_modules` 或 worktree 目錄。

1. **先在該 worktree 跑 `git status --short`**：有未 commit 殘留先告知使用者（`--force` 會把它們一併丟棄）。
2. **先**只移除連結（對實體目錄或不存在的路徑會失敗，失敗訊息可忽略，因此這一步可無條件執行）：指令見平台段落的「移除連結」。
3. **再**移除 worktree：

   ```
   git worktree remove --force .worktrees/<名稱>
   ```

4. 收尾：`git worktree list` 確認只剩預期工作區。
5. `git worktree prune` 僅在「目錄已不在但 git 仍登記」時由協調者或使用者執行；reviewer 無此權限。

### 1.7 依賴被改動時的處理（developer 回報「改了 `package.json`：是」）

工作目錄是用連結（junction／symlink）建的 worktree 時：

1. 先告知使用者：因依賴變更，該 worktree 要改用自己安裝（`<DEP_INSTALL>`）。
2. **務必先移除連結**（第 1.6 節步驟 2；連結仍在時執行安裝會刪除並重裝主工作區的 `node_modules`）。
3. 再依 1.3 的 `install-per-worktree` 於該 worktree 執行 `<DEP_INSTALL>`。
4. 完成後才進入審核。

工作目錄是主工作區（沒用 worktree）時：不要自行安裝依賴，把「developer 改動了 `package.json`」如實回報，由使用者決定。

### 1.8 異常與中途結束的統一行為

任何異常或中途結束（建立到一半失敗、無可審核內容、agent 回覆異常而中止、使用者中途放棄、使用者選擇保留現狀）：

1. 已建立 worktree 時，**明確回報 worktree 絕對路徑與分支名稱**，並提醒日後如何清除（第 1.6 節：先移除連結、再 `worktree remove`）。
2. 建立到一半失敗 → 先嘗試依第 1.6 節清除半成品；清除失敗就如實回報殘留狀況，不得隱瞞、不得假裝成功。
3. 開發 worktree 一律由協調者建立與清除；developer 不得自行建立或移除 worktree。

### 1.9 審核時 lint／build 的執行位置

- 審核他人 commit（`a..b`、單一 sha、`origin/<分支>`）→ 依第 1.5 節建立審核 worktree，在**該 worktree 內**跑 lint 與 build。
- 審核 `--working` 或協調者指定的工作目錄 → 直接在該目錄跑，**不建立**審核 worktree。
- 專案有沒有 lint／build gate 由 profile `## 指令` 決定；寫 `無` 就跳過並在回報標明「依設定檔：本專案無該 gate」（不適用、不擋 PASS，也不得說成跑過）。

## 2. 平台段落 powershell

> 本段落只在 `shell: powershell` 時由 `compile` 折入 `resolved.md`。路徑一律用反斜線形。

| 動作 | 指令 |
|---|---|
| 取得主工作區 | `git rev-parse --show-toplevel` |
| 存在性檢查 | `Test-Path .worktrees\<名稱>` |
| 建立連結 | junction 兩步（見下） |
| 驗證連結 | `Test-Path .worktrees\<名稱>\node_modules\<框架套件>\package.json` |
| 複製環境檔 | `Copy-Item <環境檔> .worktrees\<名稱>\<環境檔>` |
| 移除連結 | `cmd /c rmdir .worktrees\<名稱>\node_modules`（保留反斜線） |
| 移除 worktree | `git worktree remove --force .worktrees\<名稱>` |
| 列 worktree | `git worktree list` |

**建立連結（junction）強制兩步**（R1 第 4 題實測：`New-Item … -Target (Resolve-Path …).Path` 會被 scanner 判為含未獲准的子指令而 DENIED；括號子運算式禁用）：

1. 先取絕對路徑：

   ```powershell
   Resolve-Path node_modules
   ```

2. 把**步驟 1 回傳的字面值**代入下一條指令前，先驗證它：必須以盤符開頭、含路徑分隔符、且不含 `;`、`&&`、`|`、反引號、`$()`、括號、換行。任一不符 → 停止並回報，**不得**把未驗證字串拼進指令。

   ```powershell
   New-Item -ItemType Junction -Path .worktrees\<名稱>\node_modules -Target <已驗證的絕對路徑字面值>
   ```

3. 建立後驗證連結生效（依專案主要框架套件是否存在檢查，名由 profile 指定）：

   ```powershell
   Test-Path .worktrees\<名稱>\node_modules\<框架套件>\package.json
   ```

> 給 `cmd /c` 的移除指令**保留反斜線**：實測顯示權限比對會把反斜線正規化（斜線形 allow 也能匹配），但 `cmd` 本身會把 `/xxx` 當旗標，斜線形的實際指令會報 `Invalid switch`（`experiments.md` 第 7／7b 題）。

## 3. 平台段落 posix

> 本段落只在 `shell: posix` 時由 `compile` 折入 `resolved.md`。路徑一律用斜線形。

| 動作 | 指令 |
|---|---|
| 取得主工作區 | `git rev-parse --show-toplevel` |
| 存在性檢查 | `test -e .worktrees/<名稱>` |
| 建立連結 | `ln -s ../../node_modules .worktrees/<名稱>/node_modules` |
| 驗證連結 | `test -e .worktrees/<名稱>/node_modules/<框架套件>/package.json` |
| 複製環境檔 | `cp <環境檔> .worktrees/<名稱>/<環境檔>` |
| 移除連結 | `unlink .worktrees/<名稱>/node_modules` |
| 移除 worktree | `git worktree remove --force .worktrees/<名稱>` |
| 列 worktree | `git worktree list` |

規則：

- symlink 目標**固定 `../../node_modules`**（P4）：`.worktrees/<名稱>` 在 repo 根下一層，兩個 `../` 必定回到 repo 根。**不做 `realpath`、不代入任何路徑**；來源與目的地都不收外來值（P8）。
- **建立後以「驗證連結」確認生效**（`test -e` 對 symlink 目標存在時為真）；失敗即停止回報，不得帶著壞連結繼續。
- **不可用 `rm -rf`**：`unlink` 對實體目錄會失敗（EPERM），對不存在的路徑也會失敗；兩者都可忽略，與 `rmdir` 的語意一致。清除一律「先移除連結、再 `git worktree remove --force`」（共用規則第 1.6 節）。
- `cp` 只複製 profile `<ENV_FILES>` 清單內的單一檔名；來源仍受 profile 白名單與提示詞紀律約束。
- 即使 macOS 實測 `git worktree remove --force` 不會跟隨 symlink（主工作區 `node_modules` 完好），仍保留「先移除連結」這一步——兩平台只有一種清除程序（P5）。
