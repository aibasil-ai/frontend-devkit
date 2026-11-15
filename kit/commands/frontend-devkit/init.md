---
description: 為本專案產生或更新 frontend-devkit 設定檔（project.md）與編譯產物（resolved.md）
agent: frontend-devkit/setup
---

$ARGUMENTS

請依 setup 的流程處理：

- 無參數：偵測 → 對掃不到的欄位用 `question` 一次一題問 → 驗證四個白名單欄位的**值** → gate 可行性判定（方案 B：只做判定與標示，**不寫專案端 shell 規則**）→ 寫 `project.md` → `compile` → `inspect [probe]` → 回報「寫了什麼、跳過了什麼、目前所有 TBD、下一步指令」。
- `auto`：只做偵測與寫檔、不問問題；偵測不到就寫 `TBD（未確認）`，並逐條列出每個 TBD 與每個「需人工執行」的 gate 會讓哪些檢查失效。**P11 例外**：`worktree 目錄` 與 `worktree 名稱前綴` 的審核前綴有唯一合法值，直接寫 `.worktrees/` 與 `review-`，**不得寫 TBD**（寫 TBD 會被 P11 自己的檢查拒絕）。
- `compile`：只重譯 `resolved.md`（驗證 pack id、算 checksum、`covers` 重疊警告、把 worktree 程序依 profile 參數化折入、輸出採**規範化格式**）。
- `diff`：不寫檔，只印「重跑偵測後會改變哪些欄位、你手寫的內容是否受影響」。

共同要求：
1. 開工先確認落點就是本專案（工具可能連到別棵樹的 service）：依 profile `shell` 選平台指令——posix → `pwd -P`（與 `git rev-parse --show-toplevel` 比對；**不可用 `pwd`**，macOS 的 `/var` → `/private/var` 別名會誤判）；powershell → `Get-Location`。不是就停止回報。
2. 冪等更新：只覆蓋偵測類欄位，保留使用者手寫內容與 `## 專案覆寫`；寫入前顯示差異。
3. 寫 `<設定檔路徑>` 前必須先 `read` 並保留既有欄位；**只准**追加 `instructions` 與 `agents.<id>.model`，**不得**寫 shell 規則（依實測專案端 allow 不會生效）。
4. 四個白名單欄位（`設定檔路徑`、`kitRoot`、`worktree 目錄`、`環境檔`）任一非法 → 拒絕寫入並說明為什麼要擋。
5. 不修改 `package.json`、`.gitignore`、`.git/`、全域設定、pack 原文與程序檔。
6. **P11 值檢查（含 `init` 重跑）**：`worktree 目錄` ≠ `.worktrees/`、或 `worktree 名稱前綴` 的審核前綴 ≠ `review-` → **拒絕並停止**，錯誤訊息須指出唯一合法值「`.worktrees/`」與「`review-`」，要求使用者改 `project.md` 後重跑；**不得**自動改寫、不提供相容模式。
