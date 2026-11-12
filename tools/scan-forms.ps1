# 全站掃描（緊縮字集）：僅列「繁體不使用、簡體專屬」的字形 ＋ 一/次 數量
$ErrorActionPreference = 'Stop'
$pat = '这|没|长|个|状|绕|审|写|数|过|记|类|说|达|员|让|关|实|单|标|广|图|语|风|验|换|档|经|设|决|并|样|显|击|压|网|络|务|态|优|负|复|转|断|处|见|观|问|会|气|层|贝|车|马|门|开|闪'
$files = Get-ChildItem -Recurse -File -Include *.md -Path docs, kit, tools -ErrorAction SilentlyContinue
Write-Output '=== 簡體專屬字形命中 ==='
$found = 0
foreach ($f in $files) {
  $hits = @(Select-String -Path $f.FullName -Pattern $pat -Encoding utf8)
  foreach ($h in $hits) {
    $found++
    $ch = $h.Matches[0].Value
    $start = [Math]::Max(0, $h.Matches[0].Index - 10)
    $len = [Math]::Min(30, $h.Line.Length - $start)
    Write-Output ($f.Name + ':L' + $h.LineNumber + ' [' + $ch + '] ' + $h.Line.Substring($start, $len))
  }
}
if ($found -eq 0) { Write-Output '（0 命中）' }
Write-Output '=== 一 / 次 數量（人工判斷是否有「一→次」毀損）==='
foreach ($f in $files) {
  $t = Get-Content -Raw -Encoding UTF8 $f.FullName
  $yi = ([regex]::Matches($t, '一')).Count
  $ci = ([regex]::Matches($t, '次')).Count
  if ($yi -gt 0 -or $ci -gt 0) { Write-Output ('{0,-46} 一={1,-4} 次={2}' -f $f.Name, $yi, $ci) }
}

