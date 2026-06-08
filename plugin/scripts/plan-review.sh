#!/bin/bash
# scratchtml plan review — PermissionRequest hook on ExitPlanMode.
#
# Denies the FIRST ExitPlanMode attempt per session with instructions to
# upload the plan to scratchtml for inline review; the retry (after the
# review loop, or if the user opts out) passes through.
#
# $1 = plan_review userConfig (true/false)
# $2 = approve_mode userConfig (ask/auto) — shapes the post-upload menu text
# $3 = ui_mockups userConfig (true/false) — whether to include inline HTML/CSS/SVG mockups
# $4 = diagrams userConfig (true/false) — whether to include mermaid diagrams
#
# No jq dependency: session_id parsed with sed, JSON output via python3 json.dumps.
# Prompt text lives in ../prompts/ — edit there, not here.

[ "${1:-true}" = "true" ] || exit 0

PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$SESSION_ID" ] || exit 0

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers"
mkdir -p "$STATE_DIR"
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null

MARKER="$STATE_DIR/$SESSION_ID"
if [ -f "$MARKER" ]; then
  exit 0
fi
touch "$MARKER"

PROMPTS="${CLAUDE_PLUGIN_ROOT}/prompts"

if [ "${2:-ask}" = "auto" ]; then
  MENU="$(cat "${PROMPTS}/menu-auto.txt")"
else
  MENU="$(cat "${PROMPTS}/menu-ask.txt")"
fi

VISUAL_HINTS=""
[ "${3:-true}" = "true" ] && VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-ui-mockups.txt")"
[ "${4:-true}" = "true" ] && VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-diagrams.txt")"
VISUAL_HINTS="${VISUAL_HINTS}$(cat "${PROMPTS}/hint-callouts.txt")"

python3 -c "
import sys, json
t = open(sys.argv[1]).read().rstrip('\n')
reason = t.replace('{{VISUAL_HINTS}}', sys.argv[2]).replace('{{MENU}}', sys.argv[3])
hook = {'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': {'behavior': 'deny', 'message': reason}}}
print(json.dumps(hook))
" "${PROMPTS}/reason.txt" "$VISUAL_HINTS" "$MENU"
exit 0
