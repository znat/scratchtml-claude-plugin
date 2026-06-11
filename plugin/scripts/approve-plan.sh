#!/bin/bash
# scratchtml auto-approve — PermissionRequest hook on ExitPlanMode.
#
# When approve_mode=auto AND this session's plan just went through the
# scratchtml review loop, auto-accept the plan-approval dialog and put the
# session in auto mode. The PreToolUse gate drops a .reviewed breadcrumb on a
# reviewed exit; we consume it here. Plans that did NOT go through review (no
# breadcrumb — e.g. a skipped review) still get the built-in dialog — safety gate.
#
# $1 = approve_mode userConfig (ask/auto)

[ "${1:-ask}" = "auto" ] || exit 0

PAYLOAD="$(cat)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$SESSION_ID" ] || exit 0

MARKER="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/scratchtml-plugin}/plan-review-markers/$SESSION_ID.reviewed"
[ -f "$MARKER" ] || exit 0
rm -f "$MARKER"

printf '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","updatedPermissions":[{"type":"setMode","mode":"auto","destination":"session"}]}}}\n'
exit 0
