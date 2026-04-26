# VBRecorder

`VBRecorder` 是一个 macOS 菜单栏工具，用来把当前应用里选中的单个词条追加到记录文件。

默认会写到 `words.csv`，当前列结构是：

```csv
word,note,created_at,first_added_rank,last_accessed_at,recent_access_rank
```

## Run

平时直接在 VSCode 或终端里工作，不需要打开 Xcode GUI。

构建并启动：

```bash
./scripts/dev-build-install-run.sh
```

只跑单测：

```bash
./scripts/dev-test.sh
```

打包本地安装用 `dmg`：

```bash
./scripts/release-dmg.sh
```

GitHub Actions：
- `push main` 自动跑单测并构建一个未签名的 `Release` app artifact
- `push main` 自动更新一个 GitHub prerelease 页面：`main-latest`
- `pull_request` 也会跑同一套检查

固定安装路径：

```text
/Users/qiaqia/Applications/VBRecorder.app
```

VSCode 任务：
- `VBRecorder: Build Install Run`
- `VBRecorder: Test`
- `VBRecorder: Open Installed App`

## Access

第一次使用时，到 `系统设置 > 隐私与安全性 > 辅助功能` 勾选：

```text
/Users/qiaqia/Applications/VBRecorder.app
```

因为安装路径固定，正常情况下只需要授权一次。

## Layout

顶层目录：
- `VBRecorder/` 主应用源码
- `VBRecorderTests/` 单元测试
- `VBRecorder.xcodeproj/` 工程配置
- `scripts/` 构建和测试脚本
- `.vscode/` VSCode 任务
- `.build/` 本地构建输出
- `.gitignore` 忽略规则

`VBRecorder/` 主要文件：
- `VBRecorderApp.swift` SwiftUI 入口
- `AppDelegate.swift` 菜单栏图标、菜单、快捷键、启动流程
- `WordRecorder.swift` 录词主流程
- `WordRecordStore.swift` 记录文件读写
- `WordNormalizer.swift` 词条清洗规则
- `SelectedTextReader.swift` 前台选中文本读取
- `PasteboardSnapshot.swift` 剪贴板恢复
- `SettingsView.swift` 设置窗口内容
- `SettingsWindowController.swift` 设置窗口承载层
- `Assets.xcassets/AppIcon.appiconset/icon-source.svg` App Icon 源文件

## Commands

```bash
xcodebuild build \
  -project VBRecorder.xcodeproj \
  -scheme VBRecorder \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

```bash
xcodebuild test \
  -project VBRecorder.xcodeproj \
  -scheme VBRecorder \
  -destination 'platform=macOS' \
  -only-testing:VBRecorderTests \
  -derivedDataPath .build/DerivedData
```

```bash
xcodebuild build \
  -project VBRecorder.xcodeproj \
  -scheme VBRecorder \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build/ReleaseDerivedData
```

## CI

工作流文件：
- `.github/workflows/ci.yml`

行为：
- `push` 到 `main` 自动执行测试和 `Release` 构建
- 产出 `VBRecorder-app.zip` artifact
- 上传 `VBRecorder.xcresult` 方便看测试详情
- 自动更新 `main-latest` 这个 prerelease，便于直接下载构建产物

说明：
- CI 里用了 `CODE_SIGNING_ALLOWED=NO`，这样 GitHub 的 macOS runner 不需要你本机的签名证书也能完成检查和构建
- 自动发布页现在上传的是 `VBRecorder-app.zip`
- 这份自动发布产物适合验证和内部下载，不等于正式签名发布包
- 如果后面要做正式对外发布，建议改成 `tag` 触发、签名、公证、再上传 `dmg`

## Git

当前目录已经是一个 Git 仓库，当前分支是 `main`，不需要再次执行 `git init`。
