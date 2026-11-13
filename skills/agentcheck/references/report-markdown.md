# Markdown fallback

Only without a widget tool. Same content and card rules as `references/report.md`, labels translated. 🟢 ran or low risk, 🟡 read or medium, 🔴 assumed, high or do not push. Tip line only when useful. Feature: "should be" becomes "now". Short report: leave out the detail list. Always end with the Reply line.

````markdown
## <title> · 🟢 Push · low risk

| What | Evidence | Open risk |
|---|---|---|
| <one sentence> | 🟢 <strongest evidence> (ran) | 🟡 <risk, N min> or 🟢 none |

**Example:** <action> → 🔴 <what it gave>, should be: 🟢 <expected>

### Read in this order · <N> files

**1 · `<type>` · `path/to/file` · `functionName`**
<what this file now does>
```diff
  <context line>
- <removed line>
+ <added line>
```
Why this works: <explanation with caller file:line>
Tip (<language>): <one sentence>

> **Push?** <decision, risk accepted, worst case>. 🟡 <N min>: <steps to green>

**Evidence and risk in detail**
- 🟢 ran: `<command>` passes with the change, fails without it (<symptom>)
- 🟡 read: <claim> (`file:line`)
- 🔴 assumed: <claim>
- Risk per card: 1 🟢 · 2 🟡
- Not in this commit: <noise and unrelated hunks, or none>

Reply: explain 1 · drop 2 · ship without 2 · make green · ship
````
