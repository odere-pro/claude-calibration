---
case: known-defect-sqli
class: known-defect
workflow: code-review
---

# Expected — known-defect-sqli

The oracle for a PR-code-review workflow run over `input/`. Each table is a fenced `tsv` block; the
scorer (`../../scripts/score-flow.sh`) reads the data rows and ignores this prose. Signatures must
exist in [`rules/signatures.md`](../../../../rules/signatures.md) (gate G19 enforces it).

## Planted defects

Each `must_catch: yes` row counts against recall; catching it in the wrong `node`, or at a lower
severity than stated, does not count.

```tsv
id	node	signature	severity	must_catch	detail
d1	security-reviewer	review:security-missed	CRITICAL	yes	raw SQL string interpolation in the login query
d2	code-reviewer	review:quality-missed	MEDIUM	yes	unused import added in the diff
```

## Edge contracts

A `must_hold: yes` contract is violated when the run records its `handoff:*` signature in `actual.tsv`.

```tsv
seam	signature	must_hold	detail
orchestrator->security-reviewer	handoff:diff-not-passed	yes	the same diff revision must reach the sub-reviewer
security-reviewer->orchestrator	handoff:finding-dropped	yes	a CRITICAL finding must survive into the final synthesis
```

## Intent acceptance criteria

`owner_node: UNOWNED` marks a concern the intent needs that no node covers — a coverage gap.

```tsv
ac	expect_status	owner_node	detail
rate-limit-login	met	security-reviewer	the login endpoint must be rate-limited
no-new-secrets	met	security-reviewer	no secrets committed in the diff
v1-compat	blocked	UNOWNED	no node evaluates v1 API compatibility
```
