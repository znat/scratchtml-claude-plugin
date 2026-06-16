#!/bin/bash
# scratchtml — SessionStart guard.
#
# The plugin's document server runs as `node ${CLAUDE_PLUGIN_ROOT}/mcp/server.mjs`.
# Without Node on PATH it silently fails to connect and every scratchtml tool
# vanishes, with only a cryptic spawn error buried in `/mcp`. This hook detects
# that up front and injects install guidance so the model can explain it the
# moment the user reaches for scratchtml.
#
# Node present → no-op (exit 0, no output). The bundle targets node20, so the
# floor is Node >= 20.

command -v node >/dev/null 2>&1 && exit 0

# Static JSON (no interpolation) — safe to emit directly, no python3/jq needed.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"The scratchtml plugin's document server requires Node.js >= 20, but `node` was not found on PATH, so its MCP tools (share/upload/get/reply/list) are unavailable this session. If the user asks to share, upload, or fetch comments on scratchtml, tell them to install Node >= 20 (`brew install node`, https://nodejs.org, or nvm) and restart Claude Code."}}
JSON
exit 0
