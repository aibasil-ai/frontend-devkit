# 結構健檢（只讀）：frontmatter 規則格式、主體是否混入專案專屬事實、指令檔紀律
# 用途：M2／M3 驗收時跑；不屬於 kit 執行元件。
$ErrorActionPreference = 'Stop'

Write-Output '=== 1. 四個 agent 的 frontmatter 結構 ==='
foreach ($a in Get-ChildItem 'kit\agents\frontend-devkit' -File) {
  $L = Get-Content $a.FullName -Encoding utf8
  if ($L[0] -ne '---') { Write-Output ('FAIL 開頭不是 --- ：' + $a.Name); continue }
  $end = -1
  for ($i = 1; $i -lt $L.Count; $i++) { if ($L[$i] -eq '---') { $end = $i; break } }
  if ($end -lt 0) { Write-Output ('FAIL frontmatter 未閉合：' + $a.Name); continue }
  $fm = $L[1..($end - 1)]
  $rules = @($fm | Where-Object { $_ -match '^\s*-\s*\{' })
  $bad = @($rules | Where-Object { $_ -notmatch '\{\s*action:\s*".*",\s*resource:\s*".*",\s*effect:\s*"(allow|deny|ask)"\s*\}' })
  # 縮排檢查（第 6 站：一條頂格規則會讓整份 YAML 失效，opencode 直接跳過 agent → Agent not found）
  $dedented = @($fm | Where-Object { $_ -match '^-\s*\{' })
  $slashes = @($fm | Where-Object { $_ -match '//' })
  $keys = @($fm | Where-Object { $_ -match '^[a-z]+:' } | ForEach-Object { ($_ -split ':')[0] }) -join ','
  Write-Output ('{0,-16} 規則數={1,-4} 頂層鍵={2,-32} 格式不符={3,-3} 雙斜線={4} 頂格規則={5}' -f $a.Name, $rules.Count, $keys, $bad.Count, $slashes.Count, $dedented.Count)
  foreach ($b in $bad) { Write-Output ('    不合式：' + $b.Trim()) }
  foreach ($d in $dedented) { Write-Output ('    FAIL 規則未縮排（整份 YAML 會失效）：' + $d) }
}

Write-Output '=== 2. 主體是否混入專案專屬事實（應全為 0）==='
foreach ($p in 'ExampleBox', 'ExampleInput', 'app\.less', 'zh-TW', 'ava 2', 'Vuetify', 'en\.json') {
  $n = 0
  foreach ($f in Get-ChildItem 'kit\agents\frontend-devkit' -File) {
    $n += @(Select-String -Path $f.FullName -Pattern $p -Encoding utf8).Count
  }
  Write-Output ('{0,-14} {1}' -f $p, $n)
}

Write-Output '=== 3. 指令檔紀律 ==='
Write-Output ('  殘留「專案端追加」語彙: ' + @(Select-String -Path 'kit\commands\frontend-devkit\*.md' -Pattern '專案端追加|寫進 allow' -Encoding utf8).Count)
Write-Output ('  含 shell 塊（行首 !`）: ' + @(Select-String -Path 'kit\commands\frontend-devkit\*.md' -Pattern '^!\x60' -Encoding utf8).Count)
Write-Output '  agent 指向：'
foreach ($f in Get-ChildItem 'kit\commands\frontend-devkit' -File) {
  $line = Select-String -Path $f.FullName -Pattern '^agent:' -Encoding utf8 | Select-Object -First 1
  $sub = @(Select-String -Path $f.FullName -Pattern 'subagent: false' -Encoding utf8).Count
  Write-Output ('    ' + (Split-Path $f.FullName -Leaf) + ' -> ' + $line.Line + '   subagent:false=' + $sub)
}

Write-Output '=== 4. 尾巴三段式的相對次序（不可變 allow 必須在可變 deny 之後）==='
foreach ($f in Get-ChildItem 'kit\agents\frontend-devkit' -File) {
  $L = Get-Content $f.FullName -Encoding utf8
  $idxDenyPnpm = -1; $idxAllowFrozen = -1; $n = 0
  for ($i = 0; $i -lt $L.Count; $i++) {
    if ($L[$i] -match '^\s*-\s*\{') { $n++ }
    if ($L[$i] -match 'resource: "pnpm install \*"') { $idxDenyPnpm = $i }
    if ($L[$i] -match 'resource: "pnpm install --frozen-lockfile \*"' -and $L[$i] -match 'allow') { $idxAllowFrozen = $i }
  }
  $ok = if (($idxDenyPnpm -lt 0) -or ($idxAllowFrozen -lt 0)) { '無此對（N/A）' } elseif ($idxAllowFrozen -gt $idxDenyPnpm) { '正確：allow 在 deny 之後' } else { '錯：allow 會被翻回 deny' }
  Write-Output ('  {0,-16} 規則數={1,-4} pnpm install 對={2}' -f $f.Name, $n, $ok)
}
