# scratchtml for Claude Code

A Claude Code plugin for [scratchtml.link](https://scratchtml.link) — review, share and discuss Claude Code plans on ephemeral (24h), sandboxed, commentable links.

## What it does

When Claude finishes a plan in plan mode, this plugin routes it through a review loop instead of letting it go straight to approval:

```
plan finished ──▶ uploaded to scratchtml ──▶ link opens in your browser
                                                   │
                you leave inline comments ◀────────┘
                          │
        "Get my comments" ▼
   Claude pulls feedback ──▶ revises ──▶ re-uploads rev with a
                                         "Changes from review" table
                          │
                          ▼
              approval (built-in dialog, or automatic — see approve_mode)
```

Plus three commands, usable anytime:

| Command | What it does |
|---|---|
| `/scratchtml:share [path]` | Upload any markdown/document → shareable, commentable 24h link |
| `/scratchtml:get [slug-or-url]` | Pull inline comments, each paired with the text it refers to |
| `/scratchtml:list` | List your uploaded plans (links + expiry) |

## Install

```
/plugin marketplace add znat/scratchtml-claude-plugin
/plugin install scratchtml@scratchtml
/mcp          ← then authenticate "scratchtml" (browser sign-in)
```

Do the `/mcp` sign-in right away — it's what lets the first upload succeed.

## Configuration

All options are prompted at install and editable later via `/plugin`:

| Option | Default | Effect |
|---|---|---|
| `plan_review` | `true` | Intercept plan exit and run the review loop (once per session) |
| `auto_open` | `true` | Open uploaded plans in your browser automatically |
| `approve_mode` | `ask` | `ask`: built-in approval dialog after review. `auto`: reviewed plans are **approved automatically in auto mode** |
| `ui_mockups` | `true` | Encourage Claude to embed inline HTML/CSS mockups for UI sections of plans |
| `diagrams` | `true` | Encourage Claude to use mermaid fences for flows and architecture diagrams |

## Opting out

- **Per moment**: tell Claude "skip the scratchtml review" — the retry goes straight through. The review also only triggers once per session.
- **Per behavior**: flip the options above via `/plugin`.
- **Entirely**: `claude plugin disable scratchtml@scratchtml`.

## Tips

- **Pull comments from the plan dialog**: Claude Code's built-in approval menu can't be customized — if you're looking at it and want your scratchtml comments instead, reject the plan and type *"get my comments from scratchtml"* as the message.
- Signal you're done by returning to Claude and saying so — comments left on the page are fetched on demand, not pushed.

## Limitations

- Hooks are bash scripts — on Windows you need Git Bash.
- `auto_open` runs on the machine hosting the session: in remote sessions the browser opens on the host, not your remote device — use the link Claude posts in chat.
- The review loop fires once per session; a second plan in the same session skips straight to approval.
