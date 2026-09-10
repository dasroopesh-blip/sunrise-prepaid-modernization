# Runbooks — Cutover, Decommission, Rollback

Step-by-step operational runbooks for the risky moments of the program. Every cutover has an
explicit **rollback** path — for a payments system-of-record, we never cut over without one.

## Index

| Runbook | When | File |
|---------|------|------|
| **Phase 1 — SQL Server → EC2 Always On AG cutover** | Lift to AWS + HA | `01-phase1-ag-cutover.md` |
| **Phase 2a — SQL Server → Aurora PostgreSQL cutover** | Re-platform (per slice) | `02-phase2a-aurora-cutover.md` |
| **1,771-article replication decommission** | Retire bi-directional mesh | `03-replication-decommission.md` |
| **Rollback** | Any cutover fails | `04-rollback.md` |

## Golden rules

1. **No cutover without a tested rollback.**
2. **CDC stays running** until the cutover instant to minimize the freeze window.
3. **Reconcile financially** (`../validation/`) before flipping traffic — zero settled-amount drift.
4. **One slice at a time** for Phase 2 (by business purpose) — smaller blast radius.
5. **Beat the deadline:** all HA work (Phase 1) must complete before SQL Server 2016 EOL (Jul 14, 2026).
