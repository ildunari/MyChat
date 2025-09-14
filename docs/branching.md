Branching Strategy (Consolidation Ready)

Summary
- Work off main but never push to main directly.
- Create short‑lived feature branches per topic; keep PRs small and focused.
- Batch risky changes behind flags and tests; rebase/merge only on green.

Naming
- `feat/<scope>-YYYY-MM-DD[-slug]`
- `fix/<scope>-YYYY-MM-DD[-slug]`
- `chore/<scope>-YYYY-MM-DD[-slug]`
- Example: `feat/liquid-glass-2025-09-14`, `fix/webcanvas-fallback-2025-09-14`.

Workflow
1) `git checkout -b feat/<scope>-<date>`
2) Implement in small commits (Conventional Commits preferred).
3) Build + run tests locally.
4) Open PR → review → squash merge.
5) Delete branch after merge.

Guard Rails
- Optional pre‑push hook (see `.githooks/pre-push`) blocks pushing to `main`.
- Bypass with `ALLOW_MAIN_PUSH=1 git push` only for emergencies.

Rollback
- Every integration batch lives on its own branch (e.g., `integration/<topic>-<date>`).
- If a batch misbehaves: `git revert <range>` or drop the branch and re‑branch from the last green.

