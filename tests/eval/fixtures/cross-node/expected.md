---
case: cross-node
class: known-defect
workflow: code-review
---
## Planted defects
```tsv
id	node	signature	severity	must_catch	detail
d1	security-reviewer	review:security-missed	CRITICAL	yes	SQL injection
```
## Edge contracts
```tsv
seam	signature	must_hold	detail
```
## Intent acceptance criteria
```tsv
ac	expect_status	owner_node	detail
```
