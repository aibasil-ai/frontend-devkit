# 第 5 輪結構修正（第二批，錨點以檔內實際文字為準）
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  # §12 遷移表補 *.git/*
  @('`allow *` 之後 deny `*opencode.json`、`*opencode.jsonc`、`*.opencode/*`——**v1 遷移時被我弄丟的提權封堵**',
    '`allow *` 之後 deny `*opencode.json`、`*opencode.jsonc`、`*.opencode/*`、**`*.git/*`**（第 5 輪補 `.git`，四條；六種路徑形已由 `experiments.md` 第 6 題實測全拒）——**v1 遷移時被我弄丟的提權封堵**'),

  # §8.2 probe 第 1 條：方案 B 重定義
  @('1. **判別力第一條鐵律（G5）**：probe 的第 1 條**必須是「只存在於專案端 jsonc 的 gate 指令」**（init 剛寫進去的那條，例 `pnpm --filter web test *`）。用 `git rev-parse *` 之類「主體本来就 allow」的指令做第 1 條是無效測試——任何次序都會放行，驗不出次序。',
    '1. **方案 B 下的定位（第 5 輪重定義）**：專案端已不寫 shell 規則，「判別跨來源次序」在 B 下**無物件可測**，因此 probe 改為**版本迴歸偵測**。**第 0 條必先是 `Get-Location`**（`experiments.md` 二.1：shell 落在 service 綁定的專案目錄，可能不是你以為的那個），用來確認落點就是本專案；第 1 條測「主體靜態清單內的 gate」（例 `npm test *`）→ 預期 allow。原本的「第 1 條必須只來自專案端 jsonc」判別力設計，**整段移入 §7.3.0 的方案 A 復活檢測**。'),
  @('2. 第 1 條（專案端 gate）→ 預期 allow；第 2 條（必被拒的寫入指令，例 `git commit --allow-empty -m probe`）→ 預期 deny。',
    '2. 第 1 條（靜態清單 gate）→ 預期 allow；第 2 條（必被拒的寫入指令，例 `git commit --allow-empty -m probe`）→ 預期 deny。第 1 條若被拒＝清單與主體不同步或落點錯了（回到第 0 條查）。'),

  # 關卡 2 的 B 判準
  @('**跨來源次序判別**（只有這裡才有「只來自專案端的 gate allow」可當 probe 第 1 條，G5）',
    '**probe 的版本迴歸判別（B 版：第 0 條 `Get-Location` 落點＋第 1 條靜態清單 gate＋第 2 條地板）**'),
  @('**probe 第 1 條（專案端 gate）allow、第 2 條 DENIED**；第 1 條被拒 → 記錄、改走方案 B（§7.3.0）後重跑本關',
    '**第 0 條落點＝本專案、第 1 條 EXECUTED、第 2 條 DENIED**；另驗「profile `## 指令` 若不在靜態清單 → `resolved.md` 標『需人工執行』」（§7.3.0.1#2）。跨來源次序判別已移入 §7.3.0 的方案 A 復活檢測'),

  # §11 二次確認列補 /review 例外
  @('四個流程指令啟動前必須 `question` **二次確認**（選項文字要寫出後果：「僅執行主體基本安全項，不含專案專屬 sanitizer／白名單檢查」），未確認不得進入流程；確認後 reviewer 仍執行 §3 第 0 點，並在回報標「未啟用安全 pack」',
    '**orchestrator 的三條**（dev／fix／review-fix）啟動前必須 `question` **二次確認**（選項文字要寫出後果：「僅執行主體基本安全項，不含專案專屬 sanitizer／白名單檢查」），未確認不得進入流程；**`/review` 例外**：reviewer `question: deny`，改為**不開始審核**並輸出固定提示句（§3 第 3 點），不得假設你已同意。確認後 reviewer 仍執行 §3 第 0 點，並在回報標「未啟用安全 pack」'),

  # §5 額外 shell 改定義
  @('**寫入範圍（第 3 輪殘留漏洞 #3）**：這一欄**只追加到 developer 的規則節點**；reviewer 若需要額外指令，一律走 §8.1 的專案端 gate 逐條批准，否則「唯讀最小集」會被這欄悄悄撐大。',
    '**方案 B 下的定義（第 5 輪改正：這一欄不再是授權來源）**：① 它是 developer 的「詢問預期清單」——清單內指令首次執行時你選 `Allow always`，官方會存成專案級持久 allow（§7.3.1 事實 7），這是 B 下 developer 唯一合法的擴充路徑；② 給 `compile` 判斷「哪些 gate 需人工執行」。**reviewer 不能靠這欄擴張**（它的地板是 deny，而持久 allow 蓋不掉設定 deny），需要新指令只能改 kit 主體清單並升級。')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0].Substring(0, [Math]::Min(48, $p[0].Length))) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass12 done ==='
