---
description: 健檢目前專案的 kit 設定：TBD 彙整、來源一致性、白名單欄位值、gate 可行性、probe
agent: frontend-devkit/setup
---

$ARGUMENTS

- 無參數（或 `report`）：依 setup §5 逐項健檢並回報：生效的 `設定檔路徑`、四欄白名單值合法性、P11 固定值（`worktree 目錄`＝`.worktrees/`、審核前綴＝`review-`，其他值拒絕並指明合法值）、`## 已知豁免` 格式與數量、全文 TBD 彙整與「因 TBD 未覆蓋的檢查」、`project.md` 啟用清單 vs `resolved.md` 檔頭一致性、以源頭素材重建內文的**逐行**比對（排除檔頭動態欄；誠實標明這是 LLM 逐行比對，不是機械 diff；重建時依 profile `shell` 用與 compile 相同的擇一規則重組 worktree 程序段落，並比對檔頭 `平台`／`shell` 欄）、四個 agent 的規則存在性與是否重複安裝、`## 指令` × 主體靜態清單的判定（可執行／需人工執行／疑似可寫入）、model 與其來源、`git worktree list` 與 worktree 目錄殘留、六個指令的對照表。
- `probe`：依 setup §6 執行三條——第 0 條落點確認（posix → `pwd -P` 與 `git rev-parse --show-toplevel` 比對；powershell → `Get-Location`）、第 1 條測主體靜態清單內的 gate（預期 allow）、第 2 條測必被拒的寫入指令（預期 deny）；把結果連日期與 OpenCode 版本寫進 `project.md` 的 `## 安裝紀錄`（`resolved.md` 檔頭只放引用行）。第 2 條若被准 → 判定為提權漏洞，立即回報並建議停用 kit，引用該規則出自哪個檔案與陣列位置。

共同要求：開工先確認落點就是本專案（依 profile `shell`：posix → `pwd -P`；powershell → `Get-Location`）；本指令**不寫檔**，唯一例外是 `probe` 要更新 `## 安裝紀錄`（以及必要時 `resolved.check.md`）。發現需要改 `.gitignore` 或升級 pack 時，只給建議與理由，由使用者決定。
