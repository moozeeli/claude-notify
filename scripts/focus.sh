#!/bin/bash
# Jump to the window described by a target file (passed as $1 by ClaudeNotify on click).
T="${1:-}"
[ -n "$T" ] || exit 0
[ -f "$T" ] || exit 0
get() { sed -n "s/^$1=//p" "$T" | head -1; }
BUNDLE=$(get bundle); PROG=$(get prog); IUUID=$(get iterm); TTY=$(get tty); CWD=$(get cwd); PROFILE=$(get profile)
echo "$(date +%T) focus bundle=$BUNDLE prog=$PROG tty=$TTY cwd=$CWD"
case "$BUNDLE:$PROG" in
  com.googlecode.iterm2:*|*:iTerm.app)
    R=$(osascript -e "tell application \"iTerm2\"
      activate
      repeat with w in windows
        repeat with tb in tabs of w
          repeat with se in sessions of tb
            if (unique id of se) is \"$IUUID\" then
              if is hotkey window of w then
                tell w to reveal hotkey window
              else
                select w
              end if
              tell tb to select
              tell se to select
              return \"hotkey=\" & (is hotkey window of w)
            end if
          end repeat
        end repeat
      end repeat
      return \"no match\"
    end tell" 2>&1)
    echo "  iterm -> $R profile=$PROFILE"
    # A hotkey window never shows up in iTerm2's AppleScript `windows`. Hand over to
    # ClaudeNotify, which checks visibility and sends the hotkey itself (the keystroke must
    # come from the ClaudeNotify process so Accessibility permission is attributed to it).
    if [ "$R" = "no match" ]; then
      echo "AS_N=$(osascript -e 'tell application "iTerm2" to count windows' 2>&1)"
      echo "ACTION=hotkey"
    fi ;;
  com.apple.Terminal:*|*:Apple_Terminal)
    osascript -e "tell application \"Terminal\"
      activate
      repeat with w in windows
        repeat with tb in tabs of w
          if tty of tb is \"/dev/$TTY\" then
            set selected of tb to true
            set index of w to 1
            return
          end if
        end repeat
      end repeat
    end tell" ;;
  *)
    if [ -n "$BUNDLE" ]; then
      case "$BUNDLE" in
        com.microsoft.VSCode*|com.todesktop.*|com.vscodium*|com.exafunction.windsurf*)
          # `open -b <bundle> <dir>` focuses the window that already has <dir> open, no
          # Accessibility permission needed. Pick <dir> in this order:
          #   1) the longest opened workspace (from the editor's storage.json) containing cwd
          #   2) the git root of cwd
          #   3) fall back to matching window titles (needs Accessibility)
          case "$BUNDLE" in
            com.microsoft.VSCodeInsiders) APPDIR="Code - Insiders" ;;
            com.microsoft.VSCode) APPDIR="Code" ;;
            com.todesktop.*) APPDIR="Cursor" ;;
            com.vscodium*) APPDIR="VSCodium" ;;
            com.exafunction.windsurf*) APPDIR="Windsurf" ;;
          esac
          STORE="$HOME/Library/Application Support/$APPDIR/User/globalStorage/storage.json"
          WS=$(jq -r '.windowsState | [.lastActiveWindow, .openedWindows[]?] | .[].folder // empty' "$STORE" 2>/dev/null \
            | sed 's|^file://||' | python3 -c 'import sys,urllib.parse as u;[print(u.unquote(l.strip())) for l in sys.stdin]' \
            | while read -r d; do [[ "$CWD/" == "$d"/* ]] && echo "${#d} $d"; done | sort -rn | head -1 | cut -d' ' -f2-)
          ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
          if [ -n "$WS" ]; then
            open -b "$BUNDLE" "$WS"; echo "  editor open workspace=$WS -> $?"
          elif [ -n "$ROOT" ]; then
            open -b "$BUNDLE" "$ROOT"; echo "  editor open root=$ROOT -> $?"
          else
            # Not inside a git repo (e.g. ~): match the directory name against window titles.
            open -b "$BUNDLE"
            N=$(basename "$CWD")
            R=$(osascript -e "tell application \"System Events\" to tell (first process whose bundle identifier is \"$BUNDLE\")
              repeat with w in windows
                if name of w contains \"$N\" then
                  perform action \"AXRaise\" of w
                  return \"raised: \" & (name of w)
                end if
              end repeat
              return \"no match, titles: \" & (name of every window as text)
            end tell" 2>&1)
            echo "  editor title match name=$N -> $R"
          fi ;;
        *) open -b "$BUNDLE" ;;
      esac
    fi ;;
esac
