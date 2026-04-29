# claude-zendesk

A Claude Code skill that turns Zendesk into a queryable surface for engineering managers and team leads. Ask "are users complaining about X?", get a weekly digest of what your team's customers are reporting, drill into specific tickets — all from your terminal, all summarized by Claude.

No deploy. Local-only. Each user brings their own Zendesk API token.

## What you get

After installing, in any Claude Code session you can run:

| Command | What it does |
|---|---|
| `/zendesk` | Menu + quick "anything on fire?" check |
| `/zendesk week` | Voice-of-Customer digest for the last 7 days, with theme clustering and baseline comparison |
| `/zendesk day` | Daily triage — top urgent tickets, top 3 themes |
| `/zendesk fires` | Just the urgent stuff: open high/urgent tickets + tag spikes |
| `/zendesk ticket 12345` | Full context on one ticket: header, comment timeline, summary |
| `/zendesk "tab refresh"` | Search recent tickets for a keyword, cluster results |

Everything ties back to ticket links pointing at your Zendesk agent view.

## Install

```bash
git clone https://github.com/Ginger-Labs/claude-zendesk.git
cd claude-zendesk
./install.sh
```

The installer symlinks `skill.md` into `~/.claude/skills/zendesk/`. Edit `.env` per the install output — you'll need a Zendesk API token.

### Getting a Zendesk API token

In Zendesk: **Admin Center → Apps and integrations → Zendesk API → Token access → Add API token**. Label it something like `claude-code-<your-name>`.

If you don't see that option, API token generation is admin-gated. Ask a Zendesk admin to either enable token access for your account or grant you the right role. **Don't share someone else's token** — tokens inherit the owner's identity, which means audit logs and revocation get tangled.

## Configuration

`.env` (gitignored) holds:

- `ZENDESK_SUBDOMAIN` — the prefix of `<subdomain>.zendesk.com`
- `ZENDESK_EMAIL` — your admin email
- `ZENDESK_API_TOKEN` — your personal token
- `ZENDESK_TEAM_TAG` — the tag that scopes searches to your team. **No default.** Common picks at Ginger Labs: `web_app`, `platform_type_mac`, `ipad`, `audio`. Find candidates in your Zendesk with:
  ```
  ./zd get tags.json | jq -r '.tags | sort_by(-.count) | .[0:50] | .[] | "\(.count)\t\(.name)"'
  ```
  If you're not sure which tag is right for your team, ask a teammate or your support lead which tag they consistently use to triage your area.

## Files

- `zd` — bash wrapper around the Zendesk REST API. Handles auth, pagination, 429 backoff. Usable standalone (`./zd search '...'`).
- `skill.md` — the Claude Code skill that drives the `/zendesk` command.
- `queries.md` — catalog of useful searches you can run directly with `zd`.
- `install.sh` — symlinks the skill into your Claude Code config.

## Rate limits to know

- Account-wide: hundreds of req/min depending on plan — fine for normal use.
- **Search API: ~100 req/min, 1000 results max per query, 10 pages of 100.**
- For backfills or bulk pulls, use `/api/v2/incremental/tickets` (separate, generous limits).
- The `zd` wrapper retries on 429 with exponential backoff up to 5 attempts.

## Adapting to a non-web team

Set `ZENDESK_TEAM_TAG` in `.env` to your team's tag (e.g. `ios_app`, `mac_app`). The skill threads it through every search filter automatically. No code changes needed.

If the tag taxonomy in your Zendesk instance is different, you may also want to update the "Useful tag families" hints in `skill.md` so Claude clusters tickets sensibly for your team's surface.

## Status

Pilot. Built quickly to learn what's actually useful before investing in a polished version. Feedback welcome — open an issue.
