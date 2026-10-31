#!/bin/bash
# Remove claude-notify from ~/.claude and unregister the hook.
set -euo pipefail
BUNDLE_ID="io.github.moozeeli.claude-notify"
S="$HOME/.claude/settings.json"
CMD='bash $HOME/.claude/hooks/notify.sh'

if [ -f "$S" ] && command -v jq >/dev/null; then
  cp "$S" "$S.bak.$(date +%s)"
  jq --arg c "$CMD" '
    if .hooks.Notification then
      .hooks.Notification |= (map(.hooks |= map(select(.command != $c))) | map(select(.hooks | length > 0)))
    else . end' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
  echo "Unregistered hook from $S"
fi
rm -rf "$HOME/.claude/notify" "$HOME/.claude/hooks/notify.sh"
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "Removed. You may also remove ClaudeNotify from System Settings → Notifications."
