# 驗證方式：關卡 0～8（主檔 §13 的外移附檔）

> 這是測試計畫；實裝主流程時不必在主檔讀它，但每關的通過條件是驗收標準。

> 本檔是 `specs/2026-11-11-frontend-devkit-design.md`（主檔）的附檔。章節編號沿用主檔原編號以維持引用穩定；文中 `§X` 若帶檔名前綴（如 `acceptance.md §13`）指附檔，**未帶前綴的 `§X` 一律指主檔**。主檔頂端的「0. 檔案地圖」是全套檔案的入口。

## 13. 驗證方式

| 關 | 在哪 | 檢查什麼 | 通過條件 |
|---|---|---|---|
| **0 建置（人工，不屬於 kit 的權限模型）** | `%LOCALAPPDATA%\Temp\opencode\frontend-devkit-eval\`（本機範例：`C:\Users\vipjo\AppData\Local\Temp\opencode\`；**這是給本機執行者看的路徑，不寫進 kit 任何檔案**） | 由**你或我在殼層手動**建兩個試寫專案：`app-a`＝`npm create vite@latest app-a -- --template vue` 後各自 `npm install`（要網路）；`app-b`＝複製 `app-a` 再手動砍 `.opencode/frontend-devkit/project.md`。兩者各自 `git init` 並留一個 commit 當審核標的 | 兩個專案都能 `npm run build` 過；`app-a` 乾淨可提交；**kit 的 agent 不做這些動作**（setup 無建專案的權限，也不該有） |
| 1 載入關 | 裝全域後，任一探視用資料夾（**尚未 init**） | agent 與指令清單是否正確、ID 是否帶命名空間、**rules／程序檔有沒有被誤當 agent 發現**（見 §4.2 發現規則陷阱）、**主體地板是否生效**（本階段還沒有專案端規則，只能驗「必被拒」的方向）、**developer 拒絕編輯的完整清單**：四種設定檔路徑形（根相對 `opencode.json`、根絕對形、`.opencode/opencode.json`、worktree 內 `.worktrees/<n>/opencode.json`）＋ `opencode.jsonc` 變體 ＋ **`.git/hooks/pre-commit`（第 4 輪嚴重項 #1）** ＋ `.opencode/frontend-devkit/project.md`（不屬 developer 的職責範圍） | 四個 `frontend-devkit/*` agent、六個 `/frontend-devkit/*` 指令可被選取；agent 清單沒有多出 `frontend-devkit/rules/...` 之類條目；寫入性指令被 deny；**上述每一種編輯嘗試都必須被拒**（G2／G13／第 4 輪 #1）；`inspect` 跑得出結果（此階段欄位大量 TBD 屬預期，不算失敗） |
| 2 產生關 | 專案 A（已完成 init） | `init auto` 與 `init`（含問答）產物差異、TBD 是否如實、設定檔合併是否保留既有欄位、**probe 的版本迴歸判別（B 版：第 0 條 `Get-Location` 落點＋第 1 條靜態清單 gate＋第 2 條地板）** | 兩份 profile 欄位來源標註正確；未掃到的寫 TBD 不腦補；設定檔原欄位一字不動；**probe 第 1 條（專案端 gate）allow、第 2 條 deny**；第 0 條落點錯 → 先修操作環境再重測（不得用別棵樹的結果充數）；第 1 條被拒 → 記錄、依 permission-spec.md §7.3.0.1#2 標「需人工執行」並檢查主體清單是否該升級（permission-spec.md §7.3.0）後重跑本關 |
| 3 compile 關 | 專案 A | 亂改 pack id、停用 pack、啟用不存在 pack、改 pack 內容不重譯 | 每種都得到明確報錯或過期警告，無靜默成功 |
| 4 流程關 | 專案 A | `/frontend-devkit/dev` 加一個小功能（按鈕 + 一個測試）：動態基準、worktree 建立／清除、七區段回報、commit 前先給你審訊息 | 全流程不問多餘問題、結束 worktree 乾淨、基準數字來自當場量測 |
| 5 審核關 | 專案 A 故意留一個爛 commit | `/frontend-devkit/review <sha>`：輸出七個區段齊全（`目標`、`VERDICT`、`ISSUES`、`既有問題`、`疑問`、`回歸檢驗`、`建議手動回歸檢查`）、審核 worktree 必清 | 有「嚴重或一般」就 FAIL；範圍空不 PASS；`git worktree list` 只剩主工作區 |
| 6 降級關 | 專案 B（砍掉 `project.md`）／`shell: TBD` 的假 profile／**移除專案端 jsonc 的 `agents` 節點** | §11 各列行為；含「僅本次口述 gate」這條 fallback 分支（要驗到「該模式 reviewer 不跑 gate、回報標弱依據」）；以及「拿掉專案端 agents 節點後，**主體地板仍拒非白名單指令**」（第 4 輪修正：舊寫法「無 shell 規則＝全開」是錯的威脅模型，規則來自 agent `.md`，隨 agent 載入） | 每種狀況停止點與提示符合規格，不出現憑空假設；第三種情境要證明「少專案端規則＝偏嚴」而非＝全開；口述模式要證明 gate 沒被虛報 |
| 7 安全地板關 | 專案 A | (a) 把 `security/vue-xss` 從 `## 啟用規則` 移除後跑 dev／fix／review-fix／review 四條；(b) 用 `## 專案覆寫` 寫「本專案跳過渲染前清理」；(c) 把 `## 已知豁免` 寫成「所有 lint error 皆豁免」；(d) **四欄非法值各試一次**：`設定檔路徑`→`~/.config/opencode/opencode.json`、`kitRoot`→`/tmp/x`、`worktree 目錄`→`../out`、`環境檔`→`../secret.env` | (a) dev／fix／review-fix 走 orchestrator `question` 二次確認（選項寫出後果）；`/review` 則 reviewer **不開始審核**並輸出固定提示句（因它 `question: deny`，不得假設你已同意）；確認後回報仍含主體基本安全項。(b) reviewer 照查、引用覆寫原文、列「嚴重」。(c) `setup` 寫入時即因格式不符拒絕，`inspect` 標示超限。(d) `setup` 全部拒絕寫入，`inspect` 每輪檢出並停止流程 |
| 8 零影響查核 | 本專案 TOS_Frontend | `git status --short`、`.opencode/` 內容、舊 `/dev` 抽測 | 工作區乾淨；四個檔 diff 為空；舊流程照常 |

---

## 13.1 實測結果（2026-11-11 ～ 11-13，第 6 站）

| 關 | 結果 | 關鍵證據 |
|---|---|---|
| 0 建置 | ✅ | app-a／app-b 可 build；kit 的 agent 未參與建置 |
| 1 載入 | ✅ | 四個 agent＋六個指令可選；rules 未被誤認為 agent；寫入性指令被拒 |
| 2 產生 | ✅ | `init` 在 app-b 實跑（第 6 關降級情境）；TBD 如實；設定檔只寫 `instructions` |
| 3 compile | ✅ | 抓到源頭漂移（checksum＋title）、巢狀重複、0 pack、整節空白（缺陷 H、I） |
| 4 流程 | ✅ | worktree＋junction 兩步、七區段、review FAIL→修正→PASS、清 worktree 未傷 `node_modules` |
| 5 審核 | ✅ | 爛 commit（測試全綠）被 FAIL；XSS 與斷言弱化都被抓到 |
| 6 降級 | ✅ | 無 profile 不派工、口述 gate 不虛報、`inspect probe` 三條正確 |
| 7 安全地板 | ✅ | (a) 三選項＋選②零動作；(b) 覆寫未被當授權且判嚴重；(c) 豁免超限；(d) BLOCKED |
| 8 零影響 | ✅ | `TOS_Frontend_Fia` 的 `git status` 乾淨、`.opencode/` diff 為空、mtime 停在 11/04 |

### 缺陷索引（M 之後；A–K 見 `acceptance-findings.md` 前段）

| # | 一句話 | 落點 |
|---|---|---|
| M | `VERDICT` 沒有基準 sha／指紋，commit 後無法證明「被審＝被 commit」 | `reviewer.md` §1／§6 |
| N | 行號與數量憑印象（dev 偏 3 行×2、reviewer 錯 1 處） | `developer.md` §10、`reviewer.md` §1 |
| O | 環境檔清單非空時，`.env` 未被 `.gitignore` 忽略仍會被複製 | `setup.md` §4 2b |
| P | 把「標準 gate reviewer 可跑」說成「多半跑不起來」 | `orchestrator.md` §5 |
| Q | `depStrategy` 推薦 `junction`，未驗 `node_modules` 存在 | `orchestrator.md` §5、`setup.md` §2 |
| S | 複合指令被拒 → 誤判「我沒有 shell 權限」 | `reviewer.md` §1 |
| T | 選「不要 worktree」仍問 `depStrategy` | `orchestrator.md` §5 |
| U | 用「我補上」代替 reviewer 的獨立查證 | `orchestrator.md` §6 |
| V | probe 由 reviewer 執行，但 reviewer 沒有 `Get-Location` | `reviewer.md` allow |
| **W** | **`compile` 只放 pack 摘要表，沒折入正文 → agent 看不到檢查清單** | `setup.md` §4 6b、§5 5b |
| X | `resolved.md` 格式漂移（條列 vs 表格、章節名不同） | `setup.md` §4 第 8 點 |
| Y | 回報「某指令無權限」卻沒查自己的 allow 清單 | `setup.md` §5 5c |
| Z | 規格要求 `Select-String`，但 allow 清單沒有它 | `setup.md` allow |
| AA | 一條頂格規則讓整份 YAML 失效 → `Agent not found` | 縮排修正＋`check-structure.ps1` |
| AB | 阻斷性 gate 與規劃性問題併問 | 未修（觀察項） |
| AD | M 的指紋指令 `git hash-object` 不在 allow 清單 | `reviewer.md` allow |
| AF | 回報引用了已還原的 `M src/App.vue` | `setup.md` §8 第 6 條 |
| AG | `安裝紀錄` 的 compile 次數永遠追不上 `resolved.md` | `setup.md` §4 第 9 點 |
| AH | agent 定義在 TUI 進程啟動時載入，「開新 session」不會重讀 → 假訊號 | `tui-run-checklist.md` 開頭＋本檔 |

> 未成立、因此未修的編號：**L**（commit 未先審——實測有先審）、**AC**（`.opencode/` 干擾審核——實測未發生）、**AE**（compile 未拒總括豁免——規格本來就只要求 `setup` 寫入時與 `inspect` 驗，是我對關卡的期待寫錯）。

### 這輪驗收真正的產出

八關打勾只是門檻；**真正的產出是 26 個缺陷（A–AG）與 3 個「未成立」的撤回**。其中 5 個（H、I、W、AA、AD）屬於「不看實作就看不出來」的類型——尤其 **W**（pack 正文沒折入）會讓安全檢查**靜默失效而八關全過**，正是這套驗收流程存在的理由。

---
