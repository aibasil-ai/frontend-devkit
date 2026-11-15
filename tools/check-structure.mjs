// 結構健檢（只讀）：frontmatter 規則格式、主體是否混入專案專屬事實、指令檔紀律、尾巴三段式次序、POSIX allow 條目位置
// 用途：M2／M3 驗收時跑；不屬於 kit 執行元件。Node 版（零依賴），以 check-structure.ps1 為規格逐段移植。
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const agentDir = 'kit/agents/frontend-devkit';
const cmdDir = 'kit/commands/frontend-devkit';
const linesOf = (p) => readFileSync(join(root, p), 'utf8').split(/\r?\n/);
const padL = (s, n) => { s = String(s); return s.length >= n ? s : s + ' '.repeat(n - s.length); };

console.log('=== 1. 四個 agent 的 frontmatter 結構 ===');
for (const name of readdirSync(join(root, agentDir)).sort()) {
  if (!name.endsWith('.md')) continue;
  const L = linesOf(join(agentDir, name));
  if (L[0] !== '---') { console.log('FAIL 開頭不是 --- ：' + name); continue; }
  let end = -1;
  for (let i = 1; i < L.length; i++) { if (L[i] === '---') { end = i; break; } }
  if (end < 0) { console.log('FAIL frontmatter 未閉合：' + name); continue; }
  const fm = L.slice(1, end);
  const rules = fm.filter((l) => /^\s*-\s*\{/.test(l));
  const bad = rules.filter((l) => !/\{\s*action:\s*".*",\s*resource:\s*".*",\s*effect:\s*"(allow|deny|ask)"\s*\}/.test(l));
  // 縮排檢查（第 6 站：頂格或縮排不一致都會讓整份 YAML 失效，opencode 直接跳過 agent → Agent not found）
  const dedented = fm.filter((l) => /^-\s*\{/.test(l));
  const oddIndent = fm.filter((l) => /^\s+-\s*\{/.test(l) && !/^  -\s*\{/.test(l));
  const slashes = fm.filter((l) => l.includes('//'));
  const keys = fm.filter((l) => /^[a-z]+:/.test(l)).map((l) => l.split(':')[0]).join(',');
  console.log(`${padL(name, 16)} 規則數=${padL(rules.length, 4)} 頂層鍵=${padL(keys, 32)} 格式不符=${padL(bad.length, 3)} 雙斜線=${slashes.length} 頂格規則=${dedented.length} 縮排異常=${oddIndent.length}`);
  for (const b of bad) console.log('    不合式：' + b.trim());
  for (const d of dedented) console.log('    FAIL 規則未縮排（整份 YAML 會失效）：' + d);
  for (const o of oddIndent) console.log('    FAIL 規則縮排不是兩個空白（整份 YAML 會失效）：' + o);
}

console.log('=== 2. 主體是否混入專案專屬事實（應全為 0）===');
for (const p of ['ExampleBox', 'ExampleInput', 'app\\.less', 'zh-TW', 'ava 2', 'Vuetify', 'en\\.json']) {
  const re = new RegExp(p);
  let n = 0;
  for (const name of readdirSync(join(root, agentDir))) {
    if (!name.endsWith('.md')) continue;
    for (const l of linesOf(join(agentDir, name))) { if (re.test(l)) n++; }
  }
  console.log(`${padL(p, 14)} ${n}`);
}

console.log('=== 3. 指令檔紀律 ===');
{
  let n1 = 0;
  let n2 = 0;
  for (const name of readdirSync(join(root, cmdDir))) {
    if (!name.endsWith('.md')) continue;
    for (const l of linesOf(join(cmdDir, name))) {
      if (/專案端追加|寫進 allow/.test(l)) n1++;
      if (/^!`/.test(l)) n2++;
    }
  }
  console.log('  殘留「專案端追加」語彙: ' + n1);
  console.log('  含 shell 塊（行首 !`）: ' + n2);
  console.log('  agent 指向：');
  for (const name of readdirSync(join(root, cmdDir)).sort()) {
    if (!name.endsWith('.md')) continue;
    const L = linesOf(join(cmdDir, name));
    const line = L.find((l) => /^agent:/.test(l)) ?? '';
    const sub = L.filter((l) => l.includes('subagent: false')).length;
    console.log('    ' + name + ' -> ' + line + '   subagent:false=' + sub);
  }
}

console.log('=== 4. 尾巴三段式的相對次序（不可變 allow 必須在可變 deny 之後）===');
for (const name of readdirSync(join(root, agentDir)).sort()) {
  if (!name.endsWith('.md')) continue;
  const L = linesOf(join(agentDir, name));
  let idxDenyPnpm = -1;
  let idxAllowFrozen = -1;
  let n = 0;
  for (let i = 0; i < L.length; i++) {
    if (/^\s*-\s*\{/.test(L[i])) n++;
    if (/resource: "pnpm install \*"/.test(L[i])) idxDenyPnpm = i;
    if (/resource: "pnpm install --frozen-lockfile \*"/.test(L[i]) && L[i].includes('allow')) idxAllowFrozen = i;
  }
  const ok = (idxDenyPnpm < 0 || idxAllowFrozen < 0) ? '無此對（N/A）' : (idxAllowFrozen > idxDenyPnpm ? '正確：allow 在 deny 之後' : '錯：allow 會被翻回 deny');
  console.log(`  ${padL(name, 16)} 規則數=${padL(n, 4)} pnpm install 對=${ok}`);
}

console.log('=== 5. POSIX allow 條目位置（ln -s／unlink／pwd -P 須在尾巴第 1 段 deny 之前）===');
for (const name of readdirSync(join(root, agentDir)).sort()) {
  if (!name.endsWith('.md')) continue;
  const L = linesOf(join(agentDir, name));
  let tailIdx = -1;
  const posix = [];
  for (let i = 0; i < L.length; i++) {
    if (tailIdx < 0 && /^\s*#.*尾巴三段式/.test(L[i])) tailIdx = i;
    if (/effect: "allow"/.test(L[i]) && /resource: "(pwd -P|unlink|ln -s)/.test(L[i])) posix.push(i);
  }
  if (posix.length === 0) { console.log(`  ${padL(name, 16)} POSIX allow=無（N/A）`); continue; }
  if (tailIdx < 0) { console.log(`  ${padL(name, 16)} POSIX allow 條目=${posix.length} 無尾巴三段式段落（N/A）`); continue; }
  const bad = posix.filter((i) => i > tailIdx);
  const verdict = bad.length === 0 ? '正確：全在尾巴第 1 段之前' : 'FAIL：' + bad.map((i) => 'L' + (i + 1)).join('、') + ' 落在尾巴之後';
  console.log(`  ${padL(name, 16)} POSIX allow 條目=${posix.length} 尾巴第 1 段起=L${tailIdx + 1} ${verdict}`);
}
