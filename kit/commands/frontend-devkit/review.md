---
description: 審核指定範圍的程式變更（含同事已 push 的 commit），只回報結果，不修改任何程式
agent: frontend-devkit/reviewer
subagent: false
---

審核範圍：$ARGUMENTS

範圍語法：

- 省略：**預設使用專案 `project.md` 的 `預設審核範圍` 字面值**（通常是 `HEAD..origin/<基準分支>`）。若 profile 沒有該欄（寫 `TBD` 或 `無`），停止並請使用者明確指定範圍，不要自行猜基準。
- `a..b`：指定 commit 範圍。
- 單一 sha：該 commit 本身的變更（無 parent 時改用 `git show`）。
- `origin/<分支>`：該遠端分支相對於基準分支的變更（用 `git merge-base` 取起點）。
- `--working`：目前工作區尚未 commit 的變更（含未追蹤新檔案，要用 `read` 讀入）。

規則：

- 範圍為空（無 commit、無變更、無未追蹤檔案）→ 輸出「無可審核內容」並建議明確指定範圍；**不得輸出 `VERDICT`**。
- `git fetch` 失敗（例如遠端需要認證或網路不通）→ 如實回報原因，改用本機已有的 `origin/*` 參照續審，並在輸出標「未能更新遠端，結果可能不是最新」。
- 只回報審核結果，**不修改任何程式、不 commit**。
- 開始前確認 `resolved.md` 的啟用清單與 `project.md` 的 `## 啟用規則` 一致；不一致或缺檔先提示 `/frontend-devkit/init compile`。
- 若啟用清單內沒有任何 `security/*`：你沒有 `question` 權限，**不要假設使用者已同意** → 不開始審核，輸出固定句「啟用清單無 `security/*`，需二次確認；請改走 `/frontend-devkit/review-fix`，或在 `project.md` 的 `## 專案覆寫` 明示『已確認僅執行主體基本安全項』後重跑」。
- 驗證指令若不在你可執行的靜態清單內，照實回報「因方案 B 白名單未含此指令，未獨立執行」，不得宣稱跑過。
- 若曾建立審核 worktree（`review-<sha7>`；審核前綴固定 `review-`），結束前**必定清除**：依 `resolved.md` 的 worktree 程序平台段落——先移除連結（Windows `cmd /c rmdir .worktrees\review-<sha7>\node_modules`／macOS `unlink .worktrees/review-<sha7>/node_modules`），再 `git worktree remove --force .worktrees/review-<sha7>`，最後用 `git worktree list` 確認。
