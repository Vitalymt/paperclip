# Fork Context

This repository is a fork of the upstream Paperclip project.

## Upstream Repository

```
https://github.com/paperclipai/paperclip
```

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Upstream mirror — **never commit here directly** |
| `claude/*` / `feature/*` | All custom work, rebased on top of `main` |

## Before Starting Any Work

Sync `main` from upstream first:

```sh
./scripts/sync-upstream.sh
```

Or manually:

```sh
git fetch upstream
git checkout main && git merge upstream/main --ff-only
git push origin main
git checkout <your-branch> && git rebase main
```

If `upstream` remote is missing:

```sh
git remote add upstream https://github.com/paperclipai/paperclip.git
```

## Push Rules

After a rebase, push with:

```sh
git push origin <branch> --force-with-lease
```

Never use bare `--force`.

## Conflict Resolution During Rebase

- Upstream wins for all shared source files.
- Keep our changes for: `scripts/yc-*.sh`, `CLAUDE.md`.

## Our Custom Files (do not delete on sync)

- `CLAUDE.md` — this file
- `scripts/yc-vm-setup.sh` — Yandex Cloud VM deployment
- `scripts/yc-tunnel.sh` — SSH tunnel helper

---

For dev rules, architecture, and verification checklist see `AGENTS.md`.
