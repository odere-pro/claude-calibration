# After — CLAUDE.md trimmed, rules scoped

Project layout:

```
project/
├── CLAUDE.md                       # 80 lines (links + top-level conventions only)
└── .claude/rules/
    ├── testing.md                  # 80 lines  · paths: ["**/*.test.{ts,tsx,py}", "**/tests/**"]
    ├── frontend.md                 # 70 lines  · paths: ["src/**/*.{ts,tsx,css}", "app/**/*.{ts,tsx}"]
    ├── backend.md                  # 60 lines  · paths: ["server/**/*.ts", "api/**/*.ts"]
    ├── api.md                      # 50 lines  · paths: ["**/api/**/*.{ts,py}"]
    └── deployment.md               # 40 lines  · paths: ["infra/**", "deploy/**", "**/*Dockerfile*"]
```

Now only CLAUDE.md loads always-on: ~80 lines × 1.25 ≈ **100 tokens**. Each rule loads only when
Claude touches a matching file. Standing cost ≈ 100 tokens — comfortably under the 5,000-token
budget.

`lint.sh` no longer emits `general:context-budget-overflow`.
