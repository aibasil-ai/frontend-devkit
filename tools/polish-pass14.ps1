# 第 5 輪最後三處 A 語彙收尾
$ErrorActionPreference = 'Stop'
$path = 'docs/specs/2026-11-11-frontend-devkit-design.md'
$text = Get-Content -Raw -Encoding UTF8 $path

$pairs = @(
  # 1) §7.3.4 節首標記
  @('#### 7.3.4 跨來源紀律（避免次序依賴）',
    "#### 7.3.4 跨來源紀律（**方案 A 的保留條款**）\n\n> **現況標記（第 5 輪）**：`experiments.md` 第 3 題實測後，**方案 B 是現行預設**，本節第 1–6 點只有在「方案 A 依 §7.3.0 先決步驟覆驗成功」後才會啟用；**第 7 點（設定檔與 `.git/` 只准 `setup` 寫）是兩案通用的現行紀律**。另加一條 B 紀律：**專案端設定只准出現 `instructions` 與 `model`**，`inspect` 若偵測到 `agents.<id>.permissions` 含 shell 條目即警告（依實測它不會生效，留著只會誤導人以為已授權）。"),
  # 2) §17.7 決定表標註作廢
  @('| probe 由誰派、gate allow 寫進哪個 agent 節點 | 專案端 gate allow 一律寫進**被派者自己的節點**',
    '| probe 由誰派、gate allow 寫進哪個 agent 節點 | **（本決定已於 R1 後作廢：方案 B 下專案端不寫 shell 規則；保留原文供追溯）** 當時的寫法是：專案端 gate allow 一律寫進**被派者自己的節點**'),
  # 3) §5.1.2 尾註的「reviewer 節點專案端 allow」
  @('**reviewer 節點的專案端 allow 額外限定「僅測試／lint／build／唯讀工具類」**',
    '**reviewer 可執行的指令以主體靜態清單為限（方案 B）**：只准測試／lint／build／唯讀工具類，其餘一律「需人工執行」（§7.3.0.1#2）'),
  # 4) §13 關卡 6 的 A 語彙
  @('以及「拿掉專案端 agents 節點後，主體地板仍拒非白名單指令」',
    '以及「拿掉專案端 agents 節點（B 下它本來只含 instructions／model）後，主體地板仍拒非白名單指令」')
)

foreach ($p in $pairs) {
  if (-not $text.Contains($p[0])) { Write-Output ('MISS: ' + $p[0].Substring(0, [Math]::Min(40, $p[0].Length))) }
  $text = $text.Replace($p[0], $p[1])
}

Set-Content -Encoding utf8NoBOM -NoNewline -Path $path $text
Write-Output '=== pass14 done ==='
