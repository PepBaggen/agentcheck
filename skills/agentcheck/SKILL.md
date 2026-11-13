---
name: agentcheck
description: Explains and proves a code change (bug fix or feature, any language) before commit, push or merge. One fixed one-minute report (what changed, evidence, open risk, files in reading order with diff and why it works, push decision), backed by a proof by revert. Use after local testing, on bigger or multi-file changes, or when the user says "should I push this", "can I push", "is this safe to merge", "why does this fix work", "explain this fix", "explain this change", "what did this actually change", "review before commit", "I don't understand this diff". Not a bug hunt, style or security review.
---

# Agentcheck

A green test shows the code works now, not that this change is the reason. Tie every hunk to a step in the cause of the bug, prove it by revert, show one fixed report. Feature: Problem becomes Goal, the cause chain becomes the path through the new code, the example is before → now.

## Rules

- Read-only on the working tree and index: no staging, stash or checkout. Edit, commit or push only after an explicit yes (Approve counts). The user decides.
- Plain writing, short sentences, no em dashes, no Co-Authored-By or other AI attribution anywhere.
- Report in the user's language, labels included. Code, paths, commands and tags stay as is.
- No padding: an empty part is "none". Never write the report to a file.
- Every claim has a tag: **ran** (command and output), **read** (`file:line`) or **assumed** (not checked). Sureness is that tag, never a feeling. Never present an unchecked claim as ran or read.

## Token rules

- Read code with grep or line ranges, never whole files.
- Stat first, then diff only the files that matter. Never paste the full diff back.
- Read a `references/` file or the template only at the step that names it, once.
- Call the visual tool's `read_me` at most once per session, one module (`mockup`). Skip it if already loaded.
- At most 4 cards, about 6 diff rows each.
- Small change (one file, under about 20 changed lines): short report, one card, no evidence dropdown.

## Steps

`S` is `${CLAUDE_SKILL_DIR}`, the skill directory.

1. **Collect.** `bash S/scripts/collect-diff.sh [base-ref]` prints status, stat and untracked names. Pass the base branch if the change is committed. Then `[base-ref] --diff <paths>` for the files that matter, `--show <file>` for a new file. Number the hunks H1, H2. No diff: say so and stop. Session knowledge (repro, failing output, the ask) is a lead: re-check it against the code.
2. **Chain.** Fix: the symptom in one sentence as the user saw it, no code terms, then 3 to 5 steps back to the root cause, each a plain sentence with `file:line`, each causing the next, read from the base (`git show <base>:path`). Feature: the goal, then 3 to 5 steps from entry point to effect. Never from memory. A step without a line is `assumed`.
3. **Map.** One line per hunk: which step it cuts (fix) or carries (feature). No step: noise. No hunk maps to any step: the change works by accident or the chain is wrong. Say so and re-trace.
4. **Proof by revert.** Read `references/revert-proof.md` and follow it. Never by hand with stash or checkout.
5. **Noise.** Each hunk outside the chain (refactor, rename, debug leftover, formatting, lockfile churn, impossible-case guard, unrelated work): one line with `file:line`, what it is, keep or drop? Drop nothing yourself.
6. **Blast radius.** Grep the other callers of each function, type, query, config key or export whose behaviour changed. List those the proof did not exercise, with `file:line` and whether they could change. Search results only. Above about eight: the count and the riskiest few.
7. **Report.** Read `references/report.md` and follow it, also for the short report. Order, always: title and verdict · What, Evidence, Open risk · Example · Read in this order (cards with diff and why this works) · Push? · Evidence and risk in detail.
8. **Ship question.** End the turn with one AskUserQuestion ("Ship this change?": Approve, Decline, Leave as is) as in `references/report.md`. Approve acts on the ship preference in `~/.claude/agentcheck.json` (`push`, `commit` or `commands`, default `commands`). After any edit the user agreed to: make exactly that change, show the diff, offer to re-run the proof. A teach-back ("say it back in one sentence") is offered once, never forced.

## Follow-ups

A report button sends `agentcheck: <action> [card N (file, function)]`; a typed "explain 3" means the same. Read `references/followups.md`, then answer in chat without a new report: explain (that card, deeper), drop (show the hunks, revert only after a yes), ship without (analysis, no edits), make it green (do the open steps), ship it (the ship question).
