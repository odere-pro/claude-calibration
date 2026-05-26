---
case: known-good-clean
class: known-good
workflow: code-review
---

# Expected — known-good-clean

A clean PR the workflow should pass without raising alarms. The `## Planted defects` table is
header-only: there is nothing to catch, so any finding the run records is a false positive and shows
up as a precision miss. All acceptance criteria are expected `met`.

## Planted defects

```tsv
id	node	signature	severity	must_catch	detail
```

## Edge contracts

```tsv
seam	signature	must_hold	detail
orchestrator->security-reviewer	handoff:diff-not-passed	yes	the same diff revision must reach the sub-reviewer
```

## Intent acceptance criteria

```tsv
ac	expect_status	owner_node	detail
adds-test	met	pr-test-analyzer	the change ships with a covering test
no-new-secrets	met	security-reviewer	no secrets committed in the diff
```
