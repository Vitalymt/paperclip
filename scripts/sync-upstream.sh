#!/usr/bin/env bash
set -euo pipefail

# Sync main branch from upstream (paperclipai/paperclip) and optionally
# rebase the current feature branch on top of the updated main.
#
# Usage:
#   ./scripts/sync-upstream.sh [options]
#
# Options:
#   --rebase    Rebase current branch after syncing main (skip prompt)
#   --no-rebase Skip rebase step entirely (skip prompt)
#   --yes       Answer yes to all prompts
#
# Upstream: https://github.com/paperclipai/paperclip

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_URL="https://github.com/paperclipai/paperclip.git"

# ── Options ───────────────────────────────────────────────────────────────────
DO_REBASE=""   # empty = ask, "yes" = do it, "no" = skip
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebase)    DO_REBASE="yes"; shift ;;
    --no-rebase) DO_REBASE="no";  shift ;;
    --yes)       AUTO_YES=true;   shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
red()    { echo -e "\033[31m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }
step()   { echo; bold "▶ $*"; }

cd "$PROJECT_ROOT"

echo
bold "╔══════════════════════════════════════╗"
bold "║     Sync main ← upstream             ║"
bold "╚══════════════════════════════════════╝"

# ── 1. Ensure upstream remote ────────────────────────────────────────────────
step "Checking upstream remote"

if git remote get-url upstream &>/dev/null; then
  CURRENT_UPSTREAM="$(git remote get-url upstream)"
  if [[ "$CURRENT_UPSTREAM" != "$UPSTREAM_URL" ]]; then
    yellow "upstream URL mismatch — updating"
    git remote set-url upstream "$UPSTREAM_URL"
  fi
  green "upstream → $UPSTREAM_URL"
else
  git remote add upstream "$UPSTREAM_URL"
  green "Added upstream → $UPSTREAM_URL"
fi

# ── 2. Stash dirty working tree ───────────────────────────────────────────────
ORIGINAL_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD")"
STASHED=false

if ! git diff --quiet || ! git diff --cached --quiet; then
  step "Stashing uncommitted changes"
  git stash push -m "sync-upstream auto-stash $(date -u +%Y%m%dT%H%M%SZ)"
  STASHED=true
  green "Stashed (will restore at end)"
fi

# ── 3. Fetch upstream ─────────────────────────────────────────────────────────
step "Fetching upstream"
git fetch upstream
green "Fetched upstream"

UPSTREAM_HEAD="$(git rev-parse upstream/main)"
LOCAL_MAIN="$(git rev-parse main 2>/dev/null || echo "")"

if [[ "$LOCAL_MAIN" == "$UPSTREAM_HEAD" ]]; then
  yellow "main is already up to date with upstream/main"
else
  # ── 4. Fast-forward main ───────────────────────────────────────────────────
  step "Updating main"

  # Temporarily switch to main if we're on it
  if [[ "$ORIGINAL_BRANCH" == "main" ]]; then
    red "You are on main. The fork strategy requires you to never commit to main."
    red "Switch to a feature branch first: git checkout -b feature/my-work"
    exit 1
  fi

  git checkout main
  if git merge upstream/main --ff-only; then
    NEW_HEAD="$(git rev-parse --short main)"
    green "main updated to $NEW_HEAD"
  else
    red "Fast-forward failed — main has diverged from upstream."
    red "This should not happen. Reset with:"
    red "  git checkout main && git reset --hard upstream/main && git push origin main --force-with-lease"
    git checkout "$ORIGINAL_BRANCH"
    exit 1
  fi

  # ── 5. Push origin main ───────────────────────────────────────────────────
  step "Pushing origin/main"
  git push origin main
  green "origin/main updated"

  git checkout "$ORIGINAL_BRANCH"
fi

# ── 6. Rebase feature branch ─────────────────────────────────────────────────
if [[ "$ORIGINAL_BRANCH" == "main" ]]; then
  yellow "Nothing to rebase — you were on main."
elif [[ "$DO_REBASE" == "no" ]]; then
  yellow "Skipping rebase (--no-rebase)"
else
  step "Rebase $ORIGINAL_BRANCH on main"

  if [[ "$DO_REBASE" != "yes" && "$AUTO_YES" != "true" ]]; then
    echo -n "  Rebase '$ORIGINAL_BRANCH' on updated main? [Y/n] "
    read -r ANSWER
    [[ -z "$ANSWER" || "$ANSWER" =~ ^[Yy]$ ]] && DO_REBASE="yes" || DO_REBASE="no"
  fi

  if [[ "$DO_REBASE" == "yes" ]]; then
    if git rebase main; then
      green "Rebase complete"
      echo
      bold "  Push with:"
      echo "    git push origin $ORIGINAL_BRANCH --force-with-lease"
    else
      red "Rebase hit conflicts — resolve them, then:"
      red "  git rebase --continue"
      red "After resolving:"
      red "  git push origin $ORIGINAL_BRANCH --force-with-lease"
      # Restore stash before exiting so the user doesn't lose work
      if [[ "$STASHED" == "true" ]]; then
        yellow "Restoring stash before exit"
        git stash pop || yellow "Could not auto-pop stash — run: git stash pop"
      fi
      exit 1
    fi
  else
    yellow "Skipped rebase. Run manually when ready:"
    yellow "  git rebase main"
  fi
fi

# ── 7. Restore stash ─────────────────────────────────────────────────────────
if [[ "$STASHED" == "true" ]]; then
  step "Restoring stash"
  git stash pop
  green "Stash restored"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
bold "Done. main is in sync with upstream."
echo
