# acceptance 執行情形與發現

依 `acceptance.md` 逐關記錄實際做過的事與結果。**沒做過的關卡一律標「未驗」**，不用推定充數。

## 關卡 0　建置（人工）— 已完成 ✓

| 項目 | 結果 |
|---|---|
| 位置 | `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\` |
| app-a | `npx --yes create-vite@latest app-a --template vue`（create-vite 9.3.4，無互動提示）。`npm install` 35 套件、0 漏洞；`npm test` 通過（vitest 5.1.0，1 passed）；`npm run build` 通過（vite 8.3.8，1.76s）。commit `ae6a5e8`＋`ed9221e`，工作區乾淨 |
| app-b | 複製 app-a（排除 `node_modules`／`dist`／`.git`），`git init` ＋ commit `eca0e0e`，工作區乾淨（尚未裝依賴，關卡 6 只需它當「無 profile」的殼） |
| `.gitignore` | 兩邊都已含 `.worktrees/`（對應 profile 預設 worktree 目錄）；**由我這個人工建置步驟加，不是 kit 改的** |
| Node 環境 | 機器預設 `node` 是 **v12.22.12**（nvm 預設，TOS 專案用的）。Vite 8 需 Node 18+，故每次呼叫把 `installs\v24.15.0` 塞進該次程序 PATH，**未更動 nvm 預設** |
| 刻意留的鉤子 | app-a 的 `lint` script 是 `node -e "console.log(1)"`，用來驗 `setup` 的寫入性檢查是否會把它標成「疑似可寫入／任意執行」而非放進可執行 gate |

## 關卡 1　載入關 — 部分完成（權限與載入 ✓，四種編輯路徑屬回歸抽驗）

用 `~/.config/opencode/agents/frontend-devkit/` 暫裝四個 agent（跑完刪除），實測：

| # | 項目 | 結果 |
|---|---|---|
| 1 | 四個 agent 可被載入（含 `mode: subagent` 的 developer） | 全部成功 |
| 2 | 負向：`--agent frontend-devkit/rules/vue-xss` | `Agent not found` ✓ → `rules/` 放 `agents/` 外不會被當成 agent（§4.2 那條陷阱修法有效） |
| 3 | reviewer：`git status --short`（白名單內） | EXECUTED ✓ |
| 4 | reviewer：`git stash list`、`git tag`（尾巴第 1 段 deny，**無參數形**） | DENIED ✓ →「` *` 也匹配無參數」對 deny 同樣成立 |
| 5 | reviewer：`cmd /c rmdir .worktrees\review-zzz`（allow 寫斜線、實際打反斜線） | EXECUTED ✓ 反斜線正規化在真實 kit agent 上成立 |
| 6 | reviewer：`Test-Path .worktrees/review-zzz` | EXECUTED ✓ |
| 7 | reviewer：`npm testxyz` | DENIED ✓ `"npm test *"` 不會誤放 `npm testxyz` |
| 8 | reviewer：`Get-FileHash …` | DENIED ✓ checksum 只屬 `setup`（第 3 輪 S5 落地） |
| 9 | `edit` 的四種路徑形（根／`.opencode`／worktree 內／`opencode.jsonc`）＋ `.git/hooks` | **未驗**（R1 第 6 題已驗過 pattern 組，此處降為回歸抽驗） |
| 10 | 六個 slash 指令能否展開 | **未驗**：headless 不觸發 slash 展開，需在 TUI 看 |

附帶記一個**我的誤判**：第一次測落點時用 reviewer 跑 `Get-Location` 得到 DENIED，我一度以為工具壞了；其實 `Get-Location` 依設計只在 `setup` 的白名單內，**deny 是正確行為**。屬「測錯對象」而非缺陷，記錄下來免得以後又誤報。

## 阻塞 M3 的發現：無法把 agent 的 shell 落點改到 app-a

關卡 2～7 需要 agent 在 app-a 裡建 worktree、改檔案、跑指令。實測證明**目前的驅動方式做不到**：

| 嘗試 | shell 的 `Get-Location` 結果 | 判讀 |
|---|---|---|
| 共用 service＋`opencode run`（工作目錄設 app-a） | `TOS_Frontend`（另一個真實專案） | shell 落點不等於呼叫端 cwd |
| `--standalone`（工作目錄 app-a 或 r1-probe） | 同上（`TOS_Frontend`） | 沒有改用私服務綁定的目錄 |
| 在 app-a 起 `opencode serve --port 29401`，再 `opencode run --server http://127.0.0.1:29401`（密碼走 `OPENCODE_SERVER_PASSWORD`，連線成功、agent 正常回應） | **`TOS_Frontend_Fia`（這個對話的專案）** | `--server` 也沒改落點；shell 跟著 service 註冊的 location 走 |

**結論**：`opencode` 的 shell 工具在 **service 綁定的 location** 執行，`--server`／`--standalone` 與呼叫端 cwd 都改變不了它。因此關卡 2～7 若由我自動驅動，agent 會去改**你正在用的專案**，這不可接受 → 我停在這裡，沒有讓它寫任何東西到 app-a 之外（本節所有測試都是唯讀或權限被拒）。

**過程中也澄清一件事**：我曾以「找不到含 29401 的 `node.exe`」判定 server 已停，但 `Invoke-WebRequest` 回 200——實情是它跑在編譯後的 `opencode.exe`（PID 1956）。改停該程序後連線才被拒、`Get-NetTCPConnection` 顯示 0 個持有者。教訓：**「已清理」的斷言要用功能探測證明，不能只看程序名**。共用 service（28894）全程未受影響。

## 剩下的可行驅動方式（等你選）

1. **你在 TUI 手動跑**：在 app-a 開一個 OpenCode session（`Get-Location` 會是 app-a），依 `acceptance.md` 的關卡 2～7 逐項執行，把輸出貼給我判讀與記錄。這是**唯一不需要動到你環境**的做法，也同時會驗到 slash 指令展開（關卡 1 第 10 項）。
2. **重啟共用 service 讓它綁 app-a**：`opencode service restart` 之類會中斷這個對話；之後要回到 TOS 專案工作時還得再重啟一次。
3. **接受「關卡 2～7 延後」**：先以關卡 0/1 的實測與 R1 八題實驗作為 M3 的部分通過，把 2～7 列為上線前必驗項，寫進 README 的上手檢查清單。

（尚未開始：關卡 2～8；`kit/` 的全域安裝已清空，暫評專案 `app-a`／`app-b` 原樣留在 `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`。）
