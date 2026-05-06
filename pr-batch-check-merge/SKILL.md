---
name: pr-batch-check-merge
description: Inspect a batch of GitHub pull requests, determine safe merge order, execute merges or merge-queue enqueue for PRs that satisfy all gates when the user explicitly asks to merge, and report blockers. Use when the user wants to review, validate, queue, or merge multiple PRs after an autonomous implementation run.
---

# PR Batch Check/Merge

Check the live PR queue in the current session. If the user explicitly asked
to merge safe PRs, merge or enqueue the PRs that satisfy every required gate.
Do not draft a prompt unless the user explicitly asks for a prompt.

Use this skill when the user wants:

- a batch of PRs checked after an autonomous implementation run
- dependency or stack order across multiple PRs
- CI, review, mergeability, and conflict triage
- safe PRs merged or added to a required merge queue
- a concise report of merged PRs and blocked PRs

## Core Principle

Treat current repository evidence as authoritative.

Use this priority order:

1. live GitHub PR state, checks, reviews, mergeability, branch protection, and
   merge queue state
2. actual repository state, branches, and worktrees
3. PR body, linked issues, comments, and review threads
4. recent git history
5. docs and memory

Never decide merge readiness from a stale implementation-session report alone.
Always refresh live PR state immediately before merging or enqueueing a PR.

## Safety Boundary

Merge authority must be explicit in the current user request. Treat requests
such as "check and merge these PRs" or "merge the PRs that are safe" as merge
authority for PRs classified `ready-to-merge`. This is merge authority for PRs
classified `ready-to-merge`; it is not authority for blocked or unknown PRs. If
the user asks only to check, review, summarize, or prepare a prompt, stop after
classification and report.

Never use `--admin`, bypass a merge queue, force-push, delete non-PR branches,
or merge a PR with unknown required gates.

## Workflow

### 1. Resolve Repository and Authority

Start from the repository requested by the user. If none is provided, use the
current working directory.

Run:

```bash
git remote -v
git status --short --branch
git fetch origin
default_branch="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
repo_full_name="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
gh api "repos/${repo_full_name}/rulesets"
gh api "repos/${repo_full_name}/branches/${default_branch}/protection" || true
gh pr list --state open --limit 100 \
  --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,url
```

If rulesets or branch protection cannot be queried, record that gate as
`unknown` and block merge readiness instead of continuing as if no rules exist.

### 2. Build the PR Candidate Set

Read PR details before deciding order.

Use `gh pr view <number>` with relevant JSON fields for:

- PRs explicitly mentioned by the user
- PRs listed in an implementation handoff block
- PRs whose branches appear in a stack
- PRs that touch related files or close related issues
- PRs that are likely prerequisites or dependents

Suggested fields:

```bash
gh pr view <number> \
  --json number,title,body,state,isDraft,headRefName,baseRefName,mergeStateStatus,reviewDecision,statusCheckRollup,commits,files,closingIssuesReferences,url
gh pr checks <number>
```

Use GraphQL or GitHub UI tooling when unresolved review threads, latest-push
approval, CODEOWNER review, or merge queue details matter and the local `gh pr
view` output is insufficient.

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
  blockers. For a merge-queue repository, queue-context requirements have
  passed or `gh pr merge` can safely add the PR to the required queue.
- `ready-to-enqueue`: merge queue is required; normal PR gates are satisfied,
  but queue-context checks have not passed yet.
- `ready-after-prerequisite`: stacked PR whose prerequisite must merge first.
- `needs-rebase-or-retarget`: base branch or default-branch compatibility must
  be refreshed before checks are meaningful.
- `needs-review`: required review, CODEOWNER review, or unresolved-thread
  evidence is missing or stale.
- `needs-fix`: failing checks, unresolved material review comments, conflicts,
  or acceptance gaps.
- `blocked`: missing permissions, ambiguous stack order, external approval,
  branch protection, merge queue state, or unclear ownership.
- `unknown`: a required gate could not be verified.

For stacked PRs, checks against a prerequisite branch are provisional. Do not
merge a stacked PR until the prerequisite PR has merged, the dependent branch
has been replayed or retargeted onto the latest default branch, and checks have
passed in that final context.

For repositories using a merge queue, distinguish `ready-to-enqueue` from
`ready-to-merge`. If required GitHub Actions checks do not appear to support
the `merge_group` event, flag the queue result as `unknown` or `blocked` rather
than assuming the queue will pass.

### 5. Determine Merge Order

Prefer this order:

1. prerequisite PRs
2. stacked dependents after replay onto the latest default branch
3. independent PRs that do not conflict
4. bundled PRs after verifying every linked issue is intentionally included

If two PRs touch the same risky surface, serialize them and re-check the second
after the first is merged, queued, or blocked.

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

### 6. Execute Merge or Queue Actions

For each PR in merge order:

1. Refresh immediately before action:

   ```bash
   git fetch origin
   gh pr view <number> \
     --json number,title,state,isDraft,headRefName,baseRefName,mergeStateStatus,reviewDecision,statusCheckRollup,commits,url
   gh pr checks <number>
   ```

2. Rebuild the readiness record from refreshed evidence.
3. If the decision is not `ready-to-merge` or `ready-to-enqueue`, do not merge
   or enqueue it. Record the blocker and continue to the next independent PR.
4. Capture the exact head SHA from the refreshed PR data.
5. If no merge queue is required and the PR is `ready-to-merge`, use the
   repository's normal merge method. If no method is specified and squash merge
   is allowed, run:

   ```bash
   gh pr merge <number> --squash --delete-branch --match-head-commit <head_sha>
   ```

6. If a merge queue is required and the PR is `ready-to-enqueue`, do not pass a
   merge strategy. Add the PR to the queue or enable auto-merge with:

   ```bash
   gh pr merge <number> --auto --delete-branch --match-head-commit <head_sha>
   ```

7. After each merge or queue action, refresh PR and default-branch state before
   evaluating the next PR.

If `gh pr merge` fails, do not retry with weaker checks. Re-read the error,
refresh PR state, classify the PR again, and report the blocker.

## Output Requirements

Return:

1. PR order and final classification
2. PRs merged
3. PRs queued or auto-merge-enabled
4. PRs not merged and reasons
5. checks and review state observed
6. stacked PRs replayed or still waiting
7. follow-up fixes needed
8. decisions needing human judgment
