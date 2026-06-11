#!/bin/bash
# scratchtml post-upload — PostToolUse hook on mcp__scratchtml__upload_plan.
#
#   1. Marks that a plan was uploaded this session (.uploaded) — this is the bit
#      the PreToolUse gate reads to let the next ExitPlanMode through.
#   2. Opens the uploaded link in the default browser on THIS machine, if
#      auto_open is on (no effect in remote-controlled sessions — use the link).
#   3. If ui_mockups is on, sniffs the uploaded content for ASCII-art box drawing
#      with no real HTML and nudges Claude to re-author the mockup as HTML.
#
# $1 = auto_open (true/false)
# $2 = ui_mockups (true/false)
# $3 = approve_mode (ask/auto) — selects the post-upload menu text
#
# Always emits the post-upload guidance (relay link + Iterate/Implement menu) as
# additionalContext, so the menu fires even when the plan is uploaded BEFORE any
# ExitPlanMode attempt (the common path) — where plan-review.sh's deny+reason
# never runs. Prompt text lives in ../prompts/ — edit there, not here.

PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

if [ -n "$SESSION_ID" ]; then
  STATE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers"
  mkdir -p "$STATE_DIR"
  touch "$STATE_DIR/$SESSION_ID.uploaded"
fi

# Open in the local browser.
URL="$(printf '%s' "$PAYLOAD" | grep -oE 'https://usercontent\.scratchtml\.link/[a-z0-9]{16}' | head -n1)"
if [ "${1:-true}" = "true" ] && [ -n "$URL" ]; then
  if command -v open >/dev/null 2>&1; then
    open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1
  fi
fi

# Post-upload guidance (always) + optional ASCII-mockup nudge (prepended), as a
# single PostToolUse additionalContext object.
PROMPTS="${CLAUDE_PLUGIN_ROOT}/prompts"
if [ "${3:-ask}" = "auto" ]; then
  MENU_FILE="${PROMPTS}/menu-auto.txt"
else
  MENU_FILE="${PROMPTS}/menu-ask.txt"
fi

printf '%s' "$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    content = (d.get('tool_input') or {}).get('content', '') or ''
except Exception:
    content = ''

post_upload_path, menu_path, ui_mockups = sys.argv[1], sys.argv[2], sys.argv[3] == 'true'

menu = open(menu_path).read().rstrip('\n')
msg = open(post_upload_path).read().rstrip('\n').replace('{{MENU}}', menu)

# ASCII-mockup nudge (advisory; conservative, to avoid false positives).
if ui_mockups:
    box = set('│┃├┣└┗┌┏┐┓┘┛┤┫┬┳┴┻┼╋─━')
    has_box = sum(ch in box for ch in content) >= 4
    lc = content.lower()
    has_html = ('<div' in lc) or ('<svg' in lc)
    if has_box and not has_html:
        nudge = ('NOTE: the plan you just uploaded renders its UI as ASCII-art boxes. '
                 'scratchtml renders real HTML — re-author those mockups as inline '
                 'HTML/CSS (a self-contained <div> with inline styles, NOT inside a '
                 'code fence) and re-upload the revision first.')
        msg = nudge + '\n\n' + msg

out = {'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': msg}}
print(json.dumps(out))
" "${PROMPTS}/post-upload.txt" "$MENU_FILE" "${2:-true}"

exit 0
