# 第五批小修：把審核報告引用到的簡體字寫成「前→後」對照，並清掉我自己在正文留下的簡體字
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('**兩条例外', '**兩條例外'),
  @('照表搬運会遺失', '照表搬運會遺失'),
  @('（残留：处／试／这／没）', '（殘留四類：处→處、试→試、这→這、没→沒）'),
  @('`([\p{IsCJK}])(reviewer\|developer\|orchestrator\|setup)` → 補空白', '`([\p{IsCJKUnifiedIdeographs}])(reviewer|developer|orchestrator|setup)` → 補空白'),
  @('好处→好處、条目→條目、没有→沒有、明示范例→官方文件給的範例', '好处→好處、条目→條目、没有→沒有、明示范例→官方文件給的範例（此處為「錯字→正字」對照，刻意保留簡體形以留痕）'),
  @('「人工逐行複核」未完成', '「人工逐行複核」當時並未完成')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass5 done ==='
