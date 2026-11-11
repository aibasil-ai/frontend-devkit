# 第 5 輪收尾：把「舊 probe 語意」三處殘留改成 B 版
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('5. 「偏嚴卡死」仍是真實風險，所以 `inspect [probe]` 是必經步驟（§8.2）。probe 第 1 條**必須用「只來自專案端 jsonc 的 gate 指令」**——不能用 `git rev-parse *` 這種主體本來就 allow 的指令，那樣任何次序都會 allow，完全沒有判別力（G5）。第 1 條被拒 → 次序與假設相反，改走**方案 B**（定義見 §7.3.0）；第 2 條（必被拒的寫入指令）若被准 → **立即停用 kit**，屬提權漏洞，停止並等你處理。',
    '5. **方案 B 已是現行預設**，所以本節第 1–6 點只在「方案 A 覆驗成功後」才適用（§7.3.0 先決步驟）。`inspect [probe]` 在 B 下的職責改為**版本迴歸偵測**（§8.2）：第 0 條 `Get-Location` 確認落點、第 1 條測主體靜態清單內的 gate、第 2 條測必被拒的寫入指令。第 1 條被拒 → 清單與實作不同步或落點錯了；第 2 條被准 → **立即停用 kit**（提權漏洞，不是可用性問題），並引用該規則出自哪個檔案、哪個陣列位置。'),
  @('3. 結果判讀：第 1 條被拒 → 次序與假設相反，改走**方案 B**（定義與取捨見 §7.3.0）；第 2 條被放行 → **立即停用 kit**，這是提權漏洞（不是可用性問題），停止並等你處理，且 `setup` 要在回報裡引用那條規則的出處（哪個檔案、哪一個陣列位置）。',
    '3. 結果判讀：**第 0 條的落點必須就是本專案**（`experiments.md` 二.1 的教訓），否則整輪 probe 無效、先修操作環境再重測。第 1 條被拒 → 主體靜態清單與 profile 期望不同步（依 §7.3.0.1#2 走「需人工執行」，並檢查是不是清單該升級）；第 2 條被放行 → **立即停用 kit**，屬提權漏洞，停止並等你處理，`setup` 要在回報裡引用那條規則的出處（哪個檔案、哪個陣列位置）。'),
  @('第 2 條 deny**；第 1 條被拒 → 記錄、改走方案 B',
    '第 2 條 deny**；第 0 條落點錯 → 先修操作環境再重測（不得用別棵樹的結果充數）；第 1 條被拒 → 記錄、依 §7.3.0.1#2 標「需人工執行」並檢查主體清單是否该升級')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0].Substring(0, [Math]::Min(44, $p[0].Length))) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass13 done ==='
