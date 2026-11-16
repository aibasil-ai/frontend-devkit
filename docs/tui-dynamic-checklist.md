# TUI 動態驗證 checklist（macOS / posix）

> 目的：在 app-a / app-b 的 TUI 上逐項驗證 `frontend-devkit` 的動態行為。此清單依關卡 1–8 編排，適用於 macOS zsh / bash / sh（`shell: posix`）環境。
>
> 要邊跑邊留紀錄，搭配 [`tui-dynamic-record-template.md`](tui-dynamic-record-template.md)（每關都有「實際輸出／判定／證據」欄位）。

## 前置條件

- [ ] 在 app-a 的 TUI 內切到 `frontend-devkit/setup`
- [ ] 確認不是 default Build agent，避免被測試陷阱誤判
- [ ] 現在工作目錄應為專案根目錄
- [ ] 先核對以下命令：
  - [ ] `pwd -P`
  - [ ] `git rev-parse --show-toplevel`
  - [ ] `uname -s`
- [ ] 預期：
  - [ ] `pwd -P` 與 `git rev-parse --show-toplevel` 完全一致
  - [ ] `uname -s` 回 `Darwin`
  - [ ] `pwd` 不被允許
  - [ ] `git commit --allow-empty -m probe` 被拒絕

## 關卡 1：權限地板檢查

- [ ] 在 app-a TUI 執行：
  - [ ] `pwd -P`
  - [ ] `pwd`
  - [ ] `uname -s`
  - [ ] `git commit --allow-empty -m probe`
- [ ] 預期結果：
  - [ ] `pwd -P`：ALLOW / 可執行
  - [ ] `pwd`：DENIED
  - [ ] `uname -s`：輸出 `Darwin`
  - [ ] `git commit --allow-empty -m probe`：DENIED
- [ ] 若有 `Build` default agent 影響，先切回 `frontend-devkit/*` 再重跑
- [ ] 紀錄：
  - [ ] 路徑實際是 `/private/var/.../app-a`
  - [ ] `pwd -P` 與 git root 相同
  - [ ] 這是 macOS 正確的 `posix` 落點判準

## 關卡 2：`/frontend-devkit/init` + P11 / P13

- [ ] 在 app-a TUI 執行 `/frontend-devkit/init`
- [ ] 驗證：
  - [ ] shell 被偵測成 `posix`
  - [ ] `project.md` 被產生
  - [ ] `resolved.md` 被產生
  - [ ] `project.md` 的 `shell` 是 `posix`
  - [ ] `worktree 目錄` 是 `.worktrees/`
  - [ ] `worktree 名稱前綴` 是 `review-`
- [ ] 驗證 P11 非法值：
  - [ ] 把 `worktree 目錄` 改成 `build/worktrees/`
  - [ ] 把審核前綴改成 `audit-`
  - [ ] 預期：`init` 和 `inspect` 都拒絕，並明示唯一合法值為 `.worktrees/` 與 `review-`
- [ ] 修正回合法值後重新執行 `/frontend-devkit/init`
- [ ] 驗證 P13 動態守門：
  - [ ] 手動把 `resolved.md` 檔頭中的 `- shell：posix` 改成 `- shell：powershell`
  - [ ] 或改成 `TBD（未確認）`
  - [ ] 接著讓 `orchestrator` / `developer` / `reviewer` 三個 agent 各自開始工作
  - [ ] 預期結果：
    - [ ] 三者都立即停止
    - [ ] 要求使用者先跑 `/frontend-devkit/init compile`
    - [ ] 不得自行改寫 `resolved.md`
    - [ ] `setup` 不套用這條守門
- [ ] 恢復正確的檔頭後，再跑一次確認正常

## 關卡 3：compile / shasum / inspect

- [ ] 在 app-a TUI 執行 `/frontend-devkit/init compile`
- [ ] 驗證：
  - [ ] `resolved.md` 只折入 `posix` 平台段落
  - [ ] 不出現 PowerShell 版本內容
  - [ ] `project.md` 與 `resolved.md` 的啟用清單一致
  - [ ] `security/vue-xss` pack 已展開
- [ ] 執行 `/frontend-devkit/inspect [probe]`
- [ ] 驗證：
  - [ ] 第 0 條（落點）允許：`pwd -P`
  - [ ] 第 1 條（靜態 gate）允許：`npm test` 之類在清單上被允許或標註為無
  - [ ] 第 2 條（防寫入保護）拒絕：`git commit --allow-empty -m probe`
- [ ] 確認 `## 安裝紀錄` 已記錄 probe 結果
- [ ] 確認未修改：
  - [ ] `package.json`
  - [ ] `.gitignore`
  - [ ] `.git/`

## 關卡 4：dev 全流程

- [ ] 在 app-a TUI 執行 `/frontend-devkit/dev`
- [ ] 先確認它是否先問 worktree 位置（`worktreePolicy: ask`）
- [ ] 依 `resolved.md` 的 posix worktree 程序建立 worktree
- [ ] 驗證 symlink 建立方式：
  - [ ] 應為 `ln -s ../../node_modules .worktrees/<名稱>/node_modules`
  - [ ] 不用 junction / Windows 兩步
- [ ] 在 worktree 內做一個小功能變更
- [ ] 讓 reviewer 獨立驗證
- [ ] 結束前先清除 link：
  - [ ] `unlink .worktrees/<名稱>/node_modules`
  - [ ] 再 `git worktree remove --force .worktrees/<名稱>`
- [ ] 最後驗證：
  - [ ] `.worktrees/` 乾淨
  - [ ] `git worktree list` 只剩主工作區
  - [ ] 主工作區 `node_modules` 完好
  - [ ] 沒有刪到主工作區依賴

## 關卡 5：review

- [ ] 在 app-a 先故意留一個爛 commit
- [ ] 執行 `/frontend-devkit/review <sha>` 或 `/frontend-devkit/review --working`
- [ ] 驗證：
  - [ ] reviewer 建立 `review-<sha7>` worktree
  - [ ] 在該 worktree 內跑 lint / build / test
  - [ ] 輸出 `VERDICT`
  - [ ] 若有嚴重或一般問題，結論應為 FAIL
- [ ] 結尾清除：
  - [ ] 先 `unlink .worktrees/review-<sha7>/node_modules`
  - [ ] 再 `git worktree remove --force .worktrees/review-<sha7>`
- [ ] 最後確認：
  - [ ] `git worktree list` 只剩主工作區
  - [ ] `.worktrees/` 沒殘留
  - [ ] `review-` 前綴固定
  - [ ] 沒有影響主工作區

## 關卡 6：app-b 的降級／無 profile 行為驗證

- [ ] 切到 app-b 的 TUI
- [ ] 檢查 app-b 是否保留「無 project.md」或 `shell: TBD`
- [ ] 執行 `/frontend-devkit/init` 或相關 degraded flow
- [ ] 預期：
  - [ ] 若沒有 project profile，會提示使用者補齊設定
  - [ ] 若 `shell: TBD`，應明確警告「worktree 程序停用」
  - [ ] 不會偷偷寫成有效設定
- [ ] 如果是口述 gate 模式：
  - [ ] 確認它必須明確說明「無設定檔模式」與限制
  - [ ] 不認為這表示流程已經正常啟用
- [ ] 觀察重點：
  - [ ] `shell` 不應被偽造成 `posix`
  - [ ] `worktree` 不應被當作已定義

## 關卡 7：安全地板

- [ ] 讓 `security/vue-xss` 從 `## 啟用規則` 移除
- [ ] 執行 `/frontend-devkit/dev`、`/frontend-devkit/fix`、`/frontend-devkit/review-fix`
- [ ] 預期：
  - [ ] 若沒有任何 `security/*` 啟用，流程要走二次確認
  - [ ] `review` 不應直接開始審核
  - [ ] 輸出固定提示句，提醒使用 `/frontend-devkit/review-fix` 或在 `project.md` 的 `## 專案覆寫` 設 `securityOverride`
- [ ] 再測：
  - [ ] 在 `## 專案覆寫` 填「本專案僅主體基本安全項」
  - [ ] 只有這一列才算授權；其他文字不算
- [ ] 另驗非法值：
  - [ ] 設定檔路徑 → `~/.config/opencode/opencode.json`
  - [ ] kitRoot → `/tmp/x`
  - [ ] worktree 目錄 → `build/worktrees/`
  - [ ] 環境檔 → `../secret.env`
- [ ] 預期：
  - [ ] 全部都被拒絕
  - [ ] 必須說明為什麼非法
- [ ] 恢復合法設定後，再重跑一次驗證

## 關卡 8：零影響 / 清理收尾

- [ ] 確認 `.worktrees/` 是空的
- [ ] 確認 `git worktree list` 僅剩主工作區，不再有 detached / review 分支
- [ ] 確認 `node_modules` 完好，沒有被刪掉
- [ ] 確認沒有 `.DS_Store` 或不必要的垃圾檔
- [ ] 確認沒有誤改：
  - [ ] `package.json`
  - [ ] `.gitignore`
  - [ ] `.git/`
  - [ ] 全域設定
- [ ] 最終 sign-off：
  - [ ] 工作區乾淨
  - [ ] 沒有殘留 worktree
  - [ ] 沒有副作用

## 快速驗收判準

- [ ] 關卡 1：permission gate 通過
- [ ] 關卡 2：init + P11 + P13 正常
- [ ] 關卡 3：compile / inspect / probe 正常
- [ ] 關卡 4：dev 流程正常，worktree 清理正確
- [ ] 關卡 5：review 流程正常，review worktree 清理正確
- [ ] 關卡 6：app-b 降級行為正確
- [ ] 關卡 7：安全地板正常
- [ ] 關卡 8：零影響收尾正常

## 備註

- Windows 回歸未驗，不宣稱已驗。
- TUI 動態關卡 2–8 仍需依實測結果補齊最終驗收記錄。
- `pwd` 不得作為 POSIX 落點；必用 `pwd -P`。
- `worktree 目錄` 固定 `.worktrees/`；`review-` 為唯一合法審核前綴。
- macOS 對應工作樹依賴固定為相對 symlink `../../node_modules`。
