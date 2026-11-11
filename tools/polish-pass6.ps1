# 第六批小修：清掉我在 §17.6 自己打出的簡體字與錯序
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('而 §7.2 已把 XSS 清單全搬进 pack', '而 §7.2 已把 XSS 清單全搬進 pack'),
  @('制造一边新的字形問題', '一邊修字形問題、一邊製造新的字形問題'),
  @('我一边修字形問題、制造一边新的字形問題', '我一邊修字形問題、一邊製造新的字形問題')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text

# 完整性檢查：行數、BOM、CRLF 一致性、有無被替換壞的半形空格黏連
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $path))
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$raw = Get-Content -Raw -Encoding UTF8 $path
$crlf = ([regex]::Matches($raw, "`r`n")).Count
$lfOnly = ([regex]::Matches($raw, "(?<!`r)`n")).Count
Write-Output ('BOM: ' + $hasBom + ' / CRLF: ' + $crlf + ' / 純 LF: ' + $lfOnly + ' / 行數: ' + (($raw -split "`r?`n").Count))
Write-Output '=== 仍疑似簡體字（含刻意保留的對照例） ==='
foreach ($ch in '进会条处试这没为内机制当让说话产东' ) {
  $ln = 0
  foreach ($line in ($raw -split "`r?`n")) {
    $ln++
    if ($line.Contains([string]$ch)) { Write-Output ('L' + $ln + ' [' + $ch + '] ' + $line.Substring(0, [Math]::Min(70, $line.Length))) }
  }
}
