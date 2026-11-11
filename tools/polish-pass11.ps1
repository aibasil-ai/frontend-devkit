# 第 5 輪結構性批次修正（方案 B 貫穿、probe 重定義、降級三角色）
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  # 1) §12 遷移表補 *.git/*
  @('`*.opencode/*`（`*` 跨 `/`，一條即涵蓋根形、`.opencode` 形、worktree 內副本 `.worktrees/<n>/opencode.json`、正規化後的絕對形）',
    '`*.opencode/*`、`*.git/*`（第 5 輪補 `.git`；`*` 跨 `/`，一條即涵蓋根形、`.opencode` 形、worktree 內副本、`.git/hooks`，已由 experiments 第 6 題實測六種形全拒）'),

  # 2) D19 加「方案 A 保留條款」前綴
  @('| allow∩deny 必須為空（**方案 A 的前提**）',
    '| allow∩deny 必須為空（**方案 A 保留條款：僅在 §7.3.0 覆驗成功、方案 A 啟用後才適用**）'),

  # 3) probe 第 1 條在方案 B 下的新定義
  @('1. **判別力第一條鐵律（G5）**：probe 的第 1 條**必須是「只存在於專案端 jsonc 的 gate 指令」**（init 剛寫進去的那條，例 `pnpm --filter web test *`）。用 `git rev-parse *` 這種主體本就 allow 的指令做第 1 條是無效測試——任何次序都會 allow，驗不出次序。',
    '1. **方案 B 下的 probe 定位（第 5 輪重定義）**：專案端已不寫 shell 規則，「判別跨來源次序」這件事在 B 下**無物件可測**，因此 probe 改為**版本迴歸偵測**：第 0 條先 `Get-Location`（確認執行落點就是本專案，experiments 二.1 的教訓），第 1 條測「主體靜態清單內的 gate」（例 `npm test *`）→ 預期 allow；第 2 條測一條必被拒的寫入指令 → 預期 deny。原先「第 1 條必須只來自專案端 jsonc」的判別力設計，**整段移入 §7.3.0 的方案 A 復活檢測**（見該節先決步驟）。'),
  @('| 上次 `probe` 日期／OpenCode 版本 | 2026-11-11／v2.2.7 |',
    '| 上次 `probe` 日期／OpenCode 版本 | 2026-11-11／v2.2.7 |'),
  @('| probe 第 1 條（專案端 gate allow）結果 | allow |',
    '| probe 第 0 條 `Get-Location` 落點＝本專案？ | 是 |'),
  @('| probe 第 2 條（必被拒的寫入指令）結果 | deny |',
    '| probe 第 1 條（靜態清單 gate，如 `npm test`）／第 2 條（寫入指令）結果 | allow／deny |'),

  # 4) §13 關卡 2 的 B 判準
  @('**跨來源次序判別**（只有這裡才有「只來自專案端 jsonc 的 gate allow」可當 probe 第 1 條，G5）',
    '**probe 的版本迴歸判別（B 版）**：第 0 條 `Get-Location` 落點、第 1 條靜態清單 gate、第 2 條地板'),
  @('**probe 第 1 條（專案端 gate）allow、第 2 條 deny**；第 1 條被拒 → 記錄並改走方案 B（§7.3.0）後重跑本關',
    '第 1 條 EXECUTED、第 2 條 DENIED；另驗「profile `## 指令` 若不在靜態清單 → `resolved.md` 標『需人工執行』」（§7.3.0.1#2）。**跨來源次序的判別已移入方案 A 復活檢測**'),

  # 5) §11 口述 gate：三角色分別降級（B 語彙）
  @('**降級明細（第 4 輪一般 #7：否則物理上跑不動）**：無 profile＝無專案端 allow，而 reviewer 的 shell 是 `deny *` 起頭 → **該模式 reviewer 不執行任何 gate**（developer 是 `ask` 起頭，仍可彈窗問你後執行）。',
    '**降級明細（第 5 輪改正：方案 B 下不是「全部跑不了」，而是三角色不同）**：① **reviewer**（`deny *` 起頭）——口述 gate 若正好是靜態清單內的指令（`npm test *`、`npx eslint *`…）**可執行**；清單外一律「需人工執行」，並在回報註明；② **developer**（`ask` 起頭）——清單外會**彈窗問你**，你准了才跑；③ **orchestrator**——它的白名單本就靜態內建，不受有無 profile 影響（只有 worktree／環境檔等參數需要 profile）。'),

  # 6) §11 二次確認列補 /review 例外
  @('四個流程指令啟動前 → 用 `question` 要你**明確二次確認**',
    'dev／fix／review-fix（orchestrator，`question` allow）啟動前 → 用 `question` 要你**明確二次確認**；`/review` 例外：reviewer `question: deny`，改由它輸出固定提示句並**不開始審核**（§3 第 3 點）'),
  @('（a）dev／fix／review-fix／review 四條',
    '（a）dev／fix／review-fix 走 `question` 二次確認、review 走固定句不開始審核'),
  @('（a）必須出現 `question` 二次確認且選項寫出後果；未確認不得進入流程',
    '（a）orchestrator 三指令必須出現 `question` 二次確認且選項寫出後果；`/review` 必須**不開始審核**並輸出固定句（不得假設你已同意）'),

  # 7) §5 額外 shell 改定義（B 下不是寫規則）
  @('**寫入範圍（第 3 輪殘留漏洞 #3）**：這一欄**只追加到 developer 的規則節點**；reviewer 需要者走 §8.1 專案端 gate 逐條批准，否則「唯讀最小集」會被這欄悄悄撐大。',
    '**方案 B 下的定義（第 5 輪改正）**：這一欄**不再是授權來源**（專案端不寫 shell 規則）。它的兩個用途：① developer 的「詢問預期清單」——清單內指令首次執行時你選 `Allow always`，官方會存成專案級持久 allow（§7.3.1 事實 7），這是 B 下 developer 唯一的合法擴充路；② 給 `compile` 判斷「哪些 gate 需要人工執行」。reviewer 需要的新指令**不能靠這欄擴張**（它的地板是 deny，持久 allow 蓋不掉 deny），只能改 kit 主體清單並升級。'),

  # 8) §4.3 專案端設定內容去「shell 權限」
  @('追加 instructions、shell 權限、model（既有欄位不覆蓋）',
    '追加 instructions 與 model（既有欄位不覆蓋）。**方案 B 下不得在此寫 shell 規則**；`inspect` 若偵測到 `agents.<id>.permissions` 含 shell 條目 → 警告「與方案 B 矛盾，且依 experiments 第 3 題此類 allow 不會生效」')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0].Substring(0, [Math]::Min(50, $p[0].Length))) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass11 done ==='
