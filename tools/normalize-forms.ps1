# 一次性字形正規化：把 spec 裡混入的簡體字形改為台灣用字（只替換確定的詞，不動術語與代碼）
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

# 逐條替換（固定詞彙，避免誤傷「命令」「內建」等中性詞）
# 注意：「內」「制」在台灣正字裡本來就存在（內建、機制），刻意不放進替換表，免得錯字被「更正」
$pairs = @(
  @('现有', '現有'),
  @('一条', '一條'),
  @('危险', '危險'),
  @('东西', '東西'),
  @('写明', '寫明'),
  @('有两种', '有兩種'),
  @('机械', '機械'),
  @('之类', '之類'),
  @('本该', '本應'),
  @('出现', '出現'),
  @('违规', '違規'),
  @('不属于', '不屬於'),
  # 註：第 4 輪移除 `('只准','只准許')` 一條——String.Replace 做的擴充式替換不具冪等性，
  # 每跑一次多一個「許」，會把「僅准許」變成「僅准許許」。要正規化請用帶負面語境的 regex 或直接刪除。
  @('干扰', '干擾'),
  @('明写', '明文寫出'),
  @('搬运', '搬運'),
  @('机制', '機制'),
  @('字数', '字數'),
  @('我们', '我們'),
  @('等于', '等於'),
  @('无法', '無法'),
  @('检查', '檢查'),
  @('处理', '處理'),
  @('记录', '記錄'),
  @('设为', '設為'),
  @('。-kit 的定義', '。kit 的定義')
)

foreach ($p in $pairs) {
  $text = $text.Replace($p[0], $p[1])
}

# 修補第 1 版腳本的傷害：漢字直接黏 agent 名稱時補半形空格
$text = [regex]::Replace($text, '([\p{IsCJKUnifiedIdeographs}])(reviewer|developer|orchestrator|setup)', '$1 $2')
# 表格儲存格開頭黏住 reviewer.md 等檔名時補空格（`|` 之後直接接漢字或點開頭檔名）
$text = [regex]::Replace($text, '\|(?=[.\w\-]+\.(md|json|js|vue|ps1))', '| ')

# 尚未被替換、但仍可疑的簡體字：回報行號讓人類判斷
$suspects = '写为于并数页复盖号机现当应让们说话认产条电视观觉违录钟额际维运风险处试这没会规检专'
$lines = $text -split "`r?`n"
$hits = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  foreach ($ch in $suspects.ToCharArray()) {
    if ($lines[$i].Contains([string]$ch)) { $hits += ('L{0}: {1} -> {2}' -f ($i + 1), $ch, $lines[$i].Trim()) }
  }
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== 仍疑似簡體字形的行（需人工判斷，部分為正常用字如「制」「当」） ==='
$hits | Select-Object -First 40
Write-Output ('=== 檔內行數：' + $lines.Count)
