---
name: issue-autonomy-prompt
description: Analyze a repository's open GitHub issues, choose the most important issues to tackle next, order them by dependency and leverage, and draft a paste-ready prompt for a separate autonomous development session. Use when the user asks which issues to work on first, wants a top-N issue order, or wants a prompt for a separate autonomous coding session based on GitHub issues.
---

# Issue Autonomy Prompt

Turn a noisy open-issue backlog into a focused autonomous-development prompt.

Use this skill when the user wants:

- the next 3-10 GitHub issues to implement
- the order those issues should be tackled in
- a prompt that can be pasted into another coding session for autonomous implementation
- a nightly or long-running implementation plan based on current open issues

## Core Principle

Treat current repository evidence as authoritative.

Use this priority order:

1. actual issue state from GitHub and local repository state
2. issue bodies and acceptance criteria
3. code and tests that implement or block the requested work
4. recent git/PR history
5. docs and memory

Do not choose issues from memory alone when `gh issue list` and `gh issue view` can cheaply verify the current state.

## Workflow

### 1. Resolve Repository Context

Start from the user's requested workspace if provided. Otherwise use the current working directory.

Run:

```bash
git remote -v
git branch --show-current
gh issue list --state open --limit 100 --json number,title,labels,updatedAt,createdAt,url,assignees
```

If the repo is ambiguous or `gh` is not authenticated, report the blocker and provide the best offline prompt template only if the user can supply issue data.

### 2. Build the Candidate Set

Read issue bodies before ranking final candidates.

Use `gh issue view <number> --json number,title,body,labels,url` for:

- issues explicitly mentioned by the user
- recently created issues related to the user's goal
- likely prerequisites for those issues
- issues that appear to be duplicates, blockers, or already satisfied by recent PRs

Do not read every old issue by default. Use titles, labels, recency, and user intent to narrow the first pass.

### 3. Rank Issues

Prefer issues that unblock long-term autonomous work, observability, safe operation, and concrete user goals.

Rank by these factors, in order:

1. **Prerequisite value**: Does this issue make later issues safer or possible?
2. **Runtime safety**: Does it prevent data loss, unsafe stops, runaway loops, or irreversible actions?
3. **Observability**: Does it make future progress, health, or quality measurable?
4. **Dogfood evidence**: Was the issue seen in a real run, CI failure, or user-observed workflow?
5. **Acceptance clarity**: Can a focused vertical slice satisfy the issue without broad redesign?
6. **Dependency order**: Does another target issue explicitly depend on this one?
7. **User goal fit**: Does it match the user's current stated direction?

Usually avoid selecting:

- duplicate issues unless the duplicate is the canonical issue
- issues that are clearly blocked by unmerged work
- purely cosmetic/documentation issues when runtime/product blockers remain
- broad umbrella issues that should first be split
- issues whose acceptance criteria require external approvals the autonomous session cannot perform

### 4. Decompose Umbrella Issues

If a top candidate is an umbrella issue, split or defer it before drafting the
implementation prompt.

Prefer child issues with:

- one acceptance path per child
- one primary risk surface per child when possible
- clear production entrypoints or user-facing behavior
- an explicit parent issue reference
- closure metadata explaining how the parent will be proven complete

Do not split when splitting would hide a required migration, schema transition,
shared protocol change, or cross-cutting contract that must be reviewed and
validated as one unit. In that case, keep it bundled or blocked and explain why.

If child issues do not yet exist and the user asked only for a prompt, include a
child-issue draft section instead of silently treating the parent as
implementable.

### 5. Classify Risk Lanes

Before choosing execution mode, classify each selected issue by risk lane.

Use these lanes as a starting vocabulary:

- `docs-test-only`
- `ui`
- `local-refactor`
- `shared-api-schema`
- `persistence-migration`
- `auth-security`
- `external-io-secrets`
- `runtime-state`
- `release-deploy`

Use risk lanes to decide verification depth, review strictness, parallel
safety, and whether an issue should be independent, stacked, bundled, or
blocked. If a lane is uncertain, mark it `unknown` and serialize until the
uncertainty is resolved.

### 6. Build Execution Lanes

Classify each issue's execution relationship:

- `parallel-safe`: low-overlap issues with distinct files, contracts, state, and
  risk lanes; may run in separate worktrees or separate coding sessions.
- `serial`: issues that share files, tests, contracts, runtime state, or risky
  review surfaces.
- `stacked`: later issue needs code from an earlier unmerged PR.
- `bundled`: separate PRs would knowingly create broken intermediate states or
  duplicate one inseparable migration/schema/test-fixture change.
- `blocked`: prerequisite context or external approval is missing.

When generating prompts for parallel-safe lanes, create one isolated worktree
per lane and give each lane clear issue ownership. If the current environment
cannot run parallel sessions, preserve the lane metadata but serialize the work.
When uncertain, serialize.

### 7. Produce the Top-N Recommendation

Before drafting the long prompt, summarize the selected issues and why they are ordered that way.

Use this concise shape:

```text
1. #123 <title>
   Why first: <dependency/leverage reason>
2. #124 <title>
   Why second: <reason>
...
```

Mention strong next-tier candidates when useful, but keep the main list focused.
Include each selected issue's risk lane and execution relationship.

### 8. Draft the Autonomous Development Prompt

The prompt must be paste-ready. It should be specific enough that another session can start work without re-reading this conversation, but it must require that session to verify current repo and issue state before editing.

Include:

- base repository path
- isolated batch worktree path
- startup commands:
  - `git switch <default-branch> && git pull --ff-only`
  - `git fetch origin`
  - `mkdir -p <worktree-root>`
  - conditionally `git worktree add --detach <batch-worktree> origin/<default-branch>`
  - `cd <batch-worktree>`
  - `gh issue list --state open --limit 100`
- target issue list and recommended order
- prerequisites and dependency notes
- risk lane and parallel/serial lane for each issue
- execution mode for each issue: independent PR, stacked PR, bundled PR, or
  blocked until prerequisite PR merge
- implementation rules
- per-issue workflow
- verification commands
- review-agent requirement for substantive changes
- PR and handoff policy
- safety/approval constraints
- PR readiness manifest contract
- PR batch check/merge handoff block
- final-report format

Worktree and lane strategy:

- Generate prompts that create isolated worktrees outside the base repository,
  under a sibling or user-specified worktree root.
- If the issue set is not clearly parallel-safe, use one batch worktree and one
  active issue branch at a time.
- If the issue set has independent low-overlap lanes, the generated prompt may
  create one worktree per lane or emit separate lane prompts. Each lane must
  have clear issue ownership, branch naming, handoff scope, and conflict
  boundaries.
- Do not run issues in parallel when they share files, tests, schemas, runtime
  state, migrations, auth/security surfaces, external IO, release/deploy
  surfaces, or stack dependencies.
- If the intended worktree path already exists, the generated prompt should tell
  the session to inspect it first and either reuse it only when clean and clearly
  intended for this batch, or choose a new unique path. Do not remove an existing
  dirty worktree as a startup shortcut.
- Fresh worktrees may lack ignored setup files, local configuration, caches, or
  dependencies. The generated prompt should require per-worktree setup
  verification and must not copy secrets unless the repository's policy
  explicitly allows it.
- At the start of each issue, refresh from that issue's intended base. For
  independent PRs this is `origin/<default-branch>`; for stacked PRs this is the
  prerequisite branch recorded in the execution plan.
- When selected issues overlap with active PRs, another parallel batch, or
  user-named dependency PRs, include `gh pr list --state open --limit 50` in the
  startup checks and before each issue starts.

Risk lane usage:

- `docs-test-only`: lighter validation may be acceptable if repo policy allows.
- `ui`: include visual or interaction checks when the repository supports them.
- `local-refactor`: require focused regression tests for the touched module.
- `shared-api-schema`: require boundary or contract tests.
- `persistence-migration`: serialize; require migration, rollback, or fixture
  validation.
- `auth-security`: serialize; require security-focused review.
- `external-io-secrets`: serialize; gate external calls and secret handling.
- `runtime-state`: serialize; verify state transitions and recovery paths.
- `release-deploy`: block or require explicit release/deploy authority.

Execution modes:

- `independent PR`: start from `origin/<default-branch>`, open the PR against
  the default branch, and stop after ready PR creation and check inspection.
- `stacked PR`: use when a later issue needs code from an earlier unmerged PR.
  Branch the dependent issue from the prerequisite issue branch, open the
  dependent PR against that prerequisite branch, mark checks as provisional
  until the stack is replayed onto the default branch, and include the stack
  order in the handoff block.
- `bundled PR`: use only when separate PRs would knowingly create broken
  intermediate states, duplicate the same migration/schema/test-fixture change,
  or split one acceptance path that cannot be meaningfully separated. The PR
  body must close every bundled issue and explain why bundling was required.
- `blocked until prerequisite PR merge`: use when an issue cannot safely be
  implemented from an unmerged prerequisite branch or stacked without creating
  misleading checks, excessive conflicts, or unclear ownership.

The generated implementation prompt should never tell the implementation
session to merge PRs, close issues manually, or mutate PR base branches after
handoff unless the user explicitly asks for that in the implementation run.
Merge execution belongs in a separate PR batch check/merge run.

Stacked PR metadata must include the original base SHA, prerequisite PR or
branch, dependent branch, expected replay action (`rebase`, `retarget`, or
`cherry-pick`), and replay owner (`pr-batch-check-merge`, `human`, or
`blocked`). The implementation session must not silently retarget stacked PRs
after handoff.

Implementation PR readiness means the PR was opened with the intended base and
linked issues, the execution mode and stack/bundle metadata were recorded,
validation evidence and CI inspection were captured, independent review status
was recorded when available, unresolved risks were listed, and replay or human
judgment needs were marked. It does not mean merge-ready.

Emit a compact PR readiness manifest for the PR batch check/merge run. Use
this shape:

```text
PR readiness manifest:
- pr: <PR number or pending>
  issues: [<issue numbers>]
  mode: independent | stacked | bundled | blocked
  risk_lanes: [<risk lanes>]
  head_branch: <branch>
  base_branch: <branch>
  base_sha_at_handoff: <sha or unknown>
  head_sha_at_handoff: <sha or unknown>
  stack_parent: <PR/branch or none>
  stack_order: <position or none>
  replay_required: true | false
  replay_plan: <rebase | retarget | cherry-pick | none | unknown>
  replay_owner: pr-batch-check-merge | human | blocked | none
  validation: [<commands and results>]
  ci_state_observed: <passing | failing | pending | not-run | unknown>
  review_state_observed: <clear | findings-fixed | needs-review | unknown>
  machine_review_signals: <none | present | unknown>
  unresolved_risks: [<risks>]
  human_action_required: true | false
  next_action: <check-merge | replay-then-check | fix | wait | human-review>
```

At the end of the generated implementation prompt, include a paste-ready
handoff block for a PR batch check/merge run. If a companion skill named
`pr-batch-check-merge` is installed, tell the user or next session to use it.

## Prompt Template

Use this template and fill in repository-specific details.

````md
Create a separate worktree from `<BASE_REPO_PATH>`, then implement the
following open issues in order.

Startup steps:
- In the base repository, run
  `git switch <DEFAULT_BRANCH> && git pull --ff-only`.
- Run `git fetch origin`.
- Run `mkdir -p <WORKTREE_ROOT>`.
- Verify per-worktree setup requirements before coding. Fresh worktrees may
  miss ignored environment files, local configuration, caches, or installed
  dependencies. Do not copy secrets unless repository policy explicitly allows
  it.
- If `<BATCH_WORKTREE_PATH>` already exists, inspect it first. Reuse it only
  when it is clean and clearly intended for this batch. If it is dirty or its
  purpose is unclear, do not delete it; choose a new unique worktree path.
- Only when creating a new `<BATCH_WORKTREE_PATH>`, run
  `git worktree add --detach <BATCH_WORKTREE_PATH> origin/<DEFAULT_BRANCH>`.
- Run `cd <BATCH_WORKTREE_PATH>`.
- Re-check current state with `gh issue list --state open --limit 100` and
  `gh issue view <number>` for each target issue.
- If related open PRs or parallel batches exist, also run
  `gh pr list --state open --limit 50`.
- The target issues are currently:
  - #<N1>: <title>
  - #<N2>: <title>
  - #<N3>: <title>
  - #<N4>: <title>
  - #<N5>: <title>
- Execution plan:
  - #<N1>: risk lane <lane>; execution lane <serial | parallel-safe lane A |
    stacked | bundled | blocked>; mode <independent PR | stacked PR |
    bundled PR | blocked until prerequisite PR merge>
  - #<N2>: <risk lane, execution lane, mode, base/dependency notes>
  - #<N3>: <risk lane, execution lane, mode, base/dependency notes>
  - #<N4>: <risk lane, execution lane, mode, base/dependency notes>
  - #<N5>: <risk lane, execution lane, mode, base/dependency notes>
- Parallel lane plan:
  - <lane A>: <issues>, worktree <path>, owner/session <if applicable>
  - <lane B>: <issues>, worktree <path>, owner/session <if applicable>
  - If no lane is clearly parallel-safe, keep one serial batch worktree.
- If a target issue is already closed, skip it and include the reason in the
  final report.
- If related new open issues appear, prioritize completing this target issue
  group. Include only clear blockers, duplicates, or prerequisites in the final
  report or PR body.

Core policy:
- Prefer real code, tests, and CLI output over docs or memory.
- Use one issue, one branch, and one PR by default. Do not bundle everything
  into one large PR.
- Work serially inside a lane. Run multiple lanes in parallel only when the
  execution plan marks them parallel-safe and each lane has an isolated
  worktree. If the environment cannot run parallel sessions, serialize the
  lanes without dropping the lane metadata.
- Do not run issues in parallel when they share files, tests, schemas, runtime
  state, migrations, auth/security surfaces, external IO, release/deploy
  surfaces, or stack dependencies.
- Choose the execution mode before starting each issue:
  - independent PR
  - stacked PR
  - bundled PR
  - blocked until prerequisite PR merge
- For independent PRs, run
  `git fetch origin && git switch --detach origin/<DEFAULT_BRANCH>`, then create
  the issue branch with `git switch -c codex/issue-<number>-<short-name>`.
- For stacked PRs, branch from the prerequisite issue branch, open the dependent
  PR against that prerequisite branch, and record the stack order. Do not treat
  checks against a prerequisite branch as final default-branch readiness.
- Use bundled PRs only when separate PRs would create knowingly broken
  intermediate states, duplicate the same migration/schema/test-fixture change,
  or split one acceptance path that cannot be meaningfully separated.
- If neither independent nor stacked execution is safe, mark the issue blocked
  until the prerequisite PR merges.
- If related open PRs or parallel batches exist, run
  `gh pr list --state open --limit 50` before each issue. If a conflict is
  likely, include the conflict in the final report and reorder the issue
  sequence.
- Respect dependencies. <dependency notes>
- Implement the smallest sufficient vertical slice that satisfies each issue's
  acceptance criteria.
- If an issue is an umbrella issue, split or draft child issues before
  implementation. Prefer one acceptance path and one primary risk surface per
  child. Do not split a migration, schema transition, shared protocol, or
  cross-cutting contract if that split would hide the real review boundary.
- Do not include unrelated cleanup, broad redesign, or opportunistic fixes.
- For user intent, natural language, runtime state, safety decisions, target
  selection, and workflow semantics, do not ship short-term keyword lists,
  regular expressions, string includes, or title matching as the primary
  decision logic. Prefer typed contracts, schemas, resolvers, state machines,
  model or LLM classifiers, and production caller-path tests that can survive
  input drift.
- Use `rg` and similar searches for investigation, but do not ship decision
  logic based primarily on keyword search.
- Open ready PRs. Do not mark PRs as draft unless the user explicitly asks.
- After substantive changes, get an independent review pass if the environment
  supports it, focused only on material issues.
- Address material findings and re-run validation.
- Do not merge PRs in this implementation session.
- Do not close issues manually.
- Do not mutate PR base branches after handoff unless the user explicitly asks
  for that in this implementation session.
- Keep the worktree focused on code changes only. Do not create progress memo
  files just to track the run. Put durable handoff state in PR bodies, PR
  readiness manifest entries, review comments when needed, and the final report.

Recommended implementation order:
1. #<N1>
   - Risk lane: <risk lane>
   - Execution lane: <serial | parallel-safe lane A | stacked | bundled | blocked>
   - Execution mode: <independent PR | stacked PR | bundled PR | blocked>
   - Base/dependency: <default branch | prerequisite branch/PR | bundled issues>
   - Worktree: <path>
   - <expected implementation direction>
   - <important acceptance criteria>

2. #<N2>
   - Risk lane: <risk lane>
   - Execution lane: <serial | parallel-safe lane A | stacked | bundled | blocked>
   - Execution mode: <independent PR | stacked PR | bundled PR | blocked>
   - Base/dependency: <default branch | prerequisite branch/PR | bundled issues>
   - Worktree: <path>
   - <expected implementation direction>
   - <important acceptance criteria>

3. #<N3>
   - Risk lane: <risk lane>
   - Execution lane: <serial | parallel-safe lane A | stacked | bundled | blocked>
   - Execution mode: <independent PR | stacked PR | bundled PR | blocked>
   - Base/dependency: <default branch | prerequisite branch/PR | bundled issues>
   - Worktree: <path>
   - <expected implementation direction>
   - <important acceptance criteria>

4. #<N4>
   - Risk lane: <risk lane>
   - Execution lane: <serial | parallel-safe lane A | stacked | bundled | blocked>
   - Execution mode: <independent PR | stacked PR | bundled PR | blocked>
   - Base/dependency: <default branch | prerequisite branch/PR | bundled issues>
   - Worktree: <path>
   - <expected implementation direction>
   - <important acceptance criteria>

5. #<N5>
   - Risk lane: <risk lane>
   - Execution lane: <serial | parallel-safe lane A | stacked | bundled | blocked>
   - Execution mode: <independent PR | stacked PR | bundled PR | blocked>
   - Base/dependency: <default branch | prerequisite branch/PR | bundled issues>
   - Worktree: <path>
   - <expected implementation direction>
   - <important acceptance criteria>

Per-issue workflow:
1. Confirm the issue's risk lane, execution lane, and execution mode before
   editing.
2. Read the issue body and acceptance criteria with `gh issue view <number>`.
3. If the mode is `blocked until prerequisite PR merge`, do not implement it.
   Include the blocker, prerequisite PR, and resume condition in the final
   report, then move to the next issue.
4. If related open PRs or parallel batches exist, run
   `gh pr list --state open --limit 50`.
5. Prepare the branch:
   - For an independent PR, run
     `git fetch origin && git switch --detach origin/<DEFAULT_BRANCH>`, then
     create the branch with
     `git switch -c codex/issue-<number>-<short-name>`.
   - For a stacked PR, fetch and switch to the prerequisite issue branch, verify
     it is the intended base, then create the dependent branch from it. Open the
     dependent PR against the prerequisite branch, not the default branch.
   - For a bundled PR, create one branch for the bundled issue set and record
     every included issue before editing.
6. Verify per-worktree setup: dependencies, local config requirements, and test
   availability. Do not copy secrets unless repository policy explicitly allows
   it.
7. Trace the relevant code with `rg`. If broad exploration is needed, delegate
   it to an explorer if the environment supports that.
8. State a short implementation plan in the session before editing.
9. Implement the fix.
10. Add or update tests. Follow the repository's local instructions, and prefer
   production entrypoints and boundary-level contract tests when relevant.
11. Run the repository's standard validation commands. Include relevant focused
   tests. If present and appropriate, run commands such as:
   - `npm run typecheck`
   - `npm test -- <focused-test>`
   - `npm run lint`
   - `npm run test:changed`
12. Get an independent review pass if the environment supports it, focused only
    on material issues.
13. Address material findings and re-run validation.
14. Commit, push, and open a ready PR.
15. The PR body must include:
   - `Closes #<number>` or every `Closes #<number>` line for a bundled PR
   - implementation summary
   - risk lane and execution lane
   - validation commands
   - known unresolved risks
   - execution mode
   - base branch and stack order for stacked PRs
   - base SHA and head SHA at handoff when available
   - replay plan and replay owner for stacked PRs
   - dependency or integration status for related PRs or parallel batches
   - a note that stacked PR checks are provisional until replayed onto the
     default branch after prerequisite merges
   - a compact PR readiness manifest entry
16. Inspect CI/checks with `gh pr checks --watch` when available.
17. Do not merge. Do not close issues manually. Do not retarget PR base branches
    after handoff unless explicitly asked.
18. Before moving to the next issue, return to the base required by the next
    issue's execution mode.

Autonomous judgment:
- If CI fails, read the logs and fix the failure. If you conclude it is an
  external flaky failure, include evidence in the final report and PR comment.
- Resolve merge conflicts by fetching `origin/<DEFAULT_BRANCH>` and rebasing or
  merging the current issue branch as appropriate.
- If acceptance criteria are too broad, prefer the smallest useful vertical
  slice and create follow-up issues for the rest. Do not silently ignore
  acceptance criteria.
- If an implementation idea relies on keyword, regex, or string-includes
  classification as the primary decision mechanism, do not use it. First look
  for an existing typed API, schema, state model, model or LLM classifier, or
  domain parser. If none exists, add a durable contract.
- If only a keyword or regex workaround seems possible, stop and report that
  blocker. Do not ship the workaround.
- Do not perform external publishing, submissions, secret transmission,
  production mutation, irreversible actions, or financial actions. Treat them
  as approval-required.
- If you need to touch issues outside the target set, state the reason in the
  session before editing and include it in the final report and PR body.

Final report:
- PRs opened
- PR readiness manifest
- risk lanes and parallel lanes used
- stacked PR order, if any
- bundled PR groups, if any
- issues linked by PRs, and issues left without PRs with reasons
- validation commands run
- CI/check results
- follow-up issues
- items needing human judgment
- PR batch check/merge handoff block

PR batch check/merge handoff block:

```text
Use `pr-batch-check-merge` if it is installed.

Repository: <BASE_REPO_PATH>
Default branch: <DEFAULT_BRANCH>

PR readiness manifest:
- pr: <PR number or pending>
  issues: [<issue numbers>]
  mode: <independent | stacked | bundled | blocked>
  risk_lanes: [<risk lanes>]
  head_branch: <branch>
  base_branch: <branch>
  base_sha_at_handoff: <sha or unknown>
  head_sha_at_handoff: <sha or unknown>
  stack_parent: <PR/branch or none>
  stack_order: <position or none>
  replay_required: <true | false>
  replay_plan: <rebase | retarget | cherry-pick | none | unknown>
  replay_owner: <pr-batch-check-merge | human | blocked | none>
  validation: [<commands and results>]
  ci_state_observed: <passing | failing | pending | not-run | unknown>
  review_state_observed: <clear | findings-fixed | needs-review | unknown>
  machine_review_signals: <none | present | unknown>
  unresolved_risks: [<risks>]
  human_action_required: <true | false>
  next_action: <check-merge | replay-then-check | fix | wait | human-review>

Review these PRs in dependency order:
- <PR number>: <title> | mode: independent | base: <branch>
- <PR number>: <title> | mode: stacked | base: <prerequisite branch> |
  depends on: <PR number>
- <PR number>: <title> | mode: bundled | closes: <issues>

Check CI, review state, mergeability, conflicts, branch freshness,
branch-protection or merge-queue requirements, and stack order. Treat checks
for stacked PRs as provisional until their prerequisite PRs have merged and the
dependent PR has been replayed onto the latest default branch.

Do not merge anything unless the user explicitly grants merge authority for
this PR batch check/merge run. If merge authority is granted, the
`pr-batch-check-merge` skill should execute the live PR checks and merge or
queue only PRs that satisfy every gate.
```
````

## Output Requirements

Return:

1. the ranked issue list
2. the paste-ready autonomous development prompt
3. a paste-ready PR batch check/merge handoff block, included at the end of the
   autonomous development prompt

If the user asks only for the prompt, still include a short ranking rationale before the prompt unless they explicitly request "prompt only".

## Safety Notes

- Creating a prompt is not approval to perform dangerous actions.
- The generated prompt must explicitly gate external publishing, submissions, secret transmission, production mutation, irreversible actions, and financial actions.
- The generated implementation prompt may allow coding, tests, PR creation, and CI inspection when the user has requested autonomous development and the repository workflow supports it.
- The generated implementation prompt must not merge PRs. PR merge execution belongs in a separate PR batch check/merge run with explicit merge authority.
