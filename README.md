# 四象限 (FourQuadrants)

按 **艾森豪威尔矩阵**（紧急 × 重要）组织任务的 iOS / macOS 原生应用，基础交互参照「提醒事项」。单一 SwiftUI 代码库，SwiftData + CloudKit 同步。

## 功能
- 任务按 `紧急 / 重要` 两个标志推导到四个象限；可在象限间 **拖拽** 移动（自动翻转标志）。
- **智能粘贴解析**：新建时粘贴整段工单文本，自动拆出 工单号（高亮 badge）/ 标题 / 链接。
- 截止日期 + 本地通知、子任务、标签与搜索、完成状态与历史、每任务外部链接。
- iCloud（CloudKit）跨设备同步。

## 环境要求
- macOS 26+ 与 **Xcode 26+**（本仓库代码面向 iOS 26 / macOS 26）。
- [XcodeGen](https://github.com/yonyz/XcodeGen)（`brew install xcodegen`）—— 用于从 `project.yml` 生成工程。
- CloudKit 同步需 **付费 Apple Developer 账号**。

## 生成并打开工程
```bash
cd FourQuadrants
xcodegen generate            # 由 project.yml 生成 FourQuadrants.xcodeproj
open FourQuadrants.xcodeproj
```
> 新增/删除源文件后重新运行 `xcodegen generate` 即可，无需手动维护工程文件。

## 构建 / 测试（装好 Xcode 后）
```bash
# macOS
xcodebuild -scheme FourQuadrants -destination 'platform=macOS' build
# iOS 模拟器
xcodebuild -scheme FourQuadrants -destination 'platform=iOS Simulator,name=iPhone 16' build
# 单元测试
xcodebuild test -scheme FourQuadrants -destination 'platform=macOS'
```
解析逻辑的命令行快速校验（无需 Xcode）：
```bash
swiftc Sources/Services/TaskInputParser.swift <(一个含 main 的测试文件) -o check && ./check
```

## 同步模式

默认是 **本地模式**：`Sources/FourQuadrants.entitlements` 不含 iCloud/Push，可在 **个人开发团队** 下直接编译运行（个人团队不支持这两项能力）。数据存本地，`FourQuadrantsApp.makeContainer()` 会自动以本地存储运行。

### 切到 CloudKit 同步（需付费 Apple Developer 账号）
1. 编辑 `project.yml`，把 target 的 `CODE_SIGN_ENTITLEMENTS` 改为
   `Sources/FourQuadrants-CloudKit.entitlements`。
2. `xcodegen generate` 重新生成工程。
3. Xcode 中选中 **FourQuadrants** target → Signing & Capabilities，设置你的付费 **Team**；
   确认容器为 `iCloud.com.cod7ce.FourQuadrants`（如改 bundle id 前缀，需同步更新两个 entitlements 文件）。

## 代码结构
```
Sources/
  FourQuadrantsApp.swift     # @main，ModelContainer（CloudKit，带本地回退）
  Models/                    # TaskItem / Tag / Quadrant
  Views/                     # NavigationSplitView 外壳、象限网格、列表、详情
  Services/                  # 通知、智能解析、示例数据
  Support/                   # 颜色、绑定、拖拽 Transferable、预览容器
  Filters.swift              # 范围过滤辅助
Tests/                       # TaskInputParser 单元测试
project.yml                  # XcodeGen 工程定义
```

## SwiftData + CloudKit 约束（改模型时务必遵守）
- 每个存储属性 **可选或带默认值**；**禁止** 唯一约束 `@Attribute(.unique)`。
- 关系 **可选** 且带 `inverse`。
