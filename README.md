# frontend-devkit

給 **OpenCode** 用的一套前端開發流程 kit：把「協調者 → 開發者 → 獨立審核者」的紀律、worktree 隔離、安全地板與品質 gate，做成**可重複安裝的規則**，而不是每個專案各自複製一段 prompt。

- **4 個 agent**：`frontend-devkit/orchestrator`、`developer`、`reviewer`、`setup`
- **6 個指令**：`/frontend-devkit/dev`、`fix`、`review`、`review-fix`、`init`、`inspect`
- **每個專案一份 profile**：`project.md`（人寫）＋ `resolved.md`（`compile` 產物）
- **4 個已驗證 pack**：`security/vue-xss`、`stack/vue2-nuxt2`、`testing/ava`、`i18n/vue-i18n-json`

> 設計與決策的權威在 [`docs/specs/2026-11-11-frontend-devkit-design.md`](docs/specs/2026-11-11-frontend-devkit-design.md)；驗收紀錄在 [`docs/acceptance.md`](docs/acceptance.md) 與 [`docs/acceptance-findings.md`](docs/acceptance-findings.md)。

## 需求

| 項目 | 要求 |
|---|---|
| 平台 | **Windows PowerShell 或 macOS zsh／bash**（profile `shell` 值域：`powershell`／`posix`；**本次只驗 macOS**、Linux 未驗不宣稱支援） |
| OpenCode | 實測 `v2.2.7`（`opencode --version`） |
| 專案 | 是 git repo，且 `.gitignore` 含 `.worktrees/` |

> `depStrategy: junction` 的平台語意：Windows＝junction（兩步 `Resolve-Path`＋`New-Item`）、macOS＝固定相對 symlink `../../node_modules`（P4）。`shell` 的偵測：先 `uname -s`（`Darwin`／`Linux` → `posix`）、後 `Get-Location`（→ `powershell`），兩者皆敗 → `TBD（未確認）`。
>
> **P11 breaking change（2026-11-14）**：`worktree 目錄` 唯一合法值 `.worktrees/`、審核前綴唯一合法值 `review-`；其他值 `init`／`inspect` 一律拒絕並指明合法值。

## 安裝（專案層，建議）

完整步驟與兩種裝法見 [`docs/install.md`](docs/install.md)。最短版本：

1. 把 `kit/` 的內容複製到專案的 `.opencode/`：

   | 來源 | 目標 |
   |---|---|
   | `kit/agents/frontend-devkit/` | `.opencode/agents/frontend-devkit/` |
   | `kit/commands/frontend-devkit/` | `.opencode/commands/frontend-devkit/` |
   | `kit/rules/` | `.opencode/frontend-devkit/rules/` |
   | `kit/profile/` | `.opencode/frontend-devkit/profile/` |
   | `kit/worktree.procedures.md` | `.opencode/frontend-devkit/worktree.procedures.md` |

   macOS（zsh／bash）：

   ```bash
   KIT="kit"
   DST="<你的專案>/.opencode"
   # 先刪目標子目錄再整包複製（巢狀警告：cp -R 到已存在的同名目錄會把來源放進去）
   rm -rf "$DST/agents/frontend-devkit" "$DST/commands/frontend-devkit" "$DST/frontend-devkit/rules" "$DST/frontend-devkit/profile"
   mkdir -p "$DST/agents/frontend-devkit" "$DST/commands/frontend-devkit" "$DST/frontend-devkit"
   cp -R "$KIT/agents/frontend-devkit" "$DST/agents/"
   cp -R "$KIT/commands/frontend-devkit" "$DST/commands/"
   cp -R "$KIT/rules" "$DST/frontend-devkit/"
   cp -R "$KIT/profile" "$DST/frontend-devkit/"
   cp "$KIT/worktree.procedures.md" "$DST/frontend-devkit/"
   ```

   Windows 指令見 [`docs/install.md`](docs/install.md) §1a。

2. **重啟 TUI 進程**（不是只開新 tab）。
3. 跑 `/frontend-devkit/init`。

## 上手

```text
/frontend-devkit/init                       # 產生 project.md 並編譯 resolved.md
/frontend-devkit/dev 在 App.vue 加一個切換深色按鈕＋測試
/frontend-devkit/review --working           # 只審不修
```

第一次使用，建議先讀 [`docs/adding-a-project.md`](docs/adding-a-project.md)（init 會問什麼、四個白名單欄位怎麼填、TBD 怎麼補）。

## 指令與 agent

| 指令 | 主要 agent | 用途 |
|---|---|---|
| `/frontend-devkit/init [auto\|compile\|diff]` | `setup` | 偵測、問答、寫 `project.md`、編譯 `resolved.md` |
| `/frontend-devkit/inspect [probe]` | `setup`（probe 會派 `reviewer`） | 健檢設定與源頭一致性 |
| `/frontend-devkit/dev <任務>` | `orchestrator` → `developer`／`reviewer` | 開發，最多 3 輪 |
| `/frontend-devkit/fix <問題>` | `orchestrator` → `developer`／`reviewer` | 先重現與找根因 |
| `/frontend-devkit/review [範圍]` | `reviewer` | 只審核，輸出 `VERDICT` |
| `/frontend-devkit/review-fix [範圍]` | `orchestrator` | 先審，FAIL 才詢問並接手修 |

審核範圍可用 `a..b`、單一 sha、`origin/<分支>`、`--working`。

## 權限模型（方案 B）

**所有 shell 規則靜態寫在 agent 主體的 frontmatter**；專案端設定檔只准放兩類內容：

```json
{
  "instructions": [
    ".opencode/frontend-devkit/project.md",
    ".opencode/frontend-devkit/resolved.md"
  ]
}
```

（可選 `agents.<id>.model`；不寫就繼承 session model。）

因此：

- 專案端**不要**寫 `permission`／`shell` 自訂規則——它們不會生效，只會造成「以為放寬了」的錯覺。
- 要調整權限，改主體 `.md` 的 allow 清單，並**同步檢查對應指令是否在清單內**（這條是本專案用血換來的，見 `acceptance-findings.md` 的 V／Z／AD）。

## 升級

1. `git pull` 這個 repo。
2. **先刪目標子目錄再整包複製**（不要 `Copy-Item <來源目錄> <已存在目錄> -Recurse`，會產生 `rules/rules/`）。
3. 重啟 TUI 進程。
4. 每個已安裝專案跑一次 `/frontend-devkit/init compile`。

## 疑難排解

| 症狀 | 先查什麼 |
|---|---|
| `Agent not found: frontend-devkit/xxx` | agent `.md` 的 YAML 是否被跳過：opencode log 裡的 `agent file skipped`／`reason=markdown`。最常見是**規則行少了兩格縮排** |
| agent 清單多出一個沒看過的 `frontend-devkit/...` | 設定檔 `agents` 的鍵**拼錯了**。OpenCode 不會忽略，而是建立一個 primary agent（無 system prompt、權限 `*/* allow`）；用 `opencode debug agents` 可確認，改掉那個鍵即可 |
| 改了 kit 檔案但行為沒變 | agent 定義是**進程啟動時載入**：要重啟 TUI 進程，不是開新 tab |
| 某指令「沒有權限」 | 先 `read` 該 agent 的 allow 清單逐一確認；複合指令（`;`、`&&`、`\|`、`echo`）被拒不等於單條也無權 |
| `Get-Location` 落點不是你的專案 | shell 落在 service 綁定的專案目錄，`--server`／`--standalone`／cwd 都改不了它；macOS 落點檢查一律用 `pwd -P`（與 `git rev-parse --show-toplevel` 比對） |
| macOS 上 `pwd` 被拒（或落點誤判） | 設計如此：allow 只登記 `pwd -P`、未登記 `pwd`（P12）；`/var` → `/private/var` 的路徑別名會讓 `pwd` 與 Git 的實體路徑對不上 |
| macOS 上 worktree 依賴壞掉 | `junction` 在 macOS 是固定相對 symlink `../../node_modules`；建完以 `test -e .worktrees/<名稱>/node_modules/<框架套件>/package.json` 驗證 |
| worktree 內容出現在 `--working` | `.gitignore` 沒有 `.worktrees/`；先 `git check-ignore -v .worktrees/`（退出碼 0＝已忽略） |
| `npm ci` 在 worktree 失敗 | 主工作區沒有 `node_modules` 時 `junction` 不可用，`depStrategy` 要用 `install-per-worktree` |

## 驗收狀態

- 關卡 0～8 全數通過（2026-11-11 ～ 11-13，Windows）。結果與證據：[`docs/acceptance.md`](docs/acceptance.md) §13.1。
- macOS 驗收另立 [`docs/acceptance.md`](docs/acceptance.md) §13.2（2026-11-14 開立；2026-11-15 複驗：關 0 通過、關 1／2 部分通過、關 3～8 待 TUI；Windows 回歸未驗）；Windows 歷史紀錄保留於 §13.1 不變。
- 驗收過程抓到 30 個缺陷（A～AH），其中 6 個屬「不看實作就看不出來」：巢狀安裝、0 pack 與整節空白、**pack 正文沒折入**、YAML 縮排、指紋指令無權限。逐條紀錄在 [`docs/acceptance-findings.md`](docs/acceptance-findings.md)。

> 那份 findings 很長（>700 行），**建議保留**：它記錄了「為什麼每一條規則長這樣」。沒有它，後人會把防禦改回去。

## 文件地圖

| 檔案 | 內容 |
|---|---|
| `docs/install.md` | 兩種裝法、升級、`kitRoot`、重複安裝與落點警告 |
| `docs/adding-a-project.md` | `init` 問答範例、四個白名單欄位、TBD 補法 |
| `docs/specs/2026-11-11-frontend-devkit-design.md` | 主檔（決策與規格權威） |
| `docs/permission-spec.md` | 權限模型權威（字面同形、三段式） |
| `docs/writing-a-pack.md` | 怎麼寫一個新 pack |
| `docs/acceptance.md` | 八關驗收的通過條件與實測結果 |
| `docs/acceptance-findings.md` | 實測紀錄與缺陷索引 |
| `docs/experiments.md` | 平台行為實測（shell 落點、scanner 行為） |
| `docs/tui-run-checklist.md` | 需要人工在 TUI 跑的關卡清單 |
| `tools/` | 本 repo 的健檢腳本（**不屬於 kit**，不會被安裝） |

## 授權

[MIT](LICENSE) © 2026 Aibasil

你可以自由使用、修改、再散布（含商業使用），只需保留著作權聲明與授權條文。

## 貢獻

這個 repo 的規格是照「實測 → 記錄缺陷 → 改規則」的節奏長出來的。送 PR 時請盡量附上：

1. **重現方式**（哪個指令、什麼設定、預期與實際）。
2. 若是規則變更，說明**為什麼原本的寫法會失效**（不要只寫「比較好」）。
3. 若改了 agent 的權限，確認**對應指令已加進 allow 清單**（這條踩過三次：V／Z／AD）。

