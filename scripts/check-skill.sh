#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_file="$repo_root/issue-autonomy-prompt/SKILL.md"
pr_skill_file="$repo_root/pr-batch-check-merge/SKILL.md"
old_pr_skill='pr-batch-check-merge-''prompt'

fail() {
  printf 'check-skill: %s\n' "$1" >&2
  exit 1
}

[[ -f "$skill_file" ]] || fail "missing issue-autonomy-prompt/SKILL.md"
[[ -f "$pr_skill_file" ]] || fail "missing pr-batch-check-merge/SKILL.md"
[[ ! -e "$repo_root/$old_pr_skill" ]] \
  || fail "old PR prompt skill directory must not exist"

grep -q '^name: issue-autonomy-prompt$' "$skill_file" \
  || fail "missing expected skill name"

grep -q '^name: pr-batch-check-merge$' "$pr_skill_file" \
  || fail "missing expected PR skill name"

grep -q 'Worktree and lane strategy' "$skill_file" \
  || fail "missing worktree strategy section"

grep -q 'Only when creating a new `<BATCH_WORKTREE_PATH>`' "$skill_file" \
  || fail "worktree creation must be conditional"

grep -q 'Merge only if the user explicitly requested merge authority' "$skill_file" \
  && fail "implementation skill must not merge"

grep -q 'Do not merge PRs in this implementation session' "$skill_file" \
  || fail "implementation skill must stop before merge"

grep -q 'stacked PR checks are provisional' "$skill_file" \
  || fail "implementation skill must preserve stacked PR check caveat"

grep -q 'Classify Risk Lanes' "$skill_file" \
  || fail "implementation skill must classify risk lanes"

grep -q 'Build Execution Lanes' "$skill_file" \
  || fail "implementation skill must classify execution lanes"

grep -q 'Decompose Umbrella Issues' "$skill_file" \
  || fail "implementation skill must define umbrella decomposition"

grep -q 'PR readiness manifest' "$skill_file" \
  || fail "implementation skill must emit PR readiness manifest"

grep -q 'base_sha_at_handoff' "$skill_file" \
  || fail "manifest must include base SHA"

grep -q 'replay_owner' "$skill_file" \
  || fail "manifest must include replay owner"

grep -q '^````md$' "$skill_file" \
  || fail "issue prompt template must use four-backtick fence for nested handoff"

if grep -RInE 'tmp/|STATUS_FILE|status[- ]file|status memo' \
  "$skill_file" "$repo_root/examples" "$repo_root/README.md"; then
  fail "implementation prompt must not require tmp status files"
fi

grep -q 'Do not create progress memo' "$skill_file" \
  || fail "implementation skill must forbid progress memo files"

grep -q 'Do not optimize for the smallest possible diff' "$skill_file" \
  || fail "implementation skill must include architecture-first philosophy"

grep -q 'refactor it instead of adding compatibility layers or patching around it' "$skill_file" \
  || fail "implementation skill must prefer refactor over compatibility patches"

grep -q 'Separate mechanical refactors from behavior changes' "$skill_file" \
  || fail "implementation skill must separate refactors from behavior changes"

grep -q 'Preserve existing behavior unless the task explicitly changes it' "$skill_file" \
  || fail "implementation skill must preserve behavior by default"

grep -q 'Add or update tests around affected behavior' "$skill_file" \
  || fail "implementation skill must require tests around affected behavior"

grep -q 'Run lint, typecheck, and relevant tests' "$skill_file" \
  || fail "implementation skill must require lint typecheck and relevant tests"

grep -q 'important architectural changes' "$skill_file" \
  || fail "implementation skill final report must include architectural changes"

grep -q 'Do not wait for full CI completion by default' "$skill_file" \
  || fail "implementation skill must avoid default full CI waits"

grep -q 'ci_state_observed: pending' "$skill_file" \
  || fail "implementation skill must record pending CI in manifest"

grep -q 'leave final CI gating to `pr-batch-check-merge`' "$skill_file" \
  || fail "implementation skill must hand final CI gating to PR merge skill"

if grep -RIn -- '--watch' "$skill_file" "$repo_root/examples/serial-batch-prompt.example.md"; then
  fail "implementation prompt must not require waiting on full CI"
fi

grep -q 'Merge authority must be explicit' "$pr_skill_file" \
  || fail "PR skill must require explicit merge authority"

grep -q 'explicit invocation of `pr-batch-check-merge` or "PR Batch Check Merge"' "$pr_skill_file" \
  || fail "PR skill must treat skill invocation with target PRs as merge authority"

grep -q 'Target PRs in dependency order' "$pr_skill_file" \
  || fail "PR skill must recognize target PR dependency-order usage"

grep -q 'Explicit negative wording wins' "$pr_skill_file" \
  || fail "PR skill must let check-only requests override merge execution"

grep -q 'Do not draft a prompt' "$pr_skill_file" \
  || fail "PR skill must execute rather than draft prompts"

grep -q 'classification and report' "$pr_skill_file" \
  || fail "PR skill must stop without merging for check-only requests"

grep -q 'This is the authoritative CI gate' "$pr_skill_file" \
  || fail "PR skill must own final CI gating"

grep -q 'gh pr checks <number> --watch' "$pr_skill_file" \
  || fail "PR skill must wait for required checks when needed"

grep -q 'checks remain pending, missing' "$pr_skill_file" \
  || fail "PR skill must block unresolved required checks"

grep -q 'rebuild the readiness record again' "$pr_skill_file" \
  || fail "PR skill must rebuild readiness after waiting for checks"

grep -q 'merge or enqueue the PRs' "$pr_skill_file" \
  || fail "PR skill must perform merge or queue actions"

grep -q 'merge a stacked PR until' "$pr_skill_file" \
  || fail "PR skill must handle stacked PR provisional checks"

grep -q 'Build the Readiness Model' "$pr_skill_file" \
  || fail "PR skill must define readiness model"

grep -q 'Unknown gate state is blocking' "$pr_skill_file" \
  || fail "PR skill must block unknown required gates"

grep -q 'expected source apps' "$pr_skill_file" \
  || fail "PR skill must track expected check source apps"

grep -q 'merge_group' "$pr_skill_file" \
  || fail "PR skill must handle merge queue checks"

grep -q 'ready-to-enqueue' "$pr_skill_file" \
  || fail "PR skill must distinguish queue enqueue readiness"

grep -q 'repo_full_name=' "$pr_skill_file" \
  || fail "PR skill must derive executable repo ruleset path"

ruleset_placeholder='repos/<owner>/<repo>/rule''sets'
if grep -q "$ruleset_placeholder" "$pr_skill_file"; then
  fail "PR skill contains non-executable rulesets placeholder"
fi

grep -q 'Machine review signals' "$pr_skill_file" \
  || fail "PR skill must classify machine review signals"

merge_cmd='gh pr mer''ge'
if grep -RIn "$merge_cmd" "$skill_file"; then
  fail "implementation skill must not contain merge command"
fi

grep -q "$merge_cmd <number> --squash --delete-branch --match-head-commit <head_sha>" "$pr_skill_file" \
  || fail "PR skill must execute direct merge with head SHA guard"

grep -q "$merge_cmd <number> --auto --delete-branch --match-head-commit <head_sha>" "$pr_skill_file" \
  || fail "PR skill must enqueue merge-queue PRs with head SHA guard"

grep -q 'Never use `--admin`' "$pr_skill_file" \
  || fail "PR skill must forbid admin bypass"

grep -q 'authority for PRs classified `ready-to-merge`' "$pr_skill_file" \
  || fail "PR skill must define merge-run authority"

grep -q 'Do not draft a prompt' "$pr_skill_file" \
  || fail "PR skill must avoid prompt-only behavior"

grep -q 'PR Batch Check Merge' "$skill_file" \
  || fail "issue handoff must invoke the PR merge skill by heading"

grep -q 'Target PRs in dependency order' "$skill_file" \
  || fail "issue handoff must use target PR dependency-order format"

if grep -RIn 'Do not merge anything unless the user explicitly grants merge authority' \
  "$skill_file" "$repo_root/examples"; then
  fail "issue handoff should not require extra merge wording after invoking merge skill"
fi

if grep -RIn "$merge_cmd" README.md examples; then
  fail "README/examples should not hard-code merge execution"
fi

if grep -RIn "$old_pr_skill" README.md issue-autonomy-prompt examples pr-batch-check-merge scripts; then
  fail "found old PR prompt skill name"
fi

old_skill="github-issue-autonomy-""planner"
product_name="Pul""Seed"
if grep -RInE "$old_skill|Codex/$product_name|$product_name" "$repo_root"; then
  fail "found old or personal naming"
fi

if ! python3 - "$repo_root" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
bad = []
for path in sorted(root.rglob("*")):
    if ".git" in path.parts or not path.is_file():
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for ch in text:
        code = ord(ch)
        if (
            0x3040 <= code <= 0x309F
            or 0x30A0 <= code <= 0x30FF
            or 0x3400 <= code <= 0x9FFF
        ):
            bad.append(str(path))
            break
if bad:
    print("\n".join(bad))
    sys.exit(1)
PY
then
  fail "found non-English Japanese text"
fi

unsafe_merge_a='CI green.*mer''ge'
unsafe_merge_b='LGTM.*mer''ge'
if grep -RInE "$unsafe_merge_a|$unsafe_merge_b" "$repo_root"; then
  fail "found unconditional merge wording"
fi

printf 'check-skill: ok\n'
