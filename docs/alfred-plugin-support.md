# Alfred 插件兼容支持 · Roadmap

> 目标:让 ActivateDock 能直接加载并运行符合 **Alfred Script Filter** 协议
> 的第三方插件(占 Alfred 生态绝大多数:翻译/词典/汇率/搜索类)。
> 不追求 Alfred 全功能兼容。

---

## 状态总览

| 阶段 | 状态 | Commit | 摘要 |
|---|---|---|---|
| Spike | ✅ 完成 | `d25e350` | 端到端管道,硬编码 yd |
| Roadmap doc | ✅ 完成 | `b1f009d` | 本文件首版 |
| **B 路径** | ✅ 完成 | `5a4e972` | info.plist 解析 + Workflow Registry |
| **A 路径** | ✅ 完成 | `433cfd7` | 真 Youdao 插件 + Settings 配置 UI |
| **C 路径** | ✅ 完成 | _待提交_ | UX 打磨(hint / loading / 错误美化 / 防抖调长) |

**已识别但未规划的 follow-up** 见 §1.5。

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

> 截至 commit `433cfd7`(B + A 路径完成)。

| 文件 | 角色 | 引入 |
|---|---|---|
| `Models/AlfredItem.swift` | Alfred Script Filter JSON Codable | spike |
| `Models/SearchRow.swift` | `enum SearchRow { case app / case alfred }` 数据源切换 | spike |
| `Models/AlfredWorkflowManifest.swift` | info.plist Codable 子集(含 description) | B / A |
| `Models/Workflow.swift` | runtime workflow value type(含 description、shell-quote) | B / A |
| `Services/AlfredScriptFilterRunner.swift` | Process 包装 + 取消逻辑;接受 Workflow | spike → B |
| `Services/AlfredWorkflowLoader.swift` | 扫 plugin 目录、解 plist、产 [Workflow] | B |
| `Services/WorkflowRegistry.swift` | keyword → Workflow 索引 | B |
| `Services/PluginPaths.swift` | `~/Library/Application Support/ActivateDock/Plugins/` 约定 | B |
| `Services/PluginConfigStore.swift` | UserDefaults override store(per bundleId / per varKey) | A |
| `Views/SearchResultCell.swift` | subtitle label + alfred configure overload | spike |
| `Views/PluginVariableField.swift` | 携带 (bundleId, varKey) 的 NSTextField subclass | A |
| `Views/PluginsSettingsView.swift` | 动态生成的 plugins 配置 UI | A |
| `Controllers/SettingsContentBuilder.swift` | 加 plugins section | A |
| `Controllers/SettingsWindowController.swift` | 持有 PluginsSettingsView,窗口尺寸 480×520 | A |
| `Controllers/ViewController*.swift` | 关键词路由(查 registry)+ 数据源 dispatch + Enter 处理 | spike → B |
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
5. ⏳ **stderr 攒批读取** → 调试真插件慢,看不到实时日志。(C 后仍未做,优先级低)
6. ✅ ~~错误 UX 简陋~~ — C 路径加专用 error cell(红色 SF symbol + 红色标题 + 截断细节)。
7. ✅ ~~没有输入提示~~ — C 路径让 plugin keyword 复用既有 hint 通道,文案取自 manifest description。

### 1.5 已识别的 follow-up(未规划进任何路径)

A 路径完成后衍生的工程性事项,优先级跟 C 类似,但属于"打磨/加固"性质。

| # | 事项 | 触发场景 | 难度 |
|---|---|---|---|
| F1 | secret 字段当前**明文存 UserDefaults** → 应升级 Keychain | 凭证安全 | 中(要做加解密 API + 迁移现有值) |
| F2 | secret 字段当前**明文显示** → 应换 `NSSecureTextField` | 配置 UI 隐私 | 低(swap 控件类型,加可见性切换按钮) |
| F3 | `WorkflowRegistry` **没有热重载** → 改 plist 要重启 app(改 store 不需要) | 开发体验 | 中(FileWatcher 监听 Plugins 目录) |
| F4 | Settings 窗口**没有 scrollview** → plugin 多了内容会溢出 | UI 健壮性 | 低(把 PluginsSettingsView 包进 NSScrollView) |

**判断**:F1/F2 一组(凭证安全),F3/F4 一组(UI/DX)。如果做,建议 F1+F2 一起,F3 单独,F4 顺手。

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

**原计划:B → A → C**(实际 B、A 已交付,C 待做)

| 顺序 | 理由 | 实际 |
|---|---|---|
| **B 先** | 架构验证比单点验证更有价值。先把"通用性"打通,A 就成顺路的事。 | ✅ commit `5a4e972` |
| **A 跟在 B 后** | B 完成后,跑真 Youdao = "把改过的 plugin 放进 plugin 目录 + 配 env",几乎零工作量。 | ✅ commit `433cfd7`(顺手扩展了 Settings UI) |
| **C 最后** | UX 容易反复,在架构稳定前打磨容易做无用功。 | ✅ _待提交_ |

**当前候选**:F1+F2(凭证安全) / F3+F4(UI 加固),二选一开下一阶段。

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

## 5. 不在范围 / 不做的事

为了控制 scope,以下 Alfred 特性不实现:

- ❌ File Action(从 Finder 选中文件触发)
- ❌ Snippets(关键字展开为文本)
- ❌ Hotkey-in-workflow(单个 plugin 自带快捷键 → 跟现有 HotKeyManager 冲突)
- ❌ Universal Action / 节点图(workflow 内部多步流水)
- ❌ `.alfredworkflow` 双击安装(用户暂时手动放目录)
- ❌ Alfred 私有 API(`alfred:` URL scheme、`alfredpreferences://` 等)

如果未来要做某一项,在这份文档里加新章节或开新 doc,不要悄悄塞。

---

## 6. 法律 / 品牌

- 文档措辞使用 "**兼容 Alfred Script Filter 协议**",**不**说"支持 Alfred 插件",
  避免暗示官方关联或转载 Alfred 商标。
- 用户安装的第三方 plugin,License 责任在 plugin 作者,我们不打包不分发。
- txiki.js 等运行时按各自 License 处理(MIT / similar)。
