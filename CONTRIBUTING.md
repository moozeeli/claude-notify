# Contributing

Thanks for your interest! Issues and pull requests are welcome.

## Development

```bash
./build.sh                # build build/ClaudeNotify.app
./install.sh --no-app     # install only the scripts (keeps your permissions)
./install.sh              # rebuild and install the app (re-grant Accessibility afterwards)
```

Send a test notification:

```bash
echo '{"message":"test","cwd":"'"$PWD"'"}' | bash ~/.claude/hooks/notify.sh
```

Logs go to `~/.claude/notify/debug.log`.

## Adding support for another terminal or editor

1. In `scripts/notify.sh`, make sure the host is recognizable from the environment
   (`__CFBundleIdentifier`, `TERM_PROGRAM`, …) and record anything needed to locate
   the window in the target file.
2. In `scripts/focus.sh`, add a `case` branch that brings that window to the front.
3. Prefer approaches that don't need Accessibility permission. If a keystroke or UI
   scripting is unavoidable, do it from `src/main.swift` so the permission is granted
   to ClaudeNotify rather than to `osascript`.

## Guidelines

- Keep the shell scripts `shellcheck`-clean (CI runs `shellcheck -S warning`).
- Mention in your PR which environments you tested.
- Add a line to `CHANGELOG.md` under an `Unreleased` section.
