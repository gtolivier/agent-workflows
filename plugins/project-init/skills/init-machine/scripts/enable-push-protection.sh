#!/bin/sh
# Turn on GitHub secret scanning and push protection on the repositories
# given. Run it with your own gh login, in a normal terminal: a Claude Code
# session's token cannot change repository settings.
#
# Usage: enable-push-protection.sh <owner/repo>...
#
# Free on public repositories. A private repository needs GitHub Secret
# Protection, sold to organizations only: it fails here, and only the local
# hooks (install.sh) protect it.
set -u

# Print gh's output directly: an interactive pager would stop the script.
export GH_PAGER=cat PAGER=cat

if [ $# -eq 0 ]; then
  echo "usage: $0 <owner/repo>..." >&2
  exit 2
fi

settings='{"security_and_analysis": {
  "secret_scanning": {"status": "enabled"},
  "secret_scanning_push_protection": {"status": "enabled"}
}}'
report='"\(.full_name) (\(.visibility)): secret scanning \(.security_and_analysis.secret_scanning.status), push protection \(.security_and_analysis.secret_scanning_push_protection.status)"'

status=0
for repo; do
  if printf '%s' "$settings" |
    gh api --method PATCH "repos/$repo" --input - --jq "$report"; then
    :
  else
    echo "$repo: not changed (see the error above)." >&2
    status=1
  fi
done
exit $status
