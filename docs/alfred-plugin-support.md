# Alfred 插件兼容支持 · Roadmap

> 目标:让 ActivateDock 能直接加载并运行符合 **Alfred Script Filter** 协议
> 的第三方插件(占 Alfred 生态绝大多数:翻译/词典/汇率/搜索类)。
> 不追求 Alfred 全功能兼容。
>
> 架构层面的重构(graph runtime · 多节点类型 / connections / mods)
> 在 [workflow-graph-runtime.md](workflow-graph-runtime.md) 单独立项,**已全部完成**。
> 本文是"已交付"账本;graph runtime 的详细设计与落地进度见那份文档。

---

## 状态总览

| 阶段 | 状态 | Commit | 摘要 |
|---|---|---|---|
| Spike | ✅ 完成 | `d25e350` | 端到端管道,硬编码 yd |
| Roadmap doc | ✅ 完成 | `b1f009d` | 本文件首版 |
| **B 路径** | ✅ 完成 | `5a4e972` | info.plist 解析 + Workflow Registry |
| **A 路径** | ✅ 完成 | `433cfd7` | 真 Youdao 插件 + Settings 配置 UI |
| **C 路径** | ✅ 完成 | `35c084c` | UX 打磨(hint / loading / 错误美化 / 防抖调长) |
| **F1 + F2** | ✅ 完成 | `e4dc3b5` | 凭证安全(secret → Keychain · NSSecureTextField) |
| **F3 / F4 / TD-5 / F2-eye** | ✅ 完成 | `0c6b702` | 热重载 · Settings ScrollView · stderr 实时日志 · secret 可见性切换 |
| **F5 / F6 / F7 / F8** | ✅ 完成 | `9e2b94a` | 加载失败 + keyword 冲突 UI · 命令构造威胁模型 · manifest `secretvariables` |
| **Settings 双 tab** | ✅ 完成 | `869a943` | 通用 / Plugins 顶部导航 · flipped clip view 顶部对齐 |
| **F9 ~ F16(post-F8)** | ✅ 完成 | `bf440d5` | `{var:NAME}` 模板展开 + `userconfigurationconfig` 默认值 · 脚本语言 dispatch(shebang / `type`)· stdout 持续 drain · Settings 导入按钮 + PluginImporter · `keyword + 空格` 立即触发 · URL arg 走 NSWorkspace · TCC 错误 → 权限指引 |
| **打包工具** | ✅ 完成 | `672645c` | `build.sh` 一键 Release + zip,可选 `--install` 到 `/Applications` |
| **URL/复制 fallback** | ✅ 完成 | `6a471ef` | scriptfilter 选中后 Enter:URL 走 NSWorkspace,非 URL 复制 |
| **Graph runtime 立项** | ✅ 完成 | `cb7f236` | [workflow-graph-runtime.md](workflow-graph-runtime.md):多节点类型 / connections / mods |
| **Graph runtime 全部完成** | ✅ 完成 | — | WorkflowNode/Graph/Executor · ScriptFilterNode · mods路由 · connections解析 · action.script/openurl/copy · utility.junction · input.keyword · input.listfilter · 旧 Workflow/Runner 已删除 |

**已识别但未规划的 follow-up** 见 §1.5。post-F8 的工作以 F9–F16 形式补登。

---

## 1. 当前进展

已完成 **spike**(commit `d25e350`),验证管道端到端可行:

```
Swift 输入 "yd hello"
  → AlfredScriptFilterRunner.run()
    → spawn `tjs run alfred-stub.js hello`(env 透传)
      → JS 输出 Alfred Script Filter JSON
    → JSONDecoder → [AlfredItem]
  → SearchResultCell 渲染(title + subtitle + icon)
  → Enter 复制 arg 到剪贴板
```

### 落地的代码

> 截至 commit `e4dc3b5`(B + A + C + F1/F2 完成)。

| 文件 | 角色 | 引入 |
|---|---|---|
| `Models/AlfredItem.swift` | Alfred Script Filter JSON Codable | spike |
| `Models/SearchRow.swift` | `enum SearchRow { app / alfred / loading / error }` 数据源切换 | spike → C |
| `Models/AlfredWorkflowManifest.swift` | info.plist Codable 子集(含 description) | B / A |
| `Models/Workflow.swift` | runtime workflow value type(含 description、shell-quote) | B / A |
| `Services/AlfredScriptFilterRunner.swift` | Process 包装 + 取消逻辑;接受 Workflow | spike → B |
| `Services/AlfredWorkflowLoader.swift` | 扫 plugin 目录、解 plist、产 [Workflow] | B |
| `Services/WorkflowRegistry.swift` | keyword → Workflow 索引(`workflow(forKeyword:)` for hint/防抖) | B → C |
| `Services/PluginPaths.swift` | `~/Library/Application Support/ActivateDock/Plugins/` 约定 | B |
| `Services/PluginConfigStore.swift` | 双轨 store:secret → Keychain,普通 → UserDefaults | A → F1 |
| `Services/PluginVariableSensitivity.swift` | `isSecret(varKey:)` 启发式分类 | F1 |
| `Services/Keychain.swift` | `SecItem*` 薄封装(read/write/delete) | F1 |
| `Views/SearchResultCell.swift` | 多态 cell:app / alfred / loading / error 配置 | spike → C |
| `Views/PluginVariableField.swift` | 普通 + secure 两个 field 子类 + `PluginVariableEditing` 协议 | A → F2 |
| `Views/PluginsSettingsView.swift` | 动态生成的 plugins 配置 UI(secret row 用 secure field) | A → F2 |
| `Controllers/SettingsContentBuilder.swift` | 加 plugins section | A |
| `Controllers/SettingsWindowController.swift` | 持有 PluginsSettingsView,窗口尺寸 480×520 | A |
| `Controllers/ViewController+Search.swift` | 输入路由 + 防抖(plugin keyword 250ms,其余 120ms) | spike → C |
| `Controllers/ViewController+SearchAlfred.swift` | runAlfred + 错误展示映射(从 +Search 抽出) | C |
| `Controllers/ViewController+SearchHint.swift` | inline hint(plugin keyword 走 "输入查询内容") | spike → C |
| `Controllers/ViewController+SearchResults.swift` | table 渲染 dispatch(含 loading / error) | spike → C |
| `App/AppDelegate.swift` | 启动时 `PluginPaths.ensureExists()` + `Registry.reload()` | B |
| `spike/alfred-stub.js` | 最简 Alfred Script Filter 参考脚本 | spike |

### 仓外资产(.gitignore)

| 路径 | 用途 |
|---|---|
| `txiki-macos-arm64/tjs` | txiki.js v26.4.0 arm64 运行时,执行 JS |
| `YoudaoTranslator-master/` | 第三方有道翻译 plugin 源码(参考用) |

### Spike 阶段 Tech Debt(进度)

1. ✅ ~~硬编码绝对路径~~ — B 路径用 PluginPaths + Registry 替换。
2. ✅ ~~单 runner 实例,无 plugin 注册表~~ — B 路径加 WorkflowRegistry。
3. ✅ ~~没有 info.plist 解析~~ — B 路径加 AlfredWorkflowLoader。
4. ✅ ~~icon 路径相对解析未做~~ — B 路径在 `Workflow.resolvingIconPaths` 里 resolve。
5. ✅ ~~stderr 攒批读取~~ — `AlfredScriptFilterRunner` 改用 `readabilityHandler`,
   每收到一块 stderr 就 `NSLog("[plugin:<bundleId>] ...")`,terminationHandler 收尾时 drain 残余数据 + 拆掉 handler。
6. ✅ ~~错误 UX 简陋~~ — C 路径加专用 error cell(红色 SF symbol + 红色标题 + 截断细节)。
7. ✅ ~~没有输入提示~~ — C 路径让 plugin keyword 复用既有 hint 通道,统一 "输入查询内容"(manifest description 太长不适合 inline,留给 Settings UI 用)。

### 1.5 已识别的 follow-up(未规划进任何路径)

A 路径完成后衍生的工程性事项,优先级跟 C 类似,但属于"打磨/加固"性质。

| # | 事项 | 触发场景 | 难度 |
|---|---|---|---|
| F1 | ✅ secret 字段从 UserDefaults 迁到 Keychain | 凭证安全 | 中 — 见下 |
| F2 | ✅ secret 字段改用 `NSSecureTextField` | 配置 UI 隐私 | 低 — 见下 |
| F3 | ✅ `WorkflowRegistry` 加 FSEventStream 监听,装/改/删插件后自动 reload | 开发体验 | 中 |
| F4 | ✅ Settings 窗口外层包了 `NSScrollView`,plugin 多了不再溢出 | UI 健壮性 | 低 |
| F5 | ✅ keyword 同名冲突在 Settings 里以橙色 banner 列出(kept / ignored) | 一致性 | 低 |
| F6 | ✅ 插件加载失败(缺 plist / 解析失败 / scriptfilter 缺字段)同 banner 列出 | 一致性 | 低 |
| F7 | ✅ 命令构造威胁模型写入 `Workflow.swift` 文件头注释 | 安全文档 | 极低 |
| F8 | ✅ manifest 新增可选 `secretvariables: [String]`,声明优先于名字启发式 | 凭证安全 | 中 |
| F9 | ✅ `{var:NAME}` 模板展开 + `userconfigurationconfig` 默认值并入 `effectiveVariables`(commit `bf440d5`) | 真实 plugin 兼容性 | 中 |
| F10 | ✅ 脚本语言 dispatch:shebang 优先,否则查 `cfg.type` 选 interpreter(bash / zsh / php / ruby / python / osascript-AS / -JS),其余 fallback `/bin/sh`(新增 `Services/ScriptInvocation.swift`) | JXA / 多语言 plugin 兼容 | 中 |
| F11 | ✅ stdout 加 `readabilityHandler` 持续 drain —— 修 16KB pipe 死锁(shi 输出 ~250KB 时表现为永远 loading) | 大输出脚本可用性 | 低 |
| F12 | ✅ Settings → Plugins 顶部"+ 导入插件"按钮:`.alfredworkflow` / `.zip` / 目录三态 NSOpenPanel + `PluginImporter` 解压/查重/落盘(按 `bundleId` 而非目录名查重)| 用户安装入口 | 中 |
| F13 | ✅ `WorkflowRegistry.match` 接受空 query,UI 入口对原始 `text` 而非 trim 后的 `q` 取 keyword,`shi <空格>` 立即触发 | 行为对齐 Alfred | 低 |
| F14 | ✅ scriptfilter Enter 路径:URL arg(http/https/file/mailto/ftp/ssh)→ `NSWorkspace.open`,非 URL → 剪贴板(commit `6a471ef`)| Safari history / tabs 可用 | 低 |
| F15 | ✅ TCC fingerprint 识别 → 错误 cell 显式 "需要权限" + "系统设置 → … → 添加 ActivateDock"(FDA / Apple Events 两条路径) | 用户首跑友好度 | 低 |
| F16 | ✅ Settings 顶部分 "通用 / Plugins" 双 tab(NSSegmentedControl)+ flipped NSClipView 顶部对齐(commit `869a943`)| Settings 导航 | 低 |

**F1 + F2 实际交付**:
- `Services/Keychain.swift` — `SecItem*` 薄封装,service =
  `zerobytetech.ActivateDock.PluginConfig`,account = `<bundleId>::<varKey>`,
  失败仅 NSLog 不抛错(best-effort,用户可重输)。
- `Services/PluginVariableSensitivity.swift` — 启发式 `isSecret(varKey:)`:
  小写后包含 `secret/password/token/apikey/appkey` 或精确等于 `key/pwd`。
  Alfred manifest 没有原生 secret 标记,先用约定俗成的字段名匹配。
- `Services/PluginConfigStore.swift` — secret key 走 Keychain,普通 key 走
  UserDefaults。`mergedVariables(for:)` 按需合并。项目尚未发布首版,无存量数据
  迁移逻辑。
- `Views/PluginVariableField.swift` — 加 `PluginVariableEditing` 协议;同文件
  补 `PluginSecureVariableField: NSSecureTextField`。两类共享 `configureCommon`
  视觉配置。
- `Views/PluginsSettingsView.swift` — `makeVariableRow` 按 `isSecret` 分支选
  field 类型,delegate 走协议而不是具体类。

**F2-eye(可见性切换)** ✅:`Views/PluginSecretVariableRow.swift` 是个 NSView 包
裹同坐标重叠的 `PluginSecureVariableField` + `PluginVariableField` + 一个 SF symbol
眼睛按钮(`eye` / `eye.slash`),点击同步两边的 stringValue + 切换 `isHidden` +
迁移 firstResponder 到当前 active field。delegate / placeholder / stringValue
都按 active 字段透传,既有的 `controlTextDidEndEditing` pipeline 不用改。

**F5 / F6 / F7 / F8 实际交付**:
- `Models/PluginLoadDiagnostics.swift` — 新增 `PluginLoadFailure`(`.missingInfoPlist`
  / `.decodeFailed(detail)` / `.missingScriptFilterFields(objectUid)`)和
  `PluginKeywordConflict`(`kept` + `dropped: [Workflow]`)两个值类型。
- `Services/AlfredWorkflowLoader.swift` — `loadAll(at:)` 改返回
  `LoadResult { workflows, failures }`,失败不再只 `NSLog skip`。
- `Services/WorkflowRegistry.swift` — 重载后保留 `loadFailures`、
  `keywordConflicts`、`declaredSecretsByBundle`,供 UI 与 sensitivity 检查读取。
- `Views/PluginsSettingsView+Diagnostics.swift` — 在 plugins 列表顶部画一个橙色
  "Plugin issues" banner,逐行列出加载失败和 keyword 冲突。
- `Models/Workflow.swift` — 文件头补 "Threat model for command construction":
  只有 `{query}` 走 shell-quote,其余 manifest 字段当作用户已审计过的代码运行,
  对齐 Alfred 自身的契约。
- `Models/AlfredWorkflowManifest.swift` — 新增可选 `secretvariables: [String]`
  自定义字段(Alfred 原生没有 secret 标记)。
- `Services/PluginVariableSensitivity.swift` — `isSecret(bundleId:varKey:)`:声明
  优先,启发式兜底。`PluginConfigStore` 与 `PluginsSettingsView+Rows` 全量切到
  bundle-aware 签名。

---

## 2. 三条候选路径

### A. 接真 Youdao 插件 ✅ 已完成(commit `433cfd7`)

> 实际交付**超出**原计划:为了不让用户改 plist,A 阶段顺手做了
> `PluginConfigStore` + Settings 配置 UI + manifest description 字段。
> 这些都不在原 A 的计划里,但跟 A 的"真实场景"目标相洽。

**目的**:用一个真实第三方插件验证我们的 Swift 能跑真东西。

**做什么**:
- Fork `YoudaoTranslator-master/` 到本地工作目录,改 `src/index.ts` 第 6 行:
  `tjs.getenv('key')` → `tjs.env.key`(API 在 v26 上已变)
- `pnpm install && pnpm build` 产出 `dist/index.js`
- 把 plugin key/secret/platform 写进配置(暂存方案:Keychain / UserDefaults)
- 验证翻译流程能跑通,中文/英文双向、长句、网络异常处理

**风险**:
- 需要真实 Youdao API Key 申请
- 验证不到"通用性",只验证这一个插件
- 网络耗时比 stub 长 → 顺便验证 runner 的取消逻辑

**工作量**:~1 小时(瓶颈在 API key 申请)

### B. info.plist 解析 + plugin 注册表 ✅ 已完成(commit `5a4e972`)

**目的**:把"硬编码一个插件"升级为"扫描目录注册 N 个插件",验证架构通用性。

**做什么**:
- 设计 plugin 目录结构(见 §4)
- 写最小 Alfred plist 解析器:从 `info.plist` 的 objects 数组里挑出
  `type == alfred.workflow.input.scriptfilter` 的节点,读 keyword、
  script、scriptargtype、variables
- `AlfredWorkflowLoader.swift`:扫目录 → 解析 plist → 产 `[Workflow]`
- `WorkflowRegistry.swift`:`keyword → Workflow` 索引
- 改造 `AlfredScriptFilterRunner` 接受 `Workflow` 而不是写死 path
- 改造 search 路由:查 registry 而不是写死 `yd `
- 错误处理:plist 解析失败、脚本不存在、运行时不可执行的降级

**工作量**:~2~3 小时(瓶颈在 Alfred plist 的复杂 schema)

### C. UX 打磨 ✅ 已完成

**目的**:让 alfred 路径的输入体验跟现有 google/baidu 一致。

**实际交付**:
- ✅ Hint:`updateSearchHint` 在内置 keyword 没命中时回落到 `WorkflowRegistry`,
  plugin keyword 统一显示 "输入查询内容"(跟 google/baidu/bing 的 hint 风格一致;
  manifest `description` 留给 Settings UI 用)。
- ✅ Loading 态:`SearchRow.loading` + `SearchResultCell.configureLoading()`
  (`NSProgressIndicator` spinner + "loading…")。`runAlfred` 启动前先放
  loading row,完成后被结果/错误替换。
- ✅ 错误 cell:`SearchRow.error(title, detail)` + `configureError(...)`
  (`exclamationmark.triangle.fill` 红色 SF symbol + 红色标题 + 截断 180 字
  的细节)。`AlfredRunnerError` → 中文标题 + 折叠的技术细节。
- ✅ 防抖:`debounceDelay(for:)` 命中 plugin keyword 时拉长到 250ms,
  其余路径维持 120ms。

**衍生重构**:`runAlfred` + `errorPresentation` 抽到新文件
`ViewController+SearchAlfred.swift`,以满足 200 行/文件上限。

**工作量**:~1 小时(实际)

---

## 3. 执行顺序与理由

**原计划:B → A → C**,最终 B / A / C / F1+F2 全交付。

| 顺序 | 理由 | 实际 |
|---|---|---|
| **B 先** | 架构验证比单点验证更有价值。先把"通用性"打通,A 就成顺路的事。 | ✅ commit `5a4e972` |
| **A 跟在 B 后** | B 完成后,跑真 Youdao = "把改过的 plugin 放进 plugin 目录 + 配 env",几乎零工作量。 | ✅ commit `433cfd7`(顺手扩展了 Settings UI) |
| **C 最后** | UX 容易反复,在架构稳定前打磨容易做无用功。 | ✅ commit `35c084c` |
| **F1 + F2 (顺手加固)** | C 完成后顺势把 secret 凭证安全收尾。 | ✅ commit `e4dc3b5` |
| **F3 / F4 / TD-5 / F2-eye** | F1+F2 之后用户希望把 §1.5 列出的全部 follow-up 一并清掉。 | ✅ commit `0c6b702` |
| **F5 / F6 / F7 / F8** | §5 列出的"未规划候选"被用户提级,一次清完:加载失败/冲突 UI 提示、命令构造威胁模型、`secretvariables` 显式声明。 | ✅ commit `9e2b94a` |

**当前候选**:F1–F8 全部交付,剩下的范围议题见 §5 / §6。

---

## 4. B 的设计草案

### 4.1 Plugin 目录结构

```
~/Library/Application Support/ActivateDock/Plugins/
└── youdao-translator/
    ├── info.plist          # Alfred 标准 manifest
    ├── runtime/
    │   └── tjs             # 插件自带的运行时(可选)
    ├── dist/
    │   └── index.js        # build 产物
    └── assets/
        ├── icon.png
        └── translate.png
```

> 备选方案:把 plugin 装在仓库 `Plugins/` 目录里(跟着 app bundle 走),
> 但这样不灵活、用户不能自己装。**优先用 Application Support。**

### 4.2 最小 Alfred plist 子集

我们只需要从 `info.plist` 提取:

```xml
<key>bundleid</key>      <string>com.example.youdao</string>
<key>name</key>          <string>Youdao Translator</string>
<key>variables</key>     <dict>... 用户配的 env ...</dict>
<key>objects</key>       <array>
    <dict>
        <key>type</key>      <string>alfred.workflow.input.scriptfilter</string>
        <key>config</key>    <dict>
            <key>keyword</key>      <string>yd</string>
            <key>script</key>       <string>./runtime/tjs run dist/index.js {query}</string>
            <key>scriptargtype</key> <integer>0</integer>
        </dict>
    </dict>
</array>
```

**忽略字段**:节点连线(`connections`)、UI 元数据、其他类型节点。

### 4.3 任务拆解(B 的开发清单 — 全部完成于 `5a4e972`)

1. [x] **目录约定**:`~/Library/Application Support/ActivateDock/Plugins/` 为安装根,
       启动时 `PluginPaths.ensureExists()`。
2. [x] **`AlfredWorkflowManifest.swift`**:Codable struct,带 `description`(A 阶段新增)。
3. [x] **`AlfredWorkflowLoader.swift`**:扫描、PropertyListDecoder、产 `[Workflow]`,
       错误 log + skip。
4. [x] **`Workflow` 类型**:封装 keyword / scriptCommand / pluginDir / variables / description,
       `{query}` shell-quoted 替换。
5. [x] **`WorkflowRegistry.swift`**:keyword → Workflow 索引,启动时 reload 一次。
       (热重载未做,见 F3)
6. [x] **`AlfredScriptFilterRunner` 改造**:`run(workflow:, query:, completion:)`,
       走 `/bin/sh -c`,cwd=pluginDir,env 注入 `PluginConfigStore.mergedVariables(for:)`。
7. [x] **search 路由改造**:`WorkflowRegistry.shared.match(input:)`。
8. [x] **icon 路径解析**:`Workflow.resolvingIconPaths(in:)`,相对路径相对 pluginDir 解析。
9. [x] **错误降级**:plist 失败 → log + skip;runtime 失败 → cell 显示 `[error]` 行。
10. [x] **验收**:`spike-stub` plugin 装在 Plugins 目录,跑通后接 Youdao 真插件。

---

## 5. 未做事项汇总(写给"下一段时间想做点什么"的自己)

§1.5 列出的 follow-up(F1–F16)全部属于"打磨/加固"性质,**已全部交付**。

**架构层面的下一步**已单独立项 → [workflow-graph-runtime.md](workflow-graph-runtime.md):

引入 graph 引擎(`WorkflowNode` 协议 + `WorkflowGraph` + `WorkflowExecutor` +
`UIIntent`),把现在"单 scriptfilter + 硬编码 Enter 行为"的扁平模型升级到
Alfred 真实的"图 + 沿 connections 走 + 修饰键选边"。落地后能解锁的 plugin
能力面比 F-序列大一个量级 —— 详情见那份 doc 的 §4 节点 MVP 与 §9 落地顺序。

新发现的"打磨/加固"小事项请进 §1.5(继续 F17、F18 …);**架构性**的事项进
graph runtime 那份 doc。§6 是"明确不做"的范围声明,优先级独立于本节。

---

## 6. 不在范围 / 不做的事

为了控制 scope,以下 Alfred 特性不实现:

- ❌ File Action(从 Finder 选中文件触发)
- ❌ Snippets(关键字展开为文本)
- ❌ Hotkey-in-workflow(单个 plugin 自带快捷键 → 跟现有 HotKeyManager 冲突)
- ❌ Finder 双击 `.alfredworkflow` 直装 —— **app 内导入已支持**(F12,Settings → Plugins → "+ 导入插件",接受 `.alfredworkflow` / `.zip` / 目录)
- ❌ Alfred 私有 API(`alfred:` URL scheme、`alfredpreferences://`、`tell application "Alfred"` AppleEvent 等)。后果之一:用 AppleEvent 调 Alfred "回填搜索框"实现的 `⌥↩ Edit` 类语义不工作 —— 详 [workflow-graph-runtime.md §8](workflow-graph-runtime.md#8-不在范围)。

> Universal Action / 节点图("workflow 内部多步流水")**已从本节移除** ——
> graph runtime 立项后,connections 遍历进入实现路线;详 workflow-graph-runtime.md。

如果未来要做某一项,在这份文档里加新章节或开新 doc,不要悄悄塞。

---

## 7. 法律 / 品牌

- 文档措辞使用 "**兼容 Alfred Script Filter 协议**",**不**说"支持 Alfred 插件",
  避免暗示官方关联或转载 Alfred 商标。
- 用户安装的第三方 plugin,License 责任在 plugin 作者,我们不打包不分发。
- txiki.js 等运行时按各自 License 处理(MIT / similar)。
