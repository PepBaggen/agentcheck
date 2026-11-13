# Report

Widget tool available (for example `mcp__visualize__show_widget`, loaded with ToolSearch if deferred): read `S/assets/report-template.html` (`S` is the skill directory), fill it, render it as one widget in the chat. No widget tool: read `references/report-markdown.md` instead of the template. Same sections either way.

Keep the `<style>` and `<script>` blocks, structure and class names exactly. Only replace `{{...}}` and repeat blocks as described. No HTML comments, no leftover `{{`. HTML-escape `<`, `>`, `&` in code lines. Every `L_*` is a label, translated.

- `SR_SUMMARY`: verdict and reason in one sentence.
- `TITLE`: the bug or feature in plain words, no code terms.
- `g|y|d` + `VERDICT`: one class. `g` "Push · low risk", `y` "Push after X", `d` "Do not push: reason".
- `L_WHAT` "What" + `WHAT`: the change in one sentence.
- `L_EVIDENCE` "Evidence" + `EVIDENCE`: the strongest single piece with its tag. Span class `g` only if ran, `y` if read, `d` if assumed or none.
- `L_RISK` "Open risk" + `RISK`: the one unproven thing and the minutes to check it. None: "none", class `g`.
- `L_EXAMPLE` "Example", `ACTION` → `GAVE`, `L_SHOULD_BE` "should be": `EXPECTED`. Feature: action → what happened before, "now": what happens.
- `L_READ_ORDER` "Read in this order", `N` card count, `L_FILES` "files".
- `L_PUSH` "Push" (or "Merge", "Commit", as asked) + `DECISION`: push or not, the risk accepted, the worst case.
- `MIN` + `STEPS`: pill with the minutes (class `g`, `y`, `d` by effort), then the steps to make it green. Nothing open: drop both and the `L_GREEN` button.
- `L_GREEN` "Make green", `L_SHIP` "Ship it".
- `L_DETAIL` "Evidence and risk in detail" + `EVIDENCE_LINES`: one line per claim, tag first, joined with `<br>`: both proof runs with command and result, chain steps, callers checked.
- `RISK_PILLS`: per card `<span class="p b g|y|d">` with card number and risk.
- `NOT_IN_COMMIT`: "Not in this commit: ..." for noise and unrelated hunks, or drop it.

## File card

The `<div class="f">` block, once per card, at most 4.

- Order by dependency, data first: migration, schema or model, query, service or domain logic, handler or route, client state, UI, then tests and config. `NO` is the reading order.
- `TYPE`: short pill naming the layer in the project's terms (schema, query, service, handler, component, test, config). `FILE`: the path, shortened if long. `FUNC`: the function, method or block that changed.
- Button titles `L_EXPLAIN` "Explain better", `L_WITHOUT` "Ship without it?", `L_DROP` "Drop this change".
- `NOW_DOES`: one plain sentence, what this file now does for the bug or feature.
- Diff rows: one `.r` div per line, about 6 per card. Context: class `r x`, empty `SIGN`. Removed: `r b d`, `-`. Added: `r b g`, `+`. `LN` is the real line number, `LINE` the code. Changed lines first, then one unchanged line above and below (two if there is room) to show where it sits. Long hunk: keep the lines that carry the change.
- `L_WHY` "Why this works" stays a closed `<details>`. `WHY`: which caller reaches this line (`file:line`) and why the new line changes the outcome.
- `.tp` span, optional: `LANG` and a one-sentence `TIP` on the language or framework rule the change leans on, only when a reader new to the stack would miss it. Else delete the span. Examples: JS `??` falls back only on null or undefined, `||` also on `0`. Python: a mutable default argument is shared between calls. Go: a nil map panics on write. SQL: `NULL = NULL` is not true. Rust: `?` returns the error early.
- Same change in several files: one card, name the others in the dropdown. More than 4: card the four that carry the chain, list the rest in the dropdown. Unrelated hunks get no card. All `<details>` stay closed.

## Short report

One file and under about 20 changed lines: one card, no evidence dropdown (delete the `details.ev` block). The Evidence cell keeps its tag. Anything assumed, any noise hunk and any untested caller goes into the push line, one clause each.

## Ship question

After the report, end the turn with one AskUserQuestion (no such tool: one plain line with the same choices). Question "Ship this change?", translated, three options:

- **Approve**: act on the ship preference. `push`: commit with a short message and push the branch. `commit`: commit only. `commands`: print the exact git commands in a bash block and do nothing. Never add AI attribution to a commit. Leave noise the user did not approve out of the commit.
- **Decline**: ask what should be different (the user types it in the Other or notes field), make only that change, then run the report again.
- **Leave as is**: do nothing, end.

Verdict Push: Approve first, marked recommended. Verdict Do not push: Decline first, and Approve is labelled "Approve anyway".

Ship preference: `~/.claude/agentcheck.json`, `{"ship": "push"|"commit"|"commands"}`. No file: use `commands` and say once, in one line, how to change it ("say: agentcheck always push"). When the user says that, write the file. If CLAUDE.md or memory says never commit or push, use `commands` whatever the file says.
