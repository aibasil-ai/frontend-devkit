# 第三批小修（第 3 輪）：逐詞替換，跑完即丟，不屬 kit 執行元件
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('逐字元 diff', '逐行 diff'),
  @('專案端 allow **命中主體任一 deny**', '專案端 allow **命中主體尾巴第 1、2 段 deny**'),
  @('由 `inspect` 检出並要求移除', '由 `inspect` 檢出並要求移除'),
  @('会被注入', '會被注入'),
  @('的规则', '的規則'),
  @('也不会變危險', '也不會變危險'),
  @('專案专属的', '專案專屬的'),
  @('`.opencode` 内的設定', '`.opencode` 內的設定'),
  @('│  ├─reviewer.md', '│  ├─ reviewer.md'),
  @('|reviewer.md', '| reviewer.md'),
  @('驗證用 throwaway 專案跑七關', '驗證用 throwaway 專案跑八關'),
  @('啟用清單仍一致、七關全過', '啟用清單仍一致、八關全過'),
  @('compile 合法、七關全過', 'compile 合法、八關全過'),
  @('§13 的關卡 0～7 逐關驗證', '§13 的關卡 0～8 逐關驗證'),
  @('§13 第 7 關', '§13 第 8 關'),
  @('覆寫未附理由 |reviewer 列', '覆寫未附理由 | reviewer 列'),
  @('寫進 allow** |reviewer 依主體鐵則', '寫進 allow** | reviewer 依主體鐵則')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass3 done ==='
