# frontend-devkit 雙平台相容設計（Windows + macOS）

- 日期：2026-11-14
- 狀態：已核准（2026-11-14）；實作依 `docs/plans/2026-11-14-macos-compatibility-plan.md`
- 依據：`docs/specs/2026-11-11-frontend-devkit-design.md`（主檔）、`docs/permission-spec.md`、`docs/experiments.md`、`docs/acceptance.md`
- 本次範圍：讓 kit 的 worktree 程序、agent 權限、profile、安裝文件與 repo 健檢工具都能在 macOS（zsh／bash）執行；Windows PowerShell 路徑保留且行為不變。

---

## 1. 背景與問題

現行 kit 的執行期假設全部綁在 Windows：

1. `kit/worktree.procedures.md` 只有 PowerShell 指令（`New-Item -ItemType Junction`、`Copy-Item`、`Test-Path`、`Resolve-Path`、`cmd /c rmdir`）。
2. 四個 agent 的 frontmatter 只 allow PowerShell 指令；macOS 上會全部落到 `ask`／`deny`。
3. profile 的 `shell` 只接受 `powershell`；`depStrategy: junction` 的實作沒有 macOS 對應。
4. `setup` 的偵測、checksum、pack 正文驗證使用 `Get-Location`／`Get-FileHash`／`Select-String`／`Test-Path`。
5. `docs/install.md`、`README.md`、`docs/adding-a-project.md`、`docs/acceptance.md`、`docs/tui-run-checklist.md` 只有 Windows 步驟與 `%LOCALAPPDATA%` 路徑。
6. `tools/*.ps1` 是 repo 健檢工具，在 macOS 無法直接跑。

結果：在 macOS 上可以載入 agent，但一進入 worktree 流程就會被權限拒絕或找不到指令。這不是「換幾個字」而是缺少一層平台抽象。

## 2. 目標、非目標、反目標

### 目標

1. **同一個 kit 原始碼**同時支援 Windows PowerShell 與 macOS POSIX shell（zsh／bash／sh），不維護兩份 agent 主體。
2. macOS 上能完整跑完：`init` → `dev`／`fix` → `review`／`review-fix` → worktree 建立／清除 → commit 前人工審核。
3. `depStrategy: junction` 在 macOS 以**相對 symlink**實作，且絕不跟隨連結刪除主工作區的 `node_modules`。
4. 所有 agent 權限維持「靜態白名單、字面同形、尾巴三段式」；不引入 `node -e`、`$()`、括號子運算式或新的動態求值通道。
5. Windows 既有行為與驗收紀錄不被破壞；新增 macOS 的實驗與驗收紀錄。
6. repo 健檢工具可在 macOS 執行（Node.js 版），Windows PowerShell 版保留。

### 非目標

1. 不支援 Windows 以外的非 POSIX shell（例如 fish 的專屬語法）。
2. 不改 kit 的流程模型（三層知識、4 個 agent、6 個指令、pack 機制）。
3. 不新增 npm 依賴、不引入 third-party CLI。
4. 不改既有 Windows 驗收的歷史結論；只新增 macOS 驗收。

### 反目標（即使技術上可行也不做）

1. 用 `node -e`／`python -c`／`sh -c` 之類的動態求值繞過權限 scanner。
2. 把 shell 權限放寬成 `*` 或 `npm run *` 這種涵蓋式 allow。
3. 用絕對路徑或個人路徑寫進 kit 素材。
4. 在 macOS 直接 `rm -rf` worktree 的 `node_modules` 或 worktree 目錄。

## 3. 已定案決策

| # | 決策 | 理由 |
|---|---|---|
| P1 | **雙平台並存**：保留 Windows PowerShell 路徑，新增 macOS POSIX 路徑 | 使用者選擇；避免破壞既有 Windows 驗收與使用者的其他機器 |
| P2 | **`depStrategy: junction` 欄位不變**；Windows 用 junction、macOS 用 symlink | 使用者選擇；既有 profile 不必改值；語意都是「連結主工作區的 node_modules」 |
| P3 | profile 的 `shell` 值域擴充為 `powershell`、`posix`、`TBD（未確認）` | `posix` 是 shell 方言，涵蓋 macOS／Linux 的 zsh／bash／sh；**本次只驗 macOS**，Linux 不列入驗收、不宣稱支援 |
| P4 | macOS 的 symlink 使用**固定相對目標 `../../node_modules`**（搭配 P11 的固定 `.worktrees/`） | 不產生絕對路徑、不需要 `realpath`、不需要驗證回傳字串的注入風險；來源也固定，避免任意 symlink 目標 |
| P5 | 清除順序在兩個平台都保留「先移除連結、再 `git worktree remove --force`」 | macOS 實測 `git worktree remove --force` 不會跟隨 symlink，但保留此步可讓三種 depStrategy 只有一種程序、且對 Windows 仍是必要保命步驟 |
| P6 | `compile` 依 profile 的 `shell` **只折入對應平台的 worktree 段落** | 避免 `resolved.md` 同時出現兩套指令而讓 agent 用錯；`shell: TBD` 時折入警告並停用 worktree 程序 |
| P7 | agent 權限**同時保留** Windows 與 POSIX 的 allow 條目，不刪任何既有條目 | 同一份主體跨平台；Windows 上 POSIX 指令不存在也無害，macOS 上 PowerShell 指令不存在也無害 |
| P8 | POSIX 的 `ln`／`unlink` 權限**來源與目的地都收窄**：`ln -s ../../node_modules .worktrees/*/node_modules`、`unlink .worktrees/*/node_modules` | 實測窄化 pattern 會擋掉 `ln -s /etc/passwd .../passwd` 與非 node_modules 的 `unlink`；來源固定後不再有「任意來源 symlink」的縫 |
| P9 | `tools/*.ps1` 以 Node.js（`.mjs`，零依賴）新增跨平台版本；`.ps1` 保留 | repo 健檢工具不是 kit 元件；Node 版可在 macOS／Windows 共用，PS1 供舊環境 |
| P10 | macOS 驗收另立 `docs/acceptance.md` §13.2，不覆蓋 §13 的 Windows 紀錄 | 保留歷史證據，讓兩個平台的通過條件可各自追溯 |
| P11 | **收緊 profile 的 `worktree 目錄` 為唯一值 `.worktrees/`、`worktree 名稱前綴` 的審核前綴為唯一值 `review-`** | 靜態權限本來就只認 `.worktrees/*`／`review-*`；讓 profile 可填自訂值等於「寫得出來但跑不動」。這是本次一併修掉的既存矛盾，屬 breaking change，`init`／`inspect` 會拒絕其他值並要求改回 |
| P12 | POSIX 的落點檢查用 `pwd -P`，不是 `pwd` | 實測 macOS 的 `mktemp -d` 落在 `/var/...`，而 `git rev-parse --show-toplevel` 回 `/private/var/...`；`pwd -P` 才會與 Git 的實體路徑一致 |
| P13 | `resolved.md` 仍可進版控，但檔頭新增「平台／shell」欄；orchestrator／developer／reviewer 三個 agent 的開工檢查比對 `project.md` 的 `shell` 與檔頭值，不一致就停止並要求 `init compile`（`setup` 是寫入者，不套用此檢查） | 換平台時 `resolved.md` 會不同；只比「啟用清單」不足以偵測平台段落錯置。換平台前先跑 `init` 仍是必要步驟 |
| P14 | POSIX 的寫入／刪除／執行族清單寫進 `docs/permission-spec.md` §7.3.5#2 與主檔 §5.1.2／§7.1，不是只寫在 profile 範本 | 權威清單只有一處；否則 macOS 的 `setup`／reviewer 不會機械擋下 `mv`、`chmod`、`tee`、`sh -c`、`node -e` 之類的條目 |

## 4. 平台模型

### 4.1 `shell` 欄位與偵測

- 值域：`powershell`、`posix`、`TBD（未確認）`。
- 偵測順序（`setup`）：
  1. `uname -s` 成功且輸出 `Darwin`／`Linux` → `posix`。
  2. 否則 `Get-Location` 成功且輸出 `Path ---- …` → `powershell`。
  3. 兩者都失敗 → `TBD（未確認）`，用 `question` 請使用者確認；不得用 `$env:OS`、`$PSVersionTable`、`$()`、括號子運算式。
- 落點確認（P12）：
  - `posix`：`pwd -P`，必須等於 `git rev-parse --show-toplevel`。**不可用 `pwd`**。
  - `powershell`：`Get-Location`，判定方式不變。
- macOS 實測（2026-11-14，OpenCode v2.2.7，Darwin 25.5.0，zsh）：`uname -s` → `Darwin`、`pwd` → 專案根、`Get-Location` 在 zsh 下不可用。這證明「先 `uname`、後 `Get-Location`」的順序是必要的；若顛倒，macOS 上會先得到 command not found 而被誤判。（`pwd` 只是探針觀察；正式落點規則依 P12 用 `pwd -P`。）
- 為什麼是 `pwd -P`：在 `mktemp -d` 建的目錄下，`pwd` 回 `/var/...`、`pwd -P` 回 `/private/var/...`，而 `git rev-parse --show-toplevel` 也回 `/private/var/...`。用 `pwd` 會把合法的實體路徑誤判成落點不符。allow 清單只登記 `pwd -P` 字面；未登記的 `pwd` 會被 scanner 拒絕（實測見 §7.1）。

### 4.2 worktree 程序分平台

`kit/worktree.procedures.md` 改為「共用規則＋兩個平台段落」，由 `compile` 擇一折入。`<path>` 一律指 `.worktrees/<名稱>`（P11 固定根目錄），Windows 用反斜線、POSIX 用斜線。

| 動作 | Windows（`shell: powershell`） | macOS／POSIX（`shell: posix`） |
|---|---|---|
| 取得主工作區 | `git rev-parse --show-toplevel` | 同左 |
| 檢查路徑存在 | `Test-Path .worktrees\<名稱>` | `test -e .worktrees/<名稱>` |
| 建立 node_modules 連結 | `New-Item -ItemType Junction -Path .worktrees\<名稱>\node_modules -Target <絕對路徑>`（維持兩步） | `ln -s ../../node_modules .worktrees/<名稱>/node_modules` |
| 驗證連結 | `Test-Path .worktrees\<名稱>\node_modules\<框架套件>\package.json` | `test -e .worktrees/<名稱>/node_modules/<框架套件>/package.json` |
| 複製環境檔 | `Copy-Item <env> .worktrees\<名稱>\<env>` | `cp <env> .worktrees/<名稱>/<env>` |
| 移除連結 | `cmd /c rmdir .worktrees\<名稱>\node_modules`（保留反斜線） | `unlink .worktrees/<名稱>/node_modules` |
| 移除 worktree | `git worktree remove --force .worktrees/<名稱>` | 同左 |
| 列 worktree | `git worktree list` | 同左 |

規則：

- POSIX 的 symlink 目標固定 `../../node_modules`（P4、P11）：`.worktrees/<名稱>` 在 repo 根下一層，兩個 `../` 必定回到 repo 根。**不再有 `<WT_LINK_TARGET>` 佔位符，也不再依 worktree 目錄段數計算**；`compile` 不代入任何路徑。
- `worktree 目錄` 唯一合法值 `.worktrees/`；`worktree 名稱前綴` 的審核前綴唯一合法值 `review-`（P11）。`init`／`inspect` 對其他值一律報錯，要求使用者改回；不提供相容模式。
- `unlink` 對實體目錄會失敗（EPERM），對不存在的路徑也會失敗；兩者都可忽略，與 `rmdir` 的語意一致。**不可**改用 `rm -rf`。
- `cp` 只複製 profile `<ENV_FILES>` 清單內的單一檔名；`cp` 的來源不受 pattern 限制（與 Windows `Copy-Item *` 對等），因此仍需提示詞紀律與 profile 白名單。
- 平台段落不得互相混用；`posix` 段落不得出現 `cmd /c`、`Get-Location`、`Test-Path`、`Copy-Item`、`New-Item`、`Resolve-Path`。

### 4.3 `depStrategy: junction` 的平台語意

- 定義不變：**連結主工作區的 `node_modules`，不在 worktree 內重新安裝**。
- Windows：junction，`-Target` 必須是主工作區 `node_modules` 的絕對路徑，維持既有兩步與注入防護。
- macOS／POSIX：相對 symlink，目標固定 `../../node_modules`（P4、P11）；不做 `realpath`、不把絕對路徑寫進 `resolved.md`。
- 先驗條件：主工作區必須已有 `node_modules`。`setup` 與 `orchestrator` 的檢查：
  - `posix`：`test -e node_modules`
  - `powershell`：`Test-Path node_modules`
  - 不存在 → 不得把 `junction` 標成建議；預設改用 `install-per-worktree`，或由使用者選 `none`。
- `install-per-worktree` 與 `none` 的行為不變；macOS 的不可變安裝指令由 profile 提供（例如 `npm ci`）。

### 4.4 `compile` 的條件折入

- `setup` 讀 `project.md` 的 `shell`：
  - `powershell` → 折入 Windows 段落＋共用段落。
  - `posix` → 折入 POSIX 段落＋共用段落。
  - `TBD（未確認）` → 兩個段落都不折入；在「worktree 程序」段落寫「shell 未確認，worktree 程序停用」，並在檔頭警告。
- `resolved.md` 的「worktree 程序」段落必須只包含一個平台段落；`inspect` 重建內文時使用同一個選擇規則。
- `resolved.md` 檔頭新增「平台／shell」欄（P13），值取自 `project.md` 的 `shell` 與偵測到的 OS；`compile` 與 `inspect` 都要寫入。
- `compile` 的 checksum 對 `worktree.procedures.md` 整檔計算（不是只算被折入的段落），來源識別不變。

### 4.5 清除順序（兩個平台一致）

1. 先在該 worktree 跑 `git status --short`，有未 commit 殘留先告知使用者。
2. 移除 node_modules 連結：
   - Windows：`cmd /c rmdir <path>\node_modules`
   - POSIX：`unlink <path>/node_modules`
3. `git worktree remove --force <path>`。
4. `git worktree list` 確認只剩預期工作區。
5. `git worktree prune` 仍只由協調者或使用者執行；reviewer 無此權限。

macOS 實測：在 `.worktrees/test/node_modules` 建立 `../../node_modules` symlink 後直接 `git worktree remove --force`，主工作區 `node_modules/fakepkg/package.json` 仍存在；先 `unlink` 再 remove 也正常。保留第一步是為了跨平台一致性與 Windows 安全。

### 4.6 profile 值域收緊（P11）

這是本次的 breaking change，理由是靜態權限與程序本來就只認固定字面：

| 欄位 | 舊行為 | 新行為 |
|---|---|---|
| `worktree 目錄` | 可填任意相對路徑（例如 `build/worktrees/`） | **只接受 `.worktrees/`**；其他值一律拒絕 |
| `worktree 名稱前綴` 的審核前綴 | 可自訂（例如 `audit-`） | **只接受 `review-`**；其他值一律拒絕 |

- 拒絕點：`init`（含 `init` 重跑）與 `inspect` 都要檢查；錯誤訊息要指出合法值，並要求使用者改 `project.md` 後重跑。
- 既有專案若填了其他值，`init` 不自動改寫、不靜默降級；直接報錯，避免「寫得出來但跑不動」。
- `kit/profile/project.template.md` 的註解要同步標明唯一合法值，避免使用者以為可自訂。

### 4.7 `resolved.md` 平台守門（P13）

- `resolved.md` 仍可進版控，但檔頭固定包含：
  - `平台`：`windows` 或 `macos`（由偵測結果寫入）。
  - `shell`：`powershell` 或 `posix`。
- orchestrator／developer／reviewer 三個 agent 在開工前的第 0 步比對：`project.md` 的 `shell` 與 `resolved.md` 檔頭的 `shell` 必須一致。`setup` 是檔頭寫入者，不套用此檢查。
  - 不一致 → 停止，要求使用者先跑 `init`／`init compile`；不得自行猜測或改寫 `resolved.md`。
  - `shell: TBD（未確認）` → 同樣停止，要求先確認 shell。
- 只比對 `shell` 與平台欄，不重新計算 checksum；checksum 仍由 `inspect`／`setup` 負責。
- Windows 與 macOS 的 `resolved.md` 本來就會不同；換平台時重跑 `init` 是必要步驟，不是 diff 噪音問題。

## 5. 權限清單變更

所有新增條目都放在既有 allow 區塊，且在尾巴三段式之前；不刪除任何 Windows 條目。

P14：POSIX 的**寫入／刪除／執行族**（含 `mv`、`chmod`、`tee`、`sh -c`、`node -e` 等）的權威清單放在 `docs/permission-spec.md` §7.3.5#2，並同步寫進主檔 §5.1.2／§7.1；本節只列各 agent 實際新增的 allow 增量，不重複定義族清單。

### 5.1 orchestrator

新增：

```yaml
- { action: "shell", resource: "pwd -P",                                            effect: "allow" }
- { action: "shell", resource: "test -e *",                                         effect: "allow" }
- { action: "shell", resource: "ln -s ../../node_modules .worktrees/*/node_modules", effect: "allow" }
- { action: "shell", resource: "cp * .worktrees/*",                                 effect: "allow" }
- { action: "shell", resource: "unlink .worktrees/*/node_modules",                  effect: "allow" }
```

- `ln`／`unlink` 依 P8 收窄：來源固定 `../../node_modules`、目的地限定 `.worktrees/*/node_modules`；`unlink` 也只限 `.worktrees/*/node_modules`（實測 `/etc/passwd` 與非 node_modules 的 `unlink` 都會被 DENIED）。
- `ln -s` 的字面與程序指令完全一致，沒有 `<WT_LINK_TARGET>` 代入，因此不會出現「allow 一條、執行另一條」的漂移。
- `cp` 與 `Copy-Item * .worktrees/*` 對等；來源仍受 profile 環境檔白名單與提示詞紀律約束。
- 既有 `Test-Path *`、`Resolve-Path node_modules`、`New-Item … Junction`、`Copy-Item *`、`cmd /c rmdir` 保留給 Windows。

### 5.2 developer

新增：

```yaml
- { action: "shell", resource: "pwd -P",     effect: "allow" }
- { action: "shell", resource: "test -e *",  effect: "allow" }
```

- developer 不建立／移除 worktree，因此不需要 `ln`／`unlink`／`cp`。
- 既有 `rm`、`Remove-Item`、`Move-Item` 等 deny 不變；macOS 的 `rm` 已在第 1 段 deny。

### 5.3 reviewer

新增：

```yaml
- { action: "shell", resource: "pwd -P",                                          effect: "allow" }
- { action: "shell", resource: "test -e .worktrees/review-*",                     effect: "allow" }
- { action: "shell", resource: "ln -s ../../node_modules .worktrees/review-*/node_modules", effect: "allow" }
- { action: "shell", resource: "cp * .worktrees/review-*",                        effect: "allow" }
- { action: "shell", resource: "unlink .worktrees/review-*/node_modules",         effect: "allow" }
```

- 保留 `Get-Location` 給 Windows 的 probe 第 0 條。
- `pwd -P` 給 POSIX 的 probe 第 0 條。
- 既有「reviewer 清單不含 `Get-FileHash`」的規則不變；checksum 只屬 `setup`。

### 5.4 setup

新增：

```yaml
- { action: "shell", resource: "pwd -P",          effect: "allow" }
- { action: "shell", resource: "uname -s",        effect: "allow" }
- { action: "shell", resource: "test -e *",       effect: "allow" }
- { action: "shell", resource: "shasum -a 256 *", effect: "allow" }
- { action: "shell", resource: "grep -n *",       effect: "allow" }
```

- 保留 `Get-Location`、`cmd /c ver`、`Get-FileHash *`、`Select-String *`、`Test-Path *` 給 Windows。
- 不新增 `realpath`（POSIX 用相對 symlink，不需要）。
- `grep -n` 只用於 pack 正文存在性驗證；不允許 `grep -r` 之類的遞迴搜尋（避免超出需求）。

### 5.5 probe 三條（跨平台）

| 條 | Windows | macOS／POSIX | 預期 |
|---|---|---|---|
| 0 落點 | `Get-Location` | `pwd -P` | 回傳目前專案根的實體路徑；不是就本輪 probe 無效 |
| 1 靜態清單 gate | `npm test`（或 profile gate） | 同左 | allow |
| 2 必被拒寫入 | `git commit --allow-empty -m probe` | 同左 | deny |

- `setup` 依 profile `shell` 決定派給 reviewer 的落點指令；reviewer 兩條都已 allow。
- 第 0 條在 macOS 要用 `pwd -P` 與 `git rev-parse --show-toplevel` 比對；用 `pwd` 會被 `/var` → `/private/var` 的路徑別名誤判。
- 第 2 條若被准 → 立即停用 kit，引用規則來源。

## 6. 檔案變更清單

### 6.1 `kit/`

| 檔案 | 變更 |
|---|---|
| `kit/worktree.procedures.md` | 改為共用規則＋Windows／POSIX 兩段落；POSIX 目標固定 `../../node_modules`、目錄固定 `.worktrees/`（不用 `<WT_LINK_TARGET>`、不依段數計算）；清除順序兩平台；保留 Windows 反斜線與 junction 兩步 |
| `kit/agents/frontend-devkit/orchestrator.md` | 新增 POSIX allow（`pwd -P`、`test -e *`、固定來源 `ln -s`、`cp`、`unlink`）；提示詞改平台中性；`junction` 可行性改 `test -e`／`Test-Path`；清除程序分平台；`bash` 改 `shell`；移除「僅 PowerShell」；開工加 `resolved.md` 平台守門（P13） |
| `kit/agents/frontend-devkit/developer.md` | 新增 `pwd -P`／`test -e *`；提示詞改平台中性；開工加平台守門；保留所有 Windows deny |
| `kit/agents/frontend-devkit/reviewer.md` | 新增 POSIX allow（`pwd -P`、`test -e .worktrees/review-*`、固定來源 `ln -s`、`cp`、`unlink`）；§0／§3 的 `Test-Path`／`cmd /c rmdir`／`Copy-Item` 改平台對照；§3 清除程序分平台；開工加平台守門 |
| `kit/agents/frontend-devkit/setup.md` | shell 偵測改 `uname -s`／`Get-Location`；checksum 改 `shasum -a 256`／`Get-FileHash`；pack 驗證改 `grep -n`／`Select-String`；存在性改 `test -e`／`Test-Path`；落點改 `pwd -P`；`shell` 值域；`depStrategy` 先驗；`cp -R` 巢狀警告；`resolved.md` 檔頭寫平台／shell |
| `kit/commands/frontend-devkit/init.md` | 落點檢查改 `pwd -P`／`Get-Location`；**拒絕**非 `.worktrees/` 的 worktree 目錄與非 `review-` 的審核前綴（P11） |
| `kit/commands/frontend-devkit/inspect.md` | probe 第 0 條改 `pwd -P`／`Get-Location`；重建 `resolved.md` 時寫平台／shell 檔頭；同樣拒絕 P11 非法值 |
| `kit/commands/frontend-devkit/review.md` | 清除指令改平台中性（`unlink`／`cmd /c rmdir`）；審核前綴固定 `review-` |
| `kit/profile/project.template.md` | `shell` 值域與偵測；`depStrategy` 平台語意；`安裝紀錄` probe 0 改 `pwd -P`；`## 額外 shell` 加入 POSIX 寫入／刪除／執行族（指向權威清單）；`worktree 目錄` 註明唯一合法值 `.worktrees/`、審核前綴唯一合法值 `review-`（P11）；移除 `/abs` 自訂例 |

`kit/rules/` 無平台專屬內容，不動。

### 6.2 `docs/`

| 檔案 | 變更 |
|---|---|
| `README.md` | 平台表改「Windows PowerShell／macOS zsh-bash」；安裝最短版加 macOS；疑難排解加 macOS 列；`junction` 說明補 symlink；標明 `.worktrees/`／`review-` 為固定值（P11 breaking change） |
| `docs/install.md` | 加 macOS §1a 指令（`rm -rf`、`mkdir -p`、`cp -R`）；驗證改 `test -f`／`test ! -e`；`cp -R` 巢狀警告；shell 比對加 POSIX 例；落點檢查改 `pwd -P`；全域路徑加 `~/.config/opencode` |
| `docs/adding-a-project.md` | `depStrategy` 表補 macOS symlink；先驗改 `test -e node_modules`；常見卡點加 macOS；工作目錄／審核前綴只接受 `.worktrees/`／`review-`，其他值 `init` 會拒絕 |
| `docs/permission-spec.md` | 事實 6 加 POSIX scanner；語法紀律加 POSIX 對照（`$()`、`test -e`、`shasum`、`ln`、`unlink`、`cp`、`grep`）；**新增 §7.3.5#2 POSIX 寫入／刪除／執行族權威清單**（P14）；§7.3.3 範例加 POSIX 條目；尾巴三段式說明不變 |
| `docs/experiments.md` | 新增「R2：2026-11-14 macOS 實測」：環境、POSIX scanner 結果（含 `pwd -P` 與 `/var`→`/private/var`）、窄化 `ln`／`unlink`、symlink + worktree remove、報表；R1 保留為 Windows 歷史 |
| `docs/acceptance.md` | 新增 §13.2 macOS 關卡 0～8（`mktemp -d`、`npm create vite`、`shasum`、`test -e`、symlink 清除、P11 非法值拒絕、P13 平台守門）；狀態先標「待驗」，實測後填 |
| `docs/acceptance-findings.md` | 新增 macOS 驗收段（實測後填）；不覆蓋 Windows 段 |
| `docs/tui-run-checklist.md` | 新增 macOS 清單（`pwd -P`、`shell=posix`、`ln -s ../../node_modules`、`unlink`）；Windows 清單保留 |
| `docs/CHANGELOG.md` | 新增 2026-11-14「雙平台（macOS）」段：P1～P14、P11 為 breaking change、檔案清單、驗收狀態 |
| `docs/specs/2026-11-11-frontend-devkit-design.md` | 修訂：非目標第 1 條、D8、D23、§5.1.1#1、§5.1.2（POSIX 寫入族連到權威清單）、§7.1、§9、§11 的平台字句；檔頭加「2026-11-14 雙平台修訂」連結本檔；歷史段落保留 |
| `docs/implementation-plan.md` | 檔頭加註「此為 2026-11-12 Windows-only 歷史計畫；雙平台實作見 docs/plans/2026-11-14-macos-compatibility-plan.md」 |
| `docs/migration-map.md` | 加一列平台對照（PowerShell → POSIX），標明歷史遷移圖不因平台改寫 |

### 6.3 `tools/`

| 檔案 | 變更 |
|---|---|
| `tools/check-structure.mjs` | 新增 Node 版：frontmatter 格式、專案專屬事實、指令紀律、尾巴三段式順序；路徑用 `import.meta.url` 相對 repo |
| `tools/scan-forms.mjs` | 新增 Node 版：簡體字形掃描、一／次計數 |
| `tools/normalize-forms.mjs` | 新增 Node 版：與 `.ps1` 相同的替換與疑似字回報；寫檔用 UTF-8 無 BOM、LF |
| `tools/README.md` | 表格加 Node 版；說明 macOS 用 `node tools/*.mjs`、Windows 可續用 `.ps1` |
| `.gitattributes` | 加 `*.mjs text eol=lf` |

### 6.4 不變的部分

- `kit/rules/*` 的 pack 內容。
- `docs/writing-a-pack.md`。
- Windows 的 `cmd /c rmdir` 反斜線形與 junction 兩步注入防護。
- 方案 B（專案端不寫 shell 規則）、D18、D21、D22、D24。
- `npm ci`／`pnpm install --frozen-lockfile`／`yarn install --frozen-lockfile` 的三段式位置。

## 7. 驗證計畫

### 7.1 已完成（2026-11-14，OpenCode v2.2.7，macOS 26.5.1 arm64，zsh）

探針方式：建立臨時 agent `zzprobe/posix` 與 `zzprobe/narrow`，用假指令／無副作用指令測權限，跑完刪除。shell 落點為本 kit repo（路徑以 `<repo>` 表示）。

| 指令 | 結果 | 意義 |
|---|---|---|
| `pwd -P` | EXECUTED | POSIX 落點的正式 allow 條目 |
| `pwd` | DENIED | 未登記即被拒；證明 allow 是字面比對，不能拿 `pwd` 代替 `pwd -P`（P12） |
| `uname -s` | EXECUTED（`Darwin`） | shell／OS 偵測可用 |
| `test -e .` | EXECUTED | 存在性檢查可用（shell builtin 也能被 scanner 匹配） |
| `shasum -a 256 .gitignore` | EXECUTED | checksum 可用 |
| `cp .gitignore .worktrees/zzprobe/.gitignore` | EXECUTED（目的地不存在而失敗） | 權限放行；`cp` 可用 |
| `ln -s ../../node_modules .worktrees/zzprobe/node_modules` | EXECUTED（目的地不存在而失敗） | 固定來源的相對 symlink 權限可用 |
| `unlink .worktrees/zzprobe/node_modules` | EXECUTED（不存在而失敗） | 只移除連結的指令可用 |
| `grep -n "a b" .gitignore` | EXECUTED | 引號參數可匹配 allow |
| `git commit --allow-empty -m probe` | DENIED | 真地板在 macOS 仍有效 |
| `rm .worktrees/zzprobe/zz` | DENIED | `rm` 仍被擋 |
| `ln -s /etc/passwd .worktrees/zzprobe/passwd` | DENIED | 固定來源＋窄化目的地擋掉任意 symlink |
| `unlink .worktrees/zzprobe/passwd` | DENIED | 窄化 pattern 擋掉非 node_modules 的刪除 |

路徑別名實測（`mktemp -d` 建的專案）：

- `pwd` → `/var/folders/...`；`pwd -P` → `/private/var/folders/...`。
- `git rev-parse --show-toplevel` → `/private/var/folders/...`。
- 因此落點比對必須用 `pwd -P`；用 `pwd` 會誤判。

另外用暫存 git repo 實測：

- `.worktrees/test/node_modules → ../../node_modules` 建立成功，`test -e .../fakepkg/package.json` 為真。
- `unlink` 後主工作區 `node_modules` 完好。
- 直接 `git worktree remove --force`（未先 unlink）後主工作區 `node_modules` 仍完好；保留 unlink 第一步是防禦性設計，不是 macOS 的必要條件。

### 7.2 待做

1. **靜態檢查**：`node tools/check-structure.mjs`、`node tools/scan-forms.mjs`；確認四個 agent frontmatter 格式、POSIX 條目位置、三段式順序。
2. **YAML 載入**：`opencode debug agents` 確認 4 個 `frontend-devkit/*` agent 出現、沒有多餘條目。
3. **profile 值域（P11）**：用暫時 profile 測 `worktree 目錄: build/worktrees/` 與 `審核前綴: audit-`，確認 `init`／`inspect` 都拒絕並指出合法值；合法值可通過。
4. **平台守門（P13）**：手動把 `resolved.md` 檔頭的 `shell` 改成另一個值，確認 orchestrator／developer／reviewer 三個 agent 開工時停止並要求 `init compile`；`shell: TBD` 亦停止。`setup` 不套用此檢查（它是檔頭寫入者）。
5. **macOS 關卡 1～8**（依 `docs/acceptance.md` §13.2）：
   - 關 0：`mktemp -d` 建 app-a／app-b，`npm create vite@latest`、`npm install`、`npm run build`；記下 `pwd`／`pwd -P` 差異。
   - 關 1：agent／指令載入、POSIX 權限 allow／deny、edit deny；含 `pwd` DENIED、`pwd -P` EXECUTED。
   - 關 2：`init` 偵測 `shell=posix`、`depStrategy`、`resolved.md` 只含 POSIX worktree 段落與平台檔頭；P11 非法值拒絕。
   - 關 3：`compile`、`shasum` checksum、`inspect`、`resolved.md` 重建後檔頭仍正確。
   - 關 4：`dev` 全流程、symlink、七區段、清除 worktree；`unlink` 先行、主工作區 `node_modules` 完好。
   - 關 5：`review` 審核 worktree、`VERDICT`、清除；`review-` 前綴固定。
   - 關 6：降級（無 profile、`shell: TBD`、口述 gate）。
   - 關 7：安全地板（四種非法值、覆寫、豁免）。
   - 關 8：既有專案零影響。
6. **Windows 回歸**：至少在 Windows 上重跑 `node tools/check-structure.mjs` 與一次 `init compile`／worktree 建立清除（若無 Windows 機器，標「未驗」並在文件中如實註明；不可宣稱已驗）。
7. **文件一致性**：`grep -rn` 確認沒有殘留「僅 Windows／非 PowerShell 會拒絕」的現行規則；歷史段落（experiments R1、acceptance §13）保留但加註平台；確認沒有殘留 `<WT_LINK_TARGET>` 或自訂 worktree 目錄範例。

## 8. 風險與對策

| 風險 | 影響 | 對策 |
|---|---|---|
| POSIX scanner 對某些指令的拆句／引號行為與 PowerShell 不同 | 權限被誤拒或誤放 | R2 已實測核心指令；實作後用 `inspect [probe]` 與關卡 1 重驗；所有 allow 與程序指令字面同形 |
| `cp * .worktrees/*` 允許任意來源複製 | 機密檔被搬進 worktree | 與 Windows `Copy-Item *` 同等風險；profile 環境檔白名單＋提示詞紀律＋reviewer diff 檢查；不宣稱權限已擋死 |
| `pwd` 與 `pwd -P` 在 symlink／`/var` 別名下落點不同 | 合法的專案根被誤判、probe 失效 | 統一用 `pwd -P`；`pwd` 不進 allow；`setup`／reviewer／`init`／`inspect` 全部同字面（P12） |
| 固定 symlink 目標依賴「`.worktrees/` 在 repo 根下一層」 | 若 profile 被改成其他目錄，`../../node_modules` 會指錯 | P11 收緊 `worktree 目錄` 為唯一值 `.worktrees/`，`init`／`inspect` 拒絕其他值；建立後仍以 `test -e .../package.json` 驗證，錯即停止 |
| P11 是 breaking change，既有專案可能填了自訂目錄／前綴 | 升級後 `init` 失敗 | 錯誤訊息指出唯一合法值與修改方式；不自動改寫；CHANGELOG 標明 breaking change |
| 換平台後沒重跑 `init`，`resolved.md` 仍是另一平台的段落 | agent 用錯指令 | `resolved.md` 檔頭寫平台／shell（P13）；orchestrator／developer／reviewer 開工比對 `project.md`，不一致就停止並要求 `init compile`（`setup` 不套用） |
| `resolved.md` 進版控造成跨平台 diff | 版控噪音、誤以為壞掉 | 這是預期行為；檔頭記錄平台／shell；審查時把平台欄一起看，不把平台差異當回歸 |
| macOS `test -e` 對 symlink 的行為與 Linux 不同 | 驗證誤判 | 已實測 macOS `test -e` 對 symlink 目標為真；若目標不存在則 false，符合語意 |
| `git worktree remove --force` 在 Windows 仍可能跟隨 junction | 主工作區 node_modules 被刪 | 保留 Windows 的 `cmd /c rmdir` 第一步；文件與 agent 明確標示不可跳過 |
| 兩個平台 allow 條目讓白名單變長 | 維護成本、誤放風險 | 只新增具名、窄化條目；不新增通配；`check-structure.mjs` 檢查三段式順序 |
| `shell: posix` 被解讀成「已支援 Linux」 | 對 Linux 使用者過度承諾 | P3 明訂本次只驗 macOS；README 與 profile 註解寫「macOS 已驗、Linux 未驗」；acceptance 不設 Linux 關卡 |
| 工具 Node 版與 PS1 版行為漂移 | 檢查結果不一致 | Node 版以 PS1 為規格逐條移植；同一 commit 加測試資料；README 標明兩版等價 |

## 9. 實作順序（給規劃者）

1. **先改源頭素材**：`kit/worktree.procedures.md`（固定 `.worktrees/`、`../../node_modules`）、`kit/profile/project.template.md`（P11 值域、`shell`、POSIX 族）。
2. **再改四個 agent 的 frontmatter 與提示詞**（權限與程序要成對審；orchestrator／developer／reviewer 加入 P13 開工守門，`setup` 只負責寫入檔頭）。
3. **改三個指令檔**（init／inspect／review：`pwd -P`、P11 驗證、`resolved.md` 平台檔頭）。
4. **改權威文件**：`docs/permission-spec.md`（P14 §7.3.5#2 與主檔 §5.1.2／§7.1）。
5. **改其餘文件**（README、install、adding-a-project、experiments R2、acceptance §13.2、tui checklist、CHANGELOG、主檔修訂、implementation-plan 註記、migration-map 平台對照）。
6. **加 tools Node 版**（check-structure、scan-forms、normalize-forms）與 `.gitattributes`。
7. **跑靜態檢查與 macOS 關卡 1～8**，含 P11 非法值與 P13 守門；把結果寫進 acceptance／findings。
8. **Windows 回歸**（可用機器上）或如實標「未驗」。

每一步都要：
- 改完用 `grep` 回查平台字句，不留「僅 PowerShell」的現行規則，也不留 `<WT_LINK_TARGET>`／自訂 worktree 目錄範例。
- 權限 allow 與程序指令逐字對照，維持字面同形（特別是 `ln -s ../../node_modules ...` 與 `pwd -P`）。
- 不改 Windows 歷史段落；新增段落要標日期與平台。

## 10. 我已經決定、你可以改的細節

- `shell` 用 `posix` 而不是 `macos`：因為同一組指令也適用 Linux，且 `shell` 欄位描述的是 shell 方言不是 OS。但**本次只驗 macOS**，不宣稱 Linux 已支援。
- POSIX symlink 用**固定相對目標 `../../node_modules`**：`.worktrees/` 固定後，深度不必計算、不會有絕對路徑落盤、也不需 `realpath`。代價是不能再自訂 worktree 目錄（P11）。
- **P11 收緊 `worktree 目錄` 與審核前綴**：這是 breaking change，但靜態權限本來就只認 `.worktrees/*` 與 `review-*`；不收緊等於保留「寫得出來但跑不動」的矛盾。`init`／`inspect` 直接拒絕其他值，不自動改寫。
- POSIX 落點用 `pwd -P` 而不是 `pwd`：`/var` 與 `/private/var` 的別名會讓合法路徑被誤判；`pwd` 本身不進 allow（P12）。
- `compile` 只折入單一平台段落而不是兩段並列：避免 agent 用錯；代價是換平台要重跑 `compile`。
- `resolved.md` 保留進版控並加平台／shell 檔頭（P13）：orchestrator／developer／reviewer 開工比對，換平台沒重跑 `init` 就停止（`setup` 不套用）。只比 `shell`／平台欄，不重新算 checksum。
- POSIX 寫入／刪除／執行族只寫在權威清單（`docs/permission-spec.md` §7.3.5#2 與主檔 §5.1.2／§7.1），不散落在 kit 各檔（P14）。
- 保留 `.ps1` 工具而不是刪除：Windows 使用者與歷史腳本仍可用；Node 版是新增，不是取代。
- macOS 驗收另立 §13.2 而不是改寫 §13：保留 Windows 的歷史證據。

若以上任何一項要改，請在核准前說；核准後我會把這份設計交給規劃者拆成 `docs/plans/2026-11-14-macos-compatibility-plan.md`，再進入實作與審核。
