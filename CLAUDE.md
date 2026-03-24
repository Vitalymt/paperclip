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

## What You (the AI agent) Must Do Before Starting Work

`main` is kept in sync with upstream externally — you don't need to do that.

Your job at the start of every task:

```sh
git fetch origin
git rebase origin/main
```

Then work on the current feature branch. Push when done:

```sh
git push origin <branch> --force-with-lease
```

Never use bare `--force`.

## Rules

1. **Never commit to `main`.**
2. All work goes on `claude/*` or `feature/*` branches.
3. Rebase on `main` before starting — don't merge.
4. Resolve rebase conflicts by preferring upstream for shared files;
   keep our changes for files listed below.

## Our Custom Files (keep through rebases, never delete)

- `CLAUDE.md` — this file
- `scripts/yc-vm-setup.sh` — Yandex Cloud VM deployment
- `scripts/yc-tunnel.sh` — SSH tunnel helper
- `scripts/sync-upstream.sh` — upstream sync (run by the operator, not by you)

---

For dev rules, architecture, and verification checklist see `AGENTS.md`.
