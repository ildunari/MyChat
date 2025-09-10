This workspace uses a live planning protocol for all Codex agents.

Live Plan & Updates (Always-On)
- Start With a Plan: Before any tool calls or edits, post a short plan (5–8 bullets) in chat and mark one step as in_progress. Maintain it with `update_plan`.
- Maintain a TODO: Keep a concrete TODO list with statuses (pending/in_progress/completed) and update it as you work.
- Progress Pings: For long operations (builds, tests, multi-file patches), post brief progress updates (1–2 sentences) so the user can track activity.
- Summaries: After changes, provide what changed, where (paths), artifacts (logs/screenshots), and next steps.
- Ask vs Act: Ask only when a decision would materially change behavior, dependencies, or migration direction; otherwise act and report.
- Exceptions: For trivial actions, you may combine plan + result, but still state the mini‑plan first.

Note: These rules supplement the root AGENTS.md. When in doubt, the stricter planning/reporting rule applies.

