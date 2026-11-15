// 全站掃描（緊縮字集）：僅列「繁體不使用、簡體專屬」的字形 ＋ 一/次 數量
// Node 版（零依賴），以 scan-forms.ps1 為規格逐段移植。
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { basename, dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const pat = '这|没|长|个|状|绕|审|写|数|过|记|类|说|达|员|让|关|实|单|标|广|图|语|风|验|换|档|经|设|决|并|样|显|击|压|网|络|务|态|优|负|复|转|断|处|见|观|问|会|气|层|贝|车|马|门|开|闪|对|与|为|时|间|应|该|别|从';
const re = new RegExp(pat, 'g');

function walk(dir, out = []) {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (e.endsWith('.md')) out.push(p);
  }
  return out;
}

const files = [...walk(join(root, 'docs')), ...walk(join(root, 'kit')), ...walk(join(root, 'tools'))];
const padL = (s, n) => { s = String(s); return s.length >= n ? s : s + ' '.repeat(n - s.length); };

console.log('=== 簡體專屬字形命中 ===');
let found = 0;
for (const f of files) {
  const L = readFileSync(f, 'utf8').split(/\r?\n/);
  L.forEach((line, i) => {
    re.lastIndex = 0;
    const m = re.exec(line);
    if (m === null) return;
    found++;
    const ch = m[0];
    const start = Math.max(0, m.index - 10);
    const len = Math.min(30, line.length - start);
    console.log(basename(f) + ':L' + (i + 1) + ' [' + ch + '] ' + line.substring(start, start + len));
  });
}
if (found === 0) console.log('（0 命中）');
console.log('=== 一 / 次 數量（人工判斷是否有「一→次」毀損）===');
for (const f of files) {
  const t = readFileSync(f, 'utf8');
  const yi = (t.match(/一/g) ?? []).length;
  const ci = (t.match(/次/g) ?? []).length;
  if (yi > 0 || ci > 0) console.log(`${padL(basename(f), 46)} 一=${padL(yi, 4)} 次=${ci}`);
}
