#!/bin/bash
# scratchtml plan review — PreToolUse hook on ExitPlanMode.
#
# Denies the FIRST ExitPlanMode attempt per session with instructions to
# upload the plan to scratchtml for inline review; the retry (after the
# review loop, or if the user opts out) passes through.
#
# $1 = plan_review userConfig (true/false)
# $2 = approve_mode userConfig (ask/auto) — shapes the post-upload menu text
#
# No jq dependency: session_id parsed with sed, JSON emitted with printf.
# The deny-reason text must contain no double quotes or backslashes.

[ "${1:-true}" = "true" ] || exit 0

PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$SESSION_ID" ] || exit 0

STATE_DIR="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers"
mkdir -p "$STATE_DIR"
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null

MARKER="$STATE_DIR/$SESSION_ID"
if [ -f "$MARKER" ]; then
  # Already went through the review loop this session — allow ExitPlanMode.
  exit 0
fi
touch "$MARKER"

if [ "${2:-ask}" = "auto" ]; then
  MENU="present an AskUserQuestion with exactly two options: [Approve and go (auto mode)] - on selection call ExitPlanMode again, it will be approved automatically - and [Get my comments from scratchtml]"
else
  MENU="present an AskUserQuestion with exactly two options: [Get my comments from scratchtml] and [Proceed to approval] - on selection call ExitPlanMode again"
fi

REASON="scratchtml plan review is enabled (scratchtml plugin; toggle via /plugin). Before exiting plan mode: (1) upload the finished plan with mcp__scratchtml__upload_plan - full plan markdown, filename plan.md, or plan-revN.md for revisions; (2) relay the returned link to the user as a clickable URL; (3) $MENU; (4) if the user wants their comments: call mcp__scratchtml__get_feedback with the slug, incorporate the comments, re-upload the revision with a top section titled Changes from review that maps each comment to its resolution, and repeat from step 2; (5) when the user is ready, call ExitPlanMode again - it will be allowed this time. If the user says to skip the review, call ExitPlanMode again directly. If a scratchtml tool call fails unauthenticated, tell the user to run /mcp to sign in to scratchtml, then retry."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$REASON"
exit 0
