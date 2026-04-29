#!/usr/bin/env bash
# Installs the /zendesk Claude Code skill.
#
# Symlinks skill.md into ~/.claude/skills/zendesk/ so /zendesk is available
# in every Claude Code session. Leaves zd, queries.md, and .env in this repo —
# the skill finds them at runtime.
#
# Re-run safely: this script is idempotent.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/zendesk"

echo "→ installing /zendesk skill from $REPO_DIR"

mkdir -p "$SKILL_DIR"
ln -sfn "$REPO_DIR/skill.md" "$SKILL_DIR/skill.md"
chmod +x "$REPO_DIR/zd"

if [[ ! -f "$REPO_DIR/.env" ]]; then
  cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
  echo "→ created .env from template — fill in your token before running /zendesk"
else
  echo "→ .env already exists, leaving it alone"
fi

cat <<EOF

Done. Next steps:

1. Edit $REPO_DIR/.env and fill in:
   - ZENDESK_SUBDOMAIN     (the prefix of <subdomain>.zendesk.com)
   - ZENDESK_EMAIL         (your admin email)
   - ZENDESK_API_TOKEN     (Admin Center → Apps & integrations → Zendesk API → Token access)
   - ZENDESK_TEAM_TAG      (the tag that scopes searches to your team — REQUIRED, no default)
                          discover with: ./zd get tags.json | jq -r '.tags | sort_by(-.count) | .[0:50] | .[] | "\(.count)\t\(.name)"'
                          common picks: web_app, platform_type_mac, ipad, audio

   If you don't see "Token access" in Admin Center, your account isn't admin
   or token generation isn't enabled for agents. Ask a Zendesk admin.

2. Smoke test:
   ./zd get users/me.json | jq -r .user.email

3. In any Claude Code session, run:
   /zendesk

EOF
