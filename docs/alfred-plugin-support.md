# Alfred 插件兼容支持 · Roadmap

> 目标:让 ActivateDock 能直接加载并运行符合 **Alfred Script Filter** 协议
> 的第三方插件(占 Alfred 生态绝大多数:翻译/词典/汇率/搜索类)。
> 不追求 Alfred 全功能兼容。

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

| 文件 | 角色 |
|---|---|
| `ActivateDock/Models/AlfredItem.swift` | Codable 数据模型 |
| `ActivateDock/Models/SearchRow.swift` | `enum SearchRow { case app / case alfred }` 数据源切换 |
| `ActivateDock/Services/AlfredScriptFilterRunner.swift` | Process 包装 + 取消并发请求 |
| `ActivateDock/Views/SearchResultCell.swift` | 加 subtitle label + alfred configure overload |
| `ActivateDock/Controllers/ViewController*.swift` | yd 路由 + 数据源 dispatch + Enter 处理 |
| `spike/alfred-stub.js` | 测试 fixture(产固定 4 条 items) |

### 仓外资产(.gitignore)

| 路径 | 用途 |
|---|---|
| `txiki-macos-arm64/tjs` | txiki.js v26.4.0 arm64 运行时,执行 JS |
| `YoudaoTranslator-master/` | 第三方有道翻译 plugin 源码(参考用) |

### 已知 Tech Debt

1. **硬编码绝对路径**:`ViewController.swift` 里 alfredRunner 写死了
   `/Users/luo/Documents/iOS/ActivateDock/...` 路径,clone 出去无法运行。
2. **单 runner 实例**,无 plugin 注册表 → 只能挂 1 个插件。
3. **没有 info.plist 解析** → 关键词只能硬编码("yd ")。
4. **icon 路径相对解析未做** → 真插件的 icon.path 通常相对脚本目录。
5. **stderr 攒批读取** → 调试真插件慢,看不到实时日志。
6. **错误 UX 简陋** → 只是把 `[error]` 当一行 item 显示。
7. **没有输入提示** → 用户不知道当前 keyword 等什么。

---

## 2. 三条候选路径

### A. 接真 Youdao 插件

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

### B. info.plist 解析 + plugin 注册表(推荐先做)

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

### C. UX 打磨

**目的**:让 alfred 路径的输入体验跟现有 google/baidu 一致。

**做什么**:
- 输入纯 `yd `(无 query)显示 hint:"yd: 输入要翻译的词"
- Loading 态:正在执行外部脚本时,显示 spinner 或 "loading..." 行
- 错误显示美化:专用的 error cell(图标 + 颜色 + 折叠技术细节)
- 防抖时长针对外部进程调长(目前 120ms 偏短)

**工作量**:~1 小时

---

## 3. 执行顺序与理由

**推荐:B → A → C**

| 顺序 | 理由 |
|---|---|
| **B 先** | 架构验证比单点验证更有价值。先把"通用性"打通,A 就成顺路的事。 |
| **A 跟在 B 后** | B 完成后,跑真 Youdao = "把改过的 plugin 放进 plugin 目录 + 配 env",几乎零工作量。 |
| **C 最后** | UX 容易反复,在架构稳定前打磨容易做无用功。 |

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

### 4.3 任务拆解(B 的开发清单)

下次开发直接照这个清单做:

1. [ ] **目录约定**:确定 `~/Library/Application Support/ActivateDock/Plugins/`
       为 plugin 安装根。app 启动时自动 mkdir。
2. [ ] **`AlfredWorkflowManifest.swift`**:Codable struct 表达上面的 plist 子集。
       注意:Alfred plist 的 objects 数组成员 type 多种,需要解码时按 type 分支。
3. [ ] **`AlfredWorkflowLoader.swift`**:扫描 plugin 根 → 每个子目录读 `info.plist`
       → 用 `PropertyListDecoder` 反序列化 → 过滤 script filter 节点 → 产 `[Workflow]`。
       失败的 plugin 记日志、跳过,不要让一个坏 plugin 拖死整个 app。
4. [ ] **`Workflow` 类型**:封装 `keyword / scriptCommand / pluginDir / variables`。
       script 字段里的 `{query}` 占位符在运行前替换。
5. [ ] **`WorkflowRegistry.swift`**:`[String: Workflow]` keyword 索引。
       app 启动时 load 一次,后续可加 file watcher 热重载(v2 再做)。
6. [ ] **`AlfredScriptFilterRunner` 改造**:`run(workflow:, query:, completion:)`,
       cwd 设为 plugin 目录,env 注入 workflow.variables。
7. [ ] **search 路由改造**:`updateForSearchText` 里 hardcoded "yd " 改成
       `Registry.lookup(prefix: q)`,匹配上就走 alfred 路径。
8. [ ] **icon 路径解析**:`AlfredIcon.path` 若为相对路径,resolve 相对脚本所在目录。
9. [ ] **错误降级**:plist 解析失败 / 脚本路径不存在 / 二进制无可执行权限 →
       明确提示,不要静默。
10. [ ] **验收**:把 spike 的 stub 包装成完整 plugin 目录(带 info.plist),
        跑通后再试 Youdao(衔接 A)。

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
