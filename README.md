# claude-notify

[中文文档](README.zh-CN.md)

macOS notifications for [Claude Code](https://claude.com/claude-code) that **take you back to the exact window that needs you** when clicked.

Running several Claude Code sessions across iTerm2 tabs, a hotkey window and VS Code? Each notification shows which directory and app it came from, and clicking it jumps straight there. Multiple pending notifications each remember their own origin.

> This is an independent community project and is not affiliated with or endorsed by Anthropic.

## Features

| Where Claude Code runs | What a click does |
|---|---|
| iTerm2 window | Selects the exact window, tab and split pane |
| iTerm2 hotkey window | Reveals the hidden hotkey window (sends your hotkey); does nothing if already visible |
| VS Code extension / integrated terminal | Focuses the window that has the project open |
| Cursor / VSCodium / Windsurf | Same as VS Code (less tested) |
| Terminal.app | Selects the tab by tty (less tested) |
| Anything else (Warp, Ghostty, …) | Activates the app |

Notification title tells you what Claude needs: **"Claude Code needs your attention"** for permission prompts and other decisions, **"Claude Code is waiting for input"** when it has finished and is idle.

Notification subtitle format: `📂 <directory> · <app>`, e.g. `📂 ~/my-project · iTerm Hotkey`.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) for `swiftc`
- [`jq`](https://jqlang.github.io/jq/) (`brew install jq`)

## Install

```bash
git clone https://github.com/moozeeli/claude-notify.git
cd claude-notify
./install.sh
```

`install.sh` builds the app, copies everything into `~/.claude`, and adds this hook to `~/.claude/settings.json` (a backup is written first):

```json
{ "hooks": { "Notification": [ { "hooks": [ { "type": "command", "command": "bash $HOME/.claude/hooks/notify.sh" } ] } ] } }
```

Then grant permissions:

1. **Notifications** — allow when prompted on the first notification, or enable *ClaudeNotify* in System Settings → Notifications.
2. **Accessibility** (only needed for the iTerm2 hotkey window) — System Settings → Privacy & Security → Accessibility → **+** → press ⌘⇧G and enter `~/.claude/notify/ClaudeNotify.app`.
3. The first jump to iTerm2 / Terminal may ask whether ClaudeNotify can control that app — allow it.

Test without waiting for Claude Code:

```bash
echo '{"message":"Hello from claude-notify","cwd":"'"$PWD"'"}' | bash ~/.claude/hooks/notify.sh
```

## Configuration

Settings are stored with `defaults` and take effect immediately — no rebuild, no re-granting permissions.

```bash
# Notification language: en (default) or zh
defaults write io.github.moozeeli.claude-notify language zh

# iTerm2 hotkey (default: ⌥Space)
defaults write io.github.moozeeli.claude-notify hotkeyKeyCode -int 49           # virtual key code, 49 = Space
defaults write io.github.moozeeli.claude-notify hotkeyModifiers "option"        # option / command / control / shift, joined by "+"
```

Example: for ⌃⌘T use `hotkeyKeyCode 17` and `hotkeyModifiers "control+command"`. Double-tap modifier hotkeys cannot be simulated.

## How it works

```
Claude Code fires the Notification hook
  └─ scripts/notify.sh
       ├─ detects the host from __CFBundleIdentifier, TERM_PROGRAM, ITERM_SESSION_ID,
       │  ITERM_PROFILE, CLAUDE_CODE_ENTRYPOINT, plus tty and cwd
       ├─ writes them to a per-notification file ~/.claude/notify/targets/<time>-<pid>.target
       └─ open ClaudeNotify.app --args post <title> <subtitle> <body> <target file>

ClaudeNotify.app (Swift, UserNotifications)
  ├─ post: shows the notification with the target file path in userInfo, quits after ~3 s
  └─ on click: macOS relaunches the app and hands over the clicked notification
       └─ scripts/focus.sh <target file> performs the jump
            └─ prints ACTION=hotkey for a hidden hotkey window → the app sends the hotkey
```

Design notes:

- **Per-notification targets.** The target lives in each notification's `userInfo`, so every notification jumps to its own origin. AppleScript's `display notification` can't carry data, which is why this is a small Swift app.
- **Hotkey windows.** iTerm2's AppleScript API never lists the hotkey window, so it can't be selected directly. The app compares on-screen iTerm2 windows (CGWindowList) with the AppleScript window count; if the hotkey window isn't visible, it sends your hotkey. Because the hotkey toggles, it is not sent when the window is already showing.
- **Keystrokes come from the app itself**, so the Accessibility grant belongs to ClaudeNotify only — not to `osascript`, which would open it up to every AppleScript.
- **VS Code needs no Accessibility permission.** `open -b <bundle> <dir>` focuses the window that already has `<dir>` open. `<dir>` is the longest opened workspace containing cwd (read from the editor's `storage.json`), else the git root, else a window-title match.

## Files

```
src/main.swift        ClaudeNotify.app source
src/Info.plist        bundle id io.github.moozeeli.claude-notify, LSUIElement (no Dock icon)
assets/AppIcon.icns   App icon (regenerate with assets/make_icon.swift)
scripts/notify.sh     Claude Code Notification hook
scripts/focus.sh      Performs the jump for a target file
build.sh              Builds build/ClaudeNotify.app
install.sh            Installs into ~/.claude and registers the hook
uninstall.sh          Removes everything and unregisters the hook
```

Installed locations: `~/.claude/notify/{ClaudeNotify.app,focus.sh,targets/,debug.log}` and `~/.claude/hooks/notify.sh`.

## Updating

| Changed | Apply with | Re-grant Accessibility? |
|---|---|---|
| `scripts/*.sh` | `./install.sh --no-app` | No |
| `src/*` | `./install.sh` | **Yes** — ad-hoc signatures change on every build |

## Troubleshooting

Every click is logged to `~/.claude/notify/debug.log`:

```
21:49:12 click target=20261031214857-74100.target
21:49:12 focus bundle=com.googlecode.iterm2 prog=iTerm.app tty=ttys002 cwd=/Users/you/project
  iterm -> no match profile=Hotkey Window
AS_N=0
ACTION=hotkey
21:49:13   hotkey sent option+49 cg=0 as=0
```

| Symptom | Likely cause |
|---|---|
| No notification | Notifications not allowed, or the app failed to launch — try `open -n ~/.claude/notify/ClaudeNotify.app` |
| Launch fails with error `-10825` | Built without an explicit deployment target; use `build.sh` |
| Click does nothing, no `click` line in the log | The app wasn't relaunched; check notification permission or click it in Notification Center |
| `hotkey error: Accessibility permission not granted` | App was rebuilt; remove the old Accessibility entry and add it again |
| VS Code opens a new window | The open window is a parent of cwd that isn't recorded as a workspace |
| Testing with Claude Code's own push notification does nothing | That uses Claude Code's built-in channel and does not fire the Notification hook |

## Limitations

- Hotkey window: it can be revealed, but a specific tab inside it can't be selected.
- VS Code family: focuses the project window, not a specific terminal or panel inside it.
- iTerm2 hotkey support assumes the hotkey window belongs to a profile whose name contains "Hotkey" (iTerm2's default name is "Hotkey Window") for the subtitle label; the jump itself works regardless.

## Uninstall

```bash
./uninstall.sh
```

## License

[MIT](LICENSE)
