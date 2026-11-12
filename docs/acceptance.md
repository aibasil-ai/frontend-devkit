# 驗證方式：關卡 0～8（主檔 §13 的外移附檔）

> 這是測試計畫；實裝主流程時不必在主檔讀它，但每關的通過條件是驗收標準。

> **本檔是 `specs/2026-11-11-frontend-devkit-design.md`（主檔）的附檔。**
> 章節編號沿用主檔original編號以維持引用穩定；文中 `§X` 若帶檔名前綴（如 `acceptance.md §13`）指附檔，**未帶前綴的 `§X` 一律指主檔**。
> 主檔頂端的「0. 檔案地圖」是全套檔案的入口。

> **本檔是 `specs/2026-11-11-frontend-devkit-design.md`（主檔）的附檔。**
> 章節編號沿用主檔original編號以維持引用穩定；文中 `§X` 若帶檔名前綴（如 `acceptance.md §13`）指附檔，**未帶前綴的 `§X` 一律指主檔**。
> 主檔頂端的「0. 檔案地圖」是全套檔案的入口。
## 13. 驗證方式

| 關 | 在哪 | 檢查什麼 | 通過條件 |
|---|---|---|---|
| **0 建置（人工，不屬於 kit 的權限模型）** | `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`（本機範例：`C:\Users\vipjo\AppData\Local\Temp\opencode\`；**這是給本機執行者看的路徑，不寫進 kit 任何檔案**） | 由**你或我在殼層手動**建兩個試寫專案：`app-a`＝`npm create vite@latest app-a -- --template vue` 後各自 `npm install`（要網路）；`app-b`＝複製 `app-a` 再手動砍 `.opencode/frontend-devkit/project.md`。兩者各自 `git init` 並留一個 commit 當審核標的 | 兩個專案都能 `npm run build` 過；`app-a` 乾淨可提交；**kit 的 agent 不做這些動作**（setup 無建專案的權限，也不該有） |
| 1 載入關 | 裝全域後，任一探視用資料夾（**尚未 init**） | agent 與指令清單是否正確、ID 是否帶命名空間、**rules／程序檔有沒有被誤當 agent 發現**（見 §4.2 發現規則陷阱）、**主體地板是否生效**（本階段還沒有專案端規則，只能驗「必被拒」的方向）、**developer 拒絕編輯的完整清單**：四種設定檔路徑形（根相對 `opencode.json`、根絕對形、`.opencode/opencode.json`、worktree 內 `.worktrees/<n>/opencode.json`）＋ `opencode.jsonc` 變體 ＋ **`.git/hooks/pre-commit`（第 4 輪嚴重項 #1）** ＋ `.opencode/frontend-devkit/project.md`（不屬 developer 的職責範圍） | 四個 `frontend-devkit/*` agent、六個 `/frontend-devkit/*` 指令可被選取；agent 清單沒有多出 `frontend-devkit/rules/...` 之類條目；寫入性指令被 deny；**上述每一種編輯嘗試都必須被拒**（G2／G13／第 4 輪 #1）；`inspect` 跑得出結果（此階段欄位大量 TBD 屬預期，不算失敗） |
| 2 產生關 | 專案 A（已完成 init） | `init auto` 與 `init`（含問答）產物差異、TBD 是否如實、設定檔合併是否保留既有欄位、**probe 的版本迴歸判別（B 版：第 0 條 `Get-Location` 落點＋第 1 條靜態清單 gate＋第 2 條地板）** | 兩份 profile 欄位來源標註正確；未掃到的寫 TBD 不腦補；設定檔原欄位一字不動；**probe 第 1 條（專案端 gate）allow、第 2 條 deny**；第 0 條落點錯 → 先修操作環境再重測（不得用別棵樹的結果充數）；第 1 條被拒 → 記錄、依 permission-spec.md §7.3.0.1#2 標「需人工執行」並檢查主體清單是否该升級（permission-spec.md §7.3.0）後重跑本關 |
| 3 compile 關 | 專案 A | 亂改 pack id、停用 pack、啟用不存在 pack、改 pack 內容不重譯 | 每種都得到明確報錯或過期警告，無靜默成功 |
| 4 流程關 | 專案 A | `/frontend-devkit/dev` 加一個小功能（按鈕 + 一個測試）：動態基準、worktree 建立／清除、七區段回報、commit 前先給你審訊息 | 全流程不問多餘問題、結束 worktree 乾淨、基準數字來自當場量測 |
| 5 審核關 | 專案 A 故意留一個爛 commit | `/frontend-devkit/review <sha>`：輸出七個區段齊全（`目標`、`VERDICT`、`ISSUES`、`既有問題`、`疑問`、`回歸檢驗`、`建議手動回歸檢查`）、審核 worktree 必清 | 有「嚴重或一般」就 FAIL；範圍空不 PASS；`git worktree list` 只剩主工作區 |
| 6 降級關 | 專案 B（砍掉 `project.md`）／`shell: TBD` 的假 profile／**移除專案端 jsonc 的 `agents` 節點** | §11 各列行為；含「僅本次口述 gate」這條 fallback 分支（要驗到「該模式 reviewer 不跑 gate、回報標弱依據」）；以及「拿掉專案端 agents 節點後，**主體地板仍拒非白名單指令**」（第 4 輪修正：舊寫法「無 shell 規則＝全開」是錯的威脅模型，規則來自 agent `.md`，隨 agent 載入） | 每種狀況停止點與提示符合規格，不出現憑空假設；第三種情境要證明「少專案端規則＝偏嚴」而非＝全開；口述模式要證明 gate 沒被虛報 |
| 7 安全地板關 | 專案 A | (a) 把 `security/vue-xss` 從 `## 啟用規則` 移除後跑 dev／fix／review-fix／review 四條；(b) 用 `## 專案覆寫` 寫「本專案跳過渲染前清理」；(c) 把 `## 已知豁免` 寫成「所有 lint error 皆豁免」；(d) **四欄非法值各試一次**：`設定檔路徑`→`~/.config/opencode/opencode.json`、`kitRoot`→`/tmp/x`、`worktree 目錄`→`../out`、`環境檔`→`../secret.env` | (a) dev／fix／review-fix 走 orchestrator `question` 二次確認（選項寫出後果）；`/review` 則 reviewer **不開始審核**並輸出固定提示句（因它 `question: deny`，不得假設你已同意）；確認後回報仍含主體基本安全項。(b) reviewer 照查、引用覆寫原文、列「嚴重」。(c) `setup` 寫入時即因格式不符拒絕，`inspect` 標示超限。(d) `setup` 全部拒絕寫入，`inspect` 每輪檢出並停止流程 |
| 8 零影響查核 | 本專案 TOS_Frontend | `git status --short`、`.opencode/` 內容、舊 `/dev` 抽測 | 工作區乾淨；四個檔 diff 為空；舊流程照常 |

---
