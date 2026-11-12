---
description: 修復 bug：先重現並找根因，再依 dev 流程開發與審核，最多 3 輪
agent: frontend-devkit/orchestrator
---

模式：fix
任務：$ARGUMENTS

請依 orchestrator 流程執行，並先確認能看到專案的 `project.md` 與 `resolved.md`。派工給 developer 時要明確提醒：先重現問題並找出根因，可行時先補一個會失敗的測試，修復後確認該測試轉綠；回報需說明「修的是根因而非症狀」與理由。
