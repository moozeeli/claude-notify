#!/bin/bash
# Install into ~/.claude and register the Claude Code Notification hook.
#   ./install.sh            build + install app and scripts
#   ./install.sh --no-app   update scripts only (keeps existing permissions)
set -euo pipefail
cd "$(dirname "$0")"
BUNDLE_ID="io.github.moozeeli.claude-notify"
D="$HOME/.claude/notify"
S="$HOME/.claude/settings.json"
CMD='bash $HOME/.claude/hooks/notify.sh'

command -v jq >/dev/null || { echo "jq is required: brew install jq" >&2; exit 1; }

mkdir -p "$D/targets" "$HOME/.claude/hooks"
install -m 755 scripts/focus.sh "$D/focus.sh"
install -m 755 scripts/notify.sh "$HOME/.claude/hooks/notify.sh"

if [ "${1:-}" != "--no-app" ]; then
  ./build.sh
  rm -rf "$D/ClaudeNotify.app"
  cp -R build/ClaudeNotify.app "$D/ClaudeNotify.app"
  # Ad-hoc signatures change on every build, so any previous grant is stale.
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  cat <<MSG

App installed. If you use an iTerm2 hotkey window, grant Accessibility permission:
  System Settings → Privacy & Security → Accessibility → + → $D/ClaudeNotify.app
MSG
fi

[ -f "$S" ] || echo '{}' > "$S"
if ! jq -e --arg c "$CMD" '[.hooks.Notification[]?.hooks[]?.command] | index($c) != null' "$S" >/dev/null; then
  cp "$S" "$S.bak.$(date +%s)"
  jq --arg c "$CMD" '.hooks.Notification = ((.hooks.Notification // []) + [{"hooks":[{"type":"command","command":$c}]}])' \
    "$S" > "$S.tmp" && mv "$S.tmp" "$S"
  echo "Registered Notification hook in $S"
fi
echo "Done."
