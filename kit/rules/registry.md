# pack 註冊表（`setup` 驗證 id 存在性用）

`/frontend-devkit/init` 與 `compile` 只接受本表列出的 id。profile 的 `## 啟用規則` 引用不存在的 id 時，`setup` 必須報錯並列出本表可用的 id，**不得**靜默略過。

| id | 標題 | status | covers（管哪些檢查主題） | 適用偵測訊號 |
|---|---|---|---|---|
| `stack/vue2-nuxt2` | Vue 2 / Nuxt 2 / Vuetify 1 慣例 | 已驗證 | options API 寫法、Vuetify 1 元件屬性（不可誤用 Vuetify 2 API）、Nuxt 2 目錄與載入慣例、程式風格與命名 | `dependencies` 有 `nuxt`／`vue@2`／`vuetify@1` |
| `testing/ava` | ava 測試與特徵測試寫法 | 已驗證 | 特徵測試四步驟、元件級 `mount` 驗證執行期行為、斷言不得削弱、快照類旗標的禁用理由 | `devDependencies` 有 `ava` |
| `security/vue-xss` | Vue 專案的 XSS 細項 | 已驗證 | `v-html` 綁定來源回溯、渲染前清理才算數、清理器白名單範圍的審視要點、既有白名單不得放寬 | 任何含 `v-html`／`innerHTML` 的前端專案 |
| `i18n/vue-i18n-json` | JSON 語系檔同步 | 已驗證 | 各語系檔必須同步新增／修改、刪鍵或改名要查引用、缺語系會直接顯示鍵名 | `vue-i18n` 且存在語系 JSON 檔 |

## 尚未建立的 pack（有意為之）

`stack/vue3-vite`、`stack/react-next`、`testing/vitest`、`testing/jest`、`testing/playwright`、`i18n/next-intl`、`style/*` ——**沒有在真實專案上驗證過就不寫**。理由是這份設計的原則：審核依據必須來自事實，憑空寫的 pack 會讓 reviewer 拿錯標準去判定（比沒有 pack 更危險）。

需要時依 `docs/writing-a-pack.md` 建立；在真實專案跑過之前，檔頭 `status` 必須寫 `未驗證`，reviewer 引用時要在輸出的「疑問」區標明。

## 通用後備（不是 pack，在主體）

「要查哪些危險模式」的最小安全清單**常駐主體 agent**（主檔 §3 第 0 點），不屬於任何 pack。所以本表四個 pack 全部不啟用時，安全檢查仍然執行，只是少專案細項——這是刻意設計，防止「停用 pack ＝ 放棄安全檢查」。
