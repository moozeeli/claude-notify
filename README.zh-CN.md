# claude-notify

[English](README.md)

为 [Claude Code](https://claude.com/claude-code) 提供 macOS 系统通知，**点击通知就能回到触发它的那个窗口**。

同时在 iTerm2 的多个 tab、hotkey window、VS Code 里跑着好几个 Claude Code 会话时，每条通知都会显示来源目录和应用，点一下直接跳回去。同时有多条通知时，每条都记得自己的来源。

> 本项目是独立的社区项目，与 Anthropic 没有隶属或背书关系。

## 功能

| Claude Code 运行在 | 点击通知后 |
|---|---|
| iTerm2 窗口 | 切到对应的窗口、tab 和分屏 |
| iTerm2 hotkey window | 窗口隐藏时模拟按你的 hotkey 把它唤出来；已显示就不动 |
| VS Code 插件 / VS Code 内置终端 | 聚焦打开这个项目的窗口 |
| Cursor / VSCodium / Windsurf | 同 VS Code（测试较少） |
| Terminal.app | 按 tty 切到对应 tab（测试较少） |
| 其他（Warp、Ghostty 等） | 激活该应用 |

通知标题区分两种情况：需要你确认权限或做决定时显示 **「Claude Code 需要确认」**，回完话等你输入时显示 **「Claude Code 等待输入」**。

通知副标题格式：`📂 <目录> · <应用>`，例如 `📂 ~/my-project · iTerm Hotkey`。

## 环境要求

- macOS 13 及以上
- Xcode Command Line Tools（`xcode-select --install`），用来提供 `swiftc`
- [`jq`](https://jqlang.github.io/jq/)（`brew install jq`）

## 安装

```bash
git clone https://github.com/moozeeli/claude-notify.git
cd claude-notify
./install.sh
```

`install.sh` 会编译应用、把文件复制到 `~/.claude`，并在 `~/.claude/settings.json` 里注册下面这个 hook，注册前会先备份原文件：

```json
{ "hooks": { "Notification": [ { "hooks": [ { "type": "command", "command": "bash $HOME/.claude/hooks/notify.sh" } ] } ] } }
```

然后授予权限：

1. **通知**：第一次发通知时系统会弹窗，点允许。没弹的话，去「系统设置 → 通知」里打开 *ClaudeNotify*。
2. **辅助功能**（只有 iTerm2 hotkey window 需要）：「系统设置 → 隐私与安全性 → 辅助功能」，点 **+**，按 ⌘⇧G 输入 `~/.claude/notify/ClaudeNotify.app`。
3. 第一次跳转到 iTerm2 / Terminal 时，系统可能会询问是否允许 ClaudeNotify 控制该应用，点允许。

不等 Claude Code 也能直接测试：

```bash
echo '{"message":"Hello from claude-notify","cwd":"'"$PWD"'"}' | bash ~/.claude/hooks/notify.sh
```

## 配置

配置用 `defaults` 存储，立即生效，不用重新编译，也不用重新授权。

```bash
# 通知语言：en（默认）或 zh
defaults write io.github.moozeeli.claude-notify language zh

# iTerm2 hotkey（默认 ⌥Space）
defaults write io.github.moozeeli.claude-notify hotkeyKeyCode -int 49           # 虚拟键码，49 是空格
defaults write io.github.moozeeli.claude-notify hotkeyModifiers "option"        # option / command / control / shift，多个用 "+" 连接
```

举例：快捷键是 ⌃⌘T 的话，设置 `hotkeyKeyCode 17`、`hotkeyModifiers "control+command"`。双击修饰键这类快捷键没法模拟。

## 实现原理

```
Claude Code 触发 Notification hook
  └─ scripts/notify.sh
       ├─ 从 __CFBundleIdentifier、TERM_PROGRAM、ITERM_SESSION_ID、ITERM_PROFILE、
       │  CLAUDE_CODE_ENTRYPOINT 以及 tty、cwd 识别宿主
       ├─ 写进这条通知专属的目标文件 ~/.claude/notify/targets/<时间>-<pid>.target
       └─ open ClaudeNotify.app --args post <标题> <副标题> <正文> <目标文件>

ClaudeNotify.app（Swift，UserNotifications）
  ├─ post：发通知，目标文件路径放进 userInfo，约 3 秒后退出
  └─ 被点击：系统重新拉起应用，并交给它被点击的那条通知
       └─ scripts/focus.sh <目标文件> 执行跳转
            └─ hotkey window 隐藏时输出 ACTION=hotkey → 由应用发送 hotkey
```

设计要点：

- **每条通知自带目标**：目标存在每条通知的 `userInfo` 里，所以每条都能跳回自己的来源。AppleScript 的 `display notification` 没法附带数据，所以用 Swift 写了这个小应用。
- **hotkey window**：iTerm2 的 AppleScript 接口始终列不出 hotkey window，没法直接选中它。应用会比较屏幕上的 iTerm2 窗口数（CGWindowList）和 AppleScript 能列出的窗口数，hotkey window 没显示时就发送你的 hotkey。hotkey 是开关式的，所以窗口已经显示时不会再按。
- **按键由应用自己发出**：这样辅助功能权限只属于 ClaudeNotify。如果用 `osascript` 发，权限就算在 `osascript` 头上，等于给所有 AppleScript 开放了这个权限。
- **VS Code 不需要辅助功能权限**：`open -b <bundle> <目录>` 会聚焦已经打开该目录的窗口。目录按顺序取：编辑器 `storage.json` 里包含 cwd 的最长已打开工作区 → git 根目录 → 按窗口标题匹配。

## 文件说明

```
src/main.swift        ClaudeNotify.app 源码
src/Info.plist        bundle id io.github.moozeeli.claude-notify，LSUIElement（不显示 Dock 图标）
assets/AppIcon.icns   应用图标（用 assets/make_icon.swift 重新生成）
scripts/notify.sh     Claude Code Notification hook
scripts/focus.sh      按目标文件执行跳转
build.sh              编译到 build/ClaudeNotify.app
install.sh            安装到 ~/.claude 并注册 hook
uninstall.sh          卸载并移除 hook
```

安装后的位置：`~/.claude/notify/{ClaudeNotify.app,focus.sh,targets/,debug.log}` 和 `~/.claude/hooks/notify.sh`。

## 更新

| 改了什么 | 怎么生效 | 要重新授辅助功能权限吗 |
|---|---|---|
| `scripts/*.sh` | `./install.sh --no-app` | 不用 |
| `src/*` | `./install.sh` | **要**，本机临时签名每次编译都会变 |

## 排查

每次点击都会记到 `~/.claude/notify/debug.log`：

```
21:49:12 click target=20261031214857-74100.target
21:49:12 focus bundle=com.googlecode.iterm2 prog=iTerm.app tty=ttys002 cwd=/Users/you/project
  iterm -> no match profile=Hotkey Window
AS_N=0
ACTION=hotkey
21:49:13   hotkey sent option+49 cg=0 as=0
```

| 现象 | 可能原因 |
|---|---|
| 不弹通知 | 通知权限没开，或应用启动失败，试试 `open -n ~/.claude/notify/ClaudeNotify.app` |
| 启动报错 `-10825` | 编译时没指定部署目标，请用 `build.sh` 编译 |
| 点击没反应，日志里没有 `click` | 应用没被重新拉起，检查通知权限，或去通知中心里点 |
| `hotkey error: Accessibility permission not granted` | 应用重新编译过，删掉旧的辅助功能条目重新添加 |
| VS Code 新开了一个窗口 | 已打开的窗口是 cwd 的上级目录，但没被记录为工作区 |
| 用 Claude Code 自带的推送测试没反应 | 那走的是 Claude Code 自己的通知通道，不会触发 Notification hook |

## 已知限制

- hotkey window 能唤出来，但切不到里面的具体 tab。
- VS Code 系编辑器只能聚焦到项目窗口，定位不到里面具体的终端或面板。
- 副标题里的「Hotkey」标记依赖 profile 名包含「Hotkey」（iTerm2 默认就叫「Hotkey Window」）；跳转本身不受影响。

## 卸载

```bash
./uninstall.sh
```

## 许可证

[MIT](LICENSE)
