# 第二批小修（逐詞替换，跑完即丢，不属 kit 執行元件）
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('人填的条目也不准直接變 allow', '人填的條目也不得直接變成 allow'),
  @('以下八條就是要被折進去的內容規格', '以下九條就是要被折進去的內容規格'),
  @('四個偵測細節', '五個偵測細節'),
  @('`npm audit fix*`', '`npm audit fix *`'),
  @('也不准寫成「已執行」', '也不得寫成「已執行」'),
  @('第 2 條被准許', '第 2 條被放行'),
  @('也不准嘗試白名單外指令', '也不得嘗試白名單外指令'),
  @('不准在專案端', '不得在專案端'),
  @('控制在兩檔、目標單檔 ≤ 120 行；', '控制在兩檔、目標單檔 ≤ 120 行（**超過即為警告而非阻斷**：`inspect` 提示「注入內容已達 N 行」，由你決定要不要把熱點表精簡或改用 §4.2.2 的「主體指示 read」備援路）；')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ("MISS: " + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== done ==='
