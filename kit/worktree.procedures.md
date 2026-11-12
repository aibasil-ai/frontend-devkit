# worktree 程序（Windows / PowerShell）

> **本檔是源頭素材。** 執行期不是由 agent 直接读本檔：`/frontend-devkit/init compile` 會把下列佔位符按專案 `project.md` 的值代入，再折進該專案 `resolved.md` 的「worktree 程序」段落（主檔 D15）。開發迴圈的四個 agent 只讀 `project.md` ＋ `resolved.md`，不讀 `kitRoot`。
>
> **佔位符**（值一律來自 profile `## 識別`）：
> - `<WT_DIR>` worktree 目錄（例：`.worktrees/`）
> - `<BR_PREFIX_DEV>`／`<BR_PREFIX_FIX>` 分支前綴（例：`feature/`、`fix/`）
> - `<REVIEW_PREFIX>` 審核 worktree 名稱前綴（例：`review-`）
> - `<ENV_FILES>` 環境檔清單（逐檔，例：`.env`）
> - `<DEP_INSTALL>` 不可變依賴安裝指令（例：`npm ci`、`pnpm install --frozen-lockfile`）
>
> **禁止項**：本檔與 kit 任何素材內**不得出現個人絕對路徑**。主工作區一律執行期以 `git rev-parse --show-toplevel` 取得；需要絕對路徑的場合（junction 的 `-Target`）由該次執行結果代入，不落盤。

## 1. 主工作區與基準

- 主工作區：`git rev-parse --show-toplevel`（在專案根執行）。
- 比較基準：建立 worktree 時的起點 sha（`git rev-parse HEAD` 或指定的起點 commit）。
- 所有 shell 指令一律以工具的 `workdir` 參數指定目錄，**不要用 `cd`**；需要詢問使用者時一律用 `question` 工具。

## 2. 建立開發 worktree

1. 依任務產生 `<類型>-<slug>`（slug 為英文小寫連字號）與分支 `<BR_PREFIX_DEV 或 BR_PREFIX_FIX><slug>`。
2. 先取起點 sha 記為比較基準。
3. 建立（`<起點>` 可省略，預設目前 HEAD）：

   ```powershell
   git worktree add <WT_DIR><名稱> -b <分支> [<起點>]
   ```

4. **同名目錄或分支已存在時不硬蓋**：改用 `question` 請使用者決定（換名稱，或先處理殘留）。
5. 若 `<WT_DIR>` 未被 `.gitignore` 排除（`git check-ignore -q <WT_DIR>` 為非 0）→ **先警告再繼續**：`--working` 審核會把 worktree 內容（含下一步複製進去、可能帶密鍵的環境檔）混入未追蹤檔案清單，且容易誤 commit。建議由使用者自行把 `<WT_DIR>` 加入 `.gitignore`（kit 不擅自改 `.gitignore`）。

## 3. 依賴處理（profile `depStrategy`）

### 3a. `junction`（npm 型、平面 `node_modules` 的專案）

```powershell
New-Item -ItemType Junction -Path <WT_DIR><名稱>/node_modules -Target (取得主工作區 node_modules 的絕對路徑)
```

**括號子運算式禁用，一律走兩步**（R1 第 4 題實測：`New-Item … -Target (Resolve-Path …).Path` 會被 scanner 判為含未獲准的子指令而 DENIED）：

1. 先取絕對路徑：

   ```powershell
   Resolve-Path node_modules
   ```

2. 把**步驟 1 回傳的字面值**代入下一條指令前，先驗證它：必須以盤符開頭、含路徑分隔符、且不含 `;`、`&&`、`|`、反引號、`$()`、括號、換行。任一不符 → 停止並回報，**不得**把未驗證字串拼進指令。

   ```powershell
   New-Item -ItemType Junction -Path <WT_DIR><名稱>/node_modules -Target <已驗證的絕對路徑字面值>
   ```

3. 建立後驗證連結生效（依專案主要框架套件是否存在檢查，名由 profile 指定）：

   ```powershell
   Test-Path <WT_DIR><名稱>/node_modules/<框架套件>/package.json
   ```

### 3b. `install-per-worktree`（pnpm／yarn workspace、`node_modules` 非平面結構的專案）

在該 worktree 內執行 profile 的 `<DEP_INSTALL>`，`workdir` 必須是該 worktree 的**絕對路徑**，timeout 依 profile（建議 600000）。

- **只准用不可變安裝**（依 lockfile 重建，例如 `npm ci`、`pnpm install --frozen-lockfile`、`yarn install --frozen-lockfile`）。會改 lockfile 的可變安裝（`npm install`、`pnpm add` 等）一律由協調者之外處理，developer 不可執行。
- 安裝失敗（例如 lockfile 與 `package.json` 不同步）→ **如實回報並用 `question` 請使用者決定**；不得自行改採可變安裝、不得跳過安裝直接進入審核。

### 3c. `none`

不建立 worktree（搭配 `worktreePolicy: never`）。審核目標恆為 `--working`；仍在結束時跑一次 `git worktree list` 確認沒有前次殘留。

## 4. 環境檔複製

依 profile `<ENV_FILES>` 清單逐檔複製進 worktree：

```powershell
Copy-Item <環境檔> <WT_DIR><名稱>/<環境檔>
```

- 這些檔案可能含密鍵：**不得**出現在任何回報、commit 內容或 diff 摘要中。
- 檔名必須是單一檔名（無 `/`、`\`、`:`、`..`、萬用字元）——這是 profile 欄位白名單驗證的一環（主檔 §5.1.2），非法值 `setup` 拒絕寫入、`inspect` 每輪重驗。

## 5. 審核用 worktree（reviewer 專用，detached）

1. 名稱 `<REVIEW_PREFIX><sha7>`，`sha7` 取範圍最新 commit 的短 sha：`git rev-parse --short=7 <commit>`。
2. 先查殘留：`Test-Path <WT_DIR><名稱>`，並用 `git worktree list` 看是否已登記。
   - 目錄存在（上次中斷的殘留）→ **先按第 6 節清除，再建立**，不可報錯停擺。
   - 目錄不存在但 `git worktree list` 已登記 → `git worktree add` 會失敗：**如實回報並請使用者處理**。reviewer 沒有 `git worktree prune` 權限，也不得嘗試白名單以外的指令。
3. 建立：

   ```powershell
   git worktree add --detach <WT_DIR><名稱> <commit>
   ```

4. 依賴：範圍內改動過 `package.json`／lockfile → 依 3b 在該 worktree 內 `<DEP_INSTALL>`；否則依 3a 建立連結。
5. 複製環境檔（依第 4 節）。
6. lint／build／測試都在**這個 worktree 內**執行（`workdir` 指向它）。

## 6. 清除 worktree（三種 depStrategy 一體適用，不可跳過第一步）

> **警告**：若 `node_modules` 是 junction，直接 `git worktree remove --force` 在 Windows 可能跟隨連結，**把主工作區 `node_modules` 的內容一併刪除**。第一步不可省略。

1. **先**只移除連結（對實體目錄或不存在的路徑會失敗，失敗訊息可忽略，因此這一步可無條件執行）：

   ```powershell
   cmd /c rmdir <WT_DIR><名稱>\node_modules
   ```

   給 `cmd /c` 的這條指令**保留反斜線**：實測顯示權限比對會把反斜線正規化（斜線形 allow 也能匹配），但 `cmd` 本身會把 `/xxx` 當旗標，斜線形的實際指令會報 `Invalid switch`（`experiments.md` 第 7／7b 題）。
2. **再**移除 worktree：

   ```powershell
   git worktree remove --force <WT_DIR><名稱>
   ```

3. **清除前必查未 commit 殘留**：先在該 worktree 跑 `git status --short`；有未 commit 檔案（developer 產生的暫存檔、複製進去的環境檔）時**先告知使用者再執行**——`--force` 會把它們一併丟棄。
4. 收尾：`git worktree list` 確認只剩預期工作區。`git worktree prune` 僅在「目錄已不在但 git 仍登記」時由協調者或使用者執行；reviewer 無此權限。

## 7. 依賴被改動時的處理（developer 回報「改了 `package.json`：是」）

工作目錄是用 junction 建的 worktree 時：

1. 先告知使用者：因依賴變更，該 worktree 要改用自己安裝（`<DEP_INSTALL>`）。
2. **務必先移除 junction**（第 6 節步驟 1；junction 仍在時執行安裝會刪除並重裝主工作區的 `node_modules`）。
3. 再依 3b 於該 worktree 執行 `<DEP_INSTALL>`。
4. 完成後才進入審核。

工作目錄是主工作區（沒用 worktree）時：不要自行安裝依賴，把「developer 改動了 `package.json`」如實回報，由使用者決定。

## 8. 異常與中途結束的統一行為

任何異常或中途結束（建立到一半失敗、無可審核內容、agent 回覆異常而中止、使用者中途放棄、使用者選擇保留現狀）：

1. 已建立 worktree 時，**明確回報 worktree 絕對路徑與分支名稱**，並提醒日後如何清除（第 6 節：先 `rmdir`、再 `worktree remove`）。
2. 建立到一半失敗 → 先嘗試依第 6 節清除半成品；清除失敗就如實回報殘留狀況，不得隱瞞、不得假裝成功。
3. 開發 worktree 一律由協調者建立與清除；developer 不得自行建立或移除 worktree。

## 9. 審核時 lint／build 的執行位置

- 審核他人 commit（`a..b`、單一 sha、`origin/<分支>`）→ 依第 5 節建立審核 worktree，在**該 worktree 內**跑 lint 與 build。
- 審核 `--working` 或協調者指定的工作目錄 → 直接在該目錄跑，**不建立**審核 worktree。
- 專案有沒有 lint／build gate 由 profile `## 指令` 決定；寫 `無` 就跳過並在回報標明「依設定檔：本專案無該 gate」（不適用、不擋 PASS，也不得說成跑過）。
