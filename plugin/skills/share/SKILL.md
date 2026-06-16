---
name: share
description: Upload a markdown or HTML document to scratchtml — a report, implementation plan, design document, or UI/component mockup — returns a 24h shareable link with inline commenting. Use when the user wants to share, upload, or publish a document to scratchtml.
---

# Share a document on scratchtml

Upload any document — a report, implementation plan, design document, research summary, or self-contained UI/component mockup — to scratchtml and hand back a short-lived (24h), commentable link.

## Steps

1. Resolve what to share from `$ARGUMENTS`:
   - A file path → Read the file.
   - Pasted/quoted content → use it directly.
   - Nothing → ask what to share; if a plan or document file exists for this session, offer it as the default.
2. Call `mcp__plugin_scratchtml_scratchtml__share_document` with the full markdown as `content` and a descriptive `filename` ending in `.md` (e.g. `design-doc.md`, `report.md`, `plan.md`). Markdown is rendered to styled HTML automatically; only use an `.html` filename for prebuilt HTML documents (e.g. `mockup.html`).
   - **Publishing an updated version** of something already shared (this session or a slug/URL the user gives)? Pass `revises` with that slug/URL — the link stays the same, existing comments carry forward, and viewers can diff against the previous version.
3. Relay the returned link to the user **verbatim as a clickable URL**, with the expiry time. For a revision, note that the link is unchanged and it's now `vN`.
4. Mention that inline comments left on the page can be retrieved later with `/scratchtml:get <slug-or-url>` — which also lets Claude reply to each comment thread once it's addressed.

## Failure handling

If the call fails unauthenticated (401 / auth error), tell the user to run `/mcp` and sign in to scratchtml, then retry the upload.

If the scratchtml tools aren't available at all (no such tool / the server isn't connected), the plugin's document server didn't start — Node.js ≥20 is almost certainly not installed. Tell the user to install Node ≥20 (`brew install node`, <https://nodejs.org>, or nvm) and restart Claude Code.
