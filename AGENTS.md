# AGENTS.md

给在本仓库工作的智能体（以及协作者）的约定。

## 版本号规则

采用语义化版本 `MAJOR.MINOR.PATCH`，当前尚未到 `1.0.0`，保持在 **`0.x.x`**。

版本号记录在 `project.yml` 的 `MARKETING_VERSION`（如 `0.3.3`）。暂不使用构建号
（`CURRENT_PROJECT_VERSION`）；将来上 TestFlight / App Store 时再加回。

升级规则：
- **PATCH**：**每产生一次提交就 +1**（`0.3.2 → 0.3.3 → 0.3.4 …`）。这是默认、自动执行的。
- **MINOR**：完成一组明显的新功能后，**人为**决定 +1，并把 PATCH 归零（`0.3.7 → 0.4.0`）。
- **MAJOR**：**仅在人为明确指定时**才 +1。在此之前 MAJOR 恒为 `0`，不因功能量或提交数自动升到 `1.0.0`。

执行方式（每次提交前）：编辑 `project.yml` 把 `MARKETING_VERSION` 的 PATCH（或按需
MINOR/MAJOR）加一，随**本次**提交一起提交。

## 构建

- 生成/更新 Xcode 工程（**增删源文件后必须执行**）：`xcodegen generate`
- 编译（macOS）：`xcodebuild -scheme FourQuadrants -destination 'platform=macOS' build`
- 本地签名为「Sign to Run Locally」（`CODE_SIGN_IDENTITY = "-"`，无需开发团队）。
