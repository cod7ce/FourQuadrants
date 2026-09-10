# 肆 · FourQuadrants

一个原生 macOS / iOS 的**四象限（艾森豪威尔矩阵）任务管理**应用，SwiftUI + SwiftData。
按「紧急 / 重要」把每周任务分到四个象限，配合标签、子任务、日历/议程视图与本地笔记，帮你分清轻重缓急。

## 特性

- **四象限总览**：紧急且重要 / 重要不紧急 / 紧急不重要 / 不紧急不重要，拖拽即可换象限、排序、嵌套。
- **多级子任务**（最深 3 层）、标签分组、进度点评、富文本详情、链接与工单号识别。
- **本周议程 / 日历**视图，跨周结转，收集箱。
- **可扩展主题**：默认（跟随系统）与「终端」深色主题；可调背景图、界面透明度与模糊。
- **本地优先**：数据存本地，若有 iCloud 则自动同步。
- **自动更新**：匿名读取 GitHub Releases，发现新版可一键原地更新（见下）。

## 构建

需要 Xcode 26（部署目标 macOS/iOS 26）。工程用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 管理：

```bash
brew install xcodegen
xcodegen generate
open FourQuadrants.xcodeproj
```

`project.yml` 是工程配置的唯一来源；`FourQuadrants.xcodeproj` 由它生成、不纳入版本库。

## 发布与自动更新

- 打一个 `v*` 标签（如 `git tag v0.17.0 && git push origin v0.17.0`）会触发
  [`.github/workflows/release.yml`](.github/workflows/release.yml)：CI 构建 Release 版
  `.app`（ad-hoc 签名），打包为 `FourQuadrants-mac-arm64.zip` 并发布到对应 Release。
- App 内 `Updater`（`Sources/Services/Updater.swift`）启动后台检查最新 Release，
  发现更高版本时提示；确认后下载 zip、`ditto` 解压、去除隔离属性，写一段脚本在退出后
  原地替换 `.app` 并重启。也可在「设置 → 关于与更新」或应用菜单里手动检查。
- 未用 Sparkle：那需要 Developer ID 签名；此方案对 ad-hoc 签名的个人分发即可工作。

## 许可

个人项目，按原样提供。
