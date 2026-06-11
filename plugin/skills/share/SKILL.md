---
name: share
description: Upload a markdown file, pasted content, or the current plan to scratchtml — returns a 24h shareable link with inline commenting. Use when the user wants to share, upload, or publish a plan or document to scratchtml.
---

# Share a document on scratchtml

Upload content to scratchtml and hand back a short-lived (24h), commentable link.

## Steps

1. Resolve what to share from `$ARGUMENTS`:
   - A file path → Read the file.
   - Pasted/quoted content → use it directly.
   - Nothing → ask what to share; if a plan file exists for this session, offer it as the default.
2. Call `mcp__scratchtml__upload_plan` with the full markdown as `content` and a descriptive `filename` ending in `.md` (e.g. `plan.md`, `design-notes.md`). Markdown is rendered to styled HTML automatically; only use an `.html` filename for prebuilt HTML documents.
   - **Publishing an updated version** of something already shared (this session or a slug/URL the user gives)? Pass `revises` with that slug/URL — the link stays the same, existing comments carry forward, and viewers can diff against the previous version.
3. Relay the returned link to the user **verbatim as a clickable URL**, with the expiry time. For a revision, note that the link is unchanged and it's now `vN`.
4. Mention that inline comments left on the page can be retrieved later with `/scratchtml:get <slug-or-url>`.

## Failure handling

If the call fails unauthenticated (401 / auth error), tell the user to run `/mcp` and sign in to scratchtml, then retry the upload.
