# 安裝與升級

> 這份文件只講「怎麼裝、怎麼升、怎麼排查」。設定內容怎麼填見 [`adding-a-project.md`](adding-a-project.md)；權限模型的權威在 [`permission-spec.md`](permission-spec.md)。

## 0. 先決條件

| 項目 | 要求 | 怎麼確認 |
|---|---|---|
| 平台 | Windows + PowerShell | `Get-Location` 可用 |
| OpenCode | 實測 `v2.2.7` | `opencode --version` |
| 專案 | git repo | `git rev-parse --show-toplevel` |
| `.gitignore` | 含 `.worktrees/` | `git check-ignore -v .worktrees/`（退出碼 0＝已忽略） |

`.gitignore` 這一條不是美觀問題：`--working` 審核會把未追蹤檔案列入範圍，`.worktrees/` 沒被忽略時，worktree（含複製進去的 `.env`）會一起被看到，也容易被誤 commit。

## 1. 兩種裝法

### 1a. 專案層安裝（**建議**）

kit 只活在該專案的 `.opencode/` 底下，不影響其他專案。

```powershell
# 在 kit repo 根目錄
$kit = "kit"
$dst = "<你的專案>\.opencode"

# 先刪目標子目錄再整包複製（重要，見 §5）
foreach ($d in @("$dst\agents\frontend-devkit", "$dst\commands\frontend-devkit", "$dst\frontend-devkit\rules", "$dst\frontend-devkit\profile")) {
  if (Test-Path $d) { Remove-Item -Recurse -Force $d }
}
New-Item -ItemType Directory -Force -Path "$dst\agents\frontend-devkit", "$dst\commands\frontend-devkit", "$dst\frontend-devkit" | Out-Null

Copy-Item "$kit\agents\frontend-devkit" "$dst\agents\" -Recurse -Force
Copy-Item "$kit\commands\frontend-devkit" "$dst\commands\" -Recurse -Force
Copy-Item "$kit\rules" "$dst\frontend-devkit\" -Recurse -Force
Copy-Item "$kit\profile" "$dst\frontend-devkit\" -Recurse -Force
Copy-Item "$kit\worktree.procedures.md" "$dst\frontend-devkit\" -Force
```

驗證：

```powershell
Test-Path "$dst\agents\frontend-devkit\setup.md"       # True
Test-Path "$dst\frontend-devkit\rules\rules"           # False（若有＝巢狀安裝，見 §5）
```

**重啟 TUI 進程**，然後 `/frontend-devkit/init`。

### 1b. 全域安裝（**不建議**）

放進 `~/.config/opencode/`（Windows：`%USERPROFILE%\.config\opencode\`）可以讓所有專案共用，但有三個代價：

1. **雙份主體會疊加權限**：同一 id 若同時存在全域與專案兩份，permission 規則會附加，行為難以推理。
2. 版本只有一份，升級會同時影響所有專案。
3. 各專案仍需要自己的 `project.md`／`resolved.md`，共用主體只省了複製。

若仍要全域安裝，**不要**同時在專案裡放第二份 agent 主體。`inspect` 會檢查「是否同時存在全域與專案兩份」並警告。

## 2. 專案設定檔（`.opencode/opencode.json`）

方案 B 下，這份檔案**只准**兩類內容：

```json
{
  "instructions": [
    ".opencode/frontend-devkit/project.md",
    ".opencode/frontend-devkit/resolved.md"
  ]
}
```

- `instructions` 兩筆缺一不可：agent 靠它們看到 profile 與編譯產物。
- 可選 `agents.<id>.model`（不寫就繼承 session model）。
- **不要**寫 `permission`／`shell` 規則——在方案 B 下不會生效，只會製造「已放寬」的錯覺。

`kitRoot` 的合法值只有兩個（寫在 `project.md`）：

- `.opencode/frontend-devkit`（專案層安裝）
- `~/.config/opencode/frontend-devkit`（全域安裝）

指到別的地方 = 源頭比對基準被掉包，`init`／`inspect` 會拒絕。

## 3. 升級

```powershell
git pull                          # 更新 kit repo
# 依 §1a 的「先刪後複製」重裝到各專案的 .opencode/
# 重啟 TUI 進程
```

然後**每個專案**跑一次：

```text
/frontend-devkit/init compile
```

> ⚠️ **告警 ①**：升級後不重跑 `compile`，各專案的 `resolved.md` 會停在舊的 pack 正文與 checksum。`inspect` 會抓到漂移，但在你跑之前，agent 讀到的是舊規則。

## 4. 三個必須知道的告警

| # | 告警 | 為什麼 |
|---|---|---|
| ① | **升級後每個專案都要重跑 `init compile`** | `resolved.md` 是產物，不會自動更新；agent 只讀它 |
| ② | **不要用內建的 `build`（或其他 primary agent）跑 kit 任務** | kit 的權限是靠 `frontend-devkit/*` 主體的 frontmatter 生效的；換一個 agent 就換一套權限，可能做出你沒預期的寫入 |
| ③ | **任何 agent 都不准動 `.git/`** | developer 已 deny `*.git/*`；hook 之類的需求請在專案外自行處理，不要讓 agent 代寫 |

### shell 比對是「原始字串、字面同形」

scanner 會用**原始字串**逐字比對 allow 規則，也會把複合指令拆成子指令逐一比對。實務後果：

- `git status --short` ✅ 命中 `git status *`
- `git status --short; echo "---"` ❌ 因為 `echo` 不在清單，整串被拒
- `git diff HEAD | git hash-object --stdin` ❌ 除非兩段都 allow
- `New-Item … -Target (Resolve-Path node_modules).Path` ❌ 括號內子指令要個別 allow → 必須拆兩步（先 `Resolve-Path`、再把字面路徑代入）

所以：**一個 call 一條指令**，需要多步驟就拆開。

## 5. 安裝紀律：一律「先刪目標子目錄、再整包複製」

PowerShell 的 `Copy-Item <來源目錄> <已存在的同名目錄> -Recurse` 會把來源放**進**目標，產生：

```text
.opencode/frontend-devkit/rules/rules/
.opencode/frontend-devkit/profile/profile/
```

這比「雜亂」嚴重：巢狀副本是**舊版**。若哪天被當成源頭折入，`resolved.md` 的 checksum 反而會對得上，源頭比對等於失效。

`inspect` 會檢查並列出完整路徑，但**不會自行刪除**（那是安裝殘留，不在 agent 的可寫範圍）。

## 6. `opencode run` 與 shell 落點

實測（見 [`experiments.md`](experiments.md)）：shell 落在 **service 綁定的專案目錄**，`--server`、`--standalone`、呼叫端 cwd 都改不了它。因此：

- 自動化腳本驅動 kit 流程時，指令可能在**錯的專案**執行。
- 任何 agent 在動手前都必須先 `Get-Location` 確認落點（`inspect` 的 probe 第 0 條就是這件事）。
- 驗收與正式操作請在目標專案的 TUI 手動跑。

## 7. 方案 A 覆驗的三步先決（僅在你要改回方案 A 時）

方案 B 是現行預設。若你打算把 shell 規則搬回專案端設定檔（方案 A），必須先依序完成：

1. **確認 scanner 對 jsonc 規則的解析**與 agent frontmatter 一致（同樣是原始字串比對）。
2. **確認多來源（全域＋專案）的合成順序**符合預期（誰覆蓋誰）。
3. **用 `inspect probe` 實測**：清單內 gate＝allow、寫入性指令＝deny；任一不符就回復方案 B。

未完成這三步之前，不要把任何 shell 規則寫進專案端設定檔。
