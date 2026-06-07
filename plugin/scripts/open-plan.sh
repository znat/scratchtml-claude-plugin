#!/bin/bash
# scratchtml auto-open — PostToolUse hook on mcp__scratchtml__upload_plan.
# Opens the freshly-uploaded plan in the default browser on THIS machine
# (no effect visible in remote-controlled sessions — use the relayed link).
#
# $1 = auto_open userConfig (true/false)

[ "${1:-true}" = "true" ] || exit 0

# The tool result (in the stdin payload) contains the content URL.
URL="$(grep -oE 'https://usercontent\.scratchtml\.link/[a-z0-9]{16}' | head -n1)"
[ -n "$URL" ] || exit 0

if command -v open >/dev/null 2>&1; then
  open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" >/dev/null 2>&1
fi
exit 0
