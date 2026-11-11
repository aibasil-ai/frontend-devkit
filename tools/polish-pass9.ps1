# 第九批小修：清掉第 4 輪我自己打進去的簡體字與計數
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('deny（四条）', 'deny（四條）'),
  @('必须搭配一条明文行为', '必須搭配一條明文行為'),
  @('搭配一条明文行為', '搭配一條明文行為'),
  @('跟你说清楚', '跟你說清楚'),
  @('这条寫進', '這條寫進'),
  @('否則物理上跑不动', '否則物理上跑不動'),
  @('gate 由 developer 单方執行', 'gate 由 developer 單方執行'),
  @('由 developer 单方執行', '由 developer 單方執行'),
  @('被替換壞过一次', '被替換壞過一次'),
  @('明确标注权威在', '明確標明權威在'),
  @('實驗先行（R1 六題', '實驗先行（R1 七題'),
  @('`*.opencode/*` 是否匹配點開頭的相對路徑。結論寫進', '`*.opencode/*` 是否匹配點開頭的相對路徑、**shell 資源是否做反斜線正規化**。結論寫進')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass9 done ==='
