## v0.4.0

![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) ![Version](https://img.shields.io/badge/Release-v0.4.0-10B981?style=flat-square) ![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)

> 本次更新包含 **3 项新增功能**、**0 项优化改进** 和 **1 项问题修复**，详情如下。

### 📝 更新日志 (Changelog)

**✨ 新增功能 (New Features)**

- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **menu-bar**：move local network mode toggles into settings
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **remote**：allow switching to offline sources and unify status colors
- ![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square) **core**：default releases to no-core packaging

**🚀 优化改进 (Improvements)**

- ![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square) **暂无内容**：当前版本未包含单独归类的优化项。

**🐞 修复问题 (Bug Fixes)**

- ![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square) **settings**：avoid spurious proxy port autosaves

## v0.3.1

> 本次更新重点覆盖 `menu-bar`，主要是一次体验与交互整理。

### 变更统计

- 新增功能：0 项
- 优化改进：1 项
- 问题修复：0 项

### 按模块归纳

- `menu-bar`
  - 优化：tighten source manager modal and stabilize source refresh

## v0.3.0

> 本次更新重点覆盖 `menu-bar`、`proxy`、`rules`，同时包含能力补齐、交互整理和稳定性修复。

### 变更统计

- 新增功能：12 项
- 优化改进：15 项
- 问题修复：24 项

### 按模块归纳

- `proxy`
  - 新增：show proxy command targets inline；support batch and single-node speed testing in proxy groups
  - 优化：remove proxy providers section from proxy tab；redesign traffic overview layout
  - 修复：unify icon for latency test actions；resolve latency display for referenced proxy groups
- `menu-bar`
  - 新增：add thin scroll indicator for tab content；move provider updates to context menus
  - 优化：cap list samples during panel height measurement；optimize rules and connections tab rendering；unify pinned header and optimize row rendering；move tun mode and proxy commands to system tab
  - 修复：restore source-aware state and panel behavior；adjust footer bar spacing；prevent blank flash on first rules/connections tab switch；rebuild rules tab and trim rules view pipeline；align collapse toggles on nodes and rules tabs
- `remote-machine`
  - 新增：support web panel entry for remote machines
  - 修复：guard offline switching and improve proxy host copy；sync statusText on target switch for speed display
- `nodes`
  - 新增：add dedicated nodes tab for raw proxies management；add provider refresh actions and sync update time
  - 修复：correct panel sizing after expanding remote providers
- `system`
  - 新增：add core restart and geo update actions；reorganize terminal proxy command actions
  - 优化：reorganize system settings sections
  - 修复：sync launch-at-login state after approval
- `rules`
  - 新增：support group-based remote ruleset updates
  - 优化：align rules tab naming
  - 修复：stabilize rule list item identifiers；show rule types in Clash-native format；unify rule type display formatting；align refresh icon with nodes tab
- `update`
  - 新增：add Sparkle-based in-app updates
- `release`
  - 新增：automate changelog updates for stable releases
  - 修复：handle releases without Sparkle keys；pass Sparkle private key through stdin
- `formatter`
  - 优化：unify speed formatting logic and adjust display precision
- `connections`
  - 优化：extract connection row into standalone Equatable view
- `settings`
  - 优化：prevent redundant proxy port auto-saves；merge proxy ports into core settings
  - 修复：avoid autosave on system tab init
- `session`
  - 优化：prevent redundant view updates on identical polling payloads
- `ui`
  - 优化：remove redundant leading icons；unify core upgrade feedback and normalize version display
  - 修复：remove source labels from settings
- `popover`
  - 修复：stabilize menu bar panel height calculation
- `status-bar`
  - 修复：reset first responder when opening panel
- `package`
  - 修复：avoid reserved variable name in awk
- `i18n`
  - 修复：normalize labels for mode and port settings
- `providers`
  - 修复：correct provider update success handling

## v0.2.1

> 本次更新重点覆盖 `远程机器管理`、`远程目标感知视图`、`远程场景只读保护`，同时包含能力补齐、交互整理和稳定性修复。

### 变更统计

- 新增功能：3 项
- 优化改进：5 项
- 问题修复：5 项

### 按模块归纳

- `远程机器管理`
  - 新增：在菜单栏中新增远程机器管理面板，支持添加、编辑、删除远程控制端，并可在本地 Mihomo 与远程机器之间快速切换
- `远程目标感知视图`
  - 新增：顶部 Header 会显示当前连接目标与连通状态，Proxy、Logs、Connections、System 页面也会围绕当前目标自动刷新，多控制端场景下不容易混淆
- `远程场景只读保护`
  - 新增：连接远程机器时，涉及本地应用或仅应作用于本地内核的设置会明确标注为只读或本地生效，减少误操作风险
- `菜单栏分段控件重做`
  - 优化：顶部模式切换与标签栏改为自定义分段控件，选中态、悬停反馈和整体层次更统一，菜单栏交互更贴近原生体验
- `代理与概览展示`
  - 优化：重新整理 Proxy 页的流量概览、快捷操作、Provider/Group 行信息和节点类型展示，查看节点状态、切换配置与复制代理命令时更直观
- `连接与日志信息密度`
  - 优化：Connections 页补充过滤、排序、链路与流量摘要展示；Logs、Rules、System 页的列表与卡片布局也同步细化，在固定宽度菜单栏里能承载更多信息
- `系统代理状态可视化`
  - 优化：系统代理入口现在会同时展示后台项目授权、Helper 进程与当前生效地址等状态，定位问题和确认代理指向都更直接
- `工程结构与构建链路`
  - 优化：将应用进一步整理为 App / Session / Domain / Infrastructure / Features 等分层，并补充 beta DMG 预发布流程、二进制瘦身和打包优化，为后续迭代与分发打下更稳的基础
- `系统代理恢复链路`
  - 修复：修复系统代理在启动、唤醒或切换场景下可能出现“开关已开但系统未生效”的问题，必要时会自动补齐配置并刷新真实状态
- `helper 自恢复与预热`
  - 修复：修复系统代理 Helper 可能未及时拉起、注册状态失效或连接超时的问题，应用激活时会主动预热，并在连接失败后尝试恢复
- `授权与安装提示`
  - 修复：针对未放入“应用程序”目录、后台项目未允许、Helper 未注册或签名异常等场景补充更明确的错误提示，减少“打不开系统代理但不知道原因”的情况
- `远程切换状态一致性`
  - 修复：修复本地/远程目标切换时系统代理、快捷操作和页面状态可能不同步的问题，避免显示目标与实际控制端不一致
- `远程场景快捷操作适配`
  - 修复：修复复制终端代理命令、TUN/System Proxy 等快捷操作在远程使用场景下的适配问题，降低误用本地配置的风险

## v0.2.0

> 本次更新重点覆盖 `活动数据缓存`、`实时连接状态处理`、`菜单栏视觉打磨`，主要提升交互表现并修复稳定性问题。

### 变更统计

- 新增功能：0 项
- 优化改进：3 项
- 问题修复：6 项

### 按模块归纳

- `活动数据缓存`
  - 优化：为 Activity 页和菜单栏相关派生数据增加缓存与预计算，减少列表刷新和统计展示时的额外开销
- `实时连接状态处理`
  - 优化：整理实时连接与 WebSocket 数据流处理逻辑，降低 `AppState` 与页面刷新逻辑的耦合，提升 Activity、Proxy、Rules 等页面的刷新稳定性
- `菜单栏视觉打磨`
  - 优化：继续细化菜单栏界面的间距、标题区、Sparkline 和 System 页展示细节，整体观感更统一
- `代理分组悬停高占用`
  - 修复：修复鼠标悬停代理分组时可能触发 CPU 占用飙升的问题，显著减轻卡顿与发热
- `popover 悬停稳定性`
  - 修复：修复附着式 Popover 在鼠标移动过程中的悬停判定不稳定问题，减少误闪动和意外收起
- `system 页布局跳动`
  - 修复：修复反馈提示条出现或消失时导致的 System 页面布局偏移问题
- `tun 状态同步`
  - 修复：修复持久化的 TUN 开关状态与真实运行状态可能不一致的问题，避免界面显示和实际状态脱节
- `系统代理恢复竞态`
  - 修复：增强 Helper 恢复阶段的容错处理，减少系统代理状态恢复过程中的偶发异常
- `fallback 分组排序`
  - 修复：修复 Fallback 代理组在刷新后的排序不稳定问题，让列表顺序更可预期

## v0.1.9

> 本次更新重点覆盖 `模板化速度文本渲染`、`状态栏渲染路径`、`popover 尺寸跟随`，同时包含能力补齐、交互整理和稳定性修复。

### 变更统计

- 新增功能：1 项
- 优化改进：2 项
- 问题修复：2 项

### 按模块归纳

- `模板化速度文本渲染`
  - 新增：状态栏上下行速率文本改为缓存模板图像渲染，保留系统原生的高亮/变暗行为，同时减少文本逐帧绘制开销
- `状态栏渲染路径`
  - 优化：整理状态栏显示刷新与渲染辅助逻辑，宽度计算与运行态图标切换更直接，后续维护成本更低
- `popover 尺寸跟随`
  - 优化：菜单弹出面板改为使用标准边界尺寸，并更及时响应高度变化，减少内容变化后的尺寸滞后
- `状态栏宽度抖动`
  - 修复：修复状态栏在图标/速率模式切换时宽度容易波动的问题，显示更稳定
- `弹出面板跳变`
  - 修复：修复菜单栏弹出面板在不同屏幕参数和内容高度变化下尺寸不稳定的问题，避免打开后出现跳一下的体验

## v0.1.8

> 本次更新重点覆盖 `代理组排序切换`、`状态栏运行状态图标`、`订阅信息重设计`，同时包含能力补齐、交互整理和稳定性修复。

### 变更统计

- 新增功能：2 项
- 优化改进：2 项
- 问题修复：2 项

### 按模块归纳

- `代理组排序切换`
  - 新增：在 Proxy 页面工具栏新增排序切换，可在延迟排序与默认节点顺序之间切换，同时仍遵循隐藏不可用节点的过滤规则
- `状态栏运行状态图标`
  - 新增：更新品牌图标资源，状态栏图标区分运行（Running）与休眠（Sleeping）两种状态
- `订阅信息重设计`
  - 优化：重新设计代理订阅（Proxy Provider）行，直接展示更新时间、刷新状态、到期信息和用量进度，信息一目了然
- `provider 状态精简`
  - 优化：移除 Provider 节点级别的延迟、测试、展开等冗余状态追踪，保持订阅行聚焦于摘要信息，减少不必要的内存占用
- `状态栏图标变暗`
  - 修复：为状态栏图标启用 `isTemplate` 模式，修复多显示器切换焦点时图标不跟随系统自动变暗的问题，行为与系统电池、Wi-Fi 图标保持一致
- `helper xpc 认证`
  - 修复：XPC 认证改为基于代码签名要求（Code Signing Requirement），替代原有的 PID 签名校验方式，提升安全性与可靠性

## v0.1.7

> 本次更新重点覆盖 `系统页快捷键`、`启动延迟探测`、`退出清理流程`，同时包含能力补齐、交互整理和稳定性修复。

### 变更统计

- 新增功能：1 项
- 优化改进：2 项
- 问题修复：1 项

### 按模块归纳

- `系统页快捷键`
  - 新增：新增 `Command + ,` 快捷键，支持从菜单命令快速切换到 `System` 页面，更符合 macOS 用户习惯
- `启动延迟探测`
  - 优化：内核启动完成后会自动触发 Proxy Group 延迟测试，用户打开面板时能更快看到各组节点状态
- `退出清理流程`
  - 优化：应用退出时会主动清理系统代理，减少异常退出后系统仍残留无效代理状态的情况
- `系统代理恢复`
  - 修复：修复 ClashBar 重新启动后系统代理状态丢失的问题；如果退出前已开启代理，应用恢复运行后会自动按上次状态恢复

## v0.1.6

> 本次更新重点覆盖 `内核一键升级`、`升级反馈`、`版本同步`，同时包含能力补齐、交互整理和稳定性修复。

### 变更统计

- 新增功能：1 项
- 优化改进：3 项
- 问题修复：1 项

### 按模块归纳

- `内核一键升级`
  - 新增：在菜单栏底部新增 Mihomo 内核升级入口，支持在运行中直接检查并执行升级操作
- `升级反馈`
  - 优化：为内核升级补充进行中、成功、已是最新版、失败等明确状态提示，并同步写入日志，减少黑盒体验
- `版本同步`
  - 优化：升级完成后自动刷新内核版本号，底部显示的 Mihomo 版本会尽快与实际运行版本保持一致
- `版本检查时机`
  - 优化：应用新版检测改为在面板展开时刷新，避免后台无效轮询，同时保证用户打开菜单时能看到最新版本提示
- `升级响应兼容性`
  - 修复：兼容 Mihomo `/upgrade` 接口的多种响应与错误文案，正确识别“已是最新版”场景，避免把正常结果误判为失败
