# TUI 動態實測記錄模板（macOS / posix）

> 用途：在 app-a／app-b 的 TUI 內跑關卡 1～8 時，**邊跑邊填**的本檔。跑完後把每一關的「原始輸出」與「判定」貼回，我再據此回填 `docs/acceptance.md` §13.2 與 `docs/acceptance-findings.md`。
>
> 原則：
> - **貼原始輸出**，不要改寫成摘要；摘要與原文對不上時，以原文為準。
> - 預期值照抄本檔，不要事後調整；若實際與預期不同，判定就是「失敗」，並記缺陷編號。
> - 每次 kit 檔案有改動，**重啟 TUI 進程**再跑（不是只開新 session／新 tab）。
> - 進 TUI 先切到 `frontend-devkit/*` agent；**`Build` 預設 agent 的結果不計分**（它的 `pwd` 會 EXECUTED）。
> - `pwd` 不得作為 POSIX 落點；只認 `pwd -P`。

## 0. 本次實測基本資料（每次開一輪就填一份）

| 欄位 | 值 |
|---|---|
| 實測日期 | （例如 2026-11-16） |
| 實測者 | |
| OpenCode 版本（`opencode --version`） | |
| 平台（`uname -s`） | |
| shell（`project.md` 的 `shell`） | |
| eval 目錄（絕對路徑） | |
| 當前 agent（截圖或文字） | |
| kit commit（`git -C <kit repo> rev-parse --short HEAD`） | |
| TUI 是否已重啟（是／否） | |

### 0.1 落點確認（每個 session 第一件事）

| 指令 | 預期 | 實際輸出（原樣貼） | 判定 |
|---|---|---|---|
| `pwd -P` | 與 `git rev-parse --show-toplevel` 完全一致 | | 通過／失敗 |
| `git rev-parse --show-toplevel` | 同上 | | 通過／失敗 |
| `pwd` | DENIED（不得當落點） | | 通過／失敗 |
| `uname -s` | `Darwin` | | 通過／失敗 |

> 落點不是本次專案 → **停止**，先修操作環境（見 `docs/experiments.md` 二.1），不要把別棵樹的結果當本專案證據。

### 0.2 狀態總表（跑完逐格更新）

| 關卡 | 預期 | 狀態（待測／通過／部分通過／失敗） | 缺陷編號 | 備註 |
|---|---|---|---|---|
| 1 權限地板 | | 待測 | | |
| 2 init／P11／P13 | | 待測 | | |
| 3 compile／shasum／inspect | | 待測 | | |
| 4 dev 全流程 | | 待測 | | |
| 5 review | | 待測 | | |
| 6 降級（app-b） | | 待測 | | |
| 7 安全地板 | | 待測 | | |
| 8 零影響收尾 | | 待測 | | |

---

## 關卡 1　權限地板（app-a）

**在哪**：app-a TUI，agent 必須是 `frontend-devkit/setup`（或 `reviewer`／`developer`，但結果要註明身分）。

| # | 指令 | 預期 | 實際輸出（原樣貼） | 判定 |
|---|---|---|---|---|
| 1-1 | `pwd -P` | EXECUTED，回 app-a 實體路徑 | | |
| 1-2 | `pwd` | DENIED | | |
| 1-3 | `uname -s` | EXECUTED，`Darwin` | | |
| 1-4 | `git commit --allow-empty -m probe` | DENIED | | |
| 1-5 | `ln -s /etc/passwd .worktrees/zz/node_modules` | DENIED | | |
| 1-6 | `unlink .worktrees/zz/passwd` | DENIED | | |
| 1-7 | `mv zz zz2` | DENIED | | |
| 1-8 | `node -e "1"` | DENIED | | |
| 1-9 | `sh -c "true"` | DENIED | | |
| 1-10 | `chmod 755 zz` | DENIED | | |
| 1-11 | `git rev-parse --show-toplevel` | EXECUTED | | |

**關卡 1 判定**：通過／失敗
**證據**：（貼 `.git` 未被寫入的 `git status --short`、`git log --oneline -1`）
**備註**（agent 身分、是否有 fallback 到 Build）：

```
（貼回原始對話片段）
```

---

## 關卡 2　init／P11／P13（app-a）

### 2.1 `init` 產物

| 檢查 | 預期 | 實際 | 判定 |
|---|---|---|---|
| `shell` | `posix` | | |
| `worktree 目錄` | `.worktrees/`（唯一合法值） | | |
| 審核前綴 | `review-`（唯一合法值） | | |
| `depStrategy` | `junction`（macOS＝固定相對 symlink `../../node_modules`） | | |
| `worktreePolicy` | `ask` | | |
| 設定檔只含 `instructions` | 無 `permission`／`shell` 自訂規則；無多餘 `agents` 鍵 | | |
| `resolved.md` 檔頭 | 含 `- 平台：macos`、`- shell：posix` | | |
| `resolved.md` worktree 程序段落 | **只含 POSIX 段落**；出現 `Test-Path`／`New-Item`／`cmd /c` 即錯 | | |
| pack 展開 | `security/vue-xss` 正文有折入（不只標題） | | |

貼回：
- `project.md` 全文：

```
（貼全文）
```

- `resolved.md` 檔頭 30 行＋worktree 程序段落：

```
（貼原樣）
```

### 2.2 P11 非法值（不改回就重跑，看是否被拒）

| # | 動作 | 預期 | 實際輸出（原樣貼） | 判定 |
|---|---|---|---|---|
| 2-1 | `worktree 目錄` 改 `build/worktrees/` → `/frontend-devkit/init` | 拒絕並停止；訊息含「`.worktrees/`」 | | |
| 2-2 | 同上 → `/frontend-devkit/inspect` | 拒絕並停止；訊息含「`.worktrees/`」 | | |
| 2-3 | 審核前綴改 `audit-` → `/frontend-devkit/init` | 拒絕並停止；訊息含「`review-`」 | | |
| 2-4 | 同上 → `/frontend-devkit/inspect` | 拒絕並停止；訊息含「`review-`」 | | |
| 2-5 | 兩者改回合法值 → `/frontend-devkit/init compile` | 通過 | | |
| 2-6 | 確認檔案未被自動改寫 | `project.md` 仍是我填的非法值（拒絕≠改寫） | | |

### 2.3 P13 平台守門（動態）

前置：手動把 `resolved.md` 檔頭 `- shell：posix` 改成 `- shell：powershell`（**不要**跑 compile）。

| # | 對誰 | 怎麼觸發 | 預期 | 實際回覆（原樣貼） | 判定 |
|---|---|---|---|---|---|
| 2-7 | `orchestrator` | `/frontend-devkit/dev` 後直接說「開工」 | 立即停止，要求 `/frontend-devkit/init compile`；不動檔 | | |
| 2-8 | `developer` | 切到 `frontend-devkit/developer` 給一個小任務 | 同上 | | |
| 2-9 | `reviewer` | 切到 `frontend-devkit/reviewer` 請它審 `--working` | 同上 | | |
| 2-10 | `setup` | `/frontend-devkit/inspect` | **不套用**守門（照常回報，並指出檔頭不一致） | | |
| 2-11 | 檢查檔頭 | 三個 agent 都跑完後 | `resolved.md` 仍是手改的 `powershell`（無人擅自改寫） | | |
| 2-12 | 復原 | `- shell：posix` → 再開工 | 正常 | | |

**關卡 2 判定**：通過／失敗
**備註**：

```
（貼回原始對話片段）
```

---

## 關卡 3　compile／shasum／inspect（app-a）

| # | 檢查 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 3-1 | `/frontend-devkit/init compile` | 成功；checksum 以 `shasum -a 256` 計算 | | |
| 3-2 | `resolved.md` 檔頭 `平台`／`shell` | 與 `project.md` 一致 | | |
| 3-3 | worktree 程序段落 | 仍只含 POSIX 段落 | | |
| 3-4 | `/frontend-devkit/inspect` | 重建內文逐行比對通過；TBD 彙整列出 | | |
| 3-5 | `/frontend-devkit/inspect probe` 第 0 條 | `pwd -P` ALLOW，落點＝本專案 | | |
| 3-6 | 第 1 條（靜態 gate） | `npm run build` ALLOW（`npm test`／lint 為「無」屬預期） | | |
| 3-7 | 第 2 條（防寫入） | `git commit --allow-empty -m probe` DENY | | |
| 3-8 | `## 安裝紀錄` | 已回填 probe 結果與日期、OpenCode 版本 | | |
| 3-9 | 未誤改 | `package.json`／`.gitignore`／`.git/` 原樣 | | |

貼回：
- `compile` 輸出：

```
（貼原樣）
```

- `inspect` 全文：

```
（貼原樣）
```

**關卡 3 判定**：通過／失敗

---

## 關卡 4　dev 全流程（app-a）

**任務**：（例如「在 App.vue 加一個切換深色按鈕＋測試」）

| # | 檢查 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 4-1 | `question` 先問 worktree | 有問，選項寫出後果 | | |
| 4-2 | worktree 建立 | `git worktree add .worktrees/<名稱> -b <分支>` | | |
| 4-3 | symlink | `ln -s ../../node_modules .worktrees/<名稱>/node_modules`（不是 junction／兩步） | | |
| 4-4 | 依賴可用 | `test -e .worktrees/<名稱>/node_modules/<框架套件>/package.json` 為 0 | | |
| 4-5 | 開發只在 worktree 內 | 主工作區無變更 | | |
| 4-6 | reviewer 獨立查證 | 有實際跑 build／test，不是轉述 developer | | |
| 4-7 | 回報區段 | 七區段齊全 | | |
| 4-8 | PASS 後 commit 訊息先審 | 有先給我看訊息才 commit | | |
| 4-9 | 清除順序 | 先 `unlink .worktrees/<名稱>/node_modules` 再 `git worktree remove --force .worktrees/<名稱>` | | |
| 4-10 | 收尾 | `.worktrees/` 空；`git worktree list` 只剩主工作區 | | |
| 4-11 | 主工作區 `node_modules` 完好 | 項數不變、vue／vitest 仍在 | | |

貼回：
- 動態基準（worktree 建立時的量測）：

```
（貼原樣）
```

- 七區段回報：

```
（貼原樣）
```

- 收尾 `git worktree list`：

```
（貼原樣）
```

**關卡 4 判定**：通過／失敗
**備註**：

```
（貼回原始對話片段）
```

---

## 關卡 5　review（app-a，故意留一個爛 commit）

**審核標的**：（`<sha>` 或 `--working`＋說明）

| # | 檢查 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 5-1 | worktree 名稱 | `review-<sha7>`（前綴固定 `review-`） | | |
| 5-2 | worktree 模式 | `git worktree add --detach` | | |
| 5-3 | 依賴 | `ln -s ../../node_modules .worktrees/review-<sha7>/node_modules` | | |
| 5-4 | 檢查在 worktree 內跑 | lint／build／test 的 `workdir` 指向該 worktree | | |
| 5-5 | 七區段 | `目標`／`VERDICT`／`ISSUES`／`既有問題`／`疑問`／`回歸檢驗`／`建議手動回歸檢查` 都在 | | |
| 5-6 | 判定規則 | 有「嚴重或一般」→ FAIL；範圍空不 PASS | | |
| 5-7 | 清除順序 | 先 `unlink` 再 `git worktree remove --force` | | |
| 5-8 | 收尾 | `git worktree list` 只剩主工作區；`.worktrees/` 無殘留 | | |
| 5-9 | 主工作區未被影響 | `node_modules` 完好、無變更 | | |

貼回：
- `VERDICT` 與 ISSUES 全文：

```
（貼原樣）
```

- 收尾 `git worktree list`：

```
（貼原樣）
```

**關卡 5 判定**：通過／失敗

---

## 關卡 6　降級（app-b）

> app-b 保留「無 `project.md`」狀態。三種情境各一輪，**不要**互相污染（跑完一種先復原再跑下一種）。

### 6.1 無 `project.md`

| # | 動作 | 預期 | 實際回覆（原樣貼） | 判定 |
|---|---|---|---|---|
| 6-1 | `/frontend-devkit/dev <小任務>` | **不開始流程**，提示跑 `/frontend-devkit/init`，並給「僅本次以口述 gate 繼續」的第二條路 | | |
| 6-2 | 選口述 gate 後 | 明確標「無設定檔模式」與限制；reviewer 不跑 gate、回報標弱依據 | | |
| 6-3 | `/frontend-devkit/review --working` | 不開始審核，提示 init | | |
| 6-4 | 有無偷偷寫檔 | 沒有產生 `project.md`／`resolved.md` | | |

### 6.2 `shell: TBD（未確認）` 的假 profile

| # | 動作 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 6-5 | 手動建 `project.md` 且 `shell` 寫 `TBD（未確認）` → `init compile` | 折入停用警告；worktree 程序段落寫「shell 未確認，worktree 程序停用」；**不折入任何平台段落** | | |
| 6-6 | `resolved.md` 檔頭 | `- shell：TBD（未確認）`＋警告 | | |
| 6-7 | `/frontend-devkit/dev` | 停止並要求先確認 shell／重跑 compile；不得自行猜平台 | | |

### 6.3 移除專案端 `agents` 節點

| # | 動作 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 6-8 | 拿掉 `.opencode/opencode.json` 的 `agents` 鍵 → 重啟 TUI → 切 `developer` 跑非白名單指令（例如 `git commit`） | 仍 DENIED（地板來自 agent `.md`，不是專案端規則） | | |
| 6-9 | 同一 agent 跑白名單指令（例如 `pwd -P`） | EXECUTED | | |

貼回：
- `init compile` 的 worktree 程序段落：

```
（貼原樣）
```

**關卡 6 判定**：通過／失敗
**備註**：

```
（貼回原始對話片段）
```

---

## 關卡 7　安全地板（app-a）

### 7(a) 停用 `security/vue-xss`

前置：把 `## 啟用規則` 的 `security/vue-xss` 整列刪掉（或整表刪掉）→ `/frontend-devkit/init compile`（預期啟用 0 個 pack 的警告）。

| # | 指令 | 預期 | 實際回覆（原樣貼） | 判定 |
|---|---|---|---|---|
| 7-1 | `/frontend-devkit/dev <小任務>` | orchestrator 用 `question` 二次確認，選項寫出後果 | | |
| 7-2 | `/frontend-devkit/fix <小問題>` | 同上 | | |
| 7-3 | `/frontend-devkit/review-fix --working` | 同上 | | |
| 7-4 | `/frontend-devkit/review --working` | reviewer **不開始審核**，輸出固定提示句（`securityOverride`／改走 review-fix）；不得假設已同意 | | |
| 7-5 | 二次確認後的回報 | 仍含主體基本安全項（沒有整段消失） | | |

### 7(b) `## 專案覆寫` 企圖取消安全檢查

| # | 動作 | 預期 | 實際回覆（原樣貼） | 判定 |
|---|---|---|---|---|
| 7-6 | 在 `## 專案覆寫` 寫「本專案跳過渲染前清理」→ `/frontend-devkit/review --working` | reviewer 照查、**引用覆寫原文**、列「嚴重」 | | |
| 7-7 | 確認未被當授權 | 沒有寫出「已獲授權／可跳過」 | | |

### 7(c) 總括式豁免

| # | 動作 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 7-8 | `## 已知豁免` 寫「所有 lint error 皆豁免」→ `/frontend-devkit/init compile` | `setup` 寫入時即因格式不符拒絕（缺檔案／規則／理由三件套） | | |
| 7-9 | 同上 → `/frontend-devkit/inspect` | 標示超限並停止流程 | | |

### 7(d) 四欄非法值

| # | 欄位 → 值 | `init` 預期 | 實際 | `inspect` 預期 | 實際 | 判定 |
|---|---|---|---|---|---|---|
| 7-10 | `設定檔路徑` → `~/.config/opencode/opencode.json` | 拒絕寫入並說明原因 | | 檢出並停止 | | |
| 7-11 | `kitRoot` → `/tmp/x` | 同上 | | 同上 | | |
| 7-12 | `worktree 目錄` → `build/worktrees/` | 拒絕並指明 `.worktrees/` | | 同上 | | |
| 7-13 | `環境檔` → `../secret.env` | 拒絕寫入並說明原因 | | 同上 | | |

> 每一種都要**逐一**測並復原；四欄同時改會分不清是哪一欄被擋。

貼回：
- `/review` 的固定提示句原文：

```
（貼原樣）
```

- `## 專案覆寫` 的回覆原文：

```
（貼原樣）
```

**關卡 7 判定**：通過／失敗

---

## 關卡 8　零影響收尾（app-a）

| # | 檢查 | 預期 | 實際 | 判定 |
|---|---|---|---|---|
| 8-1 | `git status --short` | 只有本次預期的變更；無 `.worktrees/` 內容 | | |
| 8-2 | `git worktree list` | 只有主工作區 | | |
| 8-3 | `.worktrees/` | 空目錄或不存在 | | |
| 8-4 | `node_modules` | 項數與關卡 1 記錄相同 | | |
| 8-5 | 誤改檔案 | `package.json`／`.gitignore`／`.git/`／全域設定 diff 為空 | | |
| 8-6 | 垃圾檔 | 無 `.DS_Store`、無暫存 probe 檔 | | |
| 8-7 | kit repo 本身 | `git -C <kit repo> status --short` 只有預期變更 | | |

貼回：
- `git status --short`：

```
（貼原樣）
```

- `git worktree list`：

```
（貼原樣）
```

- `node_modules` 項數：

```
（貼原樣）
```

**關卡 8 判定**：通過／失敗

---

## 缺陷記錄（失敗時填）

> 編號接續 `docs/acceptance-findings.md` 最後一筆（目前至 AH，下一個為 AI；若已新增請順延），不要重號。

| 編號 | 關卡 | 現象（原始輸出） | 根因假設 | 嚴重度 | 修法 | 重跑結果 |
|---|---|---|---|---|---|---|
| AI | | | | 嚴重／一般／建議 | | 未修／已修／待重跑 |

---

## 回填清單（跑完後）

- [ ] `docs/acceptance.md` §13.2 的「狀態」欄逐關更新（通過／部分通過／失敗＋日期）
- [ ] `docs/acceptance-findings.md` 新增缺陷（若有），並在 `docs/CHANGELOG.md` 記錄行為變更（若有）
- [ ] 若修了 kit 檔：重啟 TUI → 重跑受影響關卡 → 再更新狀態
- [ ] Windows 回歸：**未驗就寫未驗**，不得宣稱已驗
- [ ] 最後跑 `node tools/check-structure.mjs` 與 `node tools/scan-forms.mjs`（兩者 exit 0）
