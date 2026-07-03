# AGENTS.md

给在本仓库工作的智能体（以及协作者）的约定。

## 版本号规则

采用语义化版本 `MAJOR.MINOR.PATCH`，当前尚未到 `1.0.0`，保持在 **`0.x.x`**。

版本号记录在 `project.yml`：
- `MARKETING_VERSION`：对用户的语义版本（如 `0.1.0`）。
- `CURRENT_PROJECT_VERSION`：构建号，单调递增。

升级规则：
- **PATCH**：**每产生一次提交就 +1**（`0.1.0 → 0.1.1 → 0.1.2 …`），构建号同时 +1。这是默认、自动执行的。
- **MINOR**：完成一组明显的新功能后，**人为**决定 +1，并把 PATCH 归零（`0.1.7 → 0.2.0`）。
- **MAJOR**：**仅在人为明确指定时**才 +1。在此之前 MAJOR 恒为 `0`，不因功能量或提交数自动升到 `1.0.0`。

执行方式（每次提交前）：
1. 编辑 `project.yml`：把 `MARKETING_VERSION` 的 PATCH（或按需 MINOR/MAJOR）加一，`CURRENT_PROJECT_VERSION` 加一。
2. 这两处改动纳入**本次**提交（即版本号随该次提交一起提交）。

## 构建

- 生成/更新 Xcode 工程（**增删源文件后必须执行**）：`xcodegen generate`
- 编译（macOS）：`xcodebuild -scheme FourQuadrants -destination 'platform=macOS' build`
- 本地签名为「Sign to Run Locally」（`CODE_SIGN_IDENTITY = "-"`，无需开发团队）。
