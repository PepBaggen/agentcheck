# Proof by revert

Pick the narrowest existing test or repro command that shows the symptom or exercises the new behaviour. From inside the repo (`S` is the skill directory, as in SKILL.md):

```bash
bash S/scripts/revert-proof.sh [--keep PATH] [--link DIR] '<test command>' [base-ref]
```

It applies the change in a scratch worktree under `$TMPDIR`, runs the command (must pass), resets to the base, runs it again (must fail), prints a table and removes the worktree. The user's tree is never touched.

- `--keep PATH`: stays applied in both runs. Use it when the test or repro is itself new or changed in this diff (normal for a feature). Without it the second run fails because the test is missing, which proves nothing. Everything uncommitted counts as the change: if the tree holds other work, say so or `--keep` those paths too.
- `--link DIR`: symlinks an ignored directory (`node_modules`, `.venv`, `vendor`, `target`) from the original tree, since a fresh worktree has no dependencies. Repeatable. Ignored env files are absent too: if the test needs one, say so rather than copying secrets.
- Workspace symlinks: a linked directory can hold links back into the repo (workspace packages, editable installs), and code reached through them is not reverted. The script prints a WARNING and the result then does not count. Run a test that imports the changed code by path, or install dependencies inside the worktree, and say which.

Exit codes: 0 proven, 1 unproven, 2 usage, 3 no diff, 4 fails even with the change.

Read the output of the failing run before calling it proven. The failure must be the symptom (wrong value, missing row, thrown error) or the missing feature. Module-not-found, "no tests found" or a compile error is a broken run, not proof. The script only catches the shell-level version (exit 126 or 127).

Be blunt:

- Passes with, fails without, failure is the symptom: proven.
- Passes both ways: "Unproven: the test passes without the change, so either the change does nothing or the test does not cover it." Do not soften it.
- Fails with the change: the change or the environment is broken. Say which.
- No test or repro: "No proof: there is no test or repro for this." Propose the smallest test that would fail without the change (file, what it asserts, about how many lines). Do not write it without a yes. Only a manual check possible: give the exact steps and mark it manual, not ran.

Limits to be honest about:

- The proof shows this change makes this test pass, not that it is complete or that nothing else broke. The blast radius says where to look.
- It is only as good as the test. A test written after the change, to fit it, is weaker than one that existed before. Say which it was.
- The worktree has no ignored files, submodules or nested repos. A linked directory is the original one: caches written into it land in the user's tree, and build output from the first run can make the second pass. `kill -9` leaves the worktree behind: `git worktree remove --force <path>`.
- No git, or a change that depends on timing, database state or an external service: the proof is manual and the report says so.
