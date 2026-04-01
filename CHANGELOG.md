## v0.5.1

> 本次更新优化了品牌视觉形象并重构了更新日志的生成方式，使项目呈现更加规范统一。

### 🚀 优化改进

- **release**：restructure changelog format and generation logic
- **branding**：replace brand logo and optimize static images

## v0.5.0

> 本次更新优化了批量延迟测试的去重与分组逻辑，使代理测速结果更准确，同时简化了发布流程并升级了 Actions 运行环境，提升整体稳定性与维护效率。

### ✨ 新增功能

- **release**：simplify changelog generation and add Copilot summaries

### 🚀 优化改进

- **actions**：force JavaScript actions to run on Node 24
- **proxy**：refactor batch latency testing with deduplication and per-group completion

## v0.4.0

> 本次更新重点覆盖 `menu-bar`、`remote`、`core`，主要补齐功能并修复关键问题。

### ✨ 新增功能

- **menu-bar**：move local network mode toggles into settings
- **remote**：allow switching to offline sources and unify status colors
- **core**：default releases to no-core packaging

### 🐞 问题修复

- **settings**：avoid spurious proxy port autosaves

## v0.3.1

> 本次更新重点覆盖 `menu-bar`，主要是一次体验与交互整理。

### 🚀 优化改进

- **menu-bar**：tighten source manager modal and stabilize source refresh

## v0.3.0

> 本次更新重点覆盖 `menu-bar`、`proxy`、`rules`，同时包含能力补齐、交互整理和稳定性修复。

### ✨ 新增功能

- **proxy**：show proxy command targets inline；support batch and single-node speed testing in proxy groups
- **menu-bar**：add thin scroll indicator for tab content；move provider updates to context menus
- **remote-machine**：support web panel entry for remote machines
- **nodes**：add dedicated nodes tab for raw proxies management；add provider refresh actions and sync update time
- **system**：add core restart and geo update actions；reorganize terminal proxy command actions
- **rules**：support group-based remote ruleset updates
- **update**：add Sparkle-based in-app updates
- **release**：automate changelog updates for stable releases

### 🚀 优化改进

- **proxy**：remove proxy providers section from proxy tab；redesign traffic overview layout
- **menu-bar**：cap list samples during panel height measurement；optimize rules and connections tab rendering；unify pinned header and optimize row rendering；move tun mode and proxy commands to system tab
- **system**：reorganize system settings sections
- **rules**：align rules tab naming
- **formatter**：unify speed formatting logic and adjust display precision
- **connections**：extract connection row into standalone Equatable view
- **settings**：prevent redundant proxy port auto-saves；merge proxy ports into core settings
- **session**：prevent redundant view updates on identical polling payloads
- **ui**：remove redundant leading icons；unify core upgrade feedback and normalize version display

### 🐞 问题修复

- **proxy**：unify icon for latency test actions；resolve latency display for referenced proxy groups
- **menu-bar**：restore source-aware state and panel behavior；adjust footer bar spacing；prevent blank flash on first rules/connections tab switch；rebuild rules tab and trim rules view pipeline；align collapse toggles on nodes and rules tabs
- **remote-machine**：guard offline switching and improve proxy host copy；sync statusText on target switch for speed display
- **nodes**：correct panel sizing after expanding remote providers
- **system**：sync launch-at-login state after approval
- **rules**：stabilize rule list item identifiers；show rule types in Clash-native format；unify rule type display formatting；align refresh icon with nodes tab
- **release**：handle releases without Sparkle keys；pass Sparkle private key through stdin
- **settings**：avoid autosave on system tab init
- **ui**：remove source labels from settings
- **popover**：stabilize menu bar panel height calculation
- **status-bar**：reset first responder when opening panel
- **package**：avoid reserved variable name in awk
- **i18n**：normalize labels for mode and port settings
- **providers**：correct provider update success handling

## v0.2.1

> 本次更新重点覆盖远程机器管理、远程目标感知视图、远程场景只读保护，同时包含能力补齐、交互整理和稳定性修复。

### ✨ 新增功能

- 在菜单栏中新增远程机器管理面板，支持添加、编辑、删除远程控制端，并可在本地 Mihomo 与远程机器之间快速切换
- 顶部 Header 会显示当前连接目标与连通状态，Proxy、Logs、Connections、System 页面也会围绕当前目标自动刷新，多控制端场景下不容易混淆
- 连接远程机器时，涉及本地应用或仅应作用于本地内核的设置会明确标注为只读或本地生效，减少误操作风险

### 🚀 优化改进

- 顶部模式切换与标签栏改为自定义分段控件，选中态、悬停反馈和整体层次更统一，菜单栏交互更贴近原生体验
- 重新整理 Proxy 页的流量概览、快捷操作、Provider/Group 行信息和节点类型展示，查看节点状态、切换配置与复制代理命令时更直观
- Connections 页补充过滤、排序、链路与流量摘要展示；Logs、Rules、System 页的列表与卡片布局也同步细化，在固定宽度菜单栏里能承载更多信息
- 系统代理入口现在会同时展示后台项目授权、Helper 进程与当前生效地址等状态，定位问题和确认代理指向都更直接
- 将应用进一步整理为 App / Session / Domain / Infrastructure / Features 等分层，并补充 beta DMG 预发布流程、二进制瘦身和打包优化，为后续迭代与分发打下更稳的基础

### 🐞 问题修复

- 修复系统代理在启动、唤醒或切换场景下可能出现"开关已开但系统未生效"的问题，必要时会自动补齐配置并刷新真实状态
- 修复系统代理 Helper 可能未及时拉起、注册状态失效或连接超时的问题，应用激活时会主动预热，并在连接失败后尝试恢复
- 针对未放入"应用程序"目录、后台项目未允许、Helper 未注册或签名异常等场景补充更明确的错误提示，减少"打不开系统代理但不知道原因"的情况
- 修复本地/远程目标切换时系统代理、快捷操作和页面状态可能不同步的问题，避免显示目标与实际控制端不一致
- 修复复制终端代理命令、TUN/System Proxy 等快捷操作在远程使用场景下的适配问题，降低误用本地配置的风险

## v0.2.0

> 本次更新重点覆盖活动数据缓存、实时连接状态处理、菜单栏视觉打磨，主要提升交互表现并修复稳定性问题。

### 🚀 优化改进

- 为 Activity 页和菜单栏相关派生数据增加缓存与预计算，减少列表刷新和统计展示时的额外开销
- 整理实时连接与 WebSocket 数据流处理逻辑，降低 `AppState` 与页面刷新逻辑的耦合，提升 Activity、Proxy、Rules 等页面的刷新稳定性
- 继续细化菜单栏界面的间距、标题区、Sparkline 和 System 页展示细节，整体观感更统一

### 🐞 问题修复

- 修复鼠标悬停代理分组时可能触发 CPU 占用飙升的问题，显著减轻卡顿与发热
- 修复附着式 Popover 在鼠标移动过程中的悬停判定不稳定问题，减少误闪动和意外收起
- 修复反馈提示条出现或消失时导致的 System 页面布局偏移问题
- 修复持久化的 TUN 开关状态与真实运行状态可能不一致的问题，避免界面显示和实际状态脱节
- 增强 Helper 恢复阶段的容错处理，减少系统代理状态恢复过程中的偶发异常
- 修复 Fallback 代理组在刷新后的排序不稳定问题，让列表顺序更可预期

## v0.1.9

> 本次更新重点覆盖模板化速度文本渲染、状态栏渲染路径、popover 尺寸跟随，同时包含能力补齐、交互整理和稳定性修复。

### ✨ 新增功能

- 状态栏上下行速率文本改为缓存模板图像渲染，保留系统原生的高亮/变暗行为，同时减少文本逐帧绘制开销

### 🚀 优化改进

- 整理状态栏显示刷新与渲染辅助逻辑，宽度计算与运行态图标切换更直接，后续维护成本更低
- 菜单弹出面板改为使用标准边界尺寸，并更及时响应高度变化，减少内容变化后的尺寸滞后

### 🐞 问题修复

- 修复状态栏在图标/速率模式切换时宽度容易波动的问题，显示更稳定
- 修复菜单栏弹出面板在不同屏幕参数和内容高度变化下尺寸不稳定的问题，避免打开后出现跳一下的体验

## v0.1.8

> 本次更新重点覆盖代理组排序切换、状态栏运行状态图标、订阅信息重设计，同时包含能力补齐、交互整理和稳定性修复。

### ✨ 新增功能

- 在 Proxy 页面工具栏新增排序切换，可在延迟排序与默认节点顺序之间切换，同时仍遵循隐藏不可用节点的过滤规则
- 更新品牌图标资源，状态栏图标区分运行（Running）与休眠（Sleeping）两种状态

### 🚀 优化改进

- 重新设计代理订阅（Proxy Provider）行，直接展示更新时间、刷新状态、到期信息和用量进度，信息一目了然
- 移除 Provider 节点级别的延迟、测试、展开等冗余状态追踪，保持订阅行聚焦于摘要信息，减少不必要的内存占用

### 🐞 问题修复

- 为状态栏图标启用 `isTemplate` 模式，修复多显示器切换焦点时图标不跟随系统自动变暗的问题，行为与系统电池、Wi-Fi 图标保持一致
- XPC 认证改为基于代码签名要求（Code Signing Requirement），替代原有的 PID 签名校验方式，提升安全性与可靠性

## v0.1.7

> 本次更新重点覆盖系统页快捷键、启动延迟探测、退出清理流程，同时包含能力补齐、交互整理和稳定性修复。

### ✨ 新增功能

- 新增 `Command + ,` 快捷键，支持从菜单命令快速切换到 `System` 页面，更符合 macOS 用户习惯

### 🚀 优化改进

- 内核启动完成后会自动触发 Proxy Group 延迟测试，用户打开面板时能更快看到各组节点状态
- 应用退出时会主动清理系统代理，减少异常退出后系统仍残留无效代理状态的情况

### 🐞 问题修复

- 修复 CatBar 重新启动后系统代理状态丢失的问题；如果退出前已开启代理，应用恢复运行后会自动按上次状态恢复

## v0.1.6

> 本次更新重点覆盖内核一键升级、升级反馈、版本同步，同时包含能力补齐、交互整理和稳定性修复。

### ✨ 新增功能

- 在菜单栏底部新增 Mihomo 内核升级入口，支持在运行中直接检查并执行升级操作

### 🚀 优化改进

- 为内核升级补充进行中、成功、已是最新版、失败等明确状态提示，并同步写入日志，减少黑盒体验
- 升级完成后自动刷新内核版本号，底部显示的 Mihomo 版本会尽快与实际运行版本保持一致
- 应用新版检测改为在面板展开时刷新，避免后台无效轮询，同时保证用户打开菜单时能看到最新版本提示

### 🐞 问题修复

- 兼容 Mihomo `/upgrade` 接口的多种响应与错误文案，正确识别"已是最新版"场景，避免把正常结果误判为失败
