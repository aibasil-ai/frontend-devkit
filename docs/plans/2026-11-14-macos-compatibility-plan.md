# frontend-devkit 雙平台相容實作計畫（Windows + macOS）

- 日期：2026-11-14
- 依據：`docs/specs/2026-11-14-macos-compatibility-design.md`（已核准，P1–P14 定案；本計畫與其衝突時以設計文件為準）
- 狀態：已實作（2026-11-15）；驗收部分通過（關 0 通過、關 1／2 部分通過、關 3～8 待 TUI；Windows 回歸未驗）

## Goal

同一份 kit 素材在 macOS（zsh／bash）上完整跑通 `init` → `dev`／`fix` → `review`／`review-fix` → worktree 建立／清除 → commit 前人工審核，並讓 repo 健檢工具可在 macOS 執行；Windows PowerShell 路徑與既有驗收紀錄一律保留且行為不變。

## Architecture

- **平台抽象層**：`kit/worktree.procedures.md` 改為「共用規則＋powershell 段落＋posix 段落」；`setup` 的 `compile` 依 profile `shell` 只折入對應平台段落（P6），`shell: TBD（未確認）` 時折入警告並停用 worktree 程序。
- **雙平台權限並存**：四個 agent 的 frontmatter 同時保留 Windows 與 POSIX allow 條目（P7），不刪任何既有條目；POSIX 的 `ln -s`／`unlink` 來源與目的地收窄到固定字面（P8）。
- **欄位語意**：`depStrategy: junction` 欄位值不變，平台語意分岔（Windows junction／macOS 固定相對 symlink `../../node_modules`，P2／P4）；`shell` 值域擴充為 `powershell`／`posix`／`TBD（未確認）`（P3）。
- **平台守門**：`resolved.md` 檔頭新增 `平台`／`shell` 欄；orchestrator／developer／reviewer 三個 agent 開工第 0 步比對 `project.md`，不一致即停止要求 `init compile`（P13；`setup` 為寫入者，不套用）。
- **breaking change（P11）**：`worktree 目錄` 唯一合法值 `.worktrees/`、審核前綴唯一合法值 `review-`；`init`／`inspect` 拒絕其他值、不自動改寫。
- **落點判定**：POSIX 一律 `pwd -P` 比對 `git rev-parse --show-toplevel`（P12），`pwd` 不進 allow。
- **工具雙軌**：`tools/*.ps1` 保留；新增零依賴 Node.js `.mjs` 版（P9），兩版等價。
- **驗收**：macOS 另立 `docs/acceptance.md` §13.2（P10），不覆蓋 §13 的 Windows 歷史；Windows 回歸無機器時如實標「未驗」。

## Tech Stack

- 純 Markdown 素材＋agent YAML frontmatter（`permissions: [{action, resource, effect}]`）＋零依賴 Node.js `.mjs` 工具。
- 非編譯專案：無 npm 依賴、無 third-party CLI（設計 §2 非目標 3）。
- 本 repo 是文件素材庫，「測試」＝`node tools/*.mjs` 靜態檢查、`opencode debug agents` 載入檢查、`grep -rn` 字句回查、以及 macOS TUI 實測（`docs/acceptance.md` §13.2）；不是單元測試。
- 文件內容一律正體中文（台灣用詞）、半形標點；frontmatter YAML 風格與既有 agent 一致（2 空格縮排、`#` 註解、禁 `//`、值不用方括號）。

## Spec 路徑

- 本次決策來源（唯一）：`docs/specs/2026-11-14-macos-compatibility-design.md`
- 被修訂的主檔與附檔：`docs/specs/2026-11-11-frontend-devkit-design.md`、`docs/permission-spec.md`、`docs/acceptance.md`、`docs/acceptance-findings.md`、`docs/experiments.md`、`docs/install.md`、`docs/adding-a-project.md`、`docs/tui-run-checklist.md`、`docs/CHANGELOG.md`、`docs/implementation-plan.md`、`docs/migration-map.md`、`README.md`
- 不變：`kit/rules/*`、`docs/writing-a-pack.md`、方案 B／D18／D21／D22／D24、三段式第三段的不可變安裝例外位置。

## Global Constraints（依設計 §2 與 P1–P14 摘錄；違反任一條即為計畫缺陷）

1. 不引入 `node -e`／`python -c`／`sh -c` 之類動態求值繞過 scanner（反目標 1）；權限維持「靜態白名單、字面同形、尾巴三段式」。
2. 不放寬成 `*` 或 `npm run *` 涵蓋式 allow（反目標 2）。
3. 絕對路徑／個人路徑不寫進 kit 素材（反目標 3）；主工作區一律執行期 `git rev-parse --show-toplevel`。
4. macOS 不直接 `rm -rf` worktree 的 `node_modules` 或 worktree 目錄（反目標 4）；清除一律「先 `unlink`／`cmd /c rmdir`、再 `git worktree remove --force`」（P5）。
5. Windows 路徑保留且行為不變：`cmd /c rmdir` 反斜線形、junction 兩步與注入防護、`Get-Location`／`Test-Path`／`Get-FileHash`／`Select-String` 條目全保留（P1／P7）。
6. `depStrategy: junction` 欄位值不變（P2）；macOS 用**固定相對目標 `../../node_modules`**，不做 `realpath`、不代入任何路徑（P4）。
7. `shell` 值域 `powershell`／`posix`／`TBD（未確認）`；本次只驗 macOS，不宣稱 Linux 支援（P3）。
8. `compile` 依 `shell` **只折入對應平台段落**，不得兩段並列；`TBD` 時折入警告並停用 worktree 程序（P6）。
9. POSIX 的 `ln`／`unlink` allow 收窄：`ln -s ../../node_modules .worktrees/*/node_modules`、`unlink .worktrees/*/node_modules`；來源固定後不再有 `<WT_LINK_TARGET>` 佔位符（P8）。
10. `.ps1` 工具保留、Node `.mjs` 版為新增且零依賴（P9）。
11. macOS 驗收另立 `docs/acceptance.md` §13.2，不覆蓋 §13 與 `docs/experiments.md` R1 的 Windows 紀錄（P10）。
12. `worktree 目錄` 唯一合法值 `.worktrees/`、審核前綴唯一合法值 `review-`；`init`（含重跑）與 `inspect` 對其他值一律報錯並指明合法值，不提供相容模式、不自動改寫（P11，breaking change）。
13. 落點檢查一律 `pwd -P`（POSIX）／`Get-Location`（Windows）；`pwd` 不進 allow（P12）。
14. `resolved.md` 檔頭新增 `平台`（`windows`／`macos`）與 `shell`（`powershell`／`posix`）欄；orchestrator／developer／reviewer 三個 agent 開工比對 `project.md`，不一致或 `TBD` → 停止並要求 `/frontend-devkit/init compile`，不得自行改寫 `resolved.md`（P13；`setup` 為寫入者，不套用）。
15. POSIX 寫入／刪除／執行族權威清單只寫一處：`docs/permission-spec.md` §7.3.5#2，主檔 §5.1.2／§7.1 只連結不重列（P14）。
16. 非目標：不支援 fish；不改流程模型（三層知識、4 個 agent、6 個指令、pack 機制）；不新增 npm 依賴；不改既有 Windows 驗收結論。

## 任務總覽（依設計 §9 順序）

| # | 任務 | 一句話 |
|---|---|---|
| 1 | 源頭素材 | `worktree.procedures.md` 雙平台段落化、`project.template.md` 值域與 P11 收緊 |
| 2 | 四個 agent | frontmatter 增 POSIX allow（§5.1–5.4）、提示詞平台中性化、P13 開工守門 |
| 3 | 三個指令 | `init`／`inspect`／`review` 的 `pwd -P`、P11 拒絕、`resolved.md` 平台檔頭、平台中性清除 |
| 4 | 權威文件 | `permission-spec.md` §7.3.5#2 POSIX 族權威清單＋主檔 §5.1.2／§7.1 連結 |
| 5 | 其餘文件 | README／install／adding-a-project／experiments R2／acceptance §13.2（待驗）／tui checklist／CHANGELOG／主檔其餘修訂／implementation-plan 註記／migration-map 對照 |
| 6 | tools Node 版 | `check-structure.mjs`／`scan-forms.mjs`／`normalize-forms.mjs`＋`tools/README.md`＋`.gitattributes` |
| 7 | 驗證與收尾 | 靜態檢查、macOS 關卡 0–8、P11 非法值、P13 守門、結果寫入 acceptance §13.2／findings、Windows 回歸或標未驗 |

---

## 任務 1　源頭素材（worktree 程序檔＋profile 範本）

**Scope**：把程序檔與範本改成「雙平台來源」；後續所有任務的欄位名、指令字面、段落名都以本任務為準。

**Files**
- Modify：`kit/worktree.procedures.md`
- Modify：`kit/profile/project.template.md`

**Interfaces（本任務產出，後續任務引用）**
- `worktree.procedures.md` 段落名（`compile`／`inspect` 的折入選擇依據）：`## 1. 共用規則（兩平台一致）`、`## 2. 平台段落 powershell`、`## 3. 平台段落 posix`。
- POSIX 指令字面（與任務 2 的 allow 字面**逐字同形**）：
  - 建立連結：`ln -s ../../node_modules .worktrees/<名稱>/node_modules`
  - 移除連結：`unlink .worktrees/<名稱>/node_modules`
  - 存在性檢查：`test -e .worktrees/<名稱>`、`test -e .worktrees/<名稱>/node_modules/<框架套件>/package.json`
  - 複製環境檔：`cp <環境檔> .worktrees/<名稱>/<環境檔>`
- profile 欄位合法值：`shell` ∈ ｛`powershell`、`posix`、`TBD（未確認）`｝；`worktree 目錄`＝`.worktrees/`（唯一）；審核前綴＝`review-`（唯一）；`## 安裝紀錄` 的 probe 第 0 條列改為 `pwd -P`（posix）／`Get-Location`（powershell）；`## 額外 shell` 新增一列指向權威清單（`docs/permission-spec.md` §7.3.5#2）。

**Steps**
- [x] 1a 重寫 `kit/worktree.procedures.md` 為「共用規則＋powershell／posix 兩段落」；POSIX symlink 目標固定 `../../node_modules`；移除 `<WT_DIR>`、`<WT_LINK_TARGET>`、`<REVIEW_PREFIX>` 佔位符（直接寫 `.worktrees/<名稱>`、`review-<sha7>`）；保留 `<BR_PREFIX_DEV>`／`<BR_PREFIX_FIX>`／`<ENV_FILES>`／`<DEP_INSTALL>` 佔位符。
  - 驗：`grep -n '<WT_DIR>\|<WT_LINK_TARGET>\|<REVIEW_PREFIX>' kit/worktree.procedures.md` → 0 命中；`grep -n '<BR_PREFIX_DEV>\|<ENV_FILES>\|<DEP_INSTALL>' kit/worktree.procedures.md` → 仍存在。
- [x] 1b 依設計 §4.2 表格落七個動作的雙平台對照（取得主工作區／存在性／建連結／驗連結／複製環境檔／移除連結／移除 worktree／列 worktree）；§4.5 清除順序五步寫進共用規則；POSIX 段落明確「不可用 `rm -rf`」。
  - 驗：POSIX 段落行範圍內 `grep -n 'cmd /c\|Get-Location\|Test-Path\|Copy-Item\|New-Item\|Resolve-Path' kit/worktree.procedures.md` → 0 命中（平台段落不得混用）；powershell 段落行範圍內 `grep -n 'pwd\|uname\|shasum\|ln -s\|unlink\|test -e\|cp '` → 0 命中。
- [x] 1c 更新 `kit/profile/project.template.md`：`shell` 列值域改三值並標偵測方式（先 `uname -s`、後 `Get-Location`，兩者皆敗 → `TBD（未確認）` 並用 `question`）；`worktree 目錄` 列註唯一合法值 `.worktrees/`；`worktree 名稱前綴` 列註審核前綴唯一 `review-`；四欄白名單表 `worktree 目錄` 列改唯一值、移除 `/abs` 自訂例；`depStrategy` 列補平台語意（macOS＝symlink）；移除「非 PowerShell 時 kit 的 worktree 程序會停止」舊後果字句，改寫 `TBD` 的後果；`## 額外 shell` 加一列「POSIX 寫入／刪除／執行族（權威清單見 `docs/permission-spec.md` §7.3.5#2）」。
  - 驗：`grep -n 'posix\|.worktrees/\|review-' kit/profile/project.template.md` 人工逐行核對值域描述與設計 §4.6 一致；`grep -n '僅 PowerShell\|只有 PowerShell' kit/profile/project.template.md` → 0。

**Risks**：`<ENV_FILES>` 佔位符保留與否若被誤刪會讓 compile 找不到環境檔清單來源；1a 的 grep 即是防線。段落名一旦定稿，任務 2 的 `setup` §4 必須引用同一字面。

---

## 任務 2　四個 agent（frontmatter＋提示詞＋P13 守門）

**Scope**：權限與程序成對審——每新增一條 allow，程序檔或提示詞裡必須有逐字同形的指令字面。

**Files**（皆 Modify）
- `kit/agents/frontend-devkit/orchestrator.md`
- `kit/agents/frontend-devkit/developer.md`
- `kit/agents/frontend-devkit/reviewer.md`
- `kit/agents/frontend-devkit/setup.md`

**Interfaces（本任務產出）**
- 五組 POSIX allow 字面（設計 §5.1–5.4，原樣抄錄；放在既有「放行」區塊內、尾巴三段式**之前**）：
  - orchestrator：`pwd -P`、`test -e *`、`ln -s ../../node_modules .worktrees/*/node_modules`、`cp * .worktrees/*`、`unlink .worktrees/*/node_modules`
  - developer：`pwd -P`、`test -e *`
  - reviewer：`pwd -P`、`test -e .worktrees/review-*`、`ln -s ../../node_modules .worktrees/review-*/node_modules`、`cp * .worktrees/review-*`、`unlink .worktrees/review-*/node_modules`
  - setup：`pwd -P`、`uname -s`、`test -e *`、`shasum -a 256 *`、`grep -n *`
- `resolved.md` 檔頭新欄位（本任務定義、任務 3 指令引用）：條列行 `- 平台：windows | macos`、`- shell：powershell | posix`，由 `compile`／`inspect` 依偵測結果寫入。
- P13 守門行為：orchestrator／developer／reviewer 開工檢查加一項——`project.md` 的 `shell` 與 `resolved.md` 檔頭 `shell`／`平台` 不一致、或 `shell: TBD（未確認）` → 停止，要求 `/frontend-devkit/init compile`；不自行改寫。
- 提示詞平台中性：把「bash 一律用 `workdir`」等「bash」措辭改「shell」；移除「僅 PowerShell」現行規則字句。

**Steps**
- [x] 2a orchestrator：frontmatter 增五條（上表）；§0 開工檢查加平台守門（P13）；§2 派工「bash」→「shell」；§4 改動 `package.json` 的處理改分平台（先 `unlink` 或先 `cmd /c rmdir`，依 `resolved.md` 平台段落）；§5 口述 gate 模式的 junction 先驗改 `Test-Path node_modules`／`test -e node_modules`；§6 PASS 後清除改「依 `resolved.md` 平台段落」。
  - 驗：五條 allow 在 `---` 內、且在 `git push *` deny 行之前（`grep -n` 行號人工對照）；`grep -n '僅 PowerShell\|只有 PowerShell' kit/agents/frontend-devkit/orchestrator.md` → 0；`grep -n 'ln -s ../../node_modules'` 在程序敘述與 allow 各至少 1 命中且字面相同。
- [x] 2b developer：frontmatter 增 `pwd -P`、`test -e *`；§1／§2 加平台守門（P13）；「bash」→「shell」；Windows deny 全保留。
  - 驗：`grep -c 'Remove-Item \*' kit/agents/frontend-devkit/developer.md` 與變更前相同（不得刪條目）；兩條新 allow 在尾巴三段式之前。
- [x] 2c reviewer：frontmatter 增五條（上表，收窄到 `review-*`）；§0 寫入性紀律加 POSIX 對照（`unlink` 只限 `.worktrees/review-*/node_modules`、不得 `rm`）；§1／§3 的 `Test-Path`／`cmd /c rmdir`／`Copy-Item` 改平台對照；§3 清除程序分平台（`unlink` 先行）；§2 加平台守門（P13）。
  - 驗：`grep -n 'unlink .worktrees/review-\*/node_modules\|ln -s ../../node_modules .worktrees/review-\*/node_modules'` 與 §5.3 字面逐字相同；`grep -n 'cmd /c rmdir'` 仍在（Windows 對照保留）。
- [x] 2d setup：frontmatter 增五條（上表，含 `uname -s`、`shasum -a 256 *`、`grep -n *`）；§1 先決檢查 shell 偵測改「`uname -s` 成功且輸出 `Darwin`／`Linux` → `posix`；否則 `Get-Location` 成功 → `powershell`；皆敗 → `TBD（未確認）` 並 `question`」；落點改 `pwd -P`／`Get-Location`（P12，比對 `git rev-parse --show-toplevel`）；§2 的 `depStrategy` 先驗改 `test -e node_modules`／`Test-Path node_modules`、`shell` 值域加 `posix`；§4 compile 依 `shell` 擇一折入平台段落（P6）、`TBD` 時折入停用警告、檔頭加 `平台`／`shell` 欄（P13）、checksum 仍對 `worktree.procedures.md` 整檔計算；§5 inspect 重建內文用同一選擇規則並寫平台檔頭；§6 probe 第 0 條依 `shell` 派 `pwd -P` 或 `Get-Location`；§7 升級固定動作補 macOS 的 `cp -R` 巢狀警告。
  - 驗：`grep -n 'uname -s\|shasum -a 256\|grep -n\|pwd -P\|test -e' kit/agents/frontend-devkit/setup.md` 位置合理；`grep -n 'Get-FileHash\|Select-String\|Test-Path\|Get-Location'` 仍在（Windows 保留）；`grep -n '平台：\|shell：'` 在 §4 檔頭規格處命中。

**Risks**：allow 字面與程序字面一字之差即失效（字面同形鐵律）——每條都用 grep 貼對照後才過；`pwd -P` 的 allow 若誤寫成 `pwd -P *` 或 `pwd *` 皆為違規（P12），任務 7 關卡 1 會用實測再驗。

---

## 任務 3　三個指令檔（init／inspect／review）

**Scope**：指令檔引用任務 2 定義的欄位與行為；不新增任何欄位名。

**Files**（皆 Modify）
- `kit/commands/frontend-devkit/init.md`
- `kit/commands/frontend-devkit/inspect.md`
- `kit/commands/frontend-devkit/review.md`

**Interfaces（本任務產出）**
- P11 拒絕行為的對外表述：`init`（含重跑）與 `inspect` 發現 `worktree 目錄` ≠ `.worktrees/` 或審核前綴 ≠ `review-` → 拒絕並**指明唯一合法值**、要求使用者改 `project.md` 後重跑；錯誤訊息須含「`.worktrees/`」與「`review-`」兩個字面。
- probe 第 0 條平台對照：posix → `pwd -P` 與 `git rev-parse --show-toplevel` 比對；powershell → `Get-Location`（P12）。
- `review` 的清除語句：posix → 先 `unlink .worktrees/review-<sha7>/node_modules`；powershell → 先 `cmd /c rmdir .worktrees\review-<sha7>\node_modules`；再 `git worktree remove --force .worktrees/review-<sha7>`。

**Steps**
- [x] 3a `init.md`：共同要求第 1 條開工落點檢查改平台對照（依 profile `shell` 選 `pwd -P` 或 `Get-Location`）；新增 P11 檢查條（`worktree 目錄`、審核前綴非法值 → 拒絕、指明合法值、不自動改寫）。
  - 驗：`grep -n 'pwd -P\|.worktrees/\|review-' kit/commands/frontend-devkit/init.md` 命中且語意為「合法值／拒絕」；`grep -n 'Get-Location' kit/commands/frontend-devkit/init.md` 仍在（Windows 對照）。
- [x] 3b `inspect.md`：`probe` 第 0 條改平台對照；`report` 加「重建 `resolved.md` 內文時寫 `平台`／`shell` 檔頭（同 setup §4 規則）與 P11 值檢查」。
  - 驗：`grep -n 'pwd -P\|平台\|shell' kit/commands/frontend-devkit/inspect.md` 命中位置正確。
- [x] 3c `review.md`：末條清除改「依 `resolved.md` 平台段落」分平台語句；審核前綴固定 `review-`（刪去任何「可自訂」暗示）。
  - 驗：`grep -n 'unlink\|cmd /c rmdir\|review-' kit/commands/frontend-devkit/review.md` 命中；`grep -n '自訂\|可改' kit/commands/frontend-devkit/review.md` → 0。

**Risks**：`dev.md`／`fix.md`／`review-fix.md` 不在本任務範圍（設計 §6.1 未列）；若實作時發現其中出現「僅 PowerShell」現行規則字句，回報並由任務 7 的 grep 統一檢出處理。

---

## 任務 4　權威文件（permission-spec §7.3.5#2＋主檔 §5.1.2／§7.1）

**Scope**：POSIX 寫入／刪除／執行族的**唯一權威清單**落在此處（P14）；主檔只連結、不重列。

**Files**（皆 Modify）
- `docs/permission-spec.md`
- `docs/specs/2026-11-11-frontend-devkit-design.md`（僅 §5.1.2、§7.1 兩節；其餘修訂在任務 5）

**Interfaces（本任務產出）**
- 新小節標題：`#### 7.3.5#2 POSIX 寫入／刪除／執行族（權威清單）`。
- 權威清單（本計畫定稿；`setup` 的 gate 寫入性檢查與各 agent 尾巴第 1 段以本清單為正典）：
  - 檔案系統寫刪：`rm *`、`mv *`、`touch *`、`mkdir *`、`rmdir *`、`sed -i *`、`dd *`、`tee *`、`chmod *`、`chown *`、`chgrp *`、`xattr *`、`truncate *`
  - 任意執行／動態求值：`sh -c *`、`bash -c *`、`zsh -c *`、`node -e *`、`python -c *`、`python3 -c *`、`perl -e *`、`ruby -e *`、`php -r *`
  - **不得列入**：`ln -s`、`unlink`、`cp`（三者有窄化 allow 需求，進 deny 族會被尾巴翻掉 allow）。
- 主檔 §5.1.2 值域更新：`shell` ∈ ｛`powershell`、`posix`、`TBD（未確認）`｝；`worktree 目錄` 唯一值 `.worktrees/`；審核前綴唯一值 `review-`（D23 修訂）；並以一句話連結權威清單。
- 主檔 §7.1 尾巴段：加一句「POSIX 寫入／刪除／執行族以 `permission-spec.md` §7.3.5#2 為正典，各 agent 尾巴第 1 段同步 deny」，不重列整份。

**Steps**
- [x] 4a `permission-spec.md`：事實 6 加「POSIX shell 指令亦可被 scanner 匹配（R2 實測見 `experiments.md`）」；§7.3.2 語法紀律表加 POSIX 對照列（`$()`／括號子運算式禁用、`test -e`、`shasum`、`ln`／`unlink` 收窄形、`cp` 來源紀律、`grep -n` 引號參數）；§7.3.3 範例加 POSIX 條目；新增 §7.3.5#2 權威清單（上表＋一句「本清單是 `## 指令`／`## 額外 shell` 寫入性檢查與各 agent 尾巴第 1 段的唯一正典」）。
  - 驗：`grep -n '7.3.5#2' docs/permission-spec.md` 命中；`grep -n 'mv \*\|chmod \*\|tee \*\|sh -c \*\|node -e \*' docs/permission-spec.md` 逐條在權威清單段落內。
- [x] 4b 主檔 §5.1.2：更新值域與唯一值（上表）；格式驗證欄與白名單表同步。
  - 驗：`grep -n 'posix\|.worktrees/\|review-' docs/specs/2026-11-11-frontend-devkit-design.md` 命中的 §5.1.2 行與設計 §4.6 一致。
- [x] 4c 主檔 §7.1：四個 agent 列各加 POSIX allow 增量摘要；尾巴段加 POSIX 族引用句。
  - 驗：`grep -n '7.3.5#2' docs/specs/2026-11-11-frontend-devkit-design.md` ≥2 命中（§5.1.2 與 §7.1）。

**Risks**：權威清單條目若在任務 2 的 agent frontmatter 未對應（寫入性檢查擋下的字面必須與尾巴 deny 同形）——4a 驗收 grep 已要求逐條對照；`rmdir *` 與既有 allow `cmd /c rmdir .worktrees/*` 不衝突（R1 第 7 題證明 scanner 對 `cmd /c …` 按整串比對、不拆出 `rmdir` 子指令），若關卡 1 實測出現誤拒，以實測為準回報修訂。

---

## 任務 5　其餘文件（docs／README）

**Scope**：依設計 §6.2 逐檔補 macOS；歷史段落一律保留並加註日期／平台。

**Files**（皆 Modify）
- `README.md`
- `docs/install.md`
- `docs/adding-a-project.md`
- `docs/experiments.md`
- `docs/acceptance.md`
- `docs/tui-run-checklist.md`
- `docs/CHANGELOG.md`
- `docs/specs/2026-11-11-frontend-devkit-design.md`（§5.1.2／§7.1 以外的小節）
- `docs/implementation-plan.md`
- `docs/migration-map.md`

**Interfaces（本任務產出，任務 7 引用）**
- `docs/acceptance.md` 新節標題：`## 13.2 macOS 關卡 0～8（2026-11-14，狀態：部分通過（2026-11-15 複驗）；其餘待 TUI）`——關卡定義依設計 §7.2 第 5 點：關 0 `mktemp -d`＋`npm create vite@latest`＋`pwd`／`pwd -P` 差異記錄；關 1 載入與 POSIX 權限（含 `pwd` DENIED、`pwd -P` EXECUTED）；關 2 `init` 偵測 `shell=posix`＋`resolved.md` 只含 POSIX 段落與平台檔頭＋P11 拒絕＋P13 平台守門；關 3 `compile`／`shasum`／`inspect` 重建後檔頭正確；關 4 `dev` 全流程＋symlink＋七區段＋清除（`unlink` 先行、主工作區 `node_modules` 完好）；關 5 `review` 審核 worktree＋`VERDICT`＋`review-` 前綴；關 6 降級（無 profile、`shell: TBD`、口述 gate）；關 7 安全地板（四種非法值、覆寫、豁免）；關 8 既有專案零影響。
- `docs/experiments.md` 新段標題：`## R2：2026-11-14 macOS 實測`（R1 段標題加註「Windows 歷史」）。
- `docs/CHANGELOG.md` 新段：`## 2026-11-14 雙平台（macOS）`（P1–P14 摘要、P11 標 breaking change、檔案清單、驗收狀態「見 acceptance §13.2」）。
- `docs/migration-map.md` 新增一列「平台對照（PowerShell → POSIX）」並標「歷史遷移圖不因平台改寫」。

**Steps**
- [x] 5a `README.md`：需求平台列改「Windows PowerShell／macOS zsh-bash」；安裝最短版加 macOS 指令；疑難排解加 macOS 列（`pwd` 被拒、落點用 `pwd -P`）；`junction` 說明補 macOS symlink；標明 `.worktrees/`／`review-` 為固定值（P11 breaking change）；驗收狀態加 macOS 指引。
  - 驗：`grep -n 'macOS\|posix\|symlink' README.md` 命中位置合理；`grep -n 'Windows + PowerShell（worktree 程序只有 PowerShell 版' README.md` → 0。
- [x] 5b `docs/install.md`：§1a 加 macOS 指令塊（`rm -rf` 目標子目錄、`mkdir -p`、`cp -R`）＋`cp -R` 巢狀警告；§0 平台列；驗證改 `test -f`／`test ! -e`；「shell 比對」加 POSIX 例；§6 落點改 `pwd -P` 對照；§1b 全域路徑加 `~/.config/opencode`。
  - 驗：`grep -n 'cp -R\|pwd -P\|test -f' docs/install.md` 命中；`grep -n '僅 PowerShell\|只有 PowerShell' docs/install.md` → 0（歷史語句除外）。
- [x] 5c `docs/adding-a-project.md`：2b `depStrategy` 表補 macOS symlink 列；先驗改 `test -e node_modules`；§6 常見卡點加 macOS；工作目錄／審核前綴唯一值（`init` 會拒絕其他值）。
  - 驗：`grep -n 'symlink\|test -e\|.worktrees/\|review-' docs/adding-a-project.md` 命中。
- [x] 5d `docs/experiments.md`：新增「R2：2026-11-14 macOS 實測」段——環境（OpenCode v2.2.7、Darwin 25.5.0、zsh）、POSIX scanner 實測表（逐條搬設計 §7.1 的 13 條結果與路徑別名實測）、symlink＋`git worktree remove --force` 實測、報表；R1 段保留並標「Windows 歷史」。
  - 驗：`grep -n 'R2\|Darwin\|/private/var' docs/experiments.md` 命中；R1 段原表格一字未動（與 HEAD diff 只新增、不刪改）。
- [x] 5e `docs/acceptance.md`：新增 §13.2 關卡 0～8 定義表（狀態「待驗」；§13.1 與缺陷索引一字不動）。
  - 驗：`grep -n '13.2' docs/acceptance.md` 命中且 §13.1 內容未改。
- [x] 5f `docs/tui-run-checklist.md`：新增 macOS 清單段（`pwd -P`、`shell=posix`、`ln -s ../../node_modules`、`unlink`）；Windows 清單保留。
- [x] 5g `docs/CHANGELOG.md`：新增 2026-11-14 段（P1–P14、P11 breaking change、檔案清單、驗收狀態待填）。
- [x] 5h 主檔其餘修訂：檔頭加「2026-11-14 雙平台修訂」連結本設計；非目標第 1 條；D8、D23 行；§5.1.1#1 shell 偵測；§9 分平台；§11 降級表的 shell 列。歷史段落保留。
  - 驗：`grep -n '2026-11-14\|posix' docs/specs/2026-11-11-frontend-devkit-design.md` 命中；`grep -rn '僅 PowerShell（worktree 程序' docs/specs/` → 0（非目標第 1 條須改寫為新語意）。
- [x] 5i `docs/implementation-plan.md`：檔頭加註「此為 2026-11-12 Windows-only 歷史計畫；雙平台實作見 `docs/plans/2026-11-14-macos-compatibility-plan.md`」。
- [x] 5j `docs/migration-map.md`：加平台對照列（PowerShell → POSIX），標明歷史遷移圖不因平台改寫。
- [x] 5k 全文件殘留檢查（本任務收尾）：
  - `grep -rn '僅 PowerShell\|只有 PowerShell 版\|非 Windows 會拒絕' docs/ README.md kit/` → 命中的僅限「歷史段落／修訂註記」（experiments R1、acceptance §13.1、implementation-plan 檔頭、CHANGELOG 歷史），現行規則 0 命中。
  - `grep -rn 'build/worktrees\|audit-' docs/ kit/` → 僅限「非法值範例」標註處。
  - `grep -rn '§' docs | grep -v '§7.3.5#2'` 與主檔「0. 檔案地圖」逐行核對引用未斷裂。

**Risks**：批量加 macOS 段落時誤改 Windows 歷史段——5d／5e 的「只新增、不刪改」驗收是防線；引用斷裂（改一處忘三處）用 5k 的 § grep 對照。

---

## 任務 6　tools Node 版（.mjs）

**Scope**：以 `.ps1` 為規格逐條移植；`.ps1` 一律保留（P9）。

**Files**
- Create：`tools/check-structure.mjs`
- Create：`tools/scan-forms.mjs`
- Create：`tools/normalize-forms.mjs`
- Modify：`tools/README.md`
- Modify：`.gitattributes`

**Interfaces（本任務產出，任務 7 引用）**
- CLI（零依賴、零參數或單一參數；路徑以 `import.meta.url` 相對 repo 根解析）：
  - `node tools/check-structure.mjs`：輸出四段——①四個 agent 的 frontmatter（開閉合、2 空格縮排、頂格／四格異常、雙斜線、規則格式）②主體是否混入專案專屬事實（7 組 pattern 同 .ps1）③指令檔紀律（`agent:` 指向、`subagent: false`、禁 shell 塊、殘留語彙）④尾巴三段式相對次序（不可變 allow 在可變 deny 之後）；新增檢查：POSIX allow 條目（`ln -s`／`unlink`／`pwd -P`）須位於尾巴第 1 段 deny 之前。
  - `node tools/scan-forms.mjs`：掃 `docs`／`kit`／`tools` 的 `*.md`，同 .ps1 的緊縮簡體字集命中＋各檔「一／次」數量。
  - `node tools/normalize-forms.mjs <目標檔>`（預設 `docs/specs/2026-11-11-frontend-devkit-design.md`）：與 .ps1 相同替換表（含冪等警告註解：擴充式替換不具冪等性）與疑似字前 40 條回報；寫檔 UTF-8 無 BOM、LF。

**Steps**
- [x] 6a `check-structure.mjs`：逐段移植＋新增 POSIX 條目位置檢查。
  - 驗：`node tools/check-structure.mjs` 對現行（尚未改完的）repo 執行不拋例外且能列出 FAIL；任務 7 前重跑須全 PASS。
- [x] 6b `scan-forms.mjs`：移植字集與計數。
  - 驗：`node tools/scan-forms.mjs` 輸出與 `pwsh tools/scan-forms.ps1` 的命中清單一致（若本機無 pwsh，改人工抽 3 檔對照）。
- [x] 6c `normalize-forms.mjs`：移植替換表；UTF-8 無 BOM、LF。
  - 驗：對 `mktemp` 暫存副本連跑兩次，`diff` 內容不變（冪等）；`xxd -l 3 <檔>` 開頭不是 `ef bb bf`；`file <檔>` 為 UTF-8。
- [x] 6d `tools/README.md`：表格加 Node 版三列；說明「macOS 用 `node tools/*.mjs`，Windows 可續用 `.ps1`，兩版等價」。
- [x] 6e `.gitattributes`：加 `*.mjs text eol=lf`。
  - 驗：`grep -n 'mjs' .gitattributes` 命中。

**Risks**：Node 版與 PS1 版行為漂移——6b 的對照輸出是防線；normalize 的冪等問題已用「暫存副本連跑兩次」攔截。

---

## 任務 7　驗證與收尾（macOS 關卡＋P11／P13＋結果落盤＋Windows 回歸）

**Scope**：依設計 §7.2 逐項執行；所有宣稱都要有貼得出的輸出。

**Files**（皆 Modify；本任務是唯一會再回頭改 kit 檔的任務——修實測發現的缺陷後，重跑對應任務的驗收 grep）
- `docs/acceptance.md`（§13.2 回填狀態與證據）
- `docs/acceptance-findings.md`（新增 macOS 驗收段）
- 必要時：任務 1–6 所屬 kit／docs 檔（修缺陷）

**Steps**
- [ ] 7a 前置（關卡 0 建置，人工）：`mktemp -d` 建 eval 目錄，`npm create vite@latest app-a`（vue 範本）→ `npm install` → `npm run build`；複製出 app-b 並砍 `.opencode/frontend-devkit/project.md`；兩者 `git init`＋留一個 commit；記錄 `pwd` vs `pwd -P` 差異（預期 `/var/...` → `/private/var/...`）。kit 以專案層裝入兩專案 `.opencode/`（macOS 指令）；**重啟 TUI 進程**。
- [ ] 7b 靜態檢查：`node tools/check-structure.mjs` 全 PASS；`node tools/scan-forms.mjs` 0 命中；`opencode debug agents` 列出四個 `frontend-devkit/*`、無 `rules/...` 條目、無幽靈 agent。
- [ ] 7c 文件一致性 grep（§7.2 第 7 項）：
  - `grep -rn '<WT_LINK_TARGET>\|<WT_DIR>\|<REVIEW_PREFIX>' kit/` → 0
  - `grep -rn '僅 PowerShell\|只有 PowerShell 版' kit/ README.md docs/install.md docs/adding-a-project.md` → 僅歷史段
  - `grep -rn 'build/worktrees\|audit-' kit/ docs/` → 僅非法值範例
  - worktree.procedures.md 的 POSIX 段落內 `grep -n 'cmd /c\|Test-Path\|New-Item\|Copy-Item\|Get-Location\|Resolve-Path'` → 0
  - 逐條對照表：allow 字面（`ln -s ../../node_modules .worktrees/*/node_modules`、`unlink .worktrees/*/node_modules`、`pwd -P`、`test -e *`、`cp * .worktrees/*`、`uname -s`、`shasum -a 256 *`、`grep -n *`）與程序檔／提示詞指令字面逐字相同（貼出兩邊行號）。
- [ ] 7d P11 非法值（§7.2 第 3 項）：暫時 profile 填 `worktree 目錄: build/worktrees/` → 跑 `init` 與 `inspect` 均拒絕並指明合法值；審核前綴填 `audit-` 同測；改回 `.worktrees/`／`review-` 可通過；記錄原始輸出。
- [ ] 7e P13 平台守門（§7.2 第 4 項）：手動把 `resolved.md` 檔頭 `shell` 改成另一值 → orchestrator／developer／reviewer 三個 agent 開工即停止並要求 `init compile`（`setup` 不套用）；`shell: TBD（未確認）` 亦停止；復原後正常。逐 agent 記錄輸出。
- [ ] 7f macOS 關卡 1～8（§7.2 第 5 項，依 `docs/acceptance.md` §13.2 與 `docs/tui-run-checklist.md` macOS 清單）：關 1 載入與 POSIX 權限（`pwd` DENIED、`pwd -P` EXECUTED、edit deny 清單）；關 2 `init`（`shell=posix`、`resolved.md` 只含 POSIX 段落與平台檔頭、P11 拒絕）；關 3 `compile`／`shasum`／`inspect` 重建檔頭正確；關 4 `dev` 全流程（symlink、七區段、清除、主工作區 `node_modules` 完好）；關 5 `review`（`VERDICT`、`review-` 前綴、worktree 必清）；關 6 降級；關 7 安全地板；關 8 既有專案零影響。每關貼原始輸出。
- [ ] 7g 結果落盤：`docs/acceptance.md` §13.2 每關狀態與關鍵證據回填（未過 → 修 kit 檔、重跑該關，不得放寬斷言）；`docs/acceptance-findings.md` 新增 macOS 驗收段（缺陷編號接續既有、通過項目逐項查證、不採信自稱）。
- [ ] 7h Windows 回歸（§7.2 第 6 項）：有 Windows 機器 → 至少重跑 `node tools/check-structure.mjs`＋一次 `init compile`／worktree 建立清除；**無機器 → 在 `docs/acceptance-findings.md` 如實標「未驗（無 Windows 機器）」**，不得宣稱已驗。
- [ ] 7i 收尾：`git worktree list` 無殘留；`git status --short` 乾淨；commit 訊息先給使用者審（本 repo 慣例，不 push）。

**Risks**：TUI 手動操作依本 repo 慣例需使用者配合（關卡 2～7 由使用者在 TUI 跑、輸出貼回）；若探針落點不是 eval 專案，該關作廢重跑（設計 §7.2 第 5 項關 1 的落點要求）。

---

## 開放問題

1. **Windows 機器可得性**：任務 7h 走實測或標「未驗」，取決於執行時是否有 Windows 機器；計畫預設走「如實標未驗」路徑。
2. **權威清單條目**：任務 4 的 §7.3.5#2 POSIX 族由本計畫定稿（見 Interfaces）；若核准者要增刪，改動點只在該小節一處（P14 唯一權威），agent 尾巴段與 `setup` 寫入性檢查同步跟改。
3. **macOS 關卡的 TUI 操作分工**：關卡 2～7 依 `docs/tui-run-checklist.md` 慣例由使用者在 eval 專案的 TUI 手動跑、把原始輸出貼回，實作 agent 負責判讀與落盤；需先與使用者確認此分工。
4. **主檔 §7.1 的 POSIX 增量呈現**：計畫採「各 agent 列加一行摘要＋尾巴段引用 §7.3.5#2」，不逐條重列整份（避免第三份清單漂移）；若核准者偏好 §7.1 全列，屬設計文件範圍外，需回設計確認。
