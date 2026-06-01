# Codex Mac Reminder

一个给 Codex 准备的 macOS 菜单栏提醒工具，用来把“需要你介入”的时刻变得足够显眼。

当 Codex 需要你手动确认、授权、选择方案或继续操作时，它会在所有连接的屏幕边缘显示 Boopa 风格的呼吸光。提醒窗口不抢焦点，不影响当前操作，并且每个屏幕右上角都有一个可以关闭本次提醒的按钮。

## 功能

- 在所有连接的显示器上显示屏幕边缘呼吸光。
- Codex 需要用户输入、确认或授权时显示呼吸提醒。
- Codex 任务结束时显示短促绿色闪光。
- 每个屏幕右上角提供较大的 `关闭本次提醒` 按钮，只关闭当前这一次提醒。
- 菜单栏常驻，支持启用、暂停、测试提醒和调整提醒颜色。
- 支持自定义“需要介入”提醒的基准颜色，边缘光仍沿用现有透明渐变逻辑。
- 附带 LaunchAgent watcher，用来捕捉部分没有走 Codex `notify` 的授权卡片。
- 所有状态和日志都保存在本机 `~/.codex` 下，不上传数据。

## 环境要求

- macOS 13 或更新版本
- Swift 6 / Xcode Command Line Tools
- Codex 支持并已配置 `notify` 命令

## 工作原理

正常的 Codex notify 路径如下：

```text
Codex notify
  -> codex-breathing-light-wrapper
  -> ~/.codex/codex-reminder-request.json
  -> codex-reminder-agent
  -> codex-breathing-light-ui
```

`codex-breathing-light-wrapper` 只负责把请求写入本地文件并立即退出，所以不会让 Codex 被 GUI 进程卡住。`codex-reminder-agent` 是菜单栏常驻进程，它运行在 macOS GUI 会话里，轮询请求文件并启动真正的屏幕边缘提醒 UI。

`codex-approval-watcher` 是补充用的 LaunchAgent。它会监听本地 Codex 日志和 session JSONL 文件，识别类似 `sandbox_permissions=require_escalated` 的授权请求，然后触发同一套提醒路径。它只关注需要用户手动介入的场景，不会捕捉普通报错。

## 安装

克隆仓库并构建 release 二进制：

```bash
git clone https://github.com/YOUR_NAME/codex-mac-reminder.git
cd codex-mac-reminder
swift test
swift build -c release
```

安装二进制到 `~/.codex/bin`：

```bash
mkdir -p "$HOME/.codex/bin" "$HOME/.codex/log"

install -m 755 .build/release/codex-breathing-light "$HOME/.codex/bin/codex-breathing-light"
install -m 755 .build/release/codex-breathing-light-ui "$HOME/.codex/bin/codex-breathing-light-ui"
install -m 755 .build/release/codex-approval-watcher "$HOME/.codex/bin/codex-approval-watcher"
install -m 755 .build/release/codex-reminder-agent "$HOME/.codex/bin/codex-reminder-agent"
install -m 755 .build/release/codex-reminder-control "$HOME/.codex/bin/codex-reminder-control"
install -m 755 codex-breathing-light-wrapper.sh "$HOME/.codex/bin/codex-breathing-light-wrapper"
```

安装 LaunchAgent。仓库里的 plist 文件使用了示例绝对路径，复制时需要替换成你自己的 `$HOME`：

```bash
mkdir -p "$HOME/Library/LaunchAgents"

sed "s#/Users/xiaoming#$HOME#g" com.xiaoming.codex-reminder-agent.plist \
  > "$HOME/Library/LaunchAgents/com.xiaoming.codex-reminder-agent.plist"

sed "s#/Users/xiaoming#$HOME#g" com.xiaoming.codex-approval-watcher.plist \
  > "$HOME/Library/LaunchAgents/com.xiaoming.codex-approval-watcher.plist"
```

加载或重启 LaunchAgent：

```bash
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.xiaoming.codex-reminder-agent.plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.xiaoming.codex-approval-watcher.plist" 2>/dev/null || true

launchctl kickstart -k "gui/$(id -u)/com.xiaoming.codex-reminder-agent"
launchctl kickstart -k "gui/$(id -u)/com.xiaoming.codex-approval-watcher"
```

## 配置 Codex

把 wrapper 加到 `~/.codex/config.toml`：

```toml
notify = ["/Users/YOUR_NAME/.codex/bin/codex-breathing-light-wrapper"]
```

这里必须使用绝对路径。TOML 字符串里不会自动展开 `$HOME`，所以请把 `/Users/YOUR_NAME` 换成你的真实用户目录。修改配置后，如有需要，重启 Codex。

## 使用

菜单栏会显示 `Codex` 或 `Codex off`：

- `Codex`：提醒已启用。
- `Codex off`：提醒已暂停。
- `测试提醒`：显示一次短促强制测试提醒。
- `调整提醒颜色...`：调整需要介入提醒的基准颜色。
- `Ctrl + Option + Command + N`：快速切换启用/暂停。

支持的提醒颜色格式：

```text
#RRGGBB
RRGGBB
red
green
blue
orange
yellow
cyan
purple
pink
```

颜色输入框留空会恢复默认红色。

命令行控制：

```bash
"$HOME/.codex/bin/codex-reminder-control" status
"$HOME/.codex/bin/codex-reminder-control" enable
"$HOME/.codex/bin/codex-reminder-control" disable
"$HOME/.codex/bin/codex-reminder-control" toggle
```

手动测试 Codex 需要确认提醒：

```bash
"$HOME/.codex/bin/codex-breathing-light-wrapper" '{"codexUserInputRequestedDuringTurn":true}'
```

手动测试 Codex 任务结束提醒：

```bash
"$HOME/.codex/bin/codex-breathing-light-wrapper" '{"codexUserInputRequestedDuringTurn":false}'
```

绕过暂停状态，直接强制显示 UI：

```bash
"$HOME/.codex/bin/codex-breathing-light-ui" --run-ui --force --duration 3 --color '#0A84FF' --animation pulse --thickness 6 --blur 24
```

## 文件位置

运行时状态和日志：

```text
~/.codex/codex-reminder-state.json
~/.codex/codex-reminder-request.json
~/.codex/log/codex-reminder-agent.log
~/.codex/log/codex-approval-watcher.log
~/.codex/log/codex-breathing-light-wrapper.log
```

安装后的二进制：

```text
~/.codex/bin/codex-breathing-light-wrapper
~/.codex/bin/codex-breathing-light
~/.codex/bin/codex-breathing-light-ui
~/.codex/bin/codex-approval-watcher
~/.codex/bin/codex-reminder-agent
~/.codex/bin/codex-reminder-control
```

LaunchAgent：

```text
~/Library/LaunchAgents/com.xiaoming.codex-reminder-agent.plist
~/Library/LaunchAgents/com.xiaoming.codex-approval-watcher.plist
```

## 项目结构

```text
Package.swift
Sources/CodexBreathingLightCore/     参数解析、状态、watcher 等共享逻辑
Sources/codex-breathing-light/       Foundation 版 UI launcher
Sources/codex-breathing-light-ui/    AppKit 屏幕边缘提醒 UI
Sources/codex-approval-watcher/      Codex 授权提示 watcher
Sources/codex-reminder-agent/        菜单栏 app 和全局快捷键
Sources/codex-reminder-control/      命令行启用/暂停/状态工具
Tests/CodexBreathingLightCoreTests/  Swift Testing 测试
```

`boopa-upstream/` 是 Boopa 的本地参考副本，不参与本 Swift package 构建。

## 开发

运行测试：

```bash
swift test
```

构建所有可执行文件：

```bash
swift build -c release
```

如果在受限的 Codex 沙箱中运行，Swift 可能会尝试把 module cache 写到工作区外。可以把缓存路径指向项目内：

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.swift-cache/clang" swift test --scratch-path .build --disable-sandbox
```

## 排查

检查菜单栏 agent 是否运行：

```bash
launchctl print "gui/$(id -u)/com.xiaoming.codex-reminder-agent"
tail -120 "$HOME/.codex/log/codex-reminder-agent.log"
```

检查授权 watcher 是否运行：

```bash
launchctl print "gui/$(id -u)/com.xiaoming.codex-approval-watcher"
tail -120 "$HOME/.codex/log/codex-approval-watcher.log"
```

检查 Codex 是否配置了 wrapper：

```bash
grep -n '^notify' "$HOME/.codex/config.toml"
```

手动触发一次需要介入提醒：

```bash
"$HOME/.codex/bin/codex-breathing-light-wrapper" '{"codexUserInputRequestedDuringTurn":true}'
```

如果旧的测试提醒窗口还残留，可以检查进程：

```bash
pgrep -fl 'codex-breathing-light|codex-breathing-light-ui'
```

## 隐私

这个工具只在本机运行。它会读取本地 Codex 日志和 session 文件来识别授权提示，并把状态和日志写到 `~/.codex` 下。它不会上传数据，也不会连接远程服务。

## 致谢

视觉效果参考了 [Boopa](https://github.com/Eilgnaw/boopa)。
