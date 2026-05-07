# Workflow Graph Runtime · 设计 / 迁移计划

> 记录把"单 scriptfilter 节点 + 硬编码 Enter 行为"重构成"图引擎"的方案
> 与影响面。立项缘起:Safari Control plugin 多数命令跑不起来,根因是
> 我们的数据模型把 plugin 压扁成了"一个 keyword 对应一段脚本",而
> Alfred 本质是一个图引擎。
>
> 配套讨论见 [alfred-plugin-support.md](alfred-plugin-support.md)。

---

## 设计原则:零 plugin 适配代码

引擎对所有 plugin 一视同仁,**不为任何具体 plugin 写专属分支**。所有节点
类型、所有 connections / mods 行为按 Alfred 的通用契约处理。

当某个 plugin 用了我们未实现的 Alfred 内部能力(典型:plugin 通过
`tell application id "com.runningwithcrayons.Alfred" to search ...`
让 Alfred 把 arg 回填搜索框,实现 `⌥↩ Edit` 这种交互),我们让它**显式失
败**(error cell 给运行时报错)而不是定向打补丁 —— 牺牲那一条特性,保住可
演化性。

这条原则的实际后果会在 §8 列出。

---

## 状态

未开工。本文档定义工作范围与切片,实施时按 §9 顺序逐步落地。

---

## 1. 现状

执行模型:

```
WorkflowRegistry.match(input)
  → Workflow                  (只对应 plugin 里一个 scriptfilter 节点)
runner.run(workflow, query)
  → 跑那段 script,产 [AlfredItem]
handleSearchSubmit
  → 选中 item.arg → 硬编码 "URL 打开 / 否则复制"
```

`Workflow` 类名名不副实 —— 它装的是 plugin 里**一个入口节点**(单个 scriptfilter),不是真正意义上的 workflow。

被这个模型卡住的具体能力:

- `input.keyword` 节点(`sw / swc / stp`):无候选列表,直接把 query 当 arg 送下游 → 我们识别不出节点类型,registry 直接 skip
- `input.listfilter` 节点(`swp`):静态列表 → 同上
- `swt ↩ Focus tab`:scriptfilter 给的 arg 不是 URL,plugin 想跑下游 osascript 切 tab → 我们当作 URL 打开了
- `⌘↩ / ⌥↩ / ⌃↩ / ⇧⌘↩` 修饰键:Alfred 用修饰键**选不同的下游边** → 我们不读 `mods` 不读 `connections`

根因不是"少做了 N 个 feature",是**整套数据模型把图压扁成了点**。

---

## 2. Alfred 的图模型

Alfred 内部对所有 plugin 一视同仁,**不存在任何 plugin 适配代码**。一个 workflow 就是一张有向图:

| 维度 | 内容 |
|---|---|
| 节点 | `input.*` / `action.*` / `utility.*` / `trigger.*`,每种类型一份泛型实现 |
| 边 | `connections[源 UID] = [{ destinationUID, modifiers, … }, …]`,modifiers 用于过滤 |
| 入口 | input / trigger 节点;由 keyword 匹配 / 全局 hotkey / 文件动作触发 |
| 终点 | action 节点;执行副作用(open / copy / run script / …)后停止 |

执行是个递归 walker:

1. 命中入口节点 → 跑它(scriptfilter 跑脚本拿候选;keyword 拿 query;listfilter 取静态/动态列表)
2. 用户选 item / 按修饰键 → 形成"上游输出 + 修饰键状态"
3. 沿 `connections[源 UID]` 找下游,按修饰键过滤边
4. 下游节点 `execute`,可能再产新输出继续递归
5. 到 action 节点收尾

`swt ↩ Focus tab` 不是 Alfred 给 Safari Control 写了适配,是这个 plugin 在自己的 plist 里画了一条边
`scriptfilter-uid → focus-tab-script-action-uid`,Alfred 沿边走到那个 action 跑它的 osascript 而已。

---

## 3. 目标架构

所有架构层决议(下文 A1–A8)均已锁定 → 见 §7 决议要点。下面是经决议后
的具体类型形状:

```swift
// === 节点协议(每种 type 一个实现)===
//
// Callback-based,与现有 AlfredScriptFilterRunner 风格一致(A1 决议)。
// 每次 execute 都拿到独立 completion 闭包;调用方负责 invalidate / 忽略
// 迟到回调以做"在飞中取消"。

protocol WorkflowNode {
    var uid: String { get }
    var nodeType: String { get }    // "input.scriptfilter" 等,带进 WorkflowError
    func execute(input: NodeInput,
                 context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void)
}

struct NodeInput {
    let arg: String?
    let modifiers: NSEvent.ModifierFlags    // 用户按 ↩ 那一刻的修饰键
}

enum NodeOutput {
    case items([AlfredItem])
    case forward(arg: String?, variables: [String: String])    // 上传变量给下游
    case terminal
}

// === 上下文(在一次 walk 中可变)===

final class WorkflowContext {
    let graph: WorkflowGraph
    let bundleId: String
    var variables: [String: String]    // 起步 = PluginConfigStore.merged;
                                         //   每次节点 .forward(variables:) 时合并 ∪ 新值
    // 注:不再持有"共享 ScriptProcessRunner" —— 每次脚本执行新建一个
    // Process(X1 决议)。简化生命周期 + 让 action.* 在窗口关闭后能自然
    // detach 跑完(X2 决议)。
}

// === 错误 ===

struct WorkflowError: Error {
    enum Kind {
        case nodeFailed(stderr: String, exitCode: Int32)
        case decodeFailed(raw: String, underlying: Error)
        case launchFailed(Error)
        case missingNode(uid: String)
        case unsupportedNodeType(String)
    }
    let kind: Kind
    let nodeUID: String?
    let nodeType: String?    // "action.script" 等,UI 显示"在 X 节点失败"
}

// === UI 意图(单向流向 UI)===

enum UIIntent {
    case showLoading
    case showItems([AlfredItem])
    case showError(WorkflowError)
    case dismissAndPerform     // action 链路终结,关窗
}

// === 图 ===

struct WorkflowGraph {
    let bundleId: String
    let nodes: [String: any WorkflowNode]    // UID → node
    let edges: [String: [Edge]]               // sourceUID → outgoing
    let entrypoints: [Entrypoint]
    let variables: [String: String]            // manifest defaults(给 context 起步用)

    struct Edge {
        let destination: String
        let modifiers: NSEvent.ModifierFlags    // [] = 默认边
    }
    struct Entrypoint {
        let keyword: String
        let nodeUID: String
    }
}

// === 引擎 ===

final class WorkflowExecutor {
    /// 启动一次 walk。intentHandler 立即收到 .showLoading,后续随节点
    /// 执行陆续收到 items / error / dismissAndPerform。返回的 token
    /// 用于"用户输入变化 → cancel"路径(影响范围:**仅 scriptfilter 入
    /// 口节点**;一旦走到 action.* 阶段不再被外部 cancel 中断,见 X2)。
    @discardableResult
    func enter(graph: WorkflowGraph,
               entry: any WorkflowNode,
               query: String,
               modifiers: NSEvent.ModifierFlags,
               variables: [String: String],
               intentHandler: @escaping (UIIntent) -> Void) -> Cancellable

    // 内部:walk(from: node, output: NodeOutput, modifiers: …) 递归
    // 每节点 execute 都开新 Process,terminationHandler 自带 detach
    // 语义。
}

protocol Cancellable: AnyObject {
    func cancel()
}
```

### 修饰键映射(A3 决议)

Alfred 的 `connections.modifiers` 是 Int 位掩码、`mods` 字典的 key 是字符串,
loader 一律转 `NSEvent.ModifierFlags`,引擎层只见原生类型:

```
connections.modifiers (Int):
  0 = 默认 / 1 = cmd / 2 = alt / 4 = ctrl / 8 = shift / 16 = fn (可组合)
mods 字典 key (String):
  "cmd" / "alt" / "ctrl" / "shift" / "cmd+shift" / "cmd+alt" / ... 任意组合
→ extension NSEvent.ModifierFlags {
    static func fromAlfredEdgeMask(_ mask: Int) -> Self
    static func fromAlfredModKey(_ key: String) -> Self
  }
```

UI 不再直接管"打开 URL 还是复制",只渲染 `UIIntent`;打开/复制成为
`action.openurl` / `action.copytoclipboard` 节点的内部行为。

---

## 4. 节点 MVP

按 Safari Control 6 个命令解锁所需的最小集:

| 节点类型 | 工作 | 输入 | 输出 |
|---|---|---|---|
| `input.scriptfilter` | 跑 plugin 脚本拿 items | query, mods | `.items(...)` |
| `input.keyword` | 直接转发 query | query | `.forward(arg: query)` |
| `input.listfilter` | 静态 stringified-JSON items(`{var:NAME}` 展开后 JSON.decode)**或** `script` 动态产 | (无 / query) | `.items(...)` |
| `utility.junction` | **纯 pass-through**,把上游 arg + variables 原封不动转发(plugin 常用作"连线集线器")| arg | `.forward(arg: arg)` |
| `action.script` | 跑脚本(env 注入 context.variables + arg) | arg | `.terminal` |
| `action.openurl` | `NSWorkspace.open(url)` | arg(URL) | `.terminal` |
| `action.copytoclipboard` | pasteboard 写入 | arg | `.terminal` |

非 MVP(列入未来 backlog):
- `utility.argstartswith` / `utility.junction` / `utility.conditional`
- `action.runscript`(独立 runtime)/ `action.browseinalfred` / Snippets

---

## 5. 修饰键(`mods`)语义

scriptfilter item 输出可携带:

```json
{ "title": "...", "arg": "default-arg",
  "mods": {
    "cmd":       { "subtitle": "⌘", "arg": "alt-arg" },
    "alt":       { "subtitle": "⌥", "valid": false },
    "cmd+shift": { "subtitle": "⇧⌘", "arg": "..." }
  }
}
```

### Codable 形状(A6 决议)

```swift
extension AlfredItem {
    let mods: [String: AlfredItemMod]?    // key: "cmd" / "alt" / "cmd+shift" / …
    let variables: [String: String]?      // 选中此 item 时 variables 注入下游
    let valid: Bool?                        // false = 灰显,Enter 不响应
}

struct AlfredItemMod: Decodable {
    let arg: String?
    let subtitle: String?
    let valid: Bool?
    let variables: [String: String]?      // 修饰键场景下专属变量注入
}
```

### 引擎处理顺序

1. 用户按 ↩ + 修饰键 X → 查 `item.mods[X]`
2. 有且 `valid != false` → 用 `mods[X].arg`(没设就回落 `item.arg`);**`mods[X].variables`** 合并进 `context.variables`
3. 沿 `connections[scriptfilter-uid]` 选 `modifiers == X` 的边;无对应边时**不**回落到默认边(对齐 Alfred)
4. 把 arg 喂给下游节点

`autocomplete` / `quicklookurl` 等其他字段属于 §11 backlog,MVP 只要上述。

### 变量传播规则(A7 决议)

`context.variables` 是引擎一次 walk 中**累积可变**的状态:

```
起步     = PluginConfigStore.mergedVariables(forBundle: graph.bundleId)
           // 即 userconfig defaults ∪ topLevel variables ∪ user overrides

每跑一个节点,output: .forward(variables: V) 时:
   context.variables = context.variables ∪ V    // V 覆盖同名

scriptfilter / listfilter 用户选中 item 后:
   context.variables ∪= item.variables ?? [:]
   context.variables ∪= item.mods[modifierKey].variables ?? [:]

每跑一次 action.script,env 注入用 当前 context.variables 的 snapshot
```

这跟 Alfred "variables propagate down the connection chain" 规则一致。

---

## 6. 迁移影响面

**重命名:**
- `Workflow` → `WorkflowEntry` 或干脆拆解,让 `WorkflowGraph + WorkflowNode` 接管
- `AlfredScriptFilterRunner` → `ScriptProcessRunner`(被 scriptfilter / action.script 共用)

**直接受影响的文件(初步清点):**

| 文件 | 影响 |
|---|---|
| `Models/Workflow.swift` | 拆解或重写 |
| `Models/AlfredWorkflowManifest.swift` | `WorkflowObject` 加 `connections` 解码;objects 的 `type` 全部分发,不再只挑 scriptfilter |
| `Services/AlfredWorkflowLoader.swift` | 产物从 `[Workflow]` 变 `[WorkflowGraph]`;扫所有节点而非过滤 |
| `Services/WorkflowRegistry.swift` | 索引由 `keyword → Workflow` 变 `keyword → (Graph, EntryNodeUID)` |
| `Services/AlfredScriptFilterRunner.swift` | 重命名 + 抽通用,被 scriptfilter/action.script 共用 |
| `Services/PluginConfigStore.swift` | `mergedVariables(for:)` 入参从 Workflow 改 WorkflowGraph |
| `Controllers/ViewController+SearchAlfred.swift` | `runAlfred` 改成订阅 `executor.enter` 的 `AsyncStream<UIIntent>` |
| `Controllers/ViewController+Search.swift` | `handleSearchSubmit` 的 `.alfred` 分支拆;Enter + modifierFlags 打包成 ExecutorIntent 喂回 executor |
| `Views/PluginsSettingsView*.swift` | `pluginGroups()` 数据源由 `allWorkflows` 改 `allGraphs`(按 bundleId 聚合) |
| **新增** `Services/Workflow/Node*.swift`(每节点一份) | scriptfilter / keyword / listfilter / action.script / action.openurl / action.copytoclipboard |
| **新增** `Services/Workflow/WorkflowExecutor.swift` | 引擎核心 |
| **新增** `Services/Workflow/WorkflowGraph.swift` | 图结构 + Edge |

行数预估(按 200 行/文件红线):
- `WorkflowGraph.swift` ~80 行
- `WorkflowExecutor.swift` ~150 行(含 UIIntent / walker)
- 各 `Node*.swift` 60–100 行,均在红线内
- `AlfredWorkflowLoader.swift` 现 100+ 行,加 connections 解析后接近 200,可能要拆 `Loader+Graph.swift`

---

## 7. 决议要点

### A · 已锁(架构层,写代码前必须定的)

| # | 议题 | 决议 | 出处 |
|---|---|---|---|
| A1 | 同步 vs 异步 | **维持 callback 风格**(与现有 `AlfredScriptFilterRunner` 一致),`execute(input:context:completion:)`;不引入 async/await。引擎层 walk 是手写递归 callback,执行通过 `Cancellable` token 控制 | §3 protocol |
| A2 | 错误对外形态 | **`WorkflowError(kind:, nodeUID:, nodeType:)`**,UI 显示"在 X 节点失败" | §3 |
| A3 | `Edge.modifiers` 表示 | **`NSEvent.ModifierFlags`**(原生);Loader 把 plist 的 Int 位掩码 / `mods` 字典 String key 都转成它 | §3 |
| A4 | `UIIntent` case 集合 | `.showLoading` / `.showItems(...)` / `.showError(WorkflowError)` / `.dismissAndPerform`,共 4 个;由 `intentHandler: (UIIntent) -> Void` 闭包推送 | §3 |
| A5 | `WorkflowContext` 字段 | `graph` + `bundleId` + **可变** `variables`(不再持有共享 ScriptProcessRunner,见 X1) | §3 |
| A6 | `AlfredItemMod` Codable | `arg` / `subtitle` / `valid` / `variables` | §5 |
| A7 | 变量传播规则 | 节点 `.forward(variables:)` 与 item / mod 上的 `variables` 字段都合并进 `context.variables`,沿链路向下游传(对齐 Alfred) | §5 |
| A8 | `scriptargtype` 语义 | **MVP 维持现行 `{query}` 文本替换**;`stdin` / `env` 模式不实现,绝大多数 plugin 写 `{query}` literal,不依赖 stdin。需要 stdin 的列入 §11 backlog | — |

### X · 行为细则(callback 模型下浮现的具体决议)

| # | 议题 | 决议 |
|---|---|---|
| X1 | `ScriptProcessRunner` 生命周期 | **每次执行新建一个 Process**(不是全局共享 runner)。简化生命周期、避免 in-flight slot 互相挤占、让 X2 的 detach 自然成立 |
| X2 | 窗口关闭时 in-flight 行为 | **scriptfilter 入口节点** → cancel(`Cancellable.cancel()` 调 `process.terminate()`);**action.\* 节点** → detach 跑完(`terminationHandler` 自然走完,UI 已经收到 `.dismissAndPerform`)。理由:用户按 Enter 是"我想要这件事发生",关窗不应阻止 |
| X3 | Loading row 时机 | **立即** —— `intentHandler(.showLoading)` 在 `enter` 调用同步触发。不引入延迟阈值,避免快命中 plugin 出现"按一下闪一下" |
| X4 | scriptfilter → scriptfilter 链式 | **MVP 不支持** —— walk 时若下游也是 scriptfilter 节点,产 `WorkflowError(.unsupportedNodeType(chain))`,进 §11 backlog |
| X5 | `utility.junction` 是否 MVP | **进 MVP** —— 实现成本极低(~10 行 pass-through),但 plugin 常用作"连线集线器",不实现会导致大量 plugin 在中间断链 |

### B · 实施期细化(留"倾向"标记,遇到再细化)

- **utility 节点 MVP 不带** —— Safari Control 不依赖;其他 plugin 常用 `argstartswith` 做 fallback,真踩到再补
- **Hotkey 节点解析但 skip 入口注册** —— 在 `PluginLoadFailure` 邻位加 `.unsupportedNode(type)`,Settings banner 显示"已识别但未启用"
- **File-action / 其他非 keyword 入口** —— 同上,统一走 `unsupportedNode` diagnostic
- **AppleEvent → Alfred 失败提示** —— stderr 模式匹配 `tell application id "com.runningwithcrayons.Alfred"` / 退出码,加一条通用 hint "此功能依赖 Alfred 本体"。**不违反零适配**:对 Alfred 通用 idiom 的反应,不针对任何 plugin
- **item `valid: false`** —— UI cell 加 `disabled` 视觉,Enter 不响应
- **空 items 列表** —— 显示 "No results" 占位行,对齐 Alfred

---

## 8. 不在范围

延续 [alfred-plugin-support.md §6](alfred-plugin-support.md#6-不在范围--不做的事):

- ❌ `trigger.hotkey`(全局 CGEventTap 跟现有 HotKeyManager 冲突)
- ❌ File Action / Snippets / Universal Action
- ❌ Alfred 私有 URL scheme(`alfred://` / `alfredpreferences://`)

本次新加:

- ❌ utility 节点的完整集合(只在 MVP 跑通后按需补)
- ❌ Workflow 互相调用(一个 workflow 的 action 触发另一 workflow 的入口)
- ❌ `action.runscript` 独立 runtime 模式(plugin 可指定 PHP / Python 路径,但 MVP 复用现有 ScriptInvocation 的语言 dispatch 即够)
- ❌ **`⌥↩ Edit` 类 "回填搜索框" 语义** —— plugin 通过 `tell application id "com.runningwithcrayons.Alfred" to search …` AppleEvent 实现,本质依赖 Alfred 私有能力(已在 alfred-plugin-support.md §6 声明 "Alfred 私有 API ❌")。维持零 plugin 适配代码原则 → 不做定向转译。具体后果:Safari Control 的 `swt ⌥↩ Edit tab URL` / `shi ⌥↩ Edit URL` 在我们这里只会显示运行时错误。

---

## 9. 落地顺序

每一步独立可提交、失败可回退。

1. ✅ 立项 —— 本文档
2. 抽 `WorkflowNode` 协议 + `WorkflowGraph` + 空 `WorkflowExecutor` 骨架;旧 scriptfilter 路径**继续可跑**(渐进迁移)
3. 把现有 scriptfilter pipeline 包成 `ScriptFilterNode`,executor 走"入口 → scriptfilter → 终点"短路径,UI 切到订阅 `UIIntent`(无功能变化,只是路径切换)
4. 加 `mods` 解码 + 修饰键路由,验证 `swt ⌘↩ Copy URL` 等跑通(回归:youdao / spike / shi 仍通)
5. 解 `connections` + 至少 `action.script` / `action.openurl` / `action.copytoclipboard`,验证 `swt ↩ Focus tab` 跑通
6. 加 `input.keyword` 节点 + entrypoints registry,验证 `sw / swc / stp` 跑通
7. 加 `input.listfilter` 节点(含动态 script 模式),验证 `swp` 跑通
8. 删/重命名 `Workflow.swift` / `AlfredScriptFilterRunner.swift`,做最终扫尾
9. 同步更新 [alfred-plugin-support.md](alfred-plugin-support.md):§6 ❌ 列表里"input.keyword 不支持"等条目移到本文 §8;状态总览补一行 "Graph runtime · 完成"

---

## 10. 风险与回滚

- **§9-3 是关键关卡** —— callback 风格(A1)与现有 UI 流一致,主要风险点变成"递归 callback 嵌套层数"。Loader 必须保证 graph 是有限深度且无环;walker 实现要在每层 callback 检测 cancellation token,否则用户输入变化时旧链路会继续跑。回退方案:仅做"加 mods + 部分 connections"的渐进打补丁路线,接受 Safari Control 部分命令永久不支持。
- **重命名风险** —— `Workflow` 出现在 13+ 文件,改名爆破半径大。建议 §9-8 单独一个 commit,前面所有步骤先用别名(`typealias WorkflowEntry = Workflow` 反过来)兼容,最后一刀切。

---

## 11. Post-MVP Backlog

MVP 跑通后视用户实际踩坑情况按需做的 C 类事项,统一登记在此:

- `scriptargtype` 完整支持(stdin / 输入变量两种 query 传递模式)
- scriptfilter 输出的 `cache` / `loosereload` / `rerun`(Alfred 智能缓存)
- item 的 `autocomplete`(Tab 补全)
- item 的 `quicklookurl`(空格 Quick Look)
- scriptfilter → scriptfilter 链式遍历(多级流水,X4 决议遇到时产 unsupported 错误)
- 多节点 loading 进度展示(分阶段)
- 走到 action 中途 Esc 取消(MVP 关窗即 detach,见 X2;主动取消进 backlog)
- 其余 utility 节点(`argstartswith` / `conditional`,`junction` 已进 MVP)—— 真踩到再补
- `action.runscript` 独立 runtime 模式

新踩到的事项加在这一节下,不要进 §1.5 类的"已交付 follow-up"或 §8 "不做"。
