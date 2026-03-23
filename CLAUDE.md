# CLAUDE.md

Working conventions for this repository. Keep this file up to date as the project evolves — Claude reads it at the start of every session, so stale information here leads to stale behavior.

## Branch model

- **`staging`** — default branch, integration target. All PRs go here.
- **`main`** — production. Promoted from `staging` only, never committed to directly.
- **Feature branches** — `feat/`, `fix/`, `docs/`, `chore/` prefixes. Always branch from `staging`.

Promote staging to production:
```bash
git push origin staging:main   # fast-forward only — will fail if diverged
```

Never create merge commits. Always rebase feature branches onto `staging` before opening a PR.

## CI/CD

- `ci.yml` — triggers on push/PR to `staging`. Runs shellcheck then builds the root image. Artifacts retained 30 days.
- `deploy.yml` — triggers on push to `main`. Downloads the last successful CI artifact from `staging` and flashes the server via the self-hosted runner (`harbor-srv`).

No deploy ever rebuilds the image — it always uses the artifact already produced by CI on `staging`.

## Runner / sudo

The GitHub Actions runner (`harbor-srv`) must never have root or sudo access directly. Privileged operations (e.g. `harbor-deploy`) are invoked via `sudo` to specific whitelisted scripts only — never `sudo bash` or unrestricted sudo.

## Commits

Follow [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `chore:`, etc.

## Never do

- Merge PRs or push to `main` without explicit user approval.
- Amend commits that have already been pushed.
- Use `--force` push on any branch.
- Grant the runner broad sudo or root access.
