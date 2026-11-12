---
description: 先審核指定範圍，FAIL 時才詢問工作方式，接手修正並重審，最多 3 輪
agent: frontend-devkit/orchestrator
---

模式：review-fix
範圍：$ARGUMENTS（省略表示用 `project.md` 的 `預設審核範圍`）

請依 orchestrator 的 review-fix 流程執行：

1. 先審不問 worktree：把範圍**原樣**交給 reviewer 解析（省略範圍時傳 `預設審核範圍` 的**字面值**，不要傳空字串或「省略」二字）。初次審核**不計輪**。
2. `PASS` 或「無可審核內容」→ 回報後結束（不改程式）。`FAIL` 才繼續。
3. FAIL 時依 `worktreePolicy` 決定工作方式；範圍是 `--working` 時**不提供 worktree 選項**（未 commit 的變更帶不進 worktree），只問「直接在主工作區修正」或「取消」。
4. 建立開發 worktree 的起點＝被審範圍最新 commit，比較基準＝該 sha；`<slug>` 由 ISSUES 主題產生。
5. 之後套用 dev／fix 的迴圈規則：每輪派**新的** reviewer；重審時要把原本完整的 ISSUES 清單與 developer 逐項處理結果（含不同意理由）交給新的 reviewer，並要求先逐項確認舊問題是否真的修好。第 3 輪仍 FAIL 就停止並詢問使用者。
6. PASS 後依協調者流程處理摘要與 commit（訊息先給使用者審），絕不 push。
