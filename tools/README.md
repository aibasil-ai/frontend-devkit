# tools/　文件與結構健檢工具（**不屬於 kit**）

這裡的腳本只服務本 repo 的品質檢查，**不會**被安裝到任何專案、也不參與 `frontend-devkit` 的任何 agent 執行。實作 kit 元件時不要引用它們。

| 腳本 | 用途 | 什麼時候跑 |
|---|---|---|
| `normalize-forms.ps1` | 確定詞的簡→繁替換；漢字黏 `reviewer`／`developer`／`orchestrator`／`setup` 時補空格；表格 `\|` 後直接接檔名時補空格 | 大量寫文件後；**跑完必須人工重讀被改動的行** |
| `normalize-forms.mjs` | 同上（Node 版，零依賴）；寫檔 UTF-8 無 BOM、LF | 同上 |
| `scan-forms.ps1` | 唯讀掃描：簡體專屬字形命中、各檔「一／次」數量 | 每次 commit 前（數量異常＝字元毀損訊號） |
| `scan-forms.mjs` | 同上（Node 版，零依賴） | 同上 |
| `check-structure.ps1` | 四個 agent 的 frontmatter 規則格式、主體是否混入專案專屬事實、六個指令檔紀律、尾巴三段式的相對次序（不可變 allow 必須在可變 deny 之後） | M2／M3 驗收（`acceptance.md` 關卡 1 之前先跑這支） |
| `check-structure.mjs` | 同上（Node 版，零依賴）＋ POSIX allow 條目（`ln -s`／`unlink`／`pwd -P`）須在尾巴第 1 段 deny 之前的檢查 | 同上 |
| `polish-pass*.ps1` | 已刪除。歷次一次性修正腳本，任務完成即清，避免堆成「沒人知道能不能刪」的垃圾 | — |

> **Node 版與 PS1 版等價**（Node 版以 PS1 為規格逐條移植）：macOS 用 `node tools/*.mjs`，Windows 可續用 `.ps1`，兩版檢查結果應一致；`check-structure.mjs` 額外多一項 POSIX allow 條目位置檢查（PS1 版維持原狀）。

## 寫腳本時的三條紀律（都是踩過出來的）

1. **不可使用「擴充式」字串替換**（例 `只准 → 只准許`）。`String.Replace` 不具冪等性，每跑一次多一個「許」；第 5 輪就是這樣產出「只准許許」，而且当场證明了當時還未跑的冪等檢查有多重要。
2. **PowerShell 雙引號字串會吃反引號與反斜線**：`"...\n\n..."` 會留字面 `\n`、`` "`e" ``／`` "`a" `` 會被當成跳脫序列吃掉字母（拆檔腳本就把 `experiments.md` 改成 `xperiments.md`、`agents` 改成 `gents`）。**需要含反引號或反斜線的內容，一律用單引號字串或 here-string。**
3. **批量替換會自我吞掉「錯字樣本」**：文件若想保留錯字對照（「X→正字」），任何字形清洗都會把它改成無意義的文字。要留痕就用**描述**（「某十餘種簡體形」）而不是貼原字。
