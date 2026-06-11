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

# ASCII-mockup nudge (advisory; conservative, to avoid false positives).
if [ "${2:-true}" = "true" ]; then
  printf '%s' "$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    content = (d.get('tool_input') or {}).get('content', '') or ''
except Exception:
    content = ''
box = set('│┃├┣└┗┌┏┐┓┘┛┤┫┬┳┴┻┼╋─━')
has_box = sum(ch in box for ch in content) >= 4
lc = content.lower()
has_html = ('<div' in lc) or ('<svg' in lc)
if has_box and not has_html:
    msg = ('The plan you just uploaded renders its UI as ASCII-art boxes. '
           'scratchtml renders real HTML — re-author those mockups as inline '
           'HTML/CSS (a self-contained <div> with inline styles, NOT inside a '
           'code fence) and re-upload the revision before relaying the link.')
    out = {'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': msg}}
    print(json.dumps(out))
"
fi
exit 0
