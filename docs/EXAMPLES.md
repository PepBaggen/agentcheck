# Examples

Three short runs on small demo code. The reports are shown in the markdown
form, which is what you get without a widget tool.

Example 1 was run for real on a throwaway repo. Examples 2 and 3 are
illustrations of the same output on other stacks.

## 1. Bug fix: the order list skips the first ten orders

A Python shop API. Page 1 of the order list starts at order 11. The fix changes
two lines in `shop/pagination.py` and adds two tests.

You ask: "should I push this?"

```
$ revert-proof.sh --keep tests 'python3 -m unittest -q tests.test_pagination'
RUN           EXPECT  RESULT   EXIT
with fix      pass    PASS     0
without fix   fail    FAIL     1
VERDICT: PROVEN
  | AssertionError: 11 != 1
  | AssertionError: 2 != 3
```

> ## Order list skips the first ten orders · 🟢 Push · low risk
>
> | What | Evidence | Open risk |
> |---|---|---|
> | Page numbers are now 1-based and a partly filled last page is counted | 🟢 tests pass with the change, fail without it (ran) | 🟡 `export_orders` also calls `paginate` and has no test, 5 min |
>
> **Example:** open the order list on page 1 → 🔴 orders 11 to 20, should be: 🟢 orders 1 to 10
>
> **1 · `service` · `shop/pagination.py` · `page_bounds`**
> ```diff
>   def page_bounds(page, per_page):
> -     start = page * per_page
> +     start = (page - 1) * per_page
> ```
> Why this works: `list_orders` (shop/api.py:8) slices with these bounds. Pages
> are 1-based, so page 1 has to map to offset 0.
>
> **Push?** Yes. You accept that the CSV export is unchecked. 🟡 5 min: run the
> export for page 1 and check that the first row is order 1.
>
> Reply: explain 1 · drop 2 · ship without 2 · make green · ship

The rendered version of this report is the screenshot in the README.

## 2. Feature: export tasks as CSV

A TypeScript todo app gets a new "Export" button. The change adds a route, a
serializer and a test. You ask: "explain this change before I open the PR".

For a feature the report shows a goal and a path instead of a problem and a
cause. The test is new in this change, so it is kept in both runs with `--keep`.

```
$ revert-proof.sh --keep test/export.test.ts --link node_modules 'npx vitest run test/export.test.ts'
with fix      pass    PASS     0
without fix   fail    FAIL     1
  | Error: expected 404 to be 200
```

> ## Export your tasks as a CSV file · 🟡 Push after checking commas
>
> | What | Evidence | Open risk |
> |---|---|---|
> | A new `/tasks/export` route returns all your tasks as CSV | 🟢 the route test passes with the change and gets a 404 without it (ran) | 🟡 a task title with a comma is not quoted, 10 min |
>
> **Example:** click Export → 🔴 nothing, the button did not exist, now: 🟢 `tasks.csv` downloads
>
> **1 · `service` · `src/tasks/to-csv.ts` · `toCsv`** (new)
> **2 · `route` · `src/routes/tasks.ts` · `GET /tasks/export`**
> **3 · `test` · `test/export.test.ts`**
>
> **Push?** After one fix. `toCsv` joins fields with a comma and does not quote
> them (read, src/tasks/to-csv.ts:7), so "Buy milk, eggs" breaks the row.
> 🟡 10 min: quote the fields and add a test with a comma in the title.
>
> Not in this commit: a renamed variable in `src/routes/index.ts:12` (noise,
> keep or drop?)

## 3. Do not push: the test passes without the fix

A Go service returns the wrong day for users in other timezones. The change
converts the timestamp to the user's zone. The existing test is green. You ask:
"is this safe to merge?"

```
$ revert-proof.sh 'go test ./report/...'
RUN           EXPECT  RESULT   EXIT
with fix      pass    PASS     0
without fix   fail    PASS     0
VERDICT: UNPROVEN. The command passes with and without the fix.
```

> ## Daily report shows the wrong day for some users · 🔴 Do not push: unproven
>
> | What | Evidence | Open risk |
> |---|---|---|
> | The report date is now converted to the user's timezone | 🔴 unproven: the test passes without the change (ran) | 🔴 nothing shows that the fix does anything, 15 min |
>
> **Example:** a user in Tokyo opens the report at 08:00 → 🔴 yesterday's date, should be: 🟢 today's date
>
> **Push?** No. The test only uses UTC (read, report/daily_test.go:21), so it
> never reaches the changed line. 🔴 15 min: add a test case with
> `Asia/Tokyo` at 23:30 UTC. It should fail without the change.

"Make green" then proposes that test, and writes it only after you say yes.
After that the proof is run again.
