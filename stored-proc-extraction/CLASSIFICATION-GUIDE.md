# Stored-Procedure Classification Guide

How to fill in the `strategy` column of `inventory-template.csv` for each of the ~1,771
articles' underlying procedures. Classify, don't guess — the strategy drives the effort.

## Decision tree

```mermaid
flowchart TD
    A[Read the stored proc] --> B{What does it primarily do?}
    B -->|Core business logic\n(posting, auth, rules)| C[relocate-springboot]
    B -->|Batch aggregation / reporting| D[glue-spark]
    B -->|Just copies/moves data| E[drop-dms-crud]
    B -->|Complex + not ready by cutover| F[defer-rds-sqlserver]
    C --> G{Feasible before EOL?}
    G -->|No| F
    G -->|Yes| H[Assign to target service + slice]
```

## Strategy values

| `strategy` | When | What happens |
|------------|------|--------------|
| `relocate-springboot` | Transactional/business logic | Reimplement in a Spring Boot `@Service`; DB reduced to CRUD via repository |
| `glue-spark` | Analytical/settlement batch | Move to the Glue Spark settlement pipeline (already in `infra`) |
| `drop-dms-crud` | Pure data movement / staging | Delete the proc; DMS + repository CRUD covers it |
| `defer-rds-sqlserver` | Too complex / low value / not ready | Park on RDS SQL Server (Phase 2b), convert later |

## Fields to capture per proc

- **business_purpose** — one of the 7 purposes (drives slicing).
- **complexity** — Simple / Medium / Complex (from SCT report + review).
- **reads_tables / writes_tables** — data footprint (informs repository design).
- **has_cursor / has_dynamic_sql** — red flags that raise effort and risk.
- **replication_articles** — how many of the 1,771 articles this proc's tables touch (so you
  know what to retire when the proc is gone).
- **target_service** — the Spring Boot service that will own the logic.

## Slicing by business purpose

Group procedures by `business_purpose` into the **7 purposes**. Migrate one slice at a time:
extract logic → parity test → cut over that slice → **retire that slice's replication
articles**. This keeps the fragile 1,771-article mesh shrinking safely (see the decommission
runbook in `../runbooks/`).

## Anti-patterns (do NOT do)

- ❌ Blindly port T-SQL → PL/pgSQL to keep logic in the DB (defeats the purpose).
- ❌ Big-bang extract all procs at once (unmanageable; no rollback granularity).
- ❌ Leave money math in the DB after cutover (must be in the app tier, tested for parity).
