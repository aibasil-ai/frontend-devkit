# 掃描器：只回報，不改寫（第 4 輪定稿前的字形複核）
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path
$lines = $text -split "`r?`n"
$suspects = '单长标移动写给还让们说话认产条电视观觉机现当应风险处让这没为与关联准许记号内字'

for ($i = 0; $i -lt $lines.Count; $i++) {
  foreach ($ch in $suspects.ToCharArray()) {
    if ($lines[$i].Contains([string]$ch)) {
      $t = $lines[$i].Trim()
      if ($t.Length -gt 96) { $t = $t.Substring(0, 96) }
      Write-Output ('L' + ($i + 1) + ' [' + $ch + '] ' + $t)
    }
  }
}
Write-Output ('總行數: ' + $lines.Count)
