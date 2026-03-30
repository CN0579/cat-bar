<div align="center">

<img src="Sources/ClashBar/Resources/Assets.xcassets/BrandLogo.imageset/logo.png" width="300" alt="ClashBar Logo" />

# ClashBar

基于 `SwiftUI + AppKit` 构建、由 `mihomo` 驱动的原生 macOS 菜单栏代理客户端，专注轻量、稳定与可观测。

<p>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&logo=apple" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift" />
  <img alt="Build" src="https://img.shields.io/badge/Build-SwiftPM-0A84FF?style=flat-square" />
  <img alt="i18n" src="https://img.shields.io/badge/i18n-zh--Hans%20%7C%20en-34C759?style=flat-square" />
  <a href="https://github.com/QuentinHsu/ClashBar/releases" target="_blank" rel="noopener noreferrer">
    <img alt="Version" src="https://img.shields.io/github/v/release/QuentinHsu/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/QuentinHsu/ClashBar/stargazers" target="_blank" rel="noopener noreferrer">
    <img alt="Stars" src="https://img.shields.io/github/stars/QuentinHsu/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://github.com/QuentinHsu/ClashBar/issues" target="_blank" rel="noopener noreferrer">
    <img alt="Issues" src="https://img.shields.io/github/issues/QuentinHsu/ClashBar?style=flat-square&logo=github" />
  </a>
  <a href="https://t.me/clashbars" target="_blank" rel="noopener noreferrer">
    <img alt="Telegram" src="https://img.shields.io/badge/Telegram-@clashbars-26A5E4?style=flat-square&logo=telegram&logoColor=white" />
  </a>
</p>

<p align="center">
  🌐 <a href="https://clashbar.vercel.app"><strong>Website: clashbar.vercel.app</strong></a>
</p>

</div>

---

## 👋 项目简介

ClashBar 是一款基于 `mihomo` 内核的原生 macOS 菜单栏代理客户端，专注于轻量、稳定、可观测的代理管理体验。
在不打开复杂主窗口的前提下，你可以在菜单栏中完成配置管理、节点切换、规则刷新、连接排障与系统代理控制。 ✨

## 👥 贡献者

感谢所有参与贡献的开发者：

[![Contributors](https://contrib.rocks/image?repo=QuentinHsu/ClashBar)](https://github.com/QuentinHsu/ClashBar/graphs/contributors)

## 🙏 致谢

- 感谢 [OpenAI Codex](https://openai.com/codex/) 在需求拆解、工程实现与文档优化中的持续协作。 🤝
- 感谢 [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 提供稳定可靠的 Core 能力。

## ✨ Star 数

[![Star History Chart](https://api.star-history.com/svg?repos=QuentinHsu/ClashBar&type=date&legend=top-left)](https://www.star-history.com/#QuentinHsu/ClashBar&type=date&legend=top-left)

## 应用内更新

项目现在支持基于 Sparkle 的应用内更新，更新源仍然来自 GitHub Release。

- 稳定版发布工作流会为每个架构和内核形态生成独立的 `appcast-*.xml`，并作为 release asset 一起上传。
- 安装包只有在构建时注入 `SPARKLE_PUBLIC_ED_KEY` 后才会启用应用内更新；未配置时会自动回退到 GitHub Releases 页面。
要让自动更新真正生效，需要在 GitHub Actions 中配置两个值：

- `vars.SPARKLE_PUBLIC_ED_KEY`
- `secrets.SPARKLE_PRIVATE_ED_KEY`

## 正式版发布

正式版默认通过 GitHub Actions 里的 `Release DMG` 工作流发布，推荐直接使用 `workflow_dispatch` 的 `auto` bump 模式。

- 版本号 `X.Y.Z` 会基于上一个稳定 tag 和最近提交的 Conventional Commits 自动计算。
- `CHANGELOG.md` 会在发布前根据上一个稳定 tag 之后的 commit 自动生成对应版本段落，并先提交回当前分支。
- `.app` 中的 `CFBundleShortVersionString` 使用语义化版本号，例如 `0.3.0`。
- `.app` 中的 `CFBundleVersion` 使用 GitHub Actions 的 `run number`，便于区分同一版本下的不同构建。

## 📄 许可证

本项目采用 `GPL-3.0 license`，详见 [LICENSE](LICENSE)。
