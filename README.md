# Issue Autonomy Prompt

A small Codex skill set for turning GitHub issue and PR queues into focused,
paste-ready prompts for autonomous coding sessions.

It contains two companion skills:

- `issue-autonomy-prompt`: ranks open issues and drafts an implementation prompt
  that opens ready PRs without merging them.
- `pr-batch-check-merge-prompt`: drafts a PR queue check/merge prompt for the
  PRs produced by an implementation run.

The issue skill helps a coding agent:

- inspect live GitHub issue state before choosing work
- rank issues by dependency, risk, and leverage
- create a bounded batch plan
- draft a prompt that starts from a clean worktree
- classify risk lanes and parallel-safe lanes
- decompose umbrella issues before implementation
- choose independent, stacked, bundled, or blocked execution modes
- emit a compact PR readiness manifest for integration handoff
- keep PR creation, validation, and merge handoff explicit

The PR skill helps a coding agent:

- inspect live PR state before deciding readiness
- classify PRs with facts, required gates, observed state, and a readiness
  decision
- check branch protection, rulesets, required checks, reviews, conflicts, stack
  order, merge queue state, and mergeability
- treat stacked PR checks as provisional until replayed onto the default branch
- treat unknown required gates as blocking
- merge only when merge authority is explicit

## Install

Copy both skill directories into your Codex skills directory:

```bash
mkdir -p ~/.codex/skills
rsync -a issue-autonomy-prompt/ ~/.codex/skills/issue-autonomy-prompt/
rsync -a pr-batch-check-merge-prompt/ ~/.codex/skills/pr-batch-check-merge-prompt/
```

Restart or refresh your Codex session so the skill list is reloaded.

## Usage

Ask Codex to use `issue-autonomy-prompt` when you want a ranked issue plan or a
prompt for another session:

```text
Use issue-autonomy-prompt for this repository. Pick the next five open issues
to tackle, explain the order, and draft a prompt for a separate autonomous
coding session.
```

The generated prompt is designed to verify current repository and issue state
before editing. It also includes a worktree setup path so the implementation
session can work away from the base checkout.

For larger batches, the issue skill can classify parallel-safe lanes. If the
environment cannot run multiple coding sessions, the generated prompt should
serialize those lanes while preserving the metadata for later integration.

After the implementation session opens PRs, use `pr-batch-check-merge-prompt`
to prepare a separate PR queue check/merge prompt:

```text
Use pr-batch-check-merge-prompt for these PRs. Check CI, reviews, conflicts,
stack order, and mergeability. Merge only if merge authority is explicit.
```

## Safety Defaults

The skill should not treat prompt creation as permission to perform dangerous
actions. Generated prompts should gate external publishing, secret transmission,
production mutation, irreversible actions, financial actions, and merge
authority behind explicit user permission.

By default, implementation prompts tell the session to open ready PRs and
inspect checks, but not merge. Merge execution is handled by the companion PR
skill and only when the user explicitly grants merge authority for that run.

## Development

Run the lightweight checker before publishing changes:

```bash
scripts/check-skill.sh
```

Do not tag a release until you have tried the installed skill in a real Codex
session and reviewed the generated prompt shape.
