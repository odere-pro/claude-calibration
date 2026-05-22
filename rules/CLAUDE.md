# CLAUDE.md — `rules`

## Scope

Two **path-scoped** rule files that ship with the plugin. Both carry `paths:` frontmatter so they
load only when calibration files are open — zero standing context otherwise (gate G6).

- `signatures.md` — the canonical **pattern-signature catalogue** (`<feature>:<short-name>` + default
  severity + trigger).
- `dispatch.md` — the **signature → bundle** map (which bundle owns the fix; recurrence archetypes).

## The four-places-in-sync rule (the load-bearing invariant)

A pattern signature is a **public contract** — the planner's recurrence detector keys on the literal
string, and older `eval-*.md` reports use the old name. **Never rename a signature in flight.**

Adding or changing a signature touches **four** places, all of which must agree:

```
1. rules/signatures.md                              ── the catalogue row
2. skills/calibrate-<feature>/reference.md          ── its "Pattern signatures" row
3. skills/calibrate-<feature>/scripts/lint.sh       ── the emit
4. rules/dispatch.md                                ── only if it has a kind:create archetype
```

A signature missing from any of these is invisible somewhere in the pipeline. Gate **G7**
(`tests/gates/07-signature-dispatch-integrity.sh`) checks the dispatch ↔ catalogue half.

## Invariants you must not break

- **Every rule has `paths:`** (gate G6, and the `plugin-dev-guard` hook) — an unconditional shipped
  rule loads always-on for every user who enables the plugin. (`CLAUDE.md` here is a briefing, not a
  rule, and is exempt in both the gate and the hook.)
- **Signature names are lowercase, hyphenated, `<feature>:` prefixed**; thresholds embedded in the
  name (`over-200`) — change the threshold, change the name, and the planner treats `over-N`/`over-M`
  as one family.
- **Bundle ownership**: each signature prefix maps to exactly one bundle (see `dispatch.md`'s
  ownership table). `general:*` rolls up cross-feature findings.

## Editing checklist

- [ ] New/changed signature reflected in all four places above.
- [ ] `paths:` frontmatter present on every rule file.
- [ ] `bash tests/gates/06-rules-have-paths.sh` and `bash tests/gates/07-signature-dispatch-integrity.sh` green.

## How to test this area

- `bash tests/gates/07-signature-dispatch-integrity.sh` — dispatch signatures exist in the catalogue;
  bundles well-formed.
- `bash tests/gates/06-rules-have-paths.sh` — `paths:` present.

## When in doubt

Full house rules: [`../.claude/rules/plugin-dev.md`](../.claude/rules/plugin-dev.md). The catalogue
itself is [`signatures.md`](signatures.md); the routing is [`dispatch.md`](dispatch.md).
