#!/bin/sh
# Put on GitHub the workspaces and repositories that init-workspace and
# init-repo set up, from their .project-init.yml:
# - creates the GitHub repository when missing (a workspace is always
#   private), and pushes the local branch;
# - for a repository: squash merge only, branch deleted after merge, squash
#   title = pull request title; a "Protect main" ruleset (no deletion, no
#   force push, linear history, pull request required, the register's CI
#   checks required); push protection when public.
# Run it with your own gh login, in a normal terminal: a Claude Code
# session's token cannot change repository settings. Safe to run again.
#
# Usage: setup-github.sh [--dry-run] <dir>...
#
# --dry-run prints what it would do and changes nothing.
set -eu

# Print gh's output directly: an interactive pager would stop the script.
export GH_PAGER=cat PAGER=cat

here=$(cd "$(dirname "$0")" && pwd)
RULESET_NAME="Protect main"
ACTIONS_APP_ID=15368 # GitHub Actions, the app that reports the CI checks

dry=false
if [ "${1-}" = --dry-run ]; then dry=true; shift; fi
if [ $# -eq 0 ]; then
  echo "usage: $0 [--dry-run] <dir>..." >&2
  exit 2
fi

# Run a command, or only print it with --dry-run.
run() {
  if [ "$dry" = true ]; then
    printf '  would run:'
    for arg; do
      case $arg in
        '' | *[[:space:]\"]*) printf " '%s'" "$arg" ;;
        *) printf ' %s' "$arg" ;;
      esac
    done
    printf '\n'
  else
    "$@"
  fi
}

# Send a JSON body to the GitHub API: gh api <method> <path> <jq report>.
api_json() {
  if [ "$dry" = true ]; then
    printf '  would run: gh api --method %s %s with:\n' "$1" "$2"
    printf '%s' "$body" | jq . | sed 's/^/    /'
  else
    printf '%s' "$body" | gh api --method "$1" "$2" --input - --jq "$3"
  fi
}

ruleset_json() { # <checks as a JSON array>
  jq -n --arg name "$RULESET_NAME" --argjson app "$ACTIONS_APP_ID" --argjson checks "$1" '{
    name: $name,
    target: "branch",
    enforcement: "active",
    bypass_actors: [],
    conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
    rules: ([
      {type: "deletion"},
      {type: "non_fast_forward"},
      {type: "required_linear_history"},
      {type: "pull_request", parameters: {
        required_approving_review_count: 0,
        dismiss_stale_reviews_on_push: false,
        require_code_owner_review: false,
        require_last_push_approval: false,
        required_review_thread_resolution: false,
        allowed_merge_methods: ["squash"]
      }}
    ] + (if ($checks | length) > 0 then [{type: "required_status_checks", parameters: {
        strict_required_status_checks_policy: false,
        do_not_enforce_on_create: false,
        required_status_checks: [$checks[] | {context: ., integration_id: $app}]
      }}] else [] end))
  }'
}

# The functions below run in an "|| status=1" context, where set -e does not
# apply: each step that can fail returns explicitly.

# owner/repo of a GitHub remote URL (https or ssh), lowercase; empty for
# another host.
github_repo_of() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -nE \
    's#^(https://([^/@]*@)?github\.com/|ssh://git@github\.com/|git@github\.com:)([^/]+/[^/]+)/?$#\3#p' |
    sed 's#\.git$##'
}

# Create the GitHub repository if missing, then push the current branch.
# An origin that already points to it, over https or ssh, is kept.
create_and_push() { # <dir> <owner/repo> <public|private> <description> <remote>
  if gh repo view "$2" --json name >/dev/null 2>&1; then
    echo "  $2 exists"
  else
    if [ -n "$4" ]; then
      run gh repo create "$2" "--$3" --description "$4" || return 1
    else
      run gh repo create "$2" "--$3" || return 1
    fi
  fi
  want=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
  if origin=$(git -C "$1" remote get-url origin 2>/dev/null); then
    if [ "$(github_repo_of "$origin")" != "$want" ]; then
      echo "  origin is $origin, not $2: point it to $2, or fix host.repo in .project-init.yml" >&2
      return 1
    fi
  else
    url=$5
    [ "$(github_repo_of "$url")" = "$want" ] || url=https://github.com/$2.git
    run git -C "$1" remote add origin "$url" || return 1
  fi
  if git -C "$1" rev-parse --verify --quiet HEAD >/dev/null; then
    run git -C "$1" push --quiet --set-upstream origin HEAD
  else
    echo "  nothing to push: no commit yet (run commit.sh first)" >&2
    return 1
  fi
}

setup_repo() { # <dir> <register as JSON>
  repo=$(printf '%s' "$2" | jq -r .host.repo)
  visibility=$(printf '%s' "$2" | jq -r .choices.visibility)
  create_and_push "$1" "$repo" "$visibility" "$(printf '%s' "$2" | jq -r '.description // ""')" \
    "$(printf '%s' "$2" | jq -r '.host.remote // ""')" || return 1

  case $(printf '%s' "$2" | jq -r '.host."squash-body" // "commit-messages"') in
    blank) squash_body=BLANK ;;
    *) squash_body=COMMIT_MESSAGES ;;
  esac
  run gh api --method PATCH "repos/$repo" \
    -F allow_squash_merge=true -F allow_merge_commit=false \
    -F allow_rebase_merge=false -F delete_branch_on_merge=true \
    -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message="$squash_body" \
    --jq '"  merge settings: squash only, branch deleted after merge, squash title = PR title, body = \(.squash_merge_commit_message)"' || return 1

  body=$(ruleset_json "$(printf '%s' "$2" | jq -c '.host."required-checks" // []')")
  # Reading the rulesets is refused too without GitHub Pro on a private
  # repository. A dry run reads them when it can: the repository may not
  # exist yet.
  if existing=$(gh api "repos/$repo/rulesets" \
    --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null); then
    if [ -n "$existing" ]; then
      api_json PUT "repos/$repo/rulesets/$existing" '"  ruleset updated: \(.name) (id \(.id))"' || ruleset_failed "$visibility"
    else
      api_json POST "repos/$repo/rulesets" '"  ruleset created: \(.name) (id \(.id))"' || ruleset_failed "$visibility"
    fi
  elif [ "$dry" = true ]; then
    api_json POST "repos/$repo/rulesets" ''
  else
    ruleset_failed "$visibility"
  fi

  if [ "$visibility" = public ]; then
    body='{"security_and_analysis": {"secret_scanning": {"status": "enabled"}, "secret_scanning_push_protection": {"status": "enabled"}}}'
    api_json PATCH "repos/$repo" '"  push protection: \(.security_and_analysis.secret_scanning_push_protection.status)"' || return 1
    if [ "$(printf '%s' "$2" | jq -r .choices.coderabbit)" = true ]; then
      echo "  CodeRabbit: give its GitHub app access to $repo (https://github.com/apps/coderabbitai)"
    fi
  fi
}

ruleset_failed() {
  if [ "$1" = private ]; then
    echo "  ruleset not applied: a private repository needs GitHub Pro (or Team) for rulesets" >&2
  else
    echo "  ruleset not applied (see the error above)" >&2
  fi
  status=1
}

status=0
for dir; do
  echo "== $dir"
  if [ ! -f "$dir/.project-init.yml" ]; then
    echo "  no .project-init.yml: set it up with init-workspace or init-repo first" >&2
    status=1
    continue
  fi
  register=$(uv run --quiet --script "$here/register.py" "$dir/.project-init.yml")
  if [ "$(printf '%s' "$register" | jq -r .host.kind)" != github ]; then
    echo "  not hosted on GitHub (host: $(printf '%s' "$register" | jq -r .host.kind)): skipped"
    continue
  fi
  case $(printf '%s' "$register" | jq -r .kind) in
    workspace)
      # Private, direct commits on main: no merge settings, no ruleset.
      create_and_push "$dir" "$(printf '%s' "$register" | jq -r .host.repo)" private "" \
        "$(printf '%s' "$register" | jq -r '.host.remote // ""')" || status=1
      ;;
    repo) setup_repo "$dir" "$register" || status=1 ;;
  esac
done
exit $status
