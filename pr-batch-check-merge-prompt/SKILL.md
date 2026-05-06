---
name: pr-batch-check-merge-prompt
description: Inspect a batch of GitHub pull requests, determine safe review and merge order, and draft a paste-ready prompt for a PR check/merge session. Use when the user wants to review, validate, queue, or merge multiple PRs after an autonomous implementation run.
---

# PR Batch Check/Merge Prompt

Turn a set of open pull requests into a safe, ordered PR check and merge
prompt.

Use this skill when the user wants:

- a batch of PRs checked after an autonomous implementation run
- dependency or stack order across multiple PRs
- CI, review, mergeability, and conflict triage
- a paste-ready prompt for a separate PR check/merge session
- merge execution guidance when the user explicitly grants merge authority

## Core Principle

Treat current repository evidence as authoritative.

Use this priority order:

1. live GitHub PR state, checks, reviews, mergeability, branch protection, and
   merge queue state
2. actual repository state, branches, and worktrees
3. PR body, linked issues, comments, and review threads
4. recent git history
5. docs and memory

Do not decide merge readiness from a stale implementation-session report alone.
Always refresh live PR state before drafting the prompt.

## Workflow

### 1. Resolve Repository and Authority

Start from the repository requested by the user. If none is provided, use the
current working directory.

Run:

```bash
git remote -v
git branch --show-current
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
repo_full_name="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
gh api "repos/${repo_full_name}/rulesets"
gh pr list --state open --limit 100 \
  --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,url
```

If rulesets or branch protection cannot be queried, record that gate as
`unknown` and block merge readiness instead of continuing as if no rules exist.

Determine whether the user explicitly granted merge authority for this run.
If merge authority is unclear, generated prompts must stop at checks,
classification, and recommendations.

### 2. Build the PR Candidate Set

Read PR details before deciding order.

Use `gh pr view <number>` with relevant JSON fields for:

- PRs explicitly mentioned by the user
- PRs listed in an implementation handoff prompt
- PRs whose branches appear in a stack
- PRs that touch related files or close related issues
- PRs that are likely prerequisites or dependents

Suggested fields:

```bash
gh pr view <number> \
  --json number,title,body,state,isDraft,headRefName,baseRefName,mergeStateStatus,reviewDecision,statusCheckRollup,commits,files,closingIssuesReferences,url
```

Use GraphQL or GitHub UI tooling when unresolved review threads or merge queue
details matter and the local `gh pr view` output is insufficient.

### 3. Build the Readiness Model

For each PR, build a compact readiness record:

- `facts`: PR number, linked issue numbers, mode, base branch, head branch, base
  SHA, head SHA, stack parent, stack order, touched risky surfaces, and author.
- `required_gates`: branch protection or ruleset policy, required checks and
  expected source apps, review policy, CODEOWNERS policy, unresolved-thread
  policy, merge queue requirement, and required code scanning or machine-review
  gates.
- `observed_state`: check conclusions and source apps, `reviewDecision`,
  requested reviewers, requested CODEOWNERS, unresolved review threads,
  approvals after latest push, `mergeStateStatus`, queue state, machine-review
  signals, and branch freshness.
- `decision`: `ready-to-merge`, `ready-to-enqueue`,
  `ready-after-prerequisite`, `needs-rebase-or-retarget`, `needs-review`,
  `needs-fix`, `blocked`, or `unknown`.

Unknown gate state is blocking. If rulesets, branch protection, expected check
sources, merge queue state, unresolved threads, or CODEOWNER requirements cannot
be verified, classify the PR as `unknown` or `blocked` and explain the missing
evidence.

Machine review signals such as reviewdog, Danger, code scanning, or AI review
comments are evidence, not human approval. They block merge only when they are
required checks, failing checks, required code-scanning protections, or explicit
repository policy.

### 4. Classify Each PR

Classify each PR as:

- `ready-to-merge`: non-draft, required checks passing, review state acceptable,
  mergeable against the current intended base, and no unresolved material
  blockers
- `ready-to-enqueue`: merge queue is required; normal PR gates are satisfied,
  but queue-context checks have not passed yet
- `ready-after-prerequisite`: stacked PR whose prerequisite must merge first
- `needs-rebase-or-retarget`: base branch or default-branch compatibility must
  be refreshed before checks are meaningful
- `needs-review`: required review, CODEOWNER review, or unresolved-thread
  evidence is missing or stale
- `needs-fix`: failing checks, unresolved material review comments, conflicts,
  or acceptance gaps
- `blocked`: missing permissions, ambiguous stack order, external approval,
  branch protection, merge queue state, or unclear ownership
- `unknown`: a required gate could not be verified

For stacked PRs, checks against a prerequisite branch are provisional. Do not
mark a stacked PR `ready-to-merge` until the prerequisite PR has merged, the
dependent branch has been replayed or retargeted onto the latest default branch,
and checks have passed in that final context.

For repositories using a merge queue, distinguish `ready-to-enqueue` from
`ready-to-merge`. A PR can pass PR checks and still fail merge queue checks
against the latest target branch plus queued changes. If required GitHub Actions
checks do not appear to support the `merge_group` event, flag the queue result
as `unknown` or `blocked` rather than assuming the queue will pass.

### 5. Determine Merge Order

Prefer this order:

1. prerequisite PRs
2. stacked dependents after replay onto the latest default branch
3. independent PRs that do not conflict
4. bundled PRs after verifying every linked issue is intentionally included

If two PRs touch the same risky surface, serialize them and re-check the second
after the first is merged or blocked.

Do not merge:

- draft PRs
- PRs with failing required checks
- PRs with unresolved material review threads
- PRs with missing or stale required reviews or CODEOWNER reviews
- stacked PRs still based on a prerequisite branch
- PRs whose mergeability or branch protection state is unknown
- PRs whose required check source app does not match the expected source
- PRs whose merge queue or `merge_group` readiness is unknown when a queue is
  required
- PRs requiring external approval the session does not have

### 6. Draft the PR Check/Merge Prompt

The prompt must be paste-ready. Include:

- repository path and repository name
- default branch
- merge authority status
- target PR list
- readiness records
- stack/dependency order
- per-PR checks to run
- classification rules
- explicit stop conditions
- merge commands only when merge authority is explicit; omit merge commands
  entirely when authority is not granted
- final-report format

## Prompt Template

Use this template and fill in repository-specific details.

```md
Check this PR batch for `<REPO>` and merge only if merge authority is explicit
in this prompt.

Repository: <REPO_PATH>
Default branch: <DEFAULT_BRANCH>
Merge authority: <explicitly granted | not granted>

Startup checks:
- `git fetch origin`
- `gh pr list --state open --limit 100`
- Inspect branch protection or rulesets for `<DEFAULT_BRANCH>` when available.
- For each target PR:
  - `gh pr view <number> --json number,title,body,state,isDraft,headRefName,baseRefName,mergeStateStatus,reviewDecision,statusCheckRollup,commits,files,closingIssuesReferences,url`
  - `gh pr checks <number>`
- If review-thread state, merge queue state, or branch protection is unclear,
  use GitHub GraphQL or the GitHub UI before deciding readiness.

Target PRs:
- #<PR1>: <title> | mode: <independent | stacked | bundled> | base: <branch>
- #<PR2>: <title> | mode: <independent | stacked | bundled> | base: <branch>
- #<PR3>: <title> | mode: <independent | stacked | bundled> | base: <branch>

Readiness record for each PR:
- facts:
  - pr: <number>
  - issues: [<issue numbers>]
  - mode: <independent | stacked | bundled>
  - base_branch: <branch>
  - head_branch: <branch>
  - base_sha: <sha or unknown>
  - head_sha: <sha or unknown>
  - stack_parent: <PR/branch or none>
  - stack_order: <position or none>
  - risky_surfaces: [<risk lanes>]
- required_gates:
  - branch_protection_or_ruleset: <known | unknown | none>
  - required_checks: [<check name + expected source app>]
  - review_policy: <required | optional | unknown>
  - codeowners_policy: <required | optional | unknown>
  - unresolved_thread_policy: <required | optional | unknown>
  - merge_queue: <required | optional | unknown>
  - required_machine_signals: [<code scanning/reviewdog/Danger/etc.>]
- observed_state:
  - checks: [<name, source, conclusion>]
  - reviewDecision: <APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | unknown>
  - requested_reviewers: [<users/teams>]
  - unresolved_review_threads: <none | present | unknown>
  - approvals_after_latest_push: <yes | no | unknown>
  - mergeStateStatus: <status>
  - queue_state: <not-required | queued | passed | failed | unknown>
  - machine_review_signals: <none | present | unknown>
- decision: <ready-to-merge | ready-to-enqueue | ready-after-prerequisite |
  needs-rebase-or-retarget | needs-review | needs-fix | blocked | unknown>

Classification:
- `ready-to-merge`: non-draft, required checks passing, review state acceptable,
  mergeable against the current intended base, and no unresolved material
  blockers. For merge-queue repositories, this means required queue-context
  checks have passed.
- `ready-to-enqueue`: merge queue is required; normal PR gates are satisfied,
  but queue-context checks have not passed yet.
- `ready-after-prerequisite`: stacked PR waiting for a prerequisite PR.
- `needs-rebase-or-retarget`: checks are stale because the base branch or
  default branch changed.
- `needs-review`: required review, CODEOWNER review, or unresolved-thread
  evidence is missing or stale.
- `needs-fix`: failing checks, unresolved material review comments, conflicts,
  or acceptance gaps.
- `blocked`: missing permissions, external approval, ambiguous stack order,
  branch protection, merge queue state, or unclear ownership.
- `unknown`: a required gate could not be verified.

Unknown-state policy:
- Treat unknown required gates as blocking.
- Do not treat a green check as satisfying protection if the expected source app
  is unknown or does not match.
- Do not treat `reviewDecision=APPROVED` as sufficient when CODEOWNERS,
  latest-push approval, stale approval, or unresolved-thread requirements are
  unknown.
- Treat machine-review signals as evidence, not human approval. They block only
  when required by checks, code-scanning protection, or explicit repo policy.

Stacked PR rules:
- Treat checks on a stacked PR as provisional while it is based on another PR
  branch.
- Merge or block the prerequisite first.
- After a prerequisite merges, replay the dependent branch onto the latest
  `<DEFAULT_BRANCH>` or retarget it as the repository workflow requires.
- Re-run checks in the final default-branch context before marking the dependent
  PR merge-ready.
- Do not merge a dependent PR solely because it passed against a prerequisite
  branch.

Merge queue rules:
- If a merge queue is required, classify a PR as ready to enqueue only after
  normal PR gates are satisfied.
- Required queue checks must pass in the merge queue context before the PR is
  considered merge-ready.
- If required GitHub Actions checks do not appear to support `merge_group`,
  mark queue readiness as unknown or blocked.

Merge policy:
- If merge authority is not explicitly granted, do not merge anything. Stop
  after classification and recommendations. Do not include merge commands in
  the generated prompt.
- If merge authority is explicitly granted, merge only PRs classified
  `ready-to-merge`.
- If merge authority is explicitly granted, add an `Authorized merge commands`
  section using the repository's normal merge method. If no method is specified
  and squash merge is allowed, generate one command per ready PR using the
  repository's squash-merge command.
- After each merge, refresh PR state before evaluating the next PR.
- If a PR fails checks, has unresolved material reviews, is draft, conflicts,
  or has unknown mergeability, do not merge it.

Final report:
- PRs merged
- PRs not merged and reasons
- checks and review state observed
- stacked PRs replayed or still waiting
- follow-up fixes needed
- decisions needing human judgment
```

## Output Requirements

Return:

1. PR order and classification
2. material blockers
3. the paste-ready PR check/merge prompt

## Safety Notes

- Creating a prompt is not approval to merge.
- Merge authority must be explicit in the current user request or in the
  generated prompt's stated authority line.
- Never merge when branch protection, review state, required checks, merge queue
  state, or stack order is unclear.
