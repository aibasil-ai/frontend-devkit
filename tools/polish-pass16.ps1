# 第 5 輪收尾：更正「未修清單」中已過期的兩項
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('3. §11 有一整列以「未批准的可寫入指令**寫進 allow**」為前提 → B 下應改寫為「口述／task 要求跑含 `--fix` 的指令：developer 彈窗預覽原文由你拒否；reviewer 因非清單指令走需人工執行」。',
    '3. §17.8（第 4 輪表）有一格落點引用錯：宣稱「README hook 告警（§14 步驟 9）」，但步驟 9 現列的是 build 告警；hook 告警實際在 §11 的 `.git/` 列。'),
  @('5. §17.8 一處「只准許許」重聲（pass10 錨點沒打中）＋ 少數「專案端」舊語彙仍散在 §15 R9／R10、§16（約 9 行，多數已標為 A 保留條款或歷史記載）。',
    '5. §15 R9／R10 仍用方案 A 語彙（「profile 逐 script 具名 allow」「提供 `## 額外 shell` 白名單」）：第二道牆應改「主體靜態清單＋需人工執行」，R10 應改「靠 `Allow always` 存成專案級持久 allow，並由 `inspect` 審查存下的規則」。'),
  @('4. §6.3 `resolved.md` 檔頭清單缺 §7.3.0.1#4 要求的「權限模式：B」；§8 `inspect` 摘要缺「profile gate × 靜態清單比對」與「專案端設定不得含 shell 條目」兩項。',
    '4. （已修，留此紀錄）`resolved.md` 檔頭已補「權限模式（A／B）」；§11 那整列「未批准的可寫入指令寫進 allow」已改寫為 B 的四道處置。')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0].Substring(0, [Math]::Min(40, $p[0].Length))) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass16 done ==='
