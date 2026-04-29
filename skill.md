---
name: zendesk
description: Query Zendesk for your team. Sub-commands via args — `/zendesk week` (weekly digest), `/zendesk day` (daily triage), `/zendesk fires` (urgent + spikes only), `/zendesk ticket <id>` (drill in), `/zendesk "<query>"` (natural-language search). No args = orient + fire check.
---

# Zendesk

Umbrella skill for any Zendesk question your team has. Backed by a `zd` REST wrapper script and a `queries.md` search catalog (located via `ZENDESK_DIR` in `.env` or by convention in the same directory as `.env`).

Output renders in chat unless the user asks to write to a file.

## Step 1: Verify auth (always)

Find the zendesk tooling directory. By convention it lives at `<repo-root>/zendesk/` next to a `.env` file. If unclear, ask the user where their `zd` script and `.env` are.

```bash
cd <ZENDESK_DIR>
./zd get users/me.json | jq -r '.user.email'
```

### If `zd` doesn't exist

The user only has the skill, not the supporting tooling. Tell them:

> This skill needs a companion `zd` bash wrapper plus a `.env`. Ask whoever shared the skill for the full `zendesk/` directory (it has `zd`, `.env.example`, `queries.md`, `README.md`). Drop it somewhere in your repo, then come back and run `/zendesk` again.

Stop. Don't continue.

### If `.env` is missing or auth fails

Walk the user through setup:

1. **Get a Zendesk API token.**
   - In Zendesk: Admin Center → Apps and integrations → Zendesk API → Token access → Add API token. Label it `claude-code-<your-name>`.
   - **If you don't see that option:** API token generation is admin-gated. Either (a) ask a Zendesk admin to enable token access for your account, or (b) ask them to grant you admin/agent role with token-generation permission. Do **not** share someone else's token — tokens inherit the owner's identity, so audit logs and revocation get tangled.
2. `cp .env.example .env` and fill in `ZENDESK_SUBDOMAIN`, `ZENDESK_EMAIL`, `ZENDESK_API_TOKEN`, and `ZENDESK_TEAM_TAG` (the tag that scopes to your team — default `web_app`; ask your team if unsure).
3. Re-run.

Stop. Don't continue until auth succeeds.

## Step 2: Read configuration from `.env`

```bash
SUBDOMAIN=$(grep ^ZENDESK_SUBDOMAIN .env | cut -d= -f2)
TEAM_TAG=$(grep ^ZENDESK_TEAM_TAG .env | cut -d= -f2)
TEAM_TAG=${TEAM_TAG:-web_app}   # default if unset
```

- Use `https://${SUBDOMAIN}.zendesk.com/agent/tickets/<id>` for ticket links — agent view, not end-user view.
- Use `tags:${TEAM_TAG}` in every search filter except drill-down (§D).

## Step 3: Branch on args

Parse the first argument:

| Arg pattern | Action | Section |
|---|---|---|
| `week`, `7` | Weekly digest | §A |
| `day`, `1`, `daily`, `today` | Daily triage | §B |
| `fires`, `urgent`, `hot` | Fires only | §C |
| `ticket <N>`, or just a number ≥ 5 digits | Drill into one ticket | §D |
| Anything in quotes / free text | Natural-language search | §E |
| Empty / `help` / `?` | Orient (menu + fire check) | §F |

If ambiguous, ask. Don't guess between digest and search.

---

## §A — Weekly digest (`/zendesk week`)

Produce a Voice-of-Customer summary the team would actually read.

1. Pull window: `./zd search "type:ticket tags:${TEAM_TAG} created>7days" > /tmp/zd-window.json`
   - If `length == 1000`: warn — search cap hit, window truncated. Suggest a shorter window or stricter filter.
2. Pull baseline: `./zd search "type:ticket tags:${TEAM_TAG} created>28days created<7days" > /tmp/zd-baseline.json`
3. **Cluster by surface, not by tag.** Group tickets by what users are actually reporting (e.g. "sync stuck", "subscription not carrying", "load failure"). Use judgment.
4. For each theme: count, baseline (÷3 to normalize), delta, 2-3 example tickets as agent-view markdown links, one-line characterization.
5. Output:

   ```
   # Zendesk digest — last 7 days (YYYY-MM-DD → YYYY-MM-DD)

   ## 🔥 Worth attention
   - Anything `priority:high` and still open
   - Themes ≥3× baseline
   - Themes new this week

   ## Top themes
   1. **Theme** — N tickets (vs M/wk baseline, ±X%)
      <one line>. Examples: [#123](url), [#124](url)

   ## Volume
   - N created, M solved, K open
   - Priority split: ...

   ## Drill in
   <2-3 follow-ups worth chasing>
   ```

Keep it tight. No raw JSON. If nothing's on fire, say so plainly.

---

## §B — Daily triage (`/zendesk day`)

Same shape as §A but:
- Window = last 24h, baseline = last 7 days ÷ 7.
- Top themes section is shorter (top 3 only).
- Lead with `priority:high` and `priority:urgent` open tickets if any.

---

## §C — Fires only (`/zendesk fires`)

Skip the routine themes. Output:
- All open `priority:high` or `priority:urgent` tickets tagged `${TEAM_TAG}` (link each)
- Any tag whose 24h count is ≥3× its 7-day-÷7 baseline
- New tags appearing this week that didn't exist in the prior 3 weeks

If nothing qualifies: `Nothing on fire.` and stop. One line is the right answer when it's the right answer.

---

## §D — Drill into one ticket (`/zendesk ticket 709317` or `/zendesk 709317`)

```bash
./zd ticket <id> | jq '.ticket | {id, subject, status, priority, tags, created_at, requester_id, description}'
./zd get "tickets/<id>/comments.json" | jq '.comments[] | {author_id, public, created_at, body: (.body[0:500])}'
```

Output:
- Ticket header (subject, status, priority, tags, created)
- Agent-view link
- Comment timeline summarized (who said what, when, public vs internal)
- One-paragraph "what's actually going on here"

Note: drill-down does **not** apply the team tag filter — the user might be asking about any ticket by ID.

---

## §E — Natural-language search (`/zendesk "tab refresh"`)

For free-text queries:

1. Search recent broad window for keyword:
   ```bash
   ./zd search "type:ticket tags:${TEAM_TAG} \"<query>\" created>30days"
   ```
2. If <5 results, widen window to 90 days. If still <5, drop the team tag filter and tell the user you broadened scope.
3. Cluster results, summarize, link 3-5 examples.
4. Tell the user how many tickets matched and over what window — important for "is this a thing or a one-off?"

---

## §F — Orient (`/zendesk` with no args)

Output a short menu + run §C (fires) inline:

```
Zendesk — what can I do?

- /zendesk week           weekly digest
- /zendesk day            daily triage
- /zendesk fires          urgent + spikes only
- /zendesk ticket <id>    drill into one
- /zendesk "<query>"      search by keyword

Quick fire check:
<§C output>
```

---

## Background context

- `${TEAM_TAG}` scopes most queries to one team's surface. Default `web_app`. Configure in `.env`.
- Search API caps at 1000 results / 10 pages of 100. For larger pulls use `/api/v2/incremental/tickets`.
- Subjects are heavily templated by support macros — cluster by tag + judgment, not subject string match.
- See `queries.md` next to the `zd` script for additional search recipes.
