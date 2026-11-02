#!/bin/bash
# Claude Code Notification hook.
# Posts a macOS notification; clicking it jumps back to where this notification came from.
#
# Language: `defaults write io.github.moozeeli.claude-notify language zh` (default: en)
set -u
BUNDLE_ID="io.github.moozeeli.claude-notify"
D="$HOME/.claude/notify"
LANG_PREF=$(defaults read "$BUNDLE_ID" language 2>/dev/null || echo en)

IN=$(cat)
case "$LANG_PREF" in
  zh*) T_CONFIRM="Claude Code 需要确认"; T_IDLE="Claude Code 等待输入"; DEFAULT_MSG="需要你的确认"; UNKNOWN="未知"; EXT="插件" ;;
  *)   T_CONFIRM="Claude Code needs your attention"; T_IDLE="Claude Code is waiting for input"; DEFAULT_MSG="Waiting for your input"; UNKNOWN="unknown"; EXT="extension" ;;
esac
# idle_prompt = finished and waiting for input; everything else (permission prompts etc.) needs a decision.
case "$(printf '%s' "$IN" | jq -r '.notification_type // ""')" in
  idle_prompt) TITLE="$T_IDLE" ;;
  *)           TITLE="$T_CONFIRM" ;;
esac
MSG=$(printf '%s' "$IN" | jq -r --arg d "$DEFAULT_MSG" '.message // $d' | tr '\n' ' ')
CWD=$(printf '%s' "$IN" | jq -r '.cwd // ""')

# Detect the host app that runs Claude Code.
BUNDLE="${__CFBundleIdentifier:-}"
PROG="${TERM_PROGRAM:-}"
TTY=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
case "$BUNDLE:$PROG" in
  com.googlecode.iterm2:*|*:iTerm.app)   WHERE="iTerm" ;;
  com.apple.Terminal:*|*:Apple_Terminal) WHERE="Terminal" ;;
  com.microsoft.VSCode*)                 WHERE="VS Code" ;;
  com.todesktop.*)                       WHERE="Cursor" ;;
  *)                                     WHERE="${PROG:-${BUNDLE:-$UNKNOWN}}" ;;
esac
[ "${CLAUDE_CODE_ENTRYPOINT:-}" = "claude-vscode" ] && WHERE="$WHERE $EXT"
case "${ITERM_PROFILE:-}" in *[Hh]otkey*) WHERE="$WHERE Hotkey" ;; esac

# One target file per notification; clean up files older than a day.
mkdir -p "$D/targets"
find "$D/targets" -name '*.target' -mtime +1 -delete 2>/dev/null
TARGET="$D/targets/$(date +%Y%m%d%H%M%S)-$$.target"
{
  echo "bundle=$BUNDLE"
  echo "prog=$PROG"
  echo "iterm=${ITERM_SESSION_ID#*:}"
  echo "tty=$TTY"
  echo "cwd=$CWD"
  echo "profile=${ITERM_PROFILE:-}"
} > "$TARGET"

open -g -n "$D/ClaudeNotify.app" --args post "$TITLE" "📂 ${CWD/#$HOME/~} · $WHERE" "$MSG" "$TARGET"
exit 0
