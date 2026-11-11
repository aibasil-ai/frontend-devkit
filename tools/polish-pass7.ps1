# 第七批小修（第 4 輪）：清重聲、修計數、統一比對形
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  # 第 4 輪一般 #5：normalize 的「只准→只准許」非冪等，造成「只准許許」重聲
  @('僅准許許', '僅准許'),
  @('只准許許', '只准許'),
  @('准許許', '准許'),
  # 計數與描述校正
  @('確定詞的簡→繁替換（24 組', '確定詞的簡→繁替換（26 組'),
  @('驗證用 throwaway 專案跑八關', '驗證用 throwaway 專案跑關 1～7（關 0 是人工建置，關 8 是本專案零影響查核）'),
  # 完整脈絡的出處：本 repo 尚未建立版本基線，不得宣稱「見 git log」
  @('完整脈絡見 git log 與對應章節', '完整脈絡見本檔 §17 各輪紀錄與對應章節'),
  # 威胁/威脅 等殘留（第 4 輪掃到「自我懺悔敘事」保留在 §17，不在正文）
  @('結果一邊修字形問題、一邊製造新問題，還把一句話替換壞成重複句', '結果一邊修字形、一邊製造新問題，還把一句話替換壞成重複句（該事故記錄留在 §17.6，不在此重複）')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass7 done ==='
