---
case: good-clean
class: known-good
workflow: code-review
---
## Planted defects
```tsv
id	node	signature	severity	must_catch	detail
```
## Edge contracts
```tsv
seam	signature	must_hold	detail
orchestrator->security-reviewer	handoff:diff-not-passed	yes	same diff reaches sub-reviewer
```
## Intent acceptance criteria
```tsv
ac	expect_status	owner_node	detail
adds-test	met	pr-test-analyzer	ships with a test
```
