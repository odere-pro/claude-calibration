# Before — standing context blown past budget

Project layout:

```
project/
├── CLAUDE.md                       # 500 lines (extensive style guide, framework notes, conventions)
└── .claude/rules/
    ├── testing.md                  # 80 lines  · no paths: frontmatter
    ├── frontend.md                 # 70 lines  · no paths: frontmatter
    ├── backend.md                  # 60 lines  · no paths: frontmatter
    ├── api.md                      # 50 lines  · no paths: frontmatter
    └── deployment.md               # 40 lines  · no paths: frontmatter
```

Estimated standing cost: `500 + (80+70+60+50+40)` = 800 lines × 1.25 tokens/line ≈ **1000 tokens
from rules alone, ~6250 tokens total**.

`lint.sh` emits:

```
project  general:context-budget-overflow  MEDIUM  CLAUDE.md + unconditional rules ≈ ~6250tokens (> 5000tokens budget); trim CLAUDE.md and add paths: to rules
```

Every request pays the full cost, even when Claude is only editing a test file.
