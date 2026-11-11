# 第四批小修（第 3 輪結尾）：命名統一與路徑標註
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  @('inspect --probe', 'inspect [probe]'),
  @('→ `inspect probe`', '→ `inspect [probe]`'),
  @('＋reviewer 必查', '＋ reviewer 必查'),
  @('源頭是獨立 git repo `C:\Users\vipjo\AI\frontend-devkit`',
    '源頭是獨立 git repo `frontend-devkit`（本機開發位置範例：`C:\Users\vipjo\AI\frontend-devkit`；**這只是範例，不是 kit 執行期引用的路徑**，執行期一律 `git rev-parse --show-toplevel`，見 §9.1）'),
  @('（本機即 `C:\Users\vipjo\AppData\Local\Temp\opencode\`）',
    '（本機範例：`C:\Users\vipjo\AppData\Local\Temp\opencode\`；**這是給本機執行者看的路徑，不寫進 kit 任何檔案**）'),
  @('1. 主工作區一律執行期取得：`git rev-parse --show-toplevel`。**kit 內任何檔案不得出現個人絕對路徑**（現行 orchestrator 第 60 行那種寫死，在 kit 裡屬禁止項）。',
    '1. 主工作區一律執行期取得：`git rev-parse --show-toplevel`。**本節禁止項的適用範圍是 `kit/agents/`、`kit/commands/`、`kit/rules/`、`kit/profile/`、`kit/worktree.procedures.md` 與專案端 `project.md`／`resolved.md`**——kit 在這些檔案內不得出現個人絕對路徑（現行 orchestrator 第 60 行那種寫死屬禁止項）。本 spec 與 README 出於說明目的可引用「本機範例路徑」，但須標明是範例。')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0]) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass4 done ==='
