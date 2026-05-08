# Example Generated Prompt

Create a separate worktree from `/path/to/repo`, then implement the following
open issues in order.

Startup steps:

- In the base repository, run `git switch main && git pull --ff-only`.
- Run `git fetch origin`.
- Run `mkdir -p /path/to/repo-worktrees`.
- Create a batch worktree only if the intended path does not already exist:
  `git worktree add --detach /path/to/repo-worktrees/example-batch origin/main`.
- Run `cd /path/to/repo-worktrees/example-batch`.
- Re-check current state with `gh issue list --state open --limit 100` and
  `gh issue view <number>` for each target issue.

Target issues:

1. #123 example first issue
2. #124 example second issue
3. #125 example third issue

Execution plan:

- #123: risk lane `local-refactor`, serial lane, independent PR, base `main`
- #124: risk lane `shared-api-schema`, stacked PR, base
  `codex/issue-123-example`, depends on #123
- #125: risk lane `docs-test-only`, serial lane in this example, independent
  PR, base `main`

Core policy:

- Prefer real code, tests, and CLI output over docs or memory.
- Use one issue, one branch, and one PR by default.
- Work inside isolated worktrees. Run separate lanes in parallel only when the
  execution plan marks them parallel-safe.
- Open ready PRs.
- After opening a PR, inspect check state once. Fix completed failures. If
  required CI is still pending, record `ci_state_observed: pending` in the PR
  readiness manifest and leave final CI gating to `pr-batch-check-merge`.
- Do not merge PRs in the implementation session.
- Do not create progress memo files just to track the run. Put durable handoff
  state in PR bodies, the PR readiness manifest, and the final report.
- Do not optimize for the smallest possible diff. Optimize for the best final
  architecture, correctness, maintainability, and testability.
- If the existing structure is misaligned with the intended architecture,
  refactor it instead of adding compatibility layers or patching around it.
- When a broader change is appropriate, first explain the target design and why
  the broader change is justified, separate mechanical refactors from behavior
  changes when possible, preserve existing behavior unless explicitly changed,
  update tests, and summarize the architectural changes in the final report.

Per-issue workflow:

1. Confirm the issue's execution mode before editing.
2. Read the issue with `gh issue view <number>`.
3. For #123 and #125, run `git fetch origin && git switch --detach origin/main`
   before creating the issue branch.
4. For #124, switch to `codex/issue-123-example` and create the dependent
   branch from that prerequisite branch.
5. Implement, test, review, commit, push, and open a ready PR.
6. For #124, open the PR against `codex/issue-123-example`, not `main`.
7. Inspect checks with `gh pr checks <number>`. Fix completed failures; leave
   pending required CI for the PR merge run unless the risk lane justifies
   waiting.
8. Do not merge. Add the PR to the final handoff block.

PR readiness manifest:

```text
- pr: #201
  issues: [123]
  mode: independent
  risk_lanes: [local-refactor]
  head_branch: codex/issue-123-example
  base_branch: main
  base_sha_at_handoff: abc123
  head_sha_at_handoff: def456
  stack_parent: none
  replay_required: false
  validation: ["npm test -- example"]
  ci_state_observed: pending
  review_state_observed: clear
  unresolved_risks: []
  human_action_required: false
  next_action: check-merge
- pr: #202
  issues: [124]
  mode: stacked
  risk_lanes: [shared-api-schema]
  head_branch: codex/issue-124-example
  base_branch: codex/issue-123-example
  base_sha_at_handoff: def456
  head_sha_at_handoff: fed321
  stack_parent: #201
  replay_required: true
  replay_plan: rebase
  replay_owner: pr-batch-check-merge
  validation: ["npm test -- schema"]
  ci_state_observed: pending
  review_state_observed: needs-review
  unresolved_risks: ["checks are provisional until replayed onto main"]
  human_action_required: false
  next_action: replay-then-check
```

PR batch check/merge handoff block:

```text
PR Batch Check Merge

Use `pr-batch-check-merge` if it is installed.
This handoff invokes the merge skill. Unless the user adds check-only, dry-run,
or do-not-merge wording, check live PR state and merge or queue only PRs that
satisfy every gate.

Repository: /path/to/repo
Default branch: main

Target PRs in dependency order:
- #201: example first issue | mode: independent | base: main
- #202: example second issue | mode: stacked | base: codex/issue-123-example |
  depends on: #201
- #203: example third issue | mode: independent | base: main

Check CI, review state, conflicts, stack order, and mergeability. Treat checks
for stacked PRs as provisional until the dependent PR is replayed onto the
latest default branch after prerequisite merges.

If a PR is not safe, leave it unmerged and report the blocker. Explicit
check-only, dry-run, or do-not-merge wording overrides merge execution.
```
