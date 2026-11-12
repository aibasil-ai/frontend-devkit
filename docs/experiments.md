# R1 實測結果（2026-11-11，OpenCode v2.2.7／Windows／PowerShell）

實驗場：`C:\Users\vipjo\AI\r1-probe`（探測專案）＋暫放全域的三個探測 agent（`agents/r1probe/probeA|B|C`，跑完已刪除；全域 `opencode.json` 已自備份還原）。
手法：agent 的 `permissions` 用**不存在的假指令**（`zzstatus`／`zzpkg`／`zzmd`／`zzjson`／`zzbad`）做地板 deny＋窄域 allow，再命它「照原字串執行」；**有送到 shell（即使回「無法辨識指令」）＝EXECUTED＝allow 生效**，被權限擋＝DENIED。假指令不會真的執行任何事，所以零副作用。

## 一、逐題結果

| # | 題目 | 實驗 | 結果 | 對 spec 的結論 |
|---|---|---|---|---|
| 1 | 尾綴 ` *` 是否匹配「無參數」形式 | allow `zzstatus *` → 跑 `zzstatus` | **EXECUTED** | ✅ 官方所述為真，`"cmd sub *"` 寫法可用 |
| 1b | 無空格形 `cmd*` 是否也匹配 | allow `Get-Location*` → 跑 `Get-Location` | **EXECUTED** | 兩種形都匹配；但 spec 仍規定 ` *` 形（較不易過寬，`zzpkg install *` 不會誤含 `zzpkg installfoo`） |
| 2 | 尾巴三段式：第 3 段能否翻回第 2 段 | allow `zzpkg *` → deny `zzpkg install *` → allow `zzpkg install --frozen *`；跑 `zzpkg install --frozen foo` | **EXECUTED** | ✅ **D20 三段式成立**（例外 allow 排最後確實生效） |
| 2b | 對照組 | 跑 `zzpkg install foo` | **DENIED** | ✅ 第 2 段 deny 壓住第 1 段寬 allow（分層正確） |
| 3 | **跨來源次序**：`opencode.json` 的 `agents.<id>.permissions` allow，能否生效於 `.md` frontmatter 已寫 `shell: * deny` 的 agent | `.md`：deny 地板＋allow `zzmd *`＋deny `zzbad *`；設定檔：allow `zzjson *`、allow `zzbad *` | `zzmd foo` EXECUTED；**`zzjson foo` DENIED**；`zzbad foo` DENIED | ❌ **方案 A 實測不通過**：agent `.md` 的規則排在設定檔之後，地板 deny 蓋掉專案端 allow。**kit 預設改為方案 B**（§7.3.0.1）；專案端**不得**再依賴追加 allow |
| 4 | PowerShell **括號子運算式** | allow `Write-Output *` → 跑 `Write-Output (Resolve-Path .).Path` | **DENIED** | ❌ 括號內的 `Resolve-Path .` 成為**次指令**、未被 allow 即全案拒 → §9.3 的 junction **必須走兩步寫法**（先 `Resolve-Path`、再把字面值代入下一條） |
| 5 | scanner 比對**原始字串**還是**重組字串** | allow `Resolve-Path -Path zzdir` → 跑 `Resolve-Path zzdir`（raw 形）；跑 `Resolve-Path -Path zzdir` | raw 形 **DENIED**；`-Path` 形 **EXECUTED** | ✅ **用原始字串逐字比對** → 程序檔與 allow 的指令字面**必須完全同形**（`X` 與 `X -Path Y` 是兩條規則） |
| 6 | `edit` 的 deny pattern 是否涵蓋各種路徑形 | deny `*opencode.json`、`*opencode.jsonc`、`*.opencode/*`、`*.git/*`，逐一試：根 `opencode.json`、根 `opencode.jsonc`、`.opencode/zz1.txt`、絕對 `C:/.../opencode.json`、`.git\hooks\zzhook`、`.worktrees\review-abc123\opencode.json` | 六種**全數 DENIED**；正常檔 `zzok.txt` EXECUTED | ✅ **D24／G2 的 pattern 組有效**（含 dot 開頭相對路徑、worktree 內副本、`.git/hooks`） |
| 7 | shell 資源是否做**反斜線正規化** | allow `cmd /c rmdir .worktrees/*`（斜線形）→ 跑 `cmd /c rmdir .worktrees\zztest`（反斜線） | **EXECUTED**（且 cmd 回「找不到檔案」，表示真的送到 shell） | ✅ **會正規化** → allow 只需**斜線一形**；撤銷第 4 輪「兩形並列」 |
| 7b | 但指令本身能否用斜線 | 跑 `cmd /c rmdir .worktrees/zztest2` | EXECUTED 權限層面通過，但 cmd 報 **`Invalid switch - "zztest2"`** | ⚠️ 對 `cmd /c`，**實際指令必須保留反斜線**（斜線被 cmd 當 switch）。故：allow 寫斜線形、程序檔指令寫反斜線形——兩者都對，不可「統一改斜線」 |
| 8 | （新）`$` 變數成員存取 | allow `Write-Output *` → 跑 `Write-Output $PSVersionTable.PSVersion.ToString()` | **DENIED** | ❌ §5.1.1#1 原探針寫法**根本跑不起來**；改用最簡 PowerShell 獨有 cmdlet：`Get-Location`（實測 EXECUTED 並回傳路徑），`cmd /c ver` 當交叉驗證 |

## 二、方法學警告（實作時必須知道）

1. **`opencode run` 的 shell 是在 service 綁定的專案目錄執行，不是呼叫端的 cwd**。本次即便我把 workdir 指到探測專案、也用 `--standalone`，`Get-Location` 仍回傳另一個專案（`TOS_Frontend`）的路徑。
   → 影響：任何「相對路徑」實驗要**先驗證實際落點**（用 `Get-Location` 當第一條）；涉及寫檔的實驗一律用**絕對路徑**。
   → 已查核：該專案的兩個未 commit 檔案（`.gitignore`、`src/data/settings/development.js`）mtime 為 2026-11-04，非本次實驗造成；實驗用的假指令與 `rmdir`（不存在的目錄）未對其產生任何寫入。
2. 專案本地 `.opencode/agents/*.md** 的 agent 在本次環境**無法被 `opencode run --agent` 找到**（同目錄、同格式的全域 agent 找得到；`--standalone`、根/`.opencode` 兩種 config 都試過）。這是**工具鏈限制**，不是 kit 的設計問題，但它擋死了「用專案端 config 追加 allow」這條驗證路——也正好是第 3 題用全域安裝形態測出「方案 A 不通過」的背景。
   → 待辦：實作階段要用**真實前端專案＋TUI 手動安裝**再驗一次第 3 題（若專案端 config 的 allow 在 TUI 形態下生效，方案 A 仍可保留為選項）。在此之前，kit 預設方案 B。
3. 實驗用完的暫放檔案已清理：`~/.config/opencode/agents/r1probe/` 刪除、`~/.config/opencode/opencode.json` 自備份還原（`agents` 鍵已消失）。備份留在 `C:\Users\vipjo\AI\r1-probe\global-opencode.json.bak`；探測專案 `C:\Users\vipjo\AI\r1-probe` 可整包刪。

## 三、spec 需要的五個定稿動作（本檔的行動清單）

1. §7.3.0／§7.3.5／§7.3.4／D13、D19：**預設改方案 B**；專案端 `opencode.json` 只留 `instructions` 註冊與 `model` 覆寫（第 3 題：allow 無效）。
2. §9.3：junction 程序**改為強制兩步**，並列明兩條個別 allow（`Resolve-Path *` 或精確形 ＋ `New-Item -ItemType Junction -Path * -Target *`），附回傳值注入防護（§7.3.0.1／原 #3 修法保留）。
3. §5.1.1#1：探針改 `Get-Location`（PowerShell 獨有、無 `$`），`cmd /c ver` 交叉驗證；`$PSVersionTable` 形列入「不可用」清單。
4. §7.1／§9.6：allow 只寫**斜線形**（實測會正規化）；程序檔的 `cmd /c` 指令**保留反斜線**（cmd 語法要求）。兩形並列的妥協撤銷。
5. §7.3.2／§15 R1：把「字面完全同形」升為語法紀律（第 5 題），並把 R1 從「待實測」改為「已實測，剩第 2 節 #2 那條待 TUI 覆驗」。
