# Workflow Graph Runtime · 设计 / 迁移计划

> 记录把"单 scriptfilter 节点 + 硬编码 Enter 行为"重构成"图引擎"的方案
> 与影响面。立项缘起:Safari Control plugin 多数命令跑不起来,根因是
> 我们的数据模型把 plugin 压扁成了"一个 keyword 对应一段脚本",而
> Alfred 本质是一个图引擎。
>
> 配套讨论见 [alfred-plugin-support.md](alfred-plugin-support.md)。

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

```swift
// 节点协议(每种 type 一个实现)
protocol WorkflowNode {
    var uid: String { get }
    func execute(input: NodeInput, context: WorkflowContext) async -> NodeOutput
}

struct NodeInput {
    let arg: String?
    let modifiers: NSEvent.ModifierFlags
    let variables: [String: String]
}

enum NodeOutput {
    case items([AlfredItem])    // scriptfilter / listfilter,等待用户选
    case forward(arg: String?)  // keyword / utility / 选中后的 scriptfilter
    case terminal               // action 完成,链路结束
}

// 整张图
struct WorkflowGraph {
    let bundleId: String
    let nodes: [String: WorkflowNode]      // UID → node
    let edges: [String: [Edge]]             // sourceUID → outgoing
    let entrypoints: [Entrypoint]           // (keyword, 入口节点 UID)
    struct Edge {
        let destination: String
        let modifiers: NSEvent.ModifierFlags    // 默认 .init() 表示无修饰
    }
}

// 引擎
final class WorkflowExecutor {
    func enter(graph: WorkflowGraph, entry: WorkflowNode, query: String, …) -> AsyncStream<UIIntent>
    func walk(from: WorkflowNode, output: NodeOutput, modifiers: …, in: WorkflowGraph)
}
```

`UIIntent` 是引擎吐回 UI 层的指令:`showItems(...)` / `showLoading` / `showError(...)` / `closeAndPerform(...)`。
UI 不再直接管"打开 URL 还是复制",只渲染引擎的意图。

---

## 4. 节点 MVP

按 Safari Control 6 个命令解锁所需的最小集:

| 节点类型 | 工作 | 输入 | 输出 |
|---|---|---|---|
| `input.scriptfilter` | 跑 plugin 脚本拿 items | query, mods | `.items(...)` |
| `input.keyword` | 直接转发 query | query | `.forward(arg: query)` |
| `input.listfilter` | 渲染 `config.fields` 静态列表(或 `script` 动态产) | (无 / query) | `.items(...)` |
| `action.script` | 跑脚本(stdin / env / arg) | arg | `.terminal` |
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

引擎按"**选中 item 用哪个 arg + 走哪条边**"二维选择处理:

1. 用户按 ↩ + 修饰键 X → 看 `item.mods[X]`
2. 有 → 用 `mods[X].arg`(没设就用默认 `arg`);若 `mods[X].valid == false` → 静默无视
3. 沿 `connections[scriptfilter-uid]` 选 `modifiers == X` 的边;无对应边时**不**回落到默认边(Alfred 行为)
4. 把 arg 喂给下游节点

`autocomplete` / `variables` / `valid` 等字段按需逐步加,MVP 只要 `mods.<key>.arg` 和 `mods.<key>.valid`。

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

## 7. 待决定事项

- **同步 vs 异步:** 借这次引入 async/await 还是继续 callback?引擎本身用 async 更顺,但跟 `Process.terminationHandler` 桥接需要 `withCheckedContinuation`。倾向 async。
- **错误对外形态:** 现 `AlfredRunnerError` 在 UI 层映射。新模型应该带"哪个节点 throw 的"信息,便于诊断 banner 显示"在 action.script 这步失败"。
- **utility 节点 MVP:** Safari Control 没用 utility,但其他 plugin 常用 `argstartswith` 做 fallback 路由。MVP 是否带?**倾向不带**,先跑 Safari Control 6 个命令再说。
- **Hotkey 节点扫不扫:** loader 解 `trigger.hotkey` 但 registry 不让它被触发?这样诊断更友好(显示"已识别但未启用")。或者完全 skip。**倾向解析但 skip 入口注册**,在 `PluginLoadFailure` 邻位加 `.unsupportedNode(type)`。
- **listfilter 的动态 script 模式:** 部分 listfilter 用 `script` 字段动态生成 fields(`swp` 拿 Safari profile 名就是这种)。MVP 是否覆盖?**倾向覆盖** —— 否则 `swp` 直接废,意义打折。
- **入口节点不从 keyword 触发的情况:** 比如 file action / hotkey 入口。MVP 不支持(§8 已声明),但 loader 是否 silently skip 还是产 diagnostic?**倾向产 diagnostic**,跟现有 keyword 冲突 banner 同语言。

---

## 8. 不在范围

延续 [alfred-plugin-support.md §6](alfred-plugin-support.md#6-不在范围--不做的事):

- ❌ `trigger.hotkey`(全局 CGEventTap 跟现有 HotKeyManager 冲突)
- ❌ File Action / Snippets / Universal Action
- ❌ Alfred 私有 URL scheme(`alfred://` / `alfredpreferences://`)

本次新加:

- ❌ utility 节点的完整集合(只在 MVP 跑通后按需补)
- ❌ Workflow 互相调用(一个 workflow 的 action 触发另一 workflow 的入口)
- ❌ `action.runscript` 独立 runtime 模式(plugin 可以指定 PHP / Python 路径,但 MVP 复用现有 ScriptInvocation 的语言 dispatch 即够)

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

- **§9-3 是关键关卡** —— 如果 executor 骨架塞不进现有 callback-based UI 流而需要大面积异步重写,回退到现有架构 + 仅做"P2 加 mods + P3 加部分 connections"的渐进打补丁路线,接受 Safari Control 部分命令永久不支持。
- **重命名风险** —— `Workflow` 出现在 13+ 文件,改名爆破半径大。建议 §9-8 单独一个 commit,前面所有步骤先用别名(`typealias WorkflowEntry = Workflow` 反过来)兼容,最后一刀切。
