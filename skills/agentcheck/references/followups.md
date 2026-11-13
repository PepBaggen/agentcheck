# Follow-ups

A report button sends `agentcheck: <action> [card N (file, function)]`. A typed "explain 3", "drop 2", "ship without 2", "make green" or "ship" means the same. Answer in chat, never with a new full report.

- **explain**: a deeper explanation of that card only: its callers, the data flow, a tiny before and after example.
- **drop**: show the exact hunks that would be reverted, grep whether other cards depend on them, say what breaks if they go. Revert only after an explicit yes, by editing those hunks (`git checkout` on the file only if the card is that file's whole change). Then offer to re-run the proof.
- **ship without**: no edits. Re-trace the cause chain without that card. If the card has its own file, run `revert-proof.sh` with `--keep` on every other changed path: the second run is then the change minus that card. Still passes (exit 1): the card is not needed for this test, answer yes, tag ran. Fails (exit 0): it is needed. Card shares a file with another card: answer from the re-traced chain, tag read.
- **make it green**: do the open steps (run the test, propose the small test, give the manual steps), report the result, update the verdict in one line.
- **ship it**: list what would be committed in one or two lines, then ask the ship question from `references/report.md`. Nothing is committed or pushed before Approve.

After any edit, show the diff and offer to re-run the proof: the diff is no longer the one that was proven.
